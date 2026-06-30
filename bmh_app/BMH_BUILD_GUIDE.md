# BMH App — Step-by-Step Build Guide
**BioMedical Healthcare · Flutter App**

---

## WHAT WE'RE BUILDING IN EACH STEP

| Step | What you get | Test on device |
|------|-------------|----------------|
| **Step 1** ✅ | Project + design tokens + Home screen + Splash | ✅ Run & see BMH look |
| **Step 2** | Health Vitals screen (HR, BP, SpO2, HRV) | ✅ See all vital cards |
| **Step 3** | BLE pairing — Health Band connect flow | ✅ Scan & pair real band |
| **Step 4** | BioScale pairing + Weight/Body screen | ✅ Step on scale, see data |
| **Step 5** | Activity screen + workout tracking | ✅ Start a live workout |
| **Step 6** | Auth screens (Sign In, Register, OTP) | ✅ Full login flow |
| **Step 7** | Medicines screen + reminders | ✅ Add & tick medicines |
| **Step 8** | Profile + Settings + Notifications | ✅ Full profile flow |
| **Step 9** | API integration (real backend data) | ✅ Live data |
| **Step 10** | BioCare alerts + outside-app notifications | ✅ Alert system live |

---

## STEP 1 — PROJECT SETUP & HOME SCREEN (Today)

### 1.1 Install Flutter (if not already)
```bash
# Download Flutter SDK
https://docs.flutter.dev/get-started/install

# Verify installation
flutter doctor

# You need:
# ✅ Flutter (>=3.10.0)
# ✅ Android Studio or Xcode
# ✅ A real phone (preferred for BLE testing)
```

### 1.2 Create the project
```bash
flutter create bmh_app --org com.biohealthcare --platforms ios,android
cd bmh_app
```

### 1.3 Replace files
Copy ALL files from the code package I gave you into your project:
```
bmh_app/
  lib/
    main.dart                         ← entry point
    shared/
      theme/
        bmh_tokens.dart               ← ALL design tokens (colors, type, spacing)
        bmh_theme.dart                ← Flutter ThemeData
      widgets/
        bmh_widgets.dart              ← All reusable components
        bmh_tabbar.dart               ← Bottom tab bar
    features/
      auth/
        splash_screen.dart            ← Animated splash
      home/
        home_screen.dart              ← Full home dashboard
        main_shell.dart               ← Tab navigation shell
  pubspec.yaml                        ← Dependencies
  android/app/src/main/AndroidManifest.xml
  ios/Runner/Info.plist
```

### 1.4 Add Google Fonts (Fraunces, Inter, JetBrains Mono)
Because we use custom fonts, you need to download them:
```bash
# Option A — Use google_fonts package (easiest, already in pubspec.yaml)
# The fonts download automatically. No extra steps needed.

# Option B — Bundle locally (for offline/production)
# Download from fonts.google.com and put in assets/fonts/
# Fraunces: https://fonts.google.com/specimen/Fraunces
# JetBrains Mono: https://fonts.google.com/specimen/JetBrains+Mono
```

If using google_fonts package, update bmh_tokens.dart font references:
```dart
// Replace 'Fraunces' with GoogleFonts.fraunces().fontFamily
// Or wrap text styles with GoogleFonts.fraunces(textStyle: ...)
import 'package:google_fonts/google_fonts.dart';
```

### 1.5 Run the app
```bash
flutter pub get
flutter run

# For specific device:
flutter devices
flutter run -d <device-id>
```

