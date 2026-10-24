# Anchor iOS + watchOS App - Setup Guide

## Prerequisites
- Xcode 15+ (with iOS 17+ and watchOS 10+ SDKs)
- Apple Developer account (for HealthKit entitlements)
- iPhone with paired Apple Watch (for testing real vitals)

## Creating the Xcode Project

Since Xcode projects (.xcodeproj) are binary/complex files that can't be
generated as text, follow these steps to set up the project:

### Step 1: Create a new Xcode project

1. Open Xcode
2. File > New > Project
3. Choose **iOS > App**
4. Settings:
   - Product Name: `Anchor`
   - Bundle Identifier: `com.varshasupreeth.anchor`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Check **Include Tests** if desired
5. Save it inside the `Anchor-iOS/` directory

### Step 2: Add watchOS target

1. File > New > Target
2. Choose **watchOS > App**
3. Settings:
   - Product Name: `AnchorWatch`
   - Bundle Identifier: `com.varshasupreeth.anchor.watchkitapp`
   - Interface: **SwiftUI**
   - Watch Connectivity: **Enabled**
4. When asked, embed it in the Anchor iOS app

### Step 3: Add source files to the Watch target

The iOS target already picks up everything in `Anchor/Anchor/` automatically.
For the watchOS target:

1. Drag the `AnchorWatch/` folder into the **AnchorWatch** target.
2. Select each of these files and tick **AnchorWatch** under Target Membership
   (File Inspector, right sidebar) so both apps share one copy:
   - `Anchor/Anchor/CrisisAlgorithm.swift`
   - `Anchor/Anchor/Models/AddictionType.swift`
   - `Anchor/Anchor/Theme.swift`

### Step 4: Configure capabilities

#### iOS Target:
1. Select the Anchor target > Signing & Capabilities
2. Add: **HealthKit** (check "Background Delivery" and "Clinical Health Records")
3. Add: **Background Modes** (check "Audio, AirPlay, and Picture in Picture")

#### watchOS Target:
1. Select AnchorWatch target > Signing & Capabilities
2. Add: **HealthKit** (check "Background Delivery")
3. Add: **Background Modes** (check "Workout Processing" and "Self Care")

### Step 5: Set deployment targets
- iOS target: iOS 17.0+
- watchOS target: watchOS 10.0+

### Step 6: Add entitlements
- Copy `Anchor/Anchor.entitlements` to the iOS target
- Set them in Build Settings > Code Signing Entitlements

### Step 7: Build & Run
1. Select the **Anchor** scheme and an iPhone simulator/device
2. Select the **AnchorWatch** scheme and a paired Watch simulator
3. Build and run both

## Architecture Overview

```
Anchor-iOS/
├── Anchor/                             # iOS app (Xcode project)
│   └── Anchor/                         # Source files (auto-included in the iOS target)
│       ├── AnchorApp.swift
│       ├── CrisisAlgorithm.swift       # Shared with Watch: vital scoring + cited thresholds
│       ├── Theme.swift                 # Shared with Watch
│       ├── WatchConnectivityManager.swift
│       ├── Models/
│       │   ├── AddictionType.swift     # Shared with Watch: per-addiction config + copy
│       │   └── UserData.swift
│       ├── Services/
│       │   ├── HealthKitManager.swift  # Live queries + background delivery, freshness checks
│       │   ├── CrisisMonitorService.swift
│       │   ├── EmergencyService.swift  # Alarm, "Are you okay?" check, bystander mode
│       │   ├── LocationProvider.swift  # One-shot location for the emergency text
│       │   └── CravingCoach.swift      # "Talk to Tide" on-device AI + safety filter
│       └── Views/                      # Includes CravingCoachView, EmergencyView
│
└── AnchorWatch/                        # watchOS app (needs its own target, see Step 2)
```

## How Crisis Detection Works

1. While monitoring is on, the Watch runs a workout session, which gives heart rate
   every few seconds. Blood oxygen is measured periodically. Breathing rate is only
   measured during sleep, so the Watch scores without it.
2. Each new reading is scored by `CrisisAlgorithm` for every addiction being tracked:
   - Readings older than a few minutes are ignored.
   - A full alert needs **two separate danger signs at once**, so one bad sensor
     reading can never trigger it.
   - Thresholds and their sources (AHA, NIH, NIAAA, SAMHSA, WHO) are documented at
     the top of `CrisisAlgorithm.swift`.
3. The iPhone also asks HealthKit to wake it when new vitals arrive (background
   delivery). iOS decides how often that happens, so the Watch is the main monitor.

## What Happens in an Alert

1. **"Are you okay?"** A 30-second countdown with a loud alarm, a spoken alert, and a
   notification in case the app isn't open. Tapping **I'M OKAY** stops it.
2. **No response: bystander mode.** The phone keeps alarming and speaks instructions
   to anyone nearby (for example "give naloxone if you have it"). It brings up the
   911 call prompt and shows one-tap buttons to call 911, call each contact, and text
   all contacts a pre-written message with a map link.
3. iOS always requires a tap before a call or text goes out. Anchor is built around
   making that one tap as easy as possible for whoever is nearby.

Use **Health → Test the emergency alert** to see the whole flow safely. Test mode
never calls or texts anyone.

## Talk to Tide (AI craving coach)

- Runs on **Apple's on-device model** (Foundation Models, iOS 26). Nothing leaves
  the phone and chats are never saved. It needs an Apple Intelligence iPhone
  (15 Pro or newer); other phones see the coping tools and hotlines instead.
- **Safety filter first:** every message is checked with plain phrase matching
  before the AI sees it.
  - Self-harm → 988 card.
  - Overdose or medical danger → 911 card.
  - A slip → a no-shame card plus a lowered-tolerance safety warning.
  The first two never reach the AI.
- Uses **motivational interviewing**: one question at a time, the person's own
  reasons, and short replies. It can quote the person's letters to their future self.
- When someone says they want to use, the app adds a direct "reflect, then ask"
  note to the prompt. If Apple's filter blocks the AI's reply, a hand-written
  motivational interviewing reply is shown instead of "I can't help."
- **Output check:** any AI reply that okays using is replaced before it's shown.
- **Distraction mode:** a request for a game or a distraction starts "would you
  rather" in a separate, short AI session with no recovery context, so it stays
  light and never brings up cravings.
- The screen always says Tide is an AI, not a counselor.

## Important Notes

- **Not a medical device.** Anchor can miss emergencies or raise false alarms. It
  adds a layer of safety and does not replace people or 911.
- **Testing**: Use a real Apple Watch for real vitals. Simulators have no HealthKit data.
- **Privacy**: All health data, chats, and journal entries stay on the device.
- **Battery**: The Watch workout session uses more battery while monitoring is on.
