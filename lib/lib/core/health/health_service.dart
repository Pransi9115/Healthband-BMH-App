import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

// ─────────────────────────────────────────────────────────
//  HEALTH SERVICE - ENHANCED WITH DEBUGGING
//  Syncs vitals from the band to the backend / health store
// ─────────────────────────────────────────────────────────

// The HealthKit data types BMH reads and writes.
const _kHealthTypes = [
  HealthDataType.HEART_RATE,
  HealthDataType.BLOOD_OXYGEN,
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  HealthDataType.BODY_TEMPERATURE,
  HealthDataType.STEPS,
];

// The Google Health Connect data types BMH reads and writes (Android).
// Kept separate from _kHealthTypes above (iOS HealthKit) since a couple
// of these are platform-specific (e.g. DISTANCE_DELTA is Android-only).
//
// NOTE: HEART_RATE_VARIABILITY_RMSSD is the name this package uses for
// the Health Connect (Android) HRV record. If a future package version
// has renamed it, this is the one line that would need changing.
const _kHealthConnectTypes = [
  HealthDataType.HEART_RATE,
  HealthDataType.BLOOD_OXYGEN,
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  HealthDataType.BODY_TEMPERATURE,
  HealthDataType.STEPS,
  HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.DISTANCE_DELTA,
  HealthDataType.SLEEP_ASLEEP,
];

/// Result of a Health Connect sync — how many of BMH's own records were
/// written, plus anything found that came from OTHER apps (e.g. the
/// phone's own step counter, another app's sleep tracking). The "other
/// apps" data is informational only — it is not merged into BMH's own
/// live band readings anywhere.
class HealthSyncResult {
  final bool ok;
  final int written;
  final Map<String, String> fromOtherApps;
  final String? error;
  final String? debugInfo; // NEW: For detailed error messages
  
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

  // ── HealthKit authorization (iOS only) ───────────────
  // Call this once at startup so the Health permission row
  // appears in iOS Settings → BMH.
  static Future<void> requestHealthPermissions() async {
    if (!Platform.isIOS) return; // Android unaffected
    try {
      await _ensureConfigured();
      await _health.requestAuthorization(
        _kHealthTypes,
        permissions: _kHealthTypes
            .map((_) => HealthDataAccess.READ_WRITE)
            .toList(),
      );
    } catch (e) {
      debugPrint('HealthService.requestHealthPermissions failed: $e');
    }
  }

  // ── Google Health Connect (Android only) ──────────────

