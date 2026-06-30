import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/ble/ble_service.dart';
import '../../../shared/theme/bmh_tokens.dart';
import '../../../shared/widgets/bmh_widgets.dart';
import '../../../shared/widgets/bmh_global_nav.dart';
import 'ble_connecting_screen.dart';

class BleScanScreen extends StatefulWidget {
  final bool isScale;
  const BleScanScreen({super.key, this.isScale = false});
  @override
  State<BleScanScreen> createState() => _BleScanScreenState();
}

class _BleScanScreenState extends State<BleScanScreen>
    with TickerProviderStateMixin {
  final _ble = BleService.instance;
  late final AnimationController _radarCtrl;
  late final AnimationController _pulseCtrl;
  bool _permissionDenied = false;
  bool _permissionChecked = false;
  bool _permissionPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _ble.addListener(_onBleChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndScan());
  }

  void _onBleChange() { if (mounted) setState(() {}); }

  Future<void> _checkAndScan() async {
    // Cancel reconnect + clear old results before scanning
    _ble.clearForScan();

    final statuses = await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();

    final locationOk =
        statuses[Permission.location] == PermissionStatus.granted ||
        statuses[Permission.locationWhenInUse] == PermissionStatus.granted;

    final permanentlyDenied =
        statuses[Permission.location] == PermissionStatus.permanentlyDenied ||
        statuses[Permission.locationWhenInUse] == PermissionStatus.permanentlyDenied;

    if (!mounted) return;
    setState(() {
      _permissionDenied = !locationOk;
      _permissionChecked = true;
      _permissionPermanentlyDenied = permanentlyDenied;
    });

    if (locationOk) {
      await _ble.stopScan();
      await Future.delayed(const Duration(milliseconds: 500));
      await _ble.startScan();
    }
  }

  Future<void> _rescan() async {
    _ble.clearForScan();
    await _ble.stopScan();
    await Future.delayed(const Duration(milliseconds: 500));
    await _ble.startScan();
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _pulseCtrl.dispose();
    _ble.removeListener(_onBleChange);
    // Do NOT stop scan on dispose — user might go back and come back
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isScale ? BMHColors.sGut : BMHColors.sCardio;
    final devices = _ble.scannedDevices;

    // Show permission denied UI
    if (_permissionChecked && _permissionDenied) {
      final isIOS = Platform.isIOS;
      final message = isIOS
          ? 'BMH needs Location access to scan for nearby Bluetooth devices. Please allow Location permission to continue.'
          : 'Location permission is required to scan for nearby Bluetooth devices on Android.';
      final title = isIOS
          ? 'Location Permission Required'
          : 'Location Permission Required';

      return Scaffold(
        backgroundColor: BMHColors.bg0,
        bottomNavigationBar: const BMHGlobalNav(),
        body: SafeArea(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 80, height: 80,
              decoration: BoxDecoration(
                color: BMHColors.danger.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: BMHColors.danger.withOpacity(0.3))),
              child: const Icon(Icons.location_off_rounded,
                color: BMHColors.danger, size: 36)),
            const SizedBox(height: 24),
            Text(title, style: BMHText.heading1, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(message,
              style: BMHText.italic, textAlign: TextAlign.center),
            const SizedBox(height: 32),
            // Primary button
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                icon: Icon(_permissionPermanentlyDenied
                  ? Icons.settings_outlined
                  : Icons.location_on_outlined, size: 18),
                label: Text(_permissionPermanentlyDenied
                  ? 'Open Settings'
                  : 'Allow Permission'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BMHColors.cyan,
                  foregroundColor: BMHColors.bg0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BMHRadius.full)),
                  elevation: 0),
                onPressed: () async {
                  if (_permissionPermanentlyDenied) {
                    await openAppSettings();
                  } else {
                    await _checkAndScan();
                  }
                })),
            const SizedBox(height: 12),
            // Secondary button
            SizedBox(width: double.infinity, height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: BMHColors.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BMHRadius.full))),
                onPressed: _checkAndScan,
                child: const Text('Try Again'))),
            const SizedBox(height: 24),
            BMHIconButton(onTap: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded,
                color: BMHColors.ink, size: 16)),
          ]),
        )),
      );
    }

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(),
      body: Stack(children: [
        Positioned(top: -100, left: 0, right: 0,
          child: Container(height: 400,
            decoration: BoxDecoration(gradient: RadialGradient(
              center: Alignment.topCenter, radius: 0.8,
              colors: [color.withOpacity(0.06), Colors.transparent])))),
        SafeArea(child: Column(children: [
          // TOP BAR
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH, vertical: 8),
            child: Row(children: [
              BMHIconButton(onTap: () async {
                await _ble.stopScan();
                if (mounted) Navigator.pop(context);
              }, icon: const Icon(Icons.arrow_back_rounded,
                color: BMHColors.ink, size: 16)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                BMHEyebrow(
                  _ble.isScanning ? 'Scanning...' : 'Scan complete',
                  showDot: _ble.isScanning),
                Text(widget.isScale ? 'Find BioScale' : 'Find Health Band',
                  style: BMHText.heading2),
              ])),
              // Refresh button — always visible when not scanning
              if (!_ble.isScanning)
                BMHIconButton(onTap: _rescan,
                  icon: const Icon(Icons.refresh_rounded,
                    color: BMHColors.cyan, size: 16)),
            ])),

          // RADAR ANIMATION
          SizedBox(height: 200,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedBuilder(animation: _radarCtrl,
                builder: (_, __) => CustomPaint(size: const Size(200, 200),
                  painter: _RadarPainter(progress: _radarCtrl.value,
                    color: color, isScanning: _ble.isScanning))),
              AnimatedBuilder(animation: _pulseCtrl,
                builder: (_, __) => Container(width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1), shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withOpacity(0.4 + 0.3 * _pulseCtrl.value),
                      width: 1.5),
                    boxShadow: [BoxShadow(
                      color: color.withOpacity(0.2 * _pulseCtrl.value),
                      blurRadius: 20)]),
                  child: Icon(widget.isScale
                    ? Icons.monitor_weight_outlined : Icons.watch_outlined,
                    color: color, size: 28))),
              if (devices.isNotEmpty)
                Positioned(top: 30, right: 60,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color,
                      borderRadius: BorderRadius.circular(BMHRadius.full)),
                    child: Text('${devices.length} found',
                      style: BMHText.monoSm.copyWith(
                        color: BMHColors.bg0, fontWeight: FontWeight.w600)))),
            ])),

          // ERROR
          if (_ble.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH),
              child: Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BMHColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(BMHRadius.md),
                  border: Border.all(color: BMHColors.danger.withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                    color: BMHColors.danger, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_ble.error!,
                    style: BMHText.bodySm.copyWith(color: BMHColors.danger))),
                ]))),

          const SizedBox(height: 8),

          // DEVICE LIST
          Expanded(child: devices.isEmpty
            ? _EmptyState(isScanning: _ble.isScanning, color: color,
                onRescan: _rescan)
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: BMHSpacing.screenH),
                itemCount: devices.length,
                itemBuilder: (_, i) => _DeviceRow(
                  device: devices[i], color: color,
                  onTap: () => _connectTo(devices[i])))),
        ])),
      ]),
    );
  }

  Future<void> _connectTo(BMHBleDevice dev) async {
    await _ble.stopScan();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BleConnectingScreen(device: dev, isScale: widget.isScale)));
  }
}