### 1.6 What you should see
- ✅ BMH splash screen with animated scan-line logo
- ✅ Deep navy (#02060F) background
- ✅ Cyan accent (#00D4E8) brand colour
- ✅ Greeting ("Good morning, Rahul")
- ✅ Daily check-in card with scan-line motif
- ✅ 4-metric grid (Steps, Heart Rate, SpO2, Weight)
- ✅ 6 expandable module cards
- ✅ Health Vitals expanded by default with vital rows
- ✅ Bottom tab bar with 5 tabs

---

## STEP 2 — HEALTH VITALS SCREEN (Next session)

### Files to add:
```
lib/features/health/
  health_screen.dart          ← Overview with BioScore hero + 8 vital rows
  vitals/
    heart_rate_detail.dart    ← Daily/Weekly/Monthly graph
    blood_pressure_detail.dart
    spo2_detail.dart          ← With measure flow
    hrv_detail.dart
    temperature_detail.dart
    stress_detail.dart
    sleep_detail.dart
    glucose_detail.dart
  widgets/
    bioscore_card.dart        ← The hero bio-score card
    vital_chart.dart          ← fl_chart line chart in BMH style
```

### Key features to build:
- BioScore hero card (dark card, scan-line body figure, composite score)
- 8 health domain rows (cardio, oxygen, DNA, metabolic, nervous, sleep, gut, body)
- Line chart with daily/weekly/monthly toggle
- SpO2 measure flow (requires band connected)

---

## STEP 3 — BLE HEALTH BAND (After Step 2)

### Using the 2208A Flutter SDK you provided:

```dart
// 1. Add dependency in pubspec.yaml (the plugin from your ZIP):
dependencies:
  ble2208_plugin:
    path: ./packages/blesdk2025_plugin  # copy the folder from the ZIP

// 2. Core BLE flow:
import 'package:ble2208_plugin/ble_sdk.dart';

// Scan → Find band → Connect → Listen to data stream
// SDK provides: Heart rate, SpO2, HRV, temperature,
//               steps, sleep, blood oxygen, ECG/PPG
```

### Device pairing screens to build:
- BB-10: Health Band Connect intro
- BB-07: Scanning animation (BLE scan)
- BB-08: Pairing progress
- BB-09: Paired confirmation + "Take first reading" CTA
- GS-08: Device disconnected banner

---

## STEP 4 — BIOSCALE + BODY SCREEN

### BioScale BLE data:
The 2208A SDK handles scale readings too. When scale sends data:
```dart
// BleConst.DeviceSendDataToAPP — scale data arrives here
// Parse: weight, fat %, muscle %, water %, BMI, visceral fat, bone mass
BleSDK.DataParsingWithData(data) // returns Map with all values
```

### Screens:
- BB-01: Body Track overview (weight hero + composition grid)
- BB-02: Weight history (line chart)
- BB-04: Body composition detail (segmental — 10 measurement points)
- BB-05: Manual weight log (fallback if scale unavailable)

---

## ARCHITECTURE DECISIONS (Already made for you)

| Concern | Choice | Why |
|---------|--------|-----|
| State management | Riverpod | Scalable, testable, Flutter-native |
| Navigation | go_router | Deep linking, declarative routes |
| BLE | flutter_blue_plus + 2208A SDK | Your SDK wraps BLE protocol |
| HTTP | Dio + Retrofit | Type-safe API client, easy error handling |
| Charts | fl_chart | Smooth, customisable, BMH-styled |
| Local storage | Hive | Fast, offline-first for health data |
| Fonts | google_fonts | Fraunces + JetBrains Mono + Inter |

---

## FILE STRUCTURE (Full app)
```
lib/
  main.dart
  shared/
    theme/
      bmh_tokens.dart       ← Design tokens (colors, type, spacing)
      bmh_theme.dart        ← ThemeData
    widgets/
      bmh_widgets.dart      ← All reusable components
      bmh_tabbar.dart       ← Tab bar
    utils/
      extensions.dart       ← DateTime, String helpers
      constants.dart        ← API base URL, keys
  core/
    api/
      api_client.dart       ← Dio + Retrofit setup
      endpoints.dart        ← All 86 endpoints
    ble/
      ble_service.dart      ← BLE singleton + device management
      band_parser.dart      ← Parse 2208A SDK data → domain models
      scale_parser.dart     ← Parse scale readings
    models/
      user.dart
      vitals.dart
      weight.dart
      activity.dart
      medicine.dart
    providers/             ← Riverpod providers
      auth_provider.dart
      vitals_provider.dart
      ble_provider.dart
      weight_provider.dart
  features/
    auth/
      splash_screen.dart    ✅ Done
      welcome_screen.dart   ← Step 6
      sign_in_screen.dart   ← Step 6
      register_screen.dart  ← Step 6
    home/
      home_screen.dart      ✅ Done
      main_shell.dart       ✅ Done
      check_in_screen.dart  ← Step 8
    health/
      health_screen.dart    ← Step 2
      vitals/...            ← Step 2
    body/
      body_screen.dart      ← Step 4
      bioscale/...          ← Step 4
    activity/
      activity_screen.dart  ← Step 5
      workout/...           ← Step 5
    medicines/
      medicines_screen.dart ← Step 7
    profile/
      profile_screen.dart   ← Step 8
```

---

## TESTING CHECKLIST — STEP 1

After running the app, verify these on your phone:

- [ ] App launches without errors
- [ ] Splash screen shows for ~1.2 seconds then fades to Home
- [ ] Background is deep navy (not black, not grey)
- [ ] Cyan (#00D4E8) accent on eyebrow text, dot, check-in arrow
- [ ] 4 metric cards show in 2×2 grid
- [ ] Tap "Health Vitals" module → expands with vital rows
- [ ] Tap "Body Track" module → expands with weight card + composition pills
- [ ] Bottom tab bar shows 5 tabs, active glows cyan
- [ ] Switching tabs works (other tabs show "Coming in Step 2" placeholder)
- [ ] Scan-line motif visible on check-in card (right side, faint horizontal lines)

---

## COMMON ISSUES & FIXES

**Font not loading / wrong font**
```bash
# Make sure assets/fonts/ folder exists with the font files
# OR use google_fonts package (no files needed)
flutter pub get && flutter clean && flutter run
```

**BLE not working on Android**
```bash
# Android 12+ requires new permissions — already in AndroidManifest.xml
# Also enable "Developer options > Bluetooth" on phone
# Run on real device, not emulator (BLE doesn't work in emulator)
```

**Build error: package not found**
```bash
flutter pub get
# If still failing:
flutter clean
flutter pub get
flutter run
```

**Status bar not transparent**
```dart
// Already set in main.dart — if it's not working, add this to MainActivity.kt:
// window.statusBarColor = Color.TRANSPARENT
```

---

## READY FOR STEP 2?

When you have Step 1 running and looking correct on your phone,
send me a message and I'll give you:
- Full Health Vitals screen code
- BioScore card widget
- fl_chart line chart styled to BMH design
- Heart Rate detail screen with daily/weekly/monthly toggle

**Message to send:** "Step 1 working, ready for Step 2 — Health Vitals"
