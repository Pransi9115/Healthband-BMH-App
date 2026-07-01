import 'dart:io';
import 'package:health/health.dart';

/// Production Health Service - Real health data from iOS HealthKit & Android Health Connect
class HealthService {
  static final Health _health = Health();

  // ========== iOS HealthKit Data Types ==========
  static const List<HealthDataType> iosHealthTypes = [
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

  // ========== Android Health Connect Data Types ==========
  static const List<HealthDataType> androidHealthTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  // ========== Request Permissions ==========
  static Future<void> requestPermissions() async {
    try {
      if (Platform.isIOS) {
        await requestIOSPermissions();
      } else if (Platform.isAndroid) {
        await requestAndroidPermissions();
      }
    } catch (e) {
      print('❌ Permission request error: $e');
      rethrow;
    }
  }

  static Future<void> requestIOSPermissions() async {
    try {
      final result = await _health.requestAuthorization(iosHealthTypes);
      if (result) {
        print('✅ iOS HealthKit permissions granted');
      } else {
        print('⚠️ iOS HealthKit permissions denied');
      }
    } catch (e) {
      print('❌ iOS permission error: $e');
    }
  }

  static Future<void> requestAndroidPermissions() async {
    try {
      final result = await _health.requestAuthorization(androidHealthTypes);
      if (result) {
        print('✅ Android Health Connect permissions granted');
      } else {
        print('⚠️ Android Health Connect permissions denied');
      }
    } catch (e) {
      print('❌ Android permission error: $e');
    }
  }

  // ========== Get All Health Data ==========
  static Future<List<HealthDataPoint>> getAllHealthData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      await requestPermissions();

      List<HealthDataType> dataTypes;
      if (Platform.isIOS) {
        dataTypes = iosHealthTypes;
      } else if (Platform.isAndroid) {
        dataTypes = androidHealthTypes;
      } else {
        return [];
      }

      List<HealthDataPoint> allData = [];

      for (var dataType in dataTypes) {
        try {
          final data = await _health.getHealthDataFromTypes(
            types: [dataType],
            startTime: startDate,
            endTime: endDate,
          );
          allData.addAll(data);
          print('✅ ${dataType.name}: ${data.length} records');
        } catch (e) {
          print('⚠️ Failed to get ${dataType.name}: $e');
        }
      }

      print('✅ Total health data: ${allData.length} records');
      return allData;
    } catch (e) {
      print('❌ Get health data error: $e');
      return [];
    }
  }

  // ========== Get Recent Heart Rate ==========
  static Future<double?> getRecentHeartRate({
    Duration lookbackDuration = const Duration(hours: 1),
  }) async {
    try {
      final now = DateTime.now();
      final startTime = now.subtract(lookbackDuration);

      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startTime,
        endTime: now,
      );

      if (data.isNotEmpty) {
        final lastValue = data.last;
        final hr = double.tryParse(lastValue.value.toString());
        print('✅ Recent heart rate: $hr bpm');
        return hr;
      }
      print('⚠️ No heart rate data found');
      return null;
    } catch (e) {
      print('❌ Heart rate error: $e');
      return null;
    }
  }

  // ========== Get Today's Steps ==========
  static Future<int?> getTodaySteps() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startOfDay,
        endTime: now,
      );

      int totalSteps = 0;
      for (var dataPoint in data) {
        totalSteps += int.tryParse(dataPoint.value.toString()) ?? 0;
      }

      print('✅ Today steps: $totalSteps');
      return totalSteps;
    } catch (e) {
      print('❌ Steps error: $e');
      return null;
    }
  }

  // ========== Get Blood Oxygen ==========
  static Future<double?> getRecentBloodOxygen({
    Duration lookbackDuration = const Duration(hours: 1),
  }) async {
    try {
      final now = DateTime.now();
      final startTime = now.subtract(lookbackDuration);

      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_OXYGEN],
        startTime: startTime,
        endTime: now,
      );

      if (data.isNotEmpty) {
        final o2 = double.tryParse(data.last.value.toString());
        print('✅ Recent O2: $o2%');
        return o2;
      }
      return null;
    } catch (e) {
      print('❌ O2 error: $e');
      return null;
    }
  }

  // ========== Get Health Summary ==========
  static Future<Map<String, dynamic>> getHealthSummary() async {
    try {
      final hr = await getRecentHeartRate();
      final o2 = await getRecentBloodOxygen();
      final steps = await getTodaySteps();

      return {
        'heartRate': hr,
        'bloodOxygen': o2,
        'steps': steps,
        'timestamp': DateTime.now(),
      };
    } catch (e) {
      print('❌ Summary error: $e');
      return {};
    }
  }
}