class _RadarPainter extends CustomPainter {
  final double progress; final Color color; final bool isScanning;
  _RadarPainter({required this.progress, required this.color, required this.isScanning});
  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(centre, i * 30.0,
        Paint()..color = color.withOpacity(0.08)
          ..style = PaintingStyle.stroke..strokeWidth = 1);
    }
    if (!isScanning) return;
    canvas.drawArc(Rect.fromCircle(center: centre, radius: 90),
      progress * math.pi * 2, math.pi * 0.8, true,
      Paint()..shader = SweepGradient(startAngle: 0, endAngle: math.pi * 2,
        colors: [color.withOpacity(0.0), color.withOpacity(0.35)],
        stops: const [0.0, 1.0],
        transform: GradientRotation(progress * math.pi * 2))
          .createShader(Rect.fromCircle(center: centre, radius: 90))
        ..style = PaintingStyle.fill);
    canvas.drawCircle(centre, progress * 90,
      Paint()..color = color.withOpacity((1 - progress) * 0.5)
        ..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }
  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
    old.progress != progress || old.isScanning != isScanning;
}

class _DeviceRow extends StatelessWidget {
  final BMHBleDevice device; final Color color; final VoidCallback onTap;
  const _DeviceRow({required this.device, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isKnown = device.type != BMHDeviceType.unknown;
    return GestureDetector(onTap: onTap,
      child: Container(margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isKnown ? color.withOpacity(0.06) : BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          border: Border.all(color: isKnown ? color.withOpacity(0.3) : BMHColors.line)),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
              color: isKnown ? color.withOpacity(0.12) : BMHColors.bg4,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isKnown ? color.withOpacity(0.3) : BMHColors.line)),
            child: Icon(device.type == BMHDeviceType.bioScale
              ? Icons.monitor_weight_outlined
              : device.type == BMHDeviceType.healthBand
                  ? Icons.watch_outlined : Icons.bluetooth_rounded,
              color: isKnown ? color : BMHColors.inkMute, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(device.name, style: BMHText.labelLg),
            const SizedBox(height: 3),
            Row(children: [
              if (isKnown) ...[
                BMHPill(device.type == BMHDeviceType.healthBand
                  ? 'Health Band' : 'BioScale', type: BMHPillType.info),
                const SizedBox(width: 6),
              ],
              Text(device.id.length > 8 ? device.id.substring(0, 8) : device.id,
                style: BMHText.monoSm.copyWith(fontSize: 9)),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _SignalBars(bars: device.signalBars, color: color),
            const SizedBox(height: 4),
            Text('${device.rssi} dBm',
              style: BMHText.monoSm.copyWith(fontSize: 9)),
          ]),
          const SizedBox(width: 10),
          Icon(Icons.chevron_right_rounded,
            color: isKnown ? color : BMHColors.inkMute, size: 20),
        ])));
  }
}

