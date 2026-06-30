import 'dart:io';
import 'package:health/health.dart';

/// Health Service for both iOS (Apple HealthKit) and Android (Google Health Connect)
class HealthService {
  static final Health _health = Health();

  // Health data types for iOS HealthKit
  static const List<HealthDataType> _kHealthKitTypes = [
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

  // Health data types for Android Google Health Connect
  static const List<HealthDataType> _kHealthConnectTypes = [
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

  /// Request HealthKit authorization for iOS
  static Future<void> requestHealthKitAuthorization() async {
    if (!Platform.isIOS) return;

    try {
      await _health.requestAuthorization(_kHealthKitTypes);
      print('✅ HealthKit authorization requested');
    } catch (e) {
      print('❌ HealthKit authorization error: $e');
    }
  }

  /// Check if HealthKit permissions are granted (iOS)
  static Future<bool> hasHealthKitPermissions() async {
    if (!Platform.isIOS) return false;

    try {
      final result = await _health.requestAuthorization(_kHealthKitTypes);
      return result;
    } catch (e) {
      print('❌ Error checking HealthKit permissions: $e');
      return false;
    }
  }

  /// Sync health data from Apple HealthKit (iOS only)
  static Future<List<HealthDataPoint>> syncWithHealthKit({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!Platform.isIOS) return [];

    try {
      // Request authorization first
      await requestHealthKitAuthorization();

      List<HealthDataPoint> healthData = [];

      for (var dataType in _kHealthKitTypes) {
        try {
          final data = await _health.getHealthDataFromTypes(
            types: [dataType],
            startTime: startDate,
            endTime: endDate,
          );
          healthData.addAll(data);
        } catch (e) {
          print('⚠️ Error fetching $dataType: $e');
        }
      }

      print('✅ iOS HealthKit sync complete: ${healthData.length} records');
      return healthData;
    } catch (e) {
      print('❌ iOS HealthKit sync error: $e');
      return [];
    }
  }

  /// Check if Health Connect is available (Android)
  static Future<bool> isHealthConnectAvailable() async {
    if (!Platform.isAndroid) return false;

    try {
      final available = await _health.getHealthConnectSdkStatus();
      return available != null;
    } catch (e) {
      print('❌ Health Connect availability check error: $e');
      return false;
    }
  }

  /// Open Health Connect app install page (Android)
  static Future<void> openHealthConnectInstall() async {
    if (!Platform.isAndroid) return;

    try {
      await _health.installHealthConnect();
      print('✅ Opening Health Connect install page');
    } catch (e) {
      print('❌ Error opening Health Connect install: $e');
    }
  }

  /// Check if Health Connect permissions are granted (Android)
  static Future<bool> hasHealthConnectPermissions() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _health.requestAuthorization(_kHealthConnectTypes);
      return result;
    } catch (e) {
      print('❌ Error checking Health Connect permissions: $e');
      return false;
    }
  }

  /// Request Health Connect permissions (Android)
  static Future<void> requestHealthConnectPermissions() async {
    if (!Platform.isAndroid) return;

    try {
      await _health.requestAuthorization(_kHealthConnectTypes);
      print('✅ Health Connect permissions requested');
    } catch (e) {
      print('❌ Health Connect permission error: $e');
    }
  }

  /// Sync health data from Google Health Connect (Android only)
  static Future<List<HealthDataPoint>> syncWithHealthConnect({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!Platform.isAndroid) return [];

    try {
      // Check if Health Connect is available
      final available = await isHealthConnectAvailable();
      if (!available) {
        print('⚠️ Health Connect not available');
        return [];
      }

      // Request permissions
      await requestHealthConnectPermissions();

      List<HealthDataPoint> healthData = [];

      for (var dataType in _kHealthConnectTypes) {
        try {
          final data = await _health.getHealthDataFromTypes(
            types: [dataType],
            startTime: startDate,
            endTime: endDate,
          );
          healthData.addAll(data);
        } catch (e) {
          print('⚠️ Error fetching $dataType: $e');
        }
      }

      print('✅ Android Health Connect sync complete: ${healthData.length} records');
      return healthData;
    } catch (e) {
      print('❌ Android Health Connect sync error: $e');
      return [];
    }
  }

  /// Universal sync method - works on both iOS and Android
  static Future<List<HealthDataPoint>> syncAll({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (Platform.isIOS) {
      return syncWithHealthKit(startDate: startDate, endDate: endDate);
    } else if (Platform.isAndroid) {
      return syncWithHealthConnect(startDate: startDate, endDate: endDate);
    }
    return [];
  }

  /// Write health data to Health app
  static Future<void> writeHealthData({
    required HealthDataType type,
    required double value,
    required DateTime dateTime,
  }) async {
    try {
      final success = await _health.writeHealthData(
        value: value,
        type: type,
        startTime: dateTime,
        endTime: dateTime,
      );

      if (success) {
        print('✅ Written $type: $value');
      } else {
        print('⚠️ Failed to write $type');
      }
    } catch (e) {
      print('❌ Error writing health data: $e');
    }
  }

  /// Get health data from both sources
  static Future<Map<String, List<HealthDataPoint>>> getAllHealthData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final allData = <String, List<HealthDataPoint>>{};

    if (Platform.isIOS) {
      final iosData = await syncWithHealthKit(
        startDate: startDate,
        endDate: endDate,
      );
      allData['iOS'] = iosData;
    } else if (Platform.isAndroid) {
      final androidData = await syncWithHealthConnect(
        startDate: startDate,
        endDate: endDate,
      );
      allData['Android'] = androidData;
    }

    return allData;
  }
}
