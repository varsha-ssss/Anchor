# Anchor iOS app

Anchor is a native SwiftUI recovery companion. This repository is set up for an **iPhone-only** TestFlight build of the iOS app. The Apple Watch sources under `AnchorWatch/` are not part of the Xcode project and are not in this build.

## Project

Open `Anchor/Anchor.xcodeproj` in Xcode 26 or later. The shared `Anchor` scheme archives the iOS app.

| Setting | Value |
|---|---|
| Bundle ID | `com.varshasupreeth.anchor` |
| Marketing version | 1.0 (`MARKETING_VERSION`) |
| Build number | 1 (`CURRENT_PROJECT_VERSION`) — bump this for every upload |
| Minimum iOS | 26.0 |
| Devices | iPhone only |
| Signing | Automatic, team `GNTAU232J6` |
| Display name | Anchor |
| Encryption | `ITSAppUsesNonExemptEncryption` = NO |

Tide, the on-device coach, uses Apple Foundation Models and needs an iPhone with Apple Intelligence (iPhone 15 Pro or newer, Apple Intelligence turned on). Other iPhones on iOS 26 still run the rest of the app.

Onboarding requires age 18 or older. Profile edits cannot save an age under 18.

## Info.plist

There is no checked-in `Info.plist`. The target generates it (`GENERATE_INFOPLIST_FILE = YES`). Purpose strings and export compliance live in the target build settings:

- `NSHealthShareUsageDescription` — heart rate, blood oxygen, and breathing rate stay on device
- `NSLocationWhenInUseUsageDescription` — one-shot location for the emergency text
- `ITSAppUsesNonExemptEncryption` = NO

The app does not declare motion access, HealthKit write access, or the `processing` background mode. `PrivacyInfo.xcprivacy` in `Anchor/Anchor/` is part of the app target. It reports no tracking, no collected data types, and UserDefaults access reason `CA92.1`.

## Archive for TestFlight

1. Use a Mac with Xcode 26 and a paid Apple Developer Program membership. HealthKit and TestFlight both require a paid team. Confirm team `GNTAU232J6` is that membership, or change `DEVELOPMENT_TEAM` to yours.
2. In Certificates, Identifiers & Profiles, enable **HealthKit** and **HealthKit Background Delivery** on `com.varshasupreeth.anchor`. Leave Clinical Health Records off.
3. In App Store Connect, create the app with that bundle ID if it does not exist yet. Add a privacy policy URL and a support URL before external testing.
4. In Xcode, select the **Anchor** scheme and **Any iOS Device (arm64)**.
5. Product > Archive, then Distribute App > App Store Connect > Upload.
6. After processing, answer export compliance if asked. The app uses no custom cryptography, so the exemption applies. The plist key should already mark this.
7. Add internal testers first. External TestFlight goes through Beta App Review.

In the test notes, say that this build is iPhone-only, that the Watch monitor is not included, that Anchor is not a medical device, and that every call or text needs a tap. **Health → Test the emergency alert** runs the alarm without contacting anyone.

Bump `CURRENT_PROJECT_VERSION` before each later upload. The shared scheme is `Anchor/Anchor.xcodeproj/xcshareddata/xcschemes/Anchor.xcscheme`.

## What this build includes

```
Anchor/
├── Anchor.xcodeproj/          # iOS app, shared Anchor scheme
└── Anchor/
    ├── AnchorApp.swift
    ├── PrivacyInfo.xcprivacy
    ├── CrisisAlgorithm.swift
    ├── Theme.swift
    ├── WatchConnectivityManager.swift
    ├── Models/
    ├── Services/              # HealthKit, emergency alarm, on-device Tide
    └── Views/
AnchorWatch/                   # watchOS sources only — not a target
```

Health data, journal entries, and Tide chats stay on the device. There is no backend. The only web URL is a `maps.apple.com` link placed in an emergency text the person must send themselves.

## Not a medical device

Anchor can miss emergencies or raise false alarms. It does not replace people or 911. iOS always requires a tap before a call or text goes out.
