import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dcli/dcli.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';

// Store the results of the IP lookup locally to speed things up
final cacheFile = join(HOME, '.elgato.dart.cache');

// Discover lights on the local network
Future<List<String>> discoverLights() async {
  var lightIpPorts = <String>[];

  final String svcName = '_elg';
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

  return lightIpPorts;
}

Future<List<Uri>> getLightUrls() async {
  var lightIpPorts = [];

  // Check for a cache file
  if (exists(cacheFile)) {
    read(cacheFile).forEach((line) => lightIpPorts.add(line));
  } else {
    lightIpPorts = await discoverLights();

    // Update the cache
    cacheFile.write(lightIpPorts.join('\n'));
    print('Wrote [${lightIpPorts.join(', ')}] to $cacheFile');
  }

  if (lightIpPorts.isEmpty) {
    print('No light(s) found, exiting...');
    exit(2);
  }

  return lightIpPorts.map((x) => Uri.parse('http://$x/elgato/lights')).toList();
}

// Send an operation to a particular light
Future<void> send(var op, var url) async {
  http.Response rawResponse;

  try {
    // Await the HTTP GET response, then decode the JSON-formatted response
    rawResponse = await http.get(url).timeout(const Duration(seconds: 3));
  } on TimeoutException {
    printerr('Timed out getting information from light at [$url], exiting...');
    exit(2);
  } on SocketException catch (error) {
    printerr('Failed to connect to light at [$url], error:\n$error');
    exit(2);
  }
  var currentState = convert.jsonDecode(rawResponse.body);

  // Update the state object with the operation
  // NB: This refers to one light only, contrary to what the key name indicates
  currentState['lights'].forEach(op);

  await http.put(url, body: convert.jsonEncode(currentState));
}

// Send an operation to all available lights
Future<void> manageLights(var op) async {
  var urls = await getLightUrls();
  Future.wait(urls.map((url) => send(op, url)));
}

void main(List<String> args) async {
  // Fetch the name of the file being invoked (elgato.dart, elgato.exe, etc.)
  var filename = Platform.script.toFilePath().split('/').last;

  // If no command is specified, default to toggle the light(s)
  args = args.isEmpty ? ['toggle'] : args;

  // Configure CLI commands and options
  CommandRunner(filename, 'A CLI for operating Elgato lights')
    ..addCommand(OnCommand())
    ..addCommand(OffCommand())
    ..addCommand(ToggleCommand())
    ..addCommand(IncreaseCommand())
    ..addCommand(DecreaseCommand())
    ..run(args).catchError((error) {
      if (error is! UsageException) throw error;
      print(error);
      exit(64); // Exit code 64 indicates a usage error
    });
}

class OnCommand extends Command {
  @override
  final name = 'on';
  @override
  final description = 'Switch light(s) on.';

  @override
  Future<void> run() async {
    op(light) => light['on'] = 1;
    manageLights(op);
  }
}

class OffCommand extends Command {
  @override
  final name = 'off';
  @override
  final description = 'Switch light(s) off.';

  @override
  Future<void> run() async {
    op(light) => light['on'] = 0;
    manageLights(op);
  }
}

class ToggleCommand extends Command {
  @override
  final name = 'toggle';
  @override
  final description = 'Toggle switch of each light. [Default]';

  @override
  Future<void> run() async {
    op(light) => light['on'] = light['on'] == 1 ? 0 : 1;
    manageLights(op);
  }
}

class IncreaseCommand extends Command {
  @override
  final name = 'increase';
  @override
  final description = 'Increase brightness or temperature of each light.';

  IncreaseCommand() {
    addSubcommand(IncreaseBrightnessCommand());
    addSubcommand(IncreaseTemperatureCommand());
  }
}

class IncreaseBrightnessCommand extends Command {
  @override
  final name = 'brightness';
  @override
  final description = 'Increase brightness of each light.';

  @override
  Future<void> run() async {
    op(light) => light['brightness'] = light['brightness'] + 5;
    manageLights(op);
  }
}

class IncreaseTemperatureCommand extends Command {
  @override
  final name = 'temperature';
  @override
  final description = 'Increase brightness of each light.';

  @override
  Future<void> run() async {
    op(light) => light['temperature'] = light['temperature'] + 5;
    manageLights(op);
  }
}

class DecreaseCommand extends Command {
  @override
  final name = 'decrease';
  @override
  final description = 'Decrease brightness or temperature of each light.';

  DecreaseCommand() {
    addSubcommand(DecreaseBrightnessCommand());
    addSubcommand(DecreaseTemperatureCommand());
  }
}

class DecreaseBrightnessCommand extends Command {
  @override
  final name = 'brightness';
  @override
  final description = 'Decrease brightness of each light.';

  @override
  Future<void> run() async {
    op(light) => light['brightness'] = light['brightness'] - 5;
    manageLights(op);
  }
}

class DecreaseTemperatureCommand extends Command {
  @override
  final name = 'temperature';
  @override
  final description = 'Decrease brightness of each light.';

  @override
  Future<void> run() async {
    op(light) => light['temperature'] = light['temperature'] - 5;
    manageLights(op);
  }
}