class _SignalBars extends StatelessWidget {
  final int bars; final Color color;
  const _SignalBars({required this.bars, required this.color});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
    children: List.generate(4, (i) => Container(
      width: 4, height: 4.0 + i * 3, margin: const EdgeInsets.only(left: 2),
      decoration: BoxDecoration(
        color: i < bars ? color : BMHColors.bg4,
        borderRadius: BorderRadius.circular(1)))));
}

class _EmptyState extends StatelessWidget {
  final bool isScanning; final Color color; final VoidCallback onRescan;
  const _EmptyState({required this.isScanning, required this.color, required this.onRescan});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (isScanning) ...[
        SizedBox(width: 32, height: 32,
          child: CircularProgressIndicator(color: color, strokeWidth: 2)),
        const SizedBox(height: 16),
        Text('Searching for devices...',
          style: BMHText.bodyMd.copyWith(color: BMHColors.inkDim)),
      ] else ...[
        Icon(Icons.bluetooth_searching_rounded, color: BMHColors.inkMute, size: 48),
        const SizedBox(height: 16),
        Text('No devices found', style: BMHText.heading2),
        const SizedBox(height: 8),
        Text('Make sure your device is powered on\nand within range',
          style: BMHText.italic, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        // Prominent rescan button when scan is complete
        ElevatedButton.icon(
          onPressed: onRescan,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Scan Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: color, foregroundColor: BMHColors.bg0)),
      ],
    ]));
}
