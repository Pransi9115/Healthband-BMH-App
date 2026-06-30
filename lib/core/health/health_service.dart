import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

// ─────────────────────────────────────────────────────────
//  HEALTH SERVICE - iOS HealthKit & Android Google Health
//  Syncs vitals from the band to Apple Health / Google Health
// ─────────────────────────────────────────────────────────

// iOS HealthKit data types (same vitals as Android)
const _kHealthKitTypes = [
  HealthDataType.HEART_RATE,
  HealthDataType.BLOOD_OXYGEN,
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  HealthDataType.BODY_TEMPERATURE,
  HealthDataType.STEPS,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.DISTANCE_DELTA,
  HealthDataType.SLEEP_ASLEEP,
];

// Android Google Health Connect data types
const _kHealthConnectTypes = [
  HealthDataType.HEART_RATE,
  HealthDataType.BLOOD_OXYGEN,
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  HealthDataType.BODY_TEMPERATURE,
  HealthDataType.STEPS,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.DISTANCE_DELTA,
  HealthDataType.SLEEP_ASLEEP,
];

/// Result of a Health Sync (iOS HealthKit or Android Health Connect)
class HealthSyncResult {
  final bool ok;
  final int written;
  final Map<String, String> fromOtherApps;
  final String? error;
  final String? debugInfo;
  
  const HealthSyncResult({
    required this.ok,
    required this.written,
    required this.fromOtherApps,
    this.error,
    this.debugInfo,
  });
}

class HealthService {
  static final Health _health = Health();
  static bool _configured = false;

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  // ════════════════════════════════════════════════════════
  //  iOS HEALTHKIT SECTION
  // ════════════════════════════════════════════════════════

  /// Request HealthKit authorization on iOS
  /// Must be called once at startup to show Health permissions in Settings
  static Future<void> requestHealthKitAuthorization() async {
    if (!Platform.isIOS) return;
    
    try {
      await _ensureConfigured();
      debugPrint('[HealthService] Requesting HealthKit authorization...');
      
      await _health.requestAuthorization(
        _kHealthKitTypes,
        permissions: _kHealthKitTypes
            .map((_) => HealthDataAccess.READ_WRITE)
            .toList(),
      );
      
      debugPrint('[HealthService] ✅ HealthKit authorization requested');
    } catch (e) {
      debugPrint('[HealthService] ❌ HealthKit authorization failed: $e');
    }
  }

  /// Check if app has HealthKit permissions on iOS
  static Future<bool> hasHealthKitPermissions() async {
    if (!Platform.isIOS) return false;
    
    try {
      await _ensureConfigured();
      
      final hasPerms = await _health.hasPermissions(
        _kHealthKitTypes,
        permissions: _kHealthKitTypes
            .map((_) => HealthDataAccess.READ_WRITE)
            .toList(),
      ) ?? false;
      
      debugPrint('[HealthService] HealthKit permissions check: $hasPerms');
      return hasPerms;
    } catch (e) {
      debugPrint('[HealthService] HealthKit permission check failed: $e');
      return false;
    }
  }

