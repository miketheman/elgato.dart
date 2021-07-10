import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';

// Store the results of the IP lookup locally to speed things up
final cacheFile = join(HOME, ".elgato.dart.cache");

var lightIpPorts = [];
var urls = lightIpPorts.map((x) => Uri.parse('http://$x/elgato/lights'));

/// Discover Elgato lights on the network
findLights() async {
  final String svcName = "_elg";
  final MDnsClient client = MDnsClient();
  await client.start();

  var svcPointer = ResourceRecordQuery.serverPointer(svcName);
  await for (var ptr in client.lookup<PtrResourceRecord>(svcPointer)) {
    var svcQuery = ResourceRecordQuery.service(ptr.domainName);
    await for (var srv in client.lookup<SrvResourceRecord>(svcQuery)) {
      var svcName = ResourceRecordQuery.addressIPv4(srv.target);
      await for (var ip in client.lookup<IPAddressResourceRecord>(svcName)) {
        lightIpPorts.add('${ip.address.host}:${srv.port}');
      }
    }
  }
  client.stop();
}

// Flip zeroes and ones
flipInt(inputInt) {
  return inputInt = 1 - inputInt;
}

/// Switch a light
Future<bool> flipSwitch(var url) async {
  var rawResponse;

  try {
    // Await the HTTP GET response, then decode the JSON-formatted response
    rawResponse = await http.get(url).timeout(const Duration(seconds: 3));
  } on TimeoutException {
    print('Timed out calling lights, exiting...');
    return false;
  } on SocketException catch (e) {
    print("Failed to connect to light, error:\n${e}");
    return false;
  }
  var currentState = convert.jsonDecode(rawResponse.body);

  // Flip the light's `on` value
  currentState['lights'].forEach((light) => light['on'] = flipInt(light['on']));

  // Update the light with the newly flipped value
  await http.put(url, body: convert.jsonEncode(currentState));

  return true;
}

void main() async {
  if (exists(cacheFile)) {
    read(cacheFile).forEach((line) => lightIpPorts.add(line));
  } else {
    await findLights();
    if (cacheFile.isNotEmpty) {
      cacheFile.write(lightIpPorts.join('\n'));
      print("Wrote ${lightIpPorts.join(', ')} to ${cacheFile}.");
    }
  }

  if (lightIpPorts.isEmpty) {
    print("No lights found, exiting...");
    exit(2);
  }

  // Execute flipSwitch() for all URLs in parallell
  Future.wait(urls.map((url) => flipSwitch(url))).then((List<bool> retValues) {
    // Return exit code 2 if any of the lights failed to flip
    if (retValues.any((x) => x == false)) {
      exit(2);
    }
  });
}
