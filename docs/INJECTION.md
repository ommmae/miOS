# Injecting miOS into Instagram

miOS is a single Mach-O dylib (`miOS.dylib`) that targets **only
`com.burbn.instagram`**. There is no daemon, no companion app, no central
preference file — the full container state (encrypted) lives inside Instagram's
own sandbox at `…/Documents/miOS/`.

## What miOS gives Instagram

A draggable **miOS** button appears in Instagram. Tapping it opens a modal
sheet with 5 tabs:

| Tab          | What it does                                                                 |
|--------------|------------------------------------------------------------------------------|
| Containers   | List / create / rename / delete / switch containers.                         |
| **Spoof**    | The full device fingerprint for the active container — model, iOS, kernel, memory, CPU, carrier, cellular IP + type, Wi-Fi SSID / BSSID / IP, battery, brightness, Low Power Mode, gyroscope, screenshot detection, mail/message availability, anti-anti-jailbreak, identifiers (IDFV / IDFA / DeviceCheck / iCloud). |
| **Location** | MKMapView picker (long-press to drop a pin), map style segment (Standard / Satellite / Hybrid) with 3 cached snapshots per container, manual coordinate entry + reverse-geocoded place name. |
| Proxy (BETA) | Per-container HTTPS proxy injected into `NSURLSessionConfiguration`.         |
| Settings     | About and "Reset miOS" (erase everything).                                   |

Each container has:

- An isolated data subtree (Documents / Library / tmp inside Instagram's sandbox).
- Its own keychain namespace (keeps each container's IG session separate).
- Its own cached App-Group state — wiped on first launch so IG re-registers.
- Its own encrypted plist of fingerprint settings
  (`miOS.container-list.plist`, `miOS.container-config.plist`,
  AES-256-CBC + HMAC-SHA256 + PBKDF2-SHA256 × 10k).
- Its own location + 3 saved map snapshots.

Switching an active container prompts a restart (Instagram must relaunch so
hooks are installed from byte 0).

## Install path 1 — Sideloaded IPA (no jailbreak)

1. Build the dylib:
   ```bash
   make FINALPACKAGE=1
   # output: .theos/obj/miOS.dylib
   ```
   Or grab the `miOS-dylib` artifact from the GitHub Actions build.

2. Patch an Instagram IPA with any signer that supports dylib injection:
   - **Sideloadly / AltStore / TrollStore** — use the *Inject .dylib* field.
   - **ldid + insert_dylib** manually:
     ```bash
     unzip Instagram.ipa -d ig/
     EXE="ig/Payload/Instagram.app/Instagram"
     insert_dylib --inplace --all-yes --weak @executable_path/Frameworks/miOS.dylib "$EXE"
     mkdir -p "ig/Payload/Instagram.app/Frameworks"
     cp miOS.dylib "ig/Payload/Instagram.app/Frameworks/"
     ldid -S "$EXE"
     ldid -S "ig/Payload/Instagram.app/Frameworks/miOS.dylib"
     cd ig && zip -r ../Instagram-miOS.ipa Payload && cd ..
     ```

3. Resign and install the IPA with your usual signer.

> No extra entitlements are required.

## Install path 2 — Jailbreak (rootless)

```bash
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
# /var/jb/Library/MobileSubstrate/DynamicLibraries/miOS.dylib
# /var/jb/Library/MobileSubstrate/DynamicLibraries/miOS.plist   # filter -> com.burbn.instagram
```
