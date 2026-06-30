import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'shared/theme/bmh_theme.dart';
import 'features/auth/splash_screen.dart';
import 'core/ble/ble_service.dart';
import 'core/health/vital_history_service.dart';
import 'core/health/health_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  GoogleFonts.config.allowRuntimeFetching = true;

  // ── Initialize services ──────────────────────────────
  BleService.instance;
  await VitalHistoryService.instance.init();

  // ── Request permissions on iOS at startup ────────────
  // This makes all permissions appear in iOS Settings
  // (same as JCVital / Fitdays behaviour)
  if (Platform.isIOS) {
    await _requestiOSPermissions();
    await HealthService.requestHealthPermissions(); // registers Health in iOS Settings
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF02060F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const BMHApp());
}

// ── iOS Permission Request ────────────────────────────
// Called once on first launch — shows iOS permission dialogs
// and registers all permissions in iOS Settings.
// Small delays between requests ensure iOS processes each
// dialog before the next one is triggered.
Future<void> _requestiOSPermissions() async {
  // Step 1 — Bluetooth (most important for BMH)
  await Permission.bluetooth.request();
  await Permission.bluetoothConnect.request();
  await Permission.bluetoothScan.request();
  await Future.delayed(const Duration(milliseconds: 200));

  // Step 2 — Location (required for BLE scanning on iOS)
  // Request WhenInUse first, then upgrade to Always so that
  // iOS Settings shows the full Location row with "Always".
  await Permission.locationWhenInUse.request();
  await Future.delayed(const Duration(milliseconds: 200));
  await Permission.locationAlways.request();
  await Future.delayed(const Duration(milliseconds: 200));

  // Step 3 — Motion & Fitness (for step counting)
  await Permission.sensors.request();
  await Future.delayed(const Duration(milliseconds: 200));

  // Step 4 — Camera (for QR pairing)
  await Permission.camera.request();
  await Future.delayed(const Duration(milliseconds: 200));

  // Step 5 — Notifications (for daily check-in reminder)
  await Permission.notification.request();
}

class BMHApp extends StatelessWidget {
  const BMHApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioMedical Healthcare',
      debugShowCheckedModeBanner: false,
      theme: BMHTheme.dark,
      darkTheme: BMHTheme.dark,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
    );
  }
}
