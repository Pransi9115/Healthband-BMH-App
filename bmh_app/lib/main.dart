import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'shared/theme/bmh_theme.dart';
import 'features/auth/splash_screen.dart';
import 'core/ble/ble_service.dart';
import 'core/health/vital_history_service.dart';

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
// and registers all permissions in iOS Settings
Future<void> _requestiOSPermissions() async {
  // Step 1 — Bluetooth (most important for BMH)
  await Permission.bluetooth.request();
  await Permission.bluetoothConnect.request();
  await Permission.bluetoothScan.request();

  // Step 2 — Location (required for BLE scanning on iOS)
  await Permission.locationWhenInUse.request();

  // Step 3 — Motion & Fitness (for step counting)
  await Permission.sensors.request();

  // Step 4 — Camera (for QR pairing)
  await Permission.camera.request();

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
