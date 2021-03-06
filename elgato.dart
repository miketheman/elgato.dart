import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';
import 'package:dcli/dcli.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';

// We store the results of the IP lookup in a file for future speedups
final cacheFile = join(HOME, ".elgato.dart.cache");

String lightIpPort = "";
Uri url = Uri.parse("http://$lightIpPort/elgato/lights");

/// Discover Elgato lights on the network
findLights() async {
  final String svcName = "_elg";
  final MDnsClient client = MDnsClient();
  await client.start();

  await for (PtrResourceRecord ptr in client
      .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(svcName))) {
    await for (SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName))) {
      await for (IPAddressResourceRecord ip
          in client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target))) {
        lightIpPort = '${ip.address.host}:${srv.port}';
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
flipSwitch() async {
  var rawResponse;

  try {
    // Await the http get response, then decode the json-formatted response.
    rawResponse = await http.get(url).timeout(const Duration(seconds: 3));
  } on TimeoutException {
    // If we didn't get a response, bail.
    print('timed out calling lights, exiting...');
    exit(2);
  } on SocketException catch (e) {
    print("Failed to connect to light, error:\n${e}");
    exit(2);
  }

  var currentState = convert.jsonDecode(rawResponse.body);

  // Flip every light's `on` value
  currentState['lights'].forEach((light) => light['on'] = flipInt(light['on']));

  // Now PUT the `currentState` back to the device
  await http.put(url, body: convert.jsonEncode(currentState));
}

void main() async {
  if (exists(cacheFile)) {
    read(cacheFile).forEach((line) => lightIpPort = line);
  } else {
    await findLights();
    if (cacheFile.isNotEmpty) {
      cacheFile.write(lightIpPort);
      print("wrote ${lightIpPort} to ${cacheFile}.");
    }
  }

  if (lightIpPort.isEmpty) {
    print("no lights found in ${cacheFile} file, exiting...");
    exit(2);
  }

  flipSwitch();
}
