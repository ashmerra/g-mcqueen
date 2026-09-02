# Tailscale Android deployment smoke test

This is a static Godot view used to verify the complete development loop:

1. Export an Android debug APK on this Linux machine.
2. Reach the Galaxy S23 through Tailscale.
3. Replace the installed app using ADB.
4. Launch it automatically.

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

