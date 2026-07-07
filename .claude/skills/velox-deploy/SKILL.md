---
description: Build Flutter iOS release and install on both Velox iPhones (iPhone mus + iPhone 12)
---

# velox-deploy

Builds the Flutter iOS release and installs it on both physical iPhones.

## Devices
- **iPhone mus** (wireless): `00008110-001C446C2E29801E` / devicectl id: `0E351098-C88C-58A9-B284-E4E551718827`
- **iPhone 12** (cable): `26B894D9-22F2-5176-BECA-4AD66199D8D3`

## Steps

### 1. Build release
```bash
flutter build ios --release
```
Wait for "Build succeeded". App will be at `build/ios/iphoneos/Runner.app`.

### 2. Install on both iPhones in parallel
Use `xcrun devicectl device install app` with each device's identifier.

For iPhone mus (wireless) use the devicectl UUID `0E351098-C88C-58A9-B284-E4E551718827`:
```bash
xcrun devicectl device install app --device 0E351098-C88C-58A9-B284-E4E551718827 build/ios/iphoneos/Runner.app
```

For iPhone 12 (cable) use the UDID `26B894D9-22F2-5176-BECA-4AD66199D8D3`:
```bash
xcrun devicectl device install app --device 26B894D9-22F2-5176-BECA-4AD66199D8D3 build/ios/iphoneos/Runner.app
```

Run both installs in parallel (two Bash tool calls in the same message).

### 3. Launch (optional)
```bash
xcrun devicectl device process launch --device <id> dj.velox.client
```

## Notes
- If iPhone 12 is not connected, install only on iPhone mus and ask the user to reconnect it
- If wireless connection fails on iPhone mus, the build still succeeds — just install via cable or ask user to ensure same WiFi
- Release mode = app works standalone without Flutter tooling (no "debug mode" restriction)
- Bundle ID: `dj.velox.client`
