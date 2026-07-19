import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────────────────
//  PERMISSIONS SERVICE - iOS & Android
//  Manages Location, Bluetooth, Camera, and Background Refresh
// ─────────────────────────────────────────────────────────

class PermissionsService {
  /// Request Location permission (Always on iOS, Background on Android)
  static Future<bool> requestLocationPermission() async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    
    try {
      final status = await Permission.location.request();
      debugPrint('[PermissionsService] Location permission: $status');
      
      if (Platform.isIOS && status.isDenied) {
        // iOS: Try to request "always" permission
        final alwaysStatus = await Permission.locationAlways.request();
        debugPrint('[PermissionsService] Location Always permission: $alwaysStatus');
        return alwaysStatus.isGranted;
      }
      
      return status.isGranted;
    } catch (e) {
      debugPrint('[PermissionsService] Location permission request failed: $e');
      return false;
    }
  }

  /// Request Bluetooth permission (iOS 13+)
  static Future<bool> requestBluetoothPermission() async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    
    try {
      PermissionStatus status;
      
      if (Platform.isIOS) {
        // iOS: Request Bluetooth permission
        status = await Permission.bluetooth.request();
        debugPrint('[PermissionsService] Bluetooth permission: $status');
      } else {
        // Android: Request Bluetooth Scan and Connect
        final scanStatus = await Permission.bluetoothScan.request();
        final connectStatus = await Permission.bluetoothConnect.request();
        debugPrint('[PermissionsService] Bluetooth Scan: $scanStatus, Connect: $connectStatus');
        status = scanStatus.isGranted && connectStatus.isGranted 
            ? PermissionStatus.granted 
            : PermissionStatus.denied;
      }
      
      return status.isGranted;
    } catch (e) {
      debugPrint('[PermissionsService] Bluetooth permission request failed: $e');
      return false;
    }
  }

  /// Request Camera permission (optional, for scanning features)
  static Future<bool> requestCameraPermission() async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    
    try {
      final status = await Permission.camera.request();
      debugPrint('[PermissionsService] Camera permission: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint('[PermissionsService] Camera permission request failed: $e');
      return false;
    }
  }

  /// Request all health-related permissions (Location + Bluetooth + Camera)
  static Future<Map<String, bool>> requestAllHealthPermissions() async {
    debugPrint('[PermissionsService] Requesting all health permissions...');
    
    final results = <String, bool>{};
    
    results['location'] = await requestLocationPermission();
    results['bluetooth'] = await requestBluetoothPermission();
    results['camera'] = await requestCameraPermission();
    
    debugPrint('[PermissionsService] Permission results: $results');
    return results;
  }

  /// Check if all health permissions are granted
  static Future<bool> hasAllHealthPermissions() async {
    try {
      final location = await Permission.location.isGranted;
      final bluetooth = Platform.isIOS 
          ? await Permission.bluetooth.isGranted
          : (await Permission.bluetoothScan.isGranted && 
             await Permission.bluetoothConnect.isGranted);
      
      debugPrint('[PermissionsService] Permissions check - '
          'Location: $location, Bluetooth: $bluetooth');
      
      // Camera is optional, don't require it
      return location && bluetooth;
    } catch (e) {
      debugPrint('[PermissionsService] Permission check failed: $e');
      return false;
    }
  }

  /// Get individual permission status
  static Future<PermissionStatus> getLocationStatus() async {
    return await Permission.location.status;
  }

  static Future<PermissionStatus> getBluetoothStatus() async {
    if (Platform.isIOS) {
      return await Permission.bluetooth.status;
    } else {
      final scanStatus = await Permission.bluetoothScan.status;
      final connectStatus = await Permission.bluetoothConnect.status;
      
      if (scanStatus.isGranted && connectStatus.isGranted) {
        return PermissionStatus.granted;
      } else if (scanStatus.isDenied && connectStatus.isDenied) {
        return PermissionStatus.denied;
      } else {
        return PermissionStatus.restricted;
      }
    }
  }

  static Future<PermissionStatus> getCameraStatus() async {
    return await Permission.camera.status;
  }

  /// Open app settings to allow user to change permissions manually
  static Future<void> openAppSettings() async {
    debugPrint('[PermissionsService] Opening app settings...');
    await openAppSettings();
  }
}
