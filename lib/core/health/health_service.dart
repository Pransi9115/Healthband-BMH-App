import 'dart:io';
import 'package:health/health.dart';

/// Health Service for iOS HealthKit and Android Google Health Connect
class HealthService {
  static final Health _health = Health();

  // HealthKit data types for iOS
  static const List<HealthDataType> _kHealthKitTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  // Google Health Connect data types for Android
  static const List<HealthDataType> _kHealthConnectTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  /// Request HealthKit authorization for iOS
  static Future<void> requestHealthKitAuthorization() async {
    if (!Platform.isIOS) return;
    try {
      await _health.requestAuthorization(_kHealthKitTypes);
      print('✅ HealthKit authorization requested');
    } catch (e) {
      print('❌ HealthKit error: $e');
    }
  }

  /// Request Health Connect permissions for Android
  static Future<void> requestHealthConnectPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      await _health.requestAuthorization(_kHealthConnectTypes);
      print('✅ Health Connect permissions requested');
    } catch (e) {
      print('❌ Health Connect error: $e');
    }
  }

  /// Sync health data from iOS HealthKit
  static Future<List<HealthDataPoint>> syncWithHealthKit({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!Platform.isIOS) return [];
    try {
      await requestHealthKitAuthorization();
      final data = await _health.getHealthDataFromTypes(
        types: _kHealthKitTypes,
        startTime: startDate,
        endTime: endDate,
      );
      print('✅ iOS HealthKit sync: ${data.length} records');
      return data;
    } catch (e) {
      print('❌ iOS sync error: $e');
      return [];
    }
  }

  /// Sync health data from Android Google Health Connect
  static Future<List<HealthDataPoint>> syncWithHealthConnect({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!Platform.isAndroid) return [];
    try {
      await requestHealthConnectPermissions();
      final data = await _health.getHealthDataFromTypes(
        types: _kHealthConnectTypes,
        startTime: startDate,
        endTime: endDate,
      );
      print('✅ Android Health Connect sync: ${data.length} records');
      return data;
    } catch (e) {
      print('❌ Android sync error: $e');
      return [];
    }
  }

  /// Universal sync - works on both platforms
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

  /// Write health data
  static Future<void> writeHealthData({
    required HealthDataType type,
    required double value,
    required DateTime dateTime,
  }) async {
    try {
      await _health.writeHealthData(
        value: value,
        type: type,
        startTime: dateTime,
        endTime: dateTime,
      );
      print('✅ Written $type: $value');
    } catch (e) {
      print('❌ Write error: $e');
    }
  }

  /// Get all health data
  static Future<List<HealthDataPoint>> getAllHealthData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return syncAll(startDate: startDate, endDate: endDate);
  }
}
