import 'package:flutter/material.dart';
import '../../../core/ble/ble_service.dart';
import '../../../shared/theme/bmh_tokens.dart';
import '../../../shared/widgets/bmh_widgets.dart';
import '../../../shared/widgets/bmh_global_nav.dart';
import 'ble_intro_screen.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final _ble = BleService.instance;

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onBleChange);
  }

  void _onBleChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _ble.removeListener(_onBleChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(children: [
                BMHIconButton(
                  onTap: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded,
                    color: BMHColors.ink, size: 16),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BMHEyebrow('Connected devices'),
                      Text('Devices', style: BMHText.heading1),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 32),

              // ── HEALTH BAND ──────────────────────────
              BMHSectionTitle('Health Band'),
              const SizedBox(height: 16),

              _ble.isBandConnected
                  ? _ConnectedDeviceCard(
                      device: _ble.connectedBand!,
                      color: BMHColors.sCardio,
                      battery: _ble.battery,
                      onDisconnect: () => _ble.disconnectDevice(
                        BMHDeviceType.healthBand),
                    )
                  : _AddDeviceCard(
                      label: 'Connect Health Band',
                      icon: Icons.watch_outlined,
                      color: BMHColors.sCardio,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BleIntroScreen(isScale: false),
                        ),
                      ),
                    ),

              const SizedBox(height: 24),

              // ── BIOSCALE ─────────────────────────────
              BMHSectionTitle('BioScale'),
              const SizedBox(height: 16),

              _ble.isScaleConnected
                  ? _ConnectedDeviceCard(
                      device: _ble.connectedScale!,
                      color: BMHColors.sGut,
                      onDisconnect: () => _ble.disconnectDevice(
                        BMHDeviceType.bioScale),
                    )
                  : _AddDeviceCard(
                      label: 'Connect BioScale',
                      icon: Icons.monitor_weight_outlined,
                      color: BMHColors.sGut,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BleIntroScreen(isScale: true),
                        ),
                      ),
                    ),

              const SizedBox(height: 32),

              // ── BLE STATUS INFO ──────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BMHColors.cyanSoft,
                  borderRadius: BorderRadius.circular(BMHRadius.md),
                  border: Border.all(color: BMHColors.lineBright),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                    color: BMHColors.cyan, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Devices reconnect automatically when in range. Keep Bluetooth enabled for continuous monitoring.',
                      style: BMHText.bodySm.copyWith(color: BMHColors.inkDim),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CONNECTED DEVICE CARD ─────────────────────────────────

class _ConnectedDeviceCard extends StatelessWidget {
  final BMHBleDevice device;
  final Color color;
  final int battery;
  final VoidCallback onDisconnect;
  const _ConnectedDeviceCard({
    required this.device,
    required this.color,
    this.battery = 0,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(
              device.type == BMHDeviceType.bioScale
                  ? Icons.monitor_weight_outlined
                  : Icons.watch_outlined,
              color: color, size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name, style: BMHText.labelLg),
                const SizedBox(height: 3),
                Text(
                  device.id.substring(0, 17),
                  style: BMHText.monoSm.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
          BMHPill('Connected', type: BMHPillType.success),
        ]),
        // Battery bar — shown when battery data is available
        if (battery > 0) ...[
          const SizedBox(height: 14),
          Row(children: [
            Icon(
              battery > 70
                  ? Icons.battery_full_rounded
                  : battery > 30
                      ? Icons.battery_4_bar_rounded
                      : Icons.battery_1_bar_rounded,
              color: battery > 20 ? color : BMHColors.danger,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: battery / 100,
                  minHeight: 5,
                  backgroundColor: BMHColors.line,
                  color: battery > 20 ? color : BMHColors.danger,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$battery%',
              style: BMHText.monoSm.copyWith(
                fontSize: 11,
                color: battery > 20 ? BMHColors.ink : BMHColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ],
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        // Disconnect
        GestureDetector(
          onTap: () => _confirmDisconnect(context),
          child: Row(children: [
            const Icon(Icons.bluetooth_disabled_rounded,
              color: BMHColors.danger, size: 16),
            const SizedBox(width: 8),
            Text('Disconnect device',
              style: BMHText.labelMd.copyWith(
                color: BMHColors.danger, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  void _confirmDisconnect(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BMHColors.bg3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          side: const BorderSide(color: BMHColors.line),
        ),
        title: Text('Disconnect?', style: BMHText.heading2),
        content: Text(
          'Are you sure you want to disconnect ${device.name}?',
          style: BMHText.bodyMd.copyWith(color: BMHColors.inkDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDisconnect();
            },
            child: Text('Disconnect',
              style: BMHText.labelLg.copyWith(color: BMHColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ── ADD DEVICE CARD ───────────────────────────────────────

class _AddDeviceCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AddDeviceCard({
    required this.label, required this.icon,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          border: Border.all(
            color: BMHColors.line, width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: BMHText.labelLg),
          ),
          Icon(Icons.add_rounded, color: color, size: 20),
        ]),
      ),
    );
  }
}
