import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';

// We store the results of the IP lookup in a file for future speedups
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

// Flips zeroes and ones
flipInt(inputInt) {
  return inputInt = 1 - inputInt;
}

/// Flips the lights
Future<bool> flipSwitch(var url) async {
  var rawResponse;

  try {
    // Await the http get response, then decode the json-formatted response.
    rawResponse = await http.get(url).timeout(const Duration(seconds: 3));
  } on TimeoutException {
    // If we didn't get a response, bail.
    print('timed out calling lights, exiting...');
    return false;
  } on SocketException catch (e) {
    print("Failed to connect to light, error:\n${e}");
    return false;
  }
  var currentState = convert.jsonDecode(rawResponse.body);

  // Flip the light's `on` value
  currentState['lights'].forEach((light) => light['on'] = flipInt(light['on']));

  // Now PUT the `currentState` back to the device
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
      print("wrote ${lightIpPorts.join(', ')} to ${cacheFile}.");
    }
  }

  if (lightIpPorts.isEmpty) {
    print("no lights found in ${cacheFile} file, exiting...");
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
