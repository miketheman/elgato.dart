# elgato.dart

A tool to interact with Elgato Lights.

## What?

Let's face it, in 2020 when a ton of us are working from home, many of us have
expanded our home workspaces - and in some cases, have added better lighting.

I purchased an [Elgato Key Light Air][] which is an excellent source of light.
I spend a non-trivial amount of time on video calls for work and for personal
life now, and oftentimes have breaks between calls during which I don't want
the light on.

I looked for a way to control the light's on/off behavior from my command line,
and didn't seem to find one, so I built one.

## Why?

The light itself has a physical power on/off switch on the back of the device,
which can be a little tricky to reach if you're placing the light right above
a monitor.
Also, when flipped on, it lights up to its most powerful setting briefly, and
then settles back to whatever configured setting I had it before I powered it
down.

Elgato provides a couple of interfaces - one is the [macOS Control Center][],
and they provide [Android][] and [iOS][] apps, but I don't want to have
pull my phone out every time I want to turn the ligths on and off, and the
desktop interface is two clicks, and I'm lazy.

There's also the [Elgato Stream Deck][] controllers, but even at the smallest
size it costs about $80USD, and I didn't want to spend that much on a light
switch. If I was controlling more things, then it is probably an excellent
choice, and many people use them.

## How?

This project is written in [Dart][], and can probably be compiled on any
platform that Dart supports (Windows, Linux, macOS) - I have a Macbook, so
I've only tested it against that platform.

There's an [open issue on Dart][] about code signing, so downloading compiled
binaries wasn't something I pursued yet.

Instead, if you want to use this, follow these steps.

_(macOS steps only for now)_

```shell
# Install dart sdk
brew install dart-lang/homebrew-dart/dart
# Clone this repo 
git clone https://github.com/miketheman/elgato.dart.git
# Enter the directory
cd elgato.dart
# Compile to native code:
dart compile exe elgato.dart
# Exceute the resulting binary
./elgato.exe
```

You can control the desired output binary py passing `-o <output filename>`
to `dart compile`.
To place the binary somewhere in your `$PATH`, such as `/usr/local/bin` for
simpler execution, use this command:

```shell
dart compile exe -o /usr/local/bin/elgato elgato.dart
```

And then you should be able to execute the program from anywhere via `elgato`.

Hooray! :tada:

## Who?

This project was inpsired by [Brett Langdon][], who had figured out how to
do this in a simpler, bash-friendly approach, while assigning a static IP
address to the light, [curl][], and [jq][], something like this:

```bash
#!/usr/bin/env bash
curl -qs http://192.168.1.10:9123/elgato/lights \
  | jq -c '{numberOfLights, lights:[.lights[] | {on: (if .on == 1 then 0 else 1 end), brightness, temperature}]}' \
  | curl -XPUT -d @- -H "Content-Type: application/json" http://192.168.1.10:9123/elgato/lights
```

[Mike Fiedler][] took this idea further and wrote a single, self-contained
binary application in [Dart][] that can discover lights on the network.

Both approaches work, so you can choose your own adventure!

I wrote this since I don't statically assign IPs on my network, to learn a
little more about Dart, and because it was fun!

## What Else?
(a collection of ideas that could improve this)

* I'm not a professional Dart developer - it's entirely possible there's better
  implementations or ways to structure the code - assistance is welcome!
  Including tests! :grin:
* At some point, this could be expanded to interact with other Elgato products,
  but starting with the only one I have right now - the [Key Light Air].
* There's no current option to remove the cache file if the IP changes, so
  removing `$HOME_FOLDER/.elgato.dart.cache` and re-running the tool will
  discover the IP of the light again and cache it. The cache is used to speed
  up subsequent invocations, since discovering an mDNS address can take a few
  seconds.
* I can imagine consdering using DNS names instead of IP addresses, especially
  in a multi-light household where you wouldn't want one command to switch all
  lights, so setting up the lights to have a common string in their name might
  be smarter, and that could be set as a configuration value (no config file
  exists yet).
* Anything else you can imagine, since we're software developers and make
  ideas come to life with technology!

[Elgato Key Light Air]: https://www.elgato.com/en/gaming/key-light-air
[macOs Control Center]: https://help.elgato.com/hc/en-us/articles/360028242091-Elgato-Control-Center-Release-Notes-macOS-
[Android]: https://play.google.com/store/apps/details?id=com.corsair.android.controlcenter&hl=en
[iOS]: https://apps.apple.com/us/app/elgato-control-center/id1446254313
[Elgato Stream Deck]: https://www.elgato.com/en/gaming/stream-deck
[Dart]: https://dart.dev/
[open issue on Dart]: https://github.com/dart-lang/sdk/issues/39106
[curl]: https://curl.haxx.se/
[jq]: https://stedolan.github.io/jq/
[Brett Langdon]: https://github.com/brettlangdon
[Mike Fiedler]: https://github.com/miketheman
