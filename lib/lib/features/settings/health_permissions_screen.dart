import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/health/health_service.dart';
import '../../core/permissions/permissions_service.dart';

// ─────────────────────────────────────────────────────────
//  HEALTH PERMISSIONS SCREEN
//  Manage and display health-related app permissions
// ─────────────────────────────────────────────────────────

class HealthPermissionsScreen extends StatefulWidget {
  const HealthPermissionsScreen({Key? key}) : super(key: key);

  @override
  State<HealthPermissionsScreen> createState() =>
      _HealthPermissionsScreenState();
}

class _HealthPermissionsScreenState extends State<HealthPermissionsScreen> {
  late PermissionStatus _locationStatus;
  late PermissionStatus _bluetoothStatus;
  late PermissionStatus _cameraStatus;
  bool _hasHealthKitAccess = false;
  bool _hasHealthConnectAccess = false;

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
  }

  Future<void> _checkAllPermissions() async {
    final locationStatus = await PermissionsService.getLocationStatus();
    final bluetoothStatus = await PermissionsService.getBluetoothStatus();
    final cameraStatus = await PermissionsService.getCameraStatus();

    bool healthKitAccess = false;
    bool healthConnectAccess = false;

    if (Platform.isIOS) {
      healthKitAccess = await HealthService.hasHealthKitPermissions();
    } else if (Platform.isAndroid) {
      healthConnectAccess = await HealthService.hasHealthConnectPermissions();
    }

    setState(() {
      _locationStatus = locationStatus;
      _bluetoothStatus = bluetoothStatus;
      _cameraStatus = cameraStatus;
      _hasHealthKitAccess = healthKitAccess;
      _hasHealthConnectAccess = healthConnectAccess;
    });
  }

  Color _getStatusColor(PermissionStatus status) {
    if (status.isGranted) return Colors.green;
    if (status.isDenied) return Colors.red;
    if (status.isRestricted) return Colors.orange;
    return Colors.grey;
  }

  String _getStatusText(PermissionStatus status) {
    if (status.isGranted) return 'Allowed';
    if (status.isDenied) return 'Denied';
    if (status.isRestricted) return 'Restricted';
    if (status.isPermanentlyDenied) return 'Permanently Denied';
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Permissions'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'ALLOW HEALTHBAND TO ACCESS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Location Permission
            _buildPermissionCard(
              icon: Icons.location_on,
              title: 'Location',
              status: _locationStatus,
              onTap: () async {
                await PermissionsService.requestLocationPermission();
                await _checkAllPermissions();
              },
            ),
            const SizedBox(height: 12),

            // Bluetooth Permission
            _buildPermissionCard(
              icon: Icons.bluetooth,
              title: 'Bluetooth',
              status: _bluetoothStatus,
              onTap: () async {
                await PermissionsService.requestBluetoothPermission();
                await _checkAllPermissions();
              },
            ),
            const SizedBox(height: 12),

            // Camera Permission
            _buildPermissionCard(
              icon: Icons.camera_alt,
              title: 'Camera',
              status: _cameraStatus,
              onTap: () async {
                await PermissionsService.requestCameraPermission();
                await _checkAllPermissions();
              },
            ),
            const SizedBox(height: 12),

            // Platform-specific: HealthKit (iOS) or Health Connect (Android)
            if (Platform.isIOS)
              _buildHealthKitCard()
            else if (Platform.isAndroid)
              _buildHealthConnectCard(),

            const SizedBox(height: 24),

            // Background App Refresh
            _buildSwitchCard(
              title: 'Background App Refresh',
              subtitle: 'Allow continuous health monitoring',
              value: true, // You can store this in SharedPreferences
              onChanged: (value) {
                // Handle background refresh toggle
              },
            ),
            const SizedBox(height: 12),

            // Mobile Data
            _buildSwitchCard(
              title: 'Mobile Data',
              subtitle: 'Use mobile data for syncing',
              value: true,
              onChanged: (value) {
                // Handle mobile data toggle
              },
            ),

            const SizedBox(height: 24),

            // Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      Platform.isIOS
                          ? 'Your health data is securely stored in Apple Health and synced with HealthBand'
                          : 'Your health data is securely stored in Google Health Connect and synced with HealthBand',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Open Settings Button (if any permission is denied)
            if (_locationStatus.isDenied ||
                _bluetoothStatus.isDenied ||
                (_hasHealthKitAccess == false && Platform.isIOS) ||
                (_hasHealthConnectAccess == false && Platform.isAndroid))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('Open App Settings'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.grey[800],
                  ),
                  onPressed: () {
                    openAppSettings();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required PermissionStatus status,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: _getStatusColor(status), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  _getStatusText(status),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  status.isGranted ? Icons.check_circle : Icons.chevron_right,
                  color: _getStatusColor(status),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthKitCard() {
    return GestureDetector(
      onTap: () async {
        await HealthService.requestHealthKitAuthorization();
        await _checkAllPermissions();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(
              Icons.favorite,
              color: _hasHealthKitAccess ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Apple Health',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  _hasHealthKitAccess ? 'Allowed' : 'Denied',
                  style: TextStyle(
                    fontSize: 12,
                    color: _hasHealthKitAccess ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _hasHealthKitAccess ? Icons.check_circle : Icons.chevron_right,
                  color: _hasHealthKitAccess ? Colors.green : Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthConnectCard() {
    return GestureDetector(
      onTap: () async {
        final available =
            await HealthService.isHealthConnectAvailable();
        if (!available) {
          await HealthService.openHealthConnectInstall();
        } else {
          await HealthService.requestHealthConnectPermissions();
        }
        await _checkAllPermissions();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(
              Icons.favorite,
              color: _hasHealthConnectAccess ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Google Health Connect',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  _hasHealthConnectAccess ? 'Allowed' : 'Denied',
                  style: TextStyle(
                    fontSize: 12,
                    color: _hasHealthConnectAccess
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _hasHealthConnectAccess
                      ? Icons.check_circle
                      : Icons.chevron_right,
                  color: _hasHealthConnectAccess ? Colors.green : Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