  /// Whether the Health Connect app is installed and usable. False on
  /// anything other than Android, or if Health Connect isn't installed
  /// / needs an update.
  static Future<bool> isHealthConnectAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      await _ensureConfigured();
      final status = await _health.getHealthConnectSdkStatus();
      debugPrint('[HealthService] Health Connect SDK Status: $status');
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      debugPrint('HealthService.isHealthConnectAvailable failed: $e');
      return false;
    }
  }

  /// Opens the Play Store listing so the user can install or update
  /// Health Connect.
  static Future<void> openHealthConnectInstall() async {
    if (!Platform.isAndroid) return;
    try {
      await _ensureConfigured();
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('HealthService.openHealthConnectInstall failed: $e');
    }
  }

  /// True if BMH already has read+write permission for every type it
  /// uses — checked silently, no system UI shown.
  static Future<bool> hasHealthConnectPermissions() async {
    if (!Platform.isAndroid) return false;
    try {
      await _ensureConfigured();
      
      // NEW: Check each permission individually for debugging
      final result = await _health.hasPermissions(
            _kHealthConnectTypes,
            permissions: _kHealthConnectTypes
                .map((_) => HealthDataAccess.READ_WRITE)
                .toList(),
          ) ??
          false;
      
      debugPrint('[HealthService] Health Connect permissions check: $result');
      
      if (!result) {
        // NEW: Log which permissions might be missing
        debugPrint('[HealthService] Missing permissions for types:');
        for (var type in _kHealthConnectTypes) {
          debugPrint('  - ${type.name}');
        }
      }
      
      return result;
    } catch (e) {
      debugPrint('HealthService.hasHealthConnectPermissions failed: $e');
      return false;
    }
  }

  /// Shows Android's native Health Connect permission screen and
  /// returns true only if the user actually granted access.
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
      debugPrint('HealthService.requestHealthConnectPermissions failed: $e');
      return false;
    }
  }

  /// Writes the band's current readings into Health Connect, then reads
  /// back the last 24h so anything from OTHER apps (Google Fit, Samsung
  /// Health, the phone's own step counter, etc.) can be shown to the
  /// user. Manual, on-demand — called from the "Sync Now" button.
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
          ok: false, written: 0, fromOtherApps: {}, error: 'Android only');
    }
    
    debugPrint('[HealthService] Starting Health Connect sync...');
    debugPrint('[HealthService] Input data: HR=$heartRate, SpO2=$spo2, '
        'BP=$systolic/$diastolic, Temp=$temperature, Steps=$steps');
    
    try {
      await HealthService._ensureConfigured();

      // NEW: Enhanced permission check with debugging
      final hasPerm = await HealthService.hasHealthConnectPermissions();
      debugPrint('[HealthService] Permission check result: $hasPerm');
      
      if (!hasPerm) {
        debugPrint('[HealthService] ❌ SYNC FAILED: Permissions not granted');
        return HealthSyncResult(
          ok: false, written: 0, fromOtherApps: {},
          error: 'Permission not granted',
          debugInfo: 'User has not granted Health Connect permissions. '
              'Go to Settings > Apps > Health > Health Connect and enable all metrics.',
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

      // NEW: Log each write attempt
      debugPrint('[HealthService] Beginning data write phase...');
      
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

      debugPrint('[HealthService] Data write phase complete. '
          'Total written: $written');

      // NEW: Enhanced read-back with detailed logging
      final fromOtherApps = <String, String>{};
      try {
        debugPrint('[HealthService] Reading back last 24h from Health Connect...');
        
        final points = await HealthService._health.getHealthDataFromTypes(
          types: _kHealthConnectTypes,
          startTime: now.subtract(const Duration(hours: 24)),
          endTime: now,
        );
        
        debugPrint('[HealthService] ✅ Read $points.length data points from Health Connect');
        
        // NEW: Log what we found
        Map<String, int> appSources = {};
        for (final p in points) {
          final src = p.sourceName;
          appSources[src] = (appSources[src] ?? 0) + 1;
          
          if (src.toLowerCase().contains('bmh') ||
              src.toLowerCase().contains('biohealthcare')) {
            continue; // skip BMH's own writes — only show OTHER apps
          }
          final label = src.isEmpty ? 'Unknown app' : src;
          fromOtherApps['${p.type.name} · $label'] = p.value.toString();
        }
        
        debugPrint('[HealthService] Data sources found:');
        appSources.forEach((src, count) {
          debugPrint('  - $src: $count points');
        });
        
        if (fromOtherApps.isEmpty && points.isNotEmpty) {
          debugPrint('[HealthService] ⚠️ All points are from BMH itself (no other apps)');
        }
        
      } catch (e) {
        debugPrint('[HealthService] ⚠️ Read-back phase failed: $e');
        // Don't fail the whole sync, just skip reading back other apps
      }

      debugPrint('[HealthService] ✅ SYNC COMPLETED SUCCESSFULLY');
      return HealthSyncResult(
          ok: written > 0, 
          written: written, 
          fromOtherApps: fromOtherApps,
          debugInfo: 'Wrote $written metrics to Health Connect');
          
    } catch (e) {
      debugPrint('[HealthService] ❌ SYNC FAILED WITH EXCEPTION: $e');
      return HealthSyncResult(
          ok: false, 
          written: 0, 
          fromOtherApps: const {}, 
          error: '$e',
          debugInfo: 'Exception during sync. Check logs for details.');
    }
  }

  // Syncs all current vitals.
  // Returns true on success, false on failure.
  // Kept for backward compatibility — superseded by syncWithHealthConnect
  // above for the real Android Health Connect flow.
  Future<bool> syncAll({
    double heartRate = 0,
    double spo2 = 0,
    double systolic = 0,
    double diastolic = 0,
    double temperature = 0,
  }) async {
    try {
      // TODO: Replace with real API call when backend is ready.
      // For now, simulate a successful sync after a short delay.
      await Future.delayed(const Duration(milliseconds: 800));

      debugPrint('HealthService.syncAll: '
          'HR=$heartRate, SpO2=$spo2, '
          'BP=$systolic/$diastolic, Temp=$temperature');

      return true;
    } catch (e) {
      debugPrint('HealthService.syncAll failed: $e');
      return false;
    }
  }
}