  /// Sync vitals with iOS HealthKit
  /// Same data types as Android, writes to Apple Health
  Future<HealthSyncResult> syncWithHealthKit({
    double heartRate = 0,
    double spo2 = 0,
    double systolic = 0,
    double diastolic = 0,
    double temperature = 0,
    double hrv = 0,
    double calories = 0,
    double distanceKm = 0,
    int steps = 0,
    int sleepMinutes = 0,
  }) async {
    if (!Platform.isIOS) {
      return const HealthSyncResult(
        ok: false,
        written: 0,
        fromOtherApps: {},
        error: 'iOS only',
      );
    }

    debugPrint('[HealthService] Starting HealthKit sync...');
    debugPrint('[HealthService] Input data: HR=$heartRate, SpO2=$spo2, '
        'BP=$systolic/$diastolic, Temp=$temperature, Steps=$steps');

    try {
      await _ensureConfigured();

      // Check permissions
      final hasPerms = await hasHealthKitPermissions();
      debugPrint('[HealthService] Permission check: $hasPerms');

      if (!hasPerms) {
        debugPrint('[HealthService] ❌ SYNC FAILED: HealthKit permissions not granted');
        return HealthSyncResult(
          ok: false,
          written: 0,
          fromOtherApps: {},
          error: 'HealthKit permission not granted',
          debugInfo: 'Go to Settings > Health > Data Access & Devices > BMH App '
              'and enable all metrics.',
        );
      }

      final now = DateTime.now();
      final justNow = now.subtract(const Duration(seconds: 30));
      int written = 0;

      Future<void> write(HealthDataType type, double value, {DateTime? start}) async {
        if (value <= 0) return;
        try {
          debugPrint('[HealthService] Writing $type = $value');
          final ok = await HealthService._health.writeHealthData(
            value: value,
            type: type,
            startTime: start ?? justNow,
            endTime: now,
          );
          if (ok) {
            written++;
            debugPrint('[HealthService] ✅ Successfully wrote $type');
          } else {
            debugPrint('[HealthService] ⚠️ Write returned false for $type');
          }
        } catch (e) {
          debugPrint('[HealthService] ❌ Write failed for $type: $e');
        }
      }

      debugPrint('[HealthService] Beginning HealthKit data write phase...');

      // Write all vital data
      await write(HealthDataType.HEART_RATE, heartRate);
      await write(HealthDataType.BLOOD_OXYGEN, spo2);
      await write(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, systolic);
      await write(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, diastolic);
      await write(HealthDataType.BODY_TEMPERATURE, temperature);
      await write(HealthDataType.STEPS, steps.toDouble());
      await write(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, hrv);
      await write(HealthDataType.ACTIVE_ENERGY_BURNED, calories);
      await write(HealthDataType.DISTANCE_DELTA, distanceKm * 1000); // km → m
      if (sleepMinutes > 0) {
        await write(
          HealthDataType.SLEEP_ASLEEP,
          sleepMinutes.toDouble(),
          start: now.subtract(Duration(minutes: sleepMinutes)),
        );
      }

      debugPrint('[HealthService] Data write phase complete. Total written: $written');

      // Read back last 24h to show data from other apps
      final fromOtherApps = <String, String>{};
      try {
        debugPrint('[HealthService] Reading back last 24h from HealthKit...');

        final points = await HealthService._health.getHealthDataFromTypes(
          types: _kHealthKitTypes,
          startTime: now.subtract(const Duration(hours: 24)),
          endTime: now,
        );

        debugPrint('[HealthService] ✅ Read ${points.length} data points from HealthKit');

        Map<String, int> appSources = {};
        for (final p in points) {
          final src = p.sourceName;
          appSources[src] = (appSources[src] ?? 0) + 1;

          // Skip BMH's own data
          if (src.toLowerCase().contains('bmh') ||
              src.toLowerCase().contains('biohealthcare')) {
            continue;
          }

          final label = src.isEmpty ? 'Unknown app' : src;
          fromOtherApps['${p.type.name} · $label'] = p.value.toString();
        }

        debugPrint('[HealthService] Data sources found:');
        appSources.forEach((src, count) {
          debugPrint('  - $src: $count points');
        });
      } catch (e) {
        debugPrint('[HealthService] ⚠️ Read-back phase failed: $e');
      }

      debugPrint('[HealthService] ✅ HEALTHKIT SYNC COMPLETED');
      return HealthSyncResult(
        ok: written > 0,
        written: written,
        fromOtherApps: fromOtherApps,
        debugInfo: 'Wrote $written metrics to HealthKit',
      );
    } catch (e) {
      debugPrint('[HealthService] ❌ HEALTHKIT SYNC FAILED: $e');
      return HealthSyncResult(
        ok: false,
        written: 0,
        fromOtherApps: {},
        error: '$e',
        debugInfo: 'Exception during HealthKit sync. Check logs.',
      );
    }
  }

  // ════════════════════════════════════════════════════════
  //  ANDROID GOOGLE HEALTH CONNECT SECTION (UNCHANGED)
  // ════════════════════════════════════════════════════════

