# G McQueen

G McQueen is a portrait flappy-style Godot game. Guide the baby pilot through
the Lightning McQueen-inspired turbo pillars and beat your high score. Each
cleared pillar celebrates with a random real “Mama” or “Dada” recording, while
hitting a pillar plays the real “dat one” recording.

## Controls

- Tap the screen (or click with a mouse) to flap.
- Press **Space** while testing on desktop to flap.
- Tap/click after a crash to start a new run.

## Android deployment

The app package is `com.victor.gmcqueen` and the debug artifact is
`build/g-mcqueen.apk`. The default target is the connected Galaxy S23 at
`100.104.51.10:5555` over Tailscale.

## One-time phone pairing

On the Galaxy S23, enable **Developer options**, **USB debugging**, and
**Wireless debugging**. Open **Pair device with pairing code** and note its
LAN IP, pairing port, and six-digit code. The Wireless debugging screen also
shows a separate debugging port.

Run:

```bash
./scripts/pair-android 192.168.x.x:PAIR_PORT 192.168.x.x:DEBUG_PORT
```

Enter the six-digit code when prompted. This changes ADB to static port 5555
and reconnects through the phone's Tailscale address (`100.104.51.10`).

## Iterate

```bash
./scripts/deploy-android
```

To follow only the app process's logs after launch:

```bash
./scripts/deploy-android --logs
```

Build without installing:

```bash
./scripts/build-android
```

Override the target when needed:

```bash
ANDROID_DEVICE=another-device:5555 ./scripts/deploy-android
```

`deploy-android` exports a signed debug APK, installs it with ADB, and launches
the app. Set `GODOT_BIN`, `ANDROID_HOME`, `JAVA_HOME`, or `APKSIGNER_BIN` when
your local tool paths differ. Set `ANDROID_LAUNCHER_ACTIVITY` only when using a
custom Android activity template.

## Web version

The `Web` export preset builds a single-threaded portrait web build into
`build/web/` (no cross-origin isolation headers needed).

```bash
./scripts/build-web
```

`scripts/serve-web` serves `build/web` on `127.0.0.1:8096` and sends the
precompressed `.gz` files to browsers that accept gzip. On this machine it runs
as the user service `g-mcqueen-web.service`, and Tailscale Serve publishes it
to the tailnet:

```bash
systemctl --user enable --now g-mcqueen-web.service
tailscale serve --bg --https=8443 http://127.0.0.1:8096
```

Play at `https://pod-nucboxg5.tail29651f.ts.net:8443/`. After rebuilding, a
page reload picks up the new build. Stop publishing with
`tailscale serve --https=8443 off`.