  /// Check if Health Connect is available on Android
  static Future<bool> isHealthConnectAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      await _ensureConfigured();
      final status = await _health.getHealthConnectSdkStatus();
      debugPrint('[HealthService] Health Connect SDK Status: $status');
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      debugPrint('[HealthService] isHealthConnectAvailable failed: $e');
      return false;
    }
  }

  /// Open Play Store to install Health Connect
  static Future<void> openHealthConnectInstall() async {
    if (!Platform.isAndroid) return;
    try {
      await _ensureConfigured();
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('[HealthService] openHealthConnectInstall failed: $e');
    }
  }

  /// Check if Health Connect permissions are granted
  static Future<bool> hasHealthConnectPermissions() async {
    if (!Platform.isAndroid) return false;
    try {
      await _ensureConfigured();

      final result = await _health.hasPermissions(
        _kHealthConnectTypes,
        permissions: _kHealthConnectTypes
            .map((_) => HealthDataAccess.READ_WRITE)
            .toList(),
      ) ?? false;

      debugPrint('[HealthService] Health Connect permissions check: $result');
      return result;
    } catch (e) {
      debugPrint('[HealthService] hasHealthConnectPermissions failed: $e');
      return false;
    }
  }

  /// Request Health Connect permissions on Android
  static Future<bool> requestHealthConnectPermissions() async {
    if (!Platform.isAndroid) return false;
    try {
      await _ensureConfigured();
      final already = await hasHealthConnectPermissions();
      if (already) return true;

      debugPrint('[HealthService] Requesting Health Connect permissions...');

      final granted = await _health.requestAuthorization(
        _kHealthConnectTypes,
        permissions: _kHealthConnectTypes
            .map((_) => HealthDataAccess.READ_WRITE)
            .toList(),
      );

      debugPrint('[HealthService] Permissions granted: $granted');
      return granted;
    } catch (e) {
      debugPrint('[HealthService] requestHealthConnectPermissions failed: $e');
      return false;
    }
  }

  /// Sync vitals with Android Google Health Connect
  Future<HealthSyncResult> syncWithHealthConnect({
    double heartRate = 0,
    double spo2 = 0,
    double systolic = 0,
    double diastolic = 0,
    double temperature = 0,
    double hrv = 0,
    double calories = 0,
    double distanceKm = 0,
    int steps = 0,
    int sleepMinutes = 0,
  }) async {
    if (!Platform.isAndroid) {
      return const HealthSyncResult(
        ok: false,
        written: 0,
        fromOtherApps: {},
        error: 'Android only',
      );
    }

    debugPrint('[HealthService] Starting Health Connect sync...');
    debugPrint('[HealthService] Input data: HR=$heartRate, SpO2=$spo2, '
        'BP=$systolic/$diastolic, Temp=$temperature, Steps=$steps');

    try {
      await HealthService._ensureConfigured();

      final hasPerm = await HealthService.hasHealthConnectPermissions();
      debugPrint('[HealthService] Permission check result: $hasPerm');

      if (!hasPerm) {
        debugPrint('[HealthService] ❌ SYNC FAILED: Permissions not granted');
        return HealthSyncResult(
          ok: false,
          written: 0,
          fromOtherApps: {},
          error: 'Permission not granted',
          debugInfo: 'Go to Settings > Apps > Health > Health Connect and enable all metrics.',
        );
      }

      final now = DateTime.now();
      final justNow = now.subtract(const Duration(seconds: 30));
      int written = 0;

      Future<void> write(HealthDataType type, double value,
          {DateTime? start}) async {
        if (value <= 0) return;
        try {
          debugPrint('[HealthService] Writing $type = $value');
          final ok = await HealthService._health.writeHealthData(
            value: value,
            type: type,
            startTime: start ?? justNow,
            endTime: now,
          );
          if (ok) {
            written++;
            debugPrint('[HealthService] ✅ Successfully wrote $type');
          } else {
            debugPrint('[HealthService] ⚠️ Write returned false for $type');
          }
        } catch (e) {
          debugPrint('[HealthService] ❌ Write failed for $type: $e');
        }
      }

      debugPrint('[HealthService] Beginning data write phase...');

      await write(HealthDataType.HEART_RATE, heartRate);
      await write(HealthDataType.BLOOD_OXYGEN, spo2);
      await write(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, systolic);
      await write(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, diastolic);
      await write(HealthDataType.BODY_TEMPERATURE, temperature);
      await write(HealthDataType.STEPS, steps.toDouble());
      await write(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, hrv);
      await write(HealthDataType.ACTIVE_ENERGY_BURNED, calories);
      await write(HealthDataType.DISTANCE_DELTA, distanceKm * 1000);
      if (sleepMinutes > 0) {
        await write(
          HealthDataType.SLEEP_ASLEEP,
          sleepMinutes.toDouble(),
          start: now.subtract(Duration(minutes: sleepMinutes)),
        );
      }

      debugPrint('[HealthService] Data write phase complete. Total written: $written');

      final fromOtherApps = <String, String>{};
      try {
        debugPrint('[HealthService] Reading back last 24h from Health Connect...');

        final points = await HealthService._health.getHealthDataFromTypes(
          types: _kHealthConnectTypes,
          startTime: now.subtract(const Duration(hours: 24)),
          endTime: now,
        );

        debugPrint('[HealthService] ✅ Read ${points.length} data points from Health Connect');

        Map<String, int> appSources = {};
        for (final p in points) {
          final src = p.sourceName;
          appSources[src] = (appSources[src] ?? 0) + 1;

          if (src.toLowerCase().contains('bmh') ||
              src.toLowerCase().contains('biohealthcare')) {
            continue;
          }
          final label = src.isEmpty ? 'Unknown app' : src;
          fromOtherApps['${p.type.name} · $label'] = p.value.toString();
        }

        debugPrint('[HealthService] Data sources found:');
        appSources.forEach((src, count) {
          debugPrint('  - $src: $count points');
        });
      } catch (e) {
        debugPrint('[HealthService] ⚠️ Read-back phase failed: $e');
      }

      debugPrint('[HealthService] ✅ SYNC COMPLETED SUCCESSFULLY');
      return HealthSyncResult(
        ok: written > 0,
        written: written,
        fromOtherApps: fromOtherApps,
        debugInfo: 'Wrote $written metrics to Health Connect',
      );
    } catch (e) {
      debugPrint('[HealthService] ❌ SYNC FAILED WITH EXCEPTION: $e');
      return HealthSyncResult(
        ok: false,
        written: 0,
        fromOtherApps: {},
        error: '$e',
        debugInfo: 'Exception during sync. Check logs for details.',
      );
    }
  }

  /// Universal sync method - calls appropriate platform method
  Future<HealthSyncResult> syncAll({
    double heartRate = 0,
    double spo2 = 0,
    double systolic = 0,
    double diastolic = 0,
    double temperature = 0,
    double hrv = 0,
    double calories = 0,
    double distanceKm = 0,
    int steps = 0,
    int sleepMinutes = 0,
  }) async {
    if (Platform.isIOS) {
      return syncWithHealthKit(
        heartRate: heartRate,
        spo2: spo2,
        systolic: systolic,
        diastolic: diastolic,
        temperature: temperature,
        hrv: hrv,
        calories: calories,
        distanceKm: distanceKm,
        steps: steps,
        sleepMinutes: sleepMinutes,
      );
    } else if (Platform.isAndroid) {
      return syncWithHealthConnect(
        heartRate: heartRate,
        spo2: spo2,
        systolic: systolic,
        diastolic: diastolic,
        temperature: temperature,
        hrv: hrv,
        calories: calories,
        distanceKm: distanceKm,
        steps: steps,
        sleepMinutes: sleepMinutes,
      );
    }

    return const HealthSyncResult(
      ok: false,
      written: 0,
      fromOtherApps: {},
      error: 'Unsupported platform',
    );
  }
}
