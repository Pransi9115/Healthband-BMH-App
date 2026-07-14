import '../../core/ble/ble_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/health/bioscore_calculator.dart';
import '../body/ble/ble_intro_screen.dart';
import '../body/ble/device_management_screen.dart';
import '../health/health_screen.dart';
import '../settings/settings_screen.dart';
import 'main_shell.dart';
import 'daily_checkin_screen.dart';
import 'biomedical_monitoring_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ble = BleService.instance;
  bool _syncing = false;
  bool _syncDone = false;
  double _profileWeight = 0;
  bool _checkInDoneToday = false;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onBleUpdate);
    _loadProfileWeight();
    _loadUserName();
    _checkTodaysCheckIn();
  }

  Future<void> _checkTodaysCheckIn() async {
    final entry = await CheckInService.todaysEntry();
    if (mounted) setState(() => _checkInDoneToday = entry != null);
  }

  Future<void> _loadUserName() async {
    final p = await SharedPreferences.getInstance();
    final n = p.getString('profile_name') ?? '';
    if (mounted && n != _userName) {
      setState(() => _userName = n);
    }
  }

  Future<void> _loadProfileWeight() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _profileWeight = p.getDouble('profile_weight') ?? 0;
    });
  }

  void _onBleUpdate() { if (mounted) setState(() {}); }
  @override
  void dispose() {
    _ble.removeListener(_onBleUpdate);
    super.dispose();
  }

  Future<void> _onSync() async {
    if (_syncing || !_ble.isBandConnected) return;
    setState(() => _syncing = true);
    await _ble.manualRefresh();
    if (mounted) {
      setState(() { _syncing = false; _syncDone = true; });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _syncDone = false);
    }
  }

  void _onBluetooth() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ble.isBandConnected
          ? const DeviceManagementScreen()
          : const BleIntroScreen(isScale: false)));
  }

  void _onSettings() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    _loadUserName(); // no-op unless the name changed in Profile
    return Scaffold(
      backgroundColor: const Color(0xFF080f1e),
      body: Stack(children: [
        Positioned(top: -100, left: -100,
          child: Container(width: 400, height: 400,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                BMHColors.cyan.withOpacity(0.06),
                Colors.transparent])))),
        SafeArea(bottom: false,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BMHSpacing.screenH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // ── TOP BAR ──────────────────────────
                    _TopBar(
                      ble: _ble,
                      syncing: _syncing,
                      syncDone: _syncDone,
                      onSync: _onSync,
                      onBluetooth: _onBluetooth,
                      onSettings: _onSettings),
                    const SizedBox(height: 32),
                    // ── GREETING ─────────────────────────
                    _Greeting(name: _userName),
                    const SizedBox(height: 28),
                    // ── BIOSCORE HERO RING ────────────────
                    // Same BioScoreCalculator used on the Health tab —
                    // shown here too as the Home screen's focal point.
                    Center(child: _BioScoreHero(ble: _ble)),
                    const SizedBox(height: 28),
                    // ── CHECK-IN CARD ─────────────────────
                    BMHCheckInCard(
                      completed: _checkInDoneToday,
                      onTap: () async {
                        if (_checkInDoneToday) return; // already done today
                        await Navigator.push(context,
                          MaterialPageRoute(
                            builder: (_) => const DailyCheckInScreen()));
                        // Reload state after returning
                        _checkTodaysCheckIn();
                      }),
                    const SizedBox(height: 40),
                    // ── TODAY'S OVERVIEW ──────────────────
                    BMHSectionTitle(
                      'Today\'s overview',
                      linkLabel: 'View all',
                      onLink: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const HealthScreen()))),
                    const SizedBox(height: 16),
                    // ── 2×3 METRIC GRID — 6 live metrics ─
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      // CRITICAL: without this, a nested GridView
                      // inherits the phone's safe-area insets as
                      // padding — that was the mystery gap between
                      // Today's overview and Modules.
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.85,
                      children: [
                        _StepsCard(ble: _ble),
                        _MetricCard(
                          value: _ble.heartRate > 0
                              ? _ble.heartRate.toString() : '--',
                          unit: 'bpm', label: 'Heart rate',
                          signalColor: BMHColors.sCardio,
                          icon: Icons.favorite_border_rounded),
                        _MetricCard(
                          value: _ble.spo2 > 0
                              ? _ble.spo2.toString() : '--',
                          unit: '%', label: 'SpO₂',
                          signalColor: BMHColors.sOxygen,
                          icon: Icons.water_drop_outlined),
                        _MetricCard(
                          value: _ble.bloodPressure,
                          unit: 'mmHg', label: 'Blood pressure',
                          signalColor: BMHColors.sSleep,
                          icon: Icons.bloodtype_outlined),
                        _MetricCard(
                          value: _ble.temperature > 0
                              ? _ble.temperature.toStringAsFixed(1) : '--',
                          unit: '°C', label: 'Temperature',
                          signalColor: BMHColors.sMetabolic,
                          icon: Icons.thermostat_outlined),
                        _MetricCard(
                          value: _profileWeight > 0
                              ? _profileWeight.toStringAsFixed(1) : '--',
                          unit: 'kg', label: 'Weight',
                          signalColor: BMHColors.sGut,
                          icon: Icons.monitor_weight_outlined),
                      ]),
                    const SizedBox(height: 8),
                    // ── MODULES ───────────────────────────
                    BMHSectionTitle('Modules'),
                    const SizedBox(height: 16),
                    BMHModuleCard(
                      title: 'Health Vitals',
                      subtitle: 'BioScore · 8 domains',
                      signalColor: BMHColors.sCardio,
                      icon: const Icon(Icons.monitor_heart_outlined),
                      initiallyOpen: false,
                      onTap: () {
                        // Switch to Health tab in MainShell instead of pushing
                        MainShell.of(context)?.switchTab(1);
                      },
                      expandedContent: _HealthModulePreview()),
                    BMHModuleCard(
                      title: 'Bio Body Track',
                      subtitle: 'BioScale · Composition',
                      signalColor: BMHColors.sBody,
                      icon: const Icon(Icons.accessibility_new_outlined),
                      expandedContent: _BodyModulePreview()),
                    BMHModuleCard(
                      title: 'Biomedical Monitoring',
                      subtitle: 'Blood · GUT · DNA',
                      signalColor: BMHColors.sDna,
                      icon: const Icon(Icons.biotech_outlined),
                      expandedContent: const _BiomedicalMonitoringPreview()),
                    BMHModuleCard(
                      title: 'Medicines',
                      subtitle: 'Schedule · Reminders',
                      signalColor: BMHColors.sNervous,
                      icon: const Icon(Icons.medication_outlined)),
                    BMHModuleCard(
                      title: 'BioMedical Diet',
                      subtitle: 'Meals · Kitchen · Macros',
                      signalColor: BMHColors.sMetabolic,
                      icon: const Icon(Icons.restaurant_menu_outlined)),
                    BMHModuleCard(
                      title: 'Bio Care Team',
                      subtitle: 'Doctors · Coaches · Consults',
                      signalColor: BMHColors.sSleep,
                      icon: const Icon(Icons.people_outline_rounded)),
                    const SizedBox(height: 120),
                  ]),
              )),
          ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  TOP BAR — new: Sync + BLE + Settings, no bell
// ─────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final BleService ble;
  final bool syncing;
  final bool syncDone;
  final VoidCallback onSync;
  final VoidCallback onBluetooth;
  final VoidCallback onSettings;

  const _TopBar({
    required this.ble,
    required this.syncing,
    required this.syncDone,
    required this.onSync,
    required this.onBluetooth,
    required this.onSettings,
  });

  static const _teal = Color(0xFF00c8c8);

  @override
  Widget build(BuildContext context) {
    final bleConnected = ble.isBandConnected;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _teal,
              borderRadius: BorderRadius.circular(10)),
            child: const Center(
              child: Icon(Icons.biotech_rounded,
                color: Colors.white, size: 20))),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('BIOMEDICAL HEALTHCARE',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 8,
                color: _teal,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
            Text('biohealthcare.group',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 10,
                color: BMHColors.inkMute)),
          ]),
        ]),

        // Action buttons
        Row(children: [
          // Sync button
          _HeaderBtn(
            onTap: onSync,
            active: bleConnected,
            color: _teal,
            child: syncDone
                ? const Icon(Icons.check_rounded,
                    size: 20, color: Color(0xFF4dbb8f))
                : AnimatedRotation(
                    turns: syncing ? 2 : 0,
                    duration: const Duration(seconds: 1),
                    child: Icon(Icons.refresh_rounded,
                      size: 20,
                      color: syncing
                          ? _teal
                          : bleConnected
                              ? _teal
                              : Colors.white.withOpacity(0.3)))),
          const SizedBox(width: 8),

          // Bluetooth button — 3 states: connected (teal), reconnecting
          // (amber, pulsing — was previously indistinguishable from a
          // dead disconnect), disconnected (red)
          Builder(builder: (_) {
            final reconnecting = !bleConnected && ble.isReconnecting;
            final btColor = bleConnected
                ? _teal
                : reconnecting
                    ? BMHColors.sNervous
                    : BMHColors.sCardio;
            return Stack(children: [
              _HeaderBtn(
                onTap: onBluetooth,
                active: true,
                color: btColor,
                child: Icon(
                  bleConnected
                      ? Icons.bluetooth_connected_rounded
                      : reconnecting
                          ? Icons.bluetooth_searching_rounded
                          : Icons.bluetooth_rounded,
                  size: 20,
                  color: btColor)),
              Positioned(top: 0, right: 0,
                child: reconnecting
                    ? BMHPulsingDot(color: btColor, size: 9)
                    : Container(
                        width: 9, height: 9,
                        decoration: BoxDecoration(
                          color: bleConnected
                              ? const Color(0xFF4dbb8f)
                              : BMHColors.sCardio,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF080f1e), width: 1.5)))),
            ]);
          }),
          const SizedBox(width: 8),

          // Settings button
          _HeaderBtn(
            onTap: onSettings,
            active: false,
            color: BMHColors.inkMute,
            child: Icon(Icons.settings_outlined,
              size: 20, color: BMHColors.inkMute)),
        ]),
      ],
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool active;
  final Color color;
  final Widget child;
  const _HeaderBtn({
    required this.onTap,
    required this.active,
    required this.color,
    required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? color.withOpacity(0.12)
            : const Color(0xFF1a3050),
        border: Border.all(
          color: active
              ? color.withOpacity(0.5)
              : const Color(0xFF2a4060),
          width: active ? 1.5 : 0.5)),
      child: Center(child: child)));
}

// ─────────────────────────────────────────────────────────
//  GREETING
// ─────────────────────────────────────────────────────────
class _Greeting extends StatelessWidget {
  final String name;
  const _Greeting({this.name = ''});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning'
                   : hour < 18 ? 'Good afternoon' : 'Good evening';
    // Show the user's real name (set at Sign Up, editable in
    // Profile). If none stored ('BMH User' default), greet plainly.
    final display =
        (name.isEmpty || name == 'BMH User') ? '' : name.split(' ').first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const BMHEyebrow('All systems operating', showDot: true),
      const SizedBox(height: 8),
      Text.rich(TextSpan(
        style: BMHText.greetTitle,
        children: [
          TextSpan(text: display.isEmpty ? greeting : '$greeting, '),
          if (display.isNotEmpty)
            TextSpan(text: display,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: Color(0xFF00c8c8),
                fontWeight: FontWeight.w400)),
        ])),
      const SizedBox(height: 8),
      Text('Your biology is listening. Here\'s today\'s snapshot.',
        style: BMHText.italic),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
//  BIOSCORE HERO RING
//  Same score/connection state as the Health tab's BioScore
//  card (via BioScoreCalculator) — just the calmer, single-
//  focal-point ring treatment from the Calm Dark reference.
// ─────────────────────────────────────────────────────────
class _BioScoreHero extends StatelessWidget {
  final BleService ble;
  const _BioScoreHero({required this.ble});

  @override
  Widget build(BuildContext context) {
    final result = BioScoreCalculator.compute(ble);
    final hasScore = result.hasScore;
    final fraction = hasScore ? (result.score / 100).clamp(0.0, 1.0) : 0.0;

    final statusText = hasScore
        ? 'All systems steady · live from band'
        : !ble.isBandConnected
            ? 'Connect your band to see BioScore'
            : 'Wear your band to calculate BioScore';
    final statusColor = hasScore ? BMHColors.sGut : BMHColors.inkMute;

    return Column(
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring — fraction of score/100, same idea as the
              // step/progress bars used elsewhere in the app.
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    transform: const GradientRotation(-math.pi / 2),
                    colors: hasScore
                        ? [BMHColors.cyan, BMHColors.sGut, BMHColors.line, BMHColors.line]
                        : [BMHColors.line, BMHColors.line],
                    stops: hasScore
                        ? [0.0, fraction * 0.7, fraction, 1.0]
                        : null,
                  ),
                  boxShadow: hasScore ? BMHShadows.glow(BMHColors.cyan) : null,
                ),
              ),
              // Inner disc
              Container(
                width: 172,
                height: 172,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(0, -0.4),
                    colors: [BMHColors.bg3, BMHColors.bg1],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('BIOSCORE', style: BMHText.eyebrow.copyWith(letterSpacing: 1.6)),
                    const SizedBox(height: 4),
                    Text(
                      hasScore ? '${result.score}' : '--',
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontWeight: FontWeight.w300,
                        fontSize: 56,
                        height: 1,
                        color: hasScore ? BMHColors.ink : BMHColors.inkMute,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasScore ? result.label : 'No data yet',
                      style: BMHText.bodySm.copyWith(color: BMHColors.inkDim),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(BMHRadius.full),
            border: Border.all(color: statusColor.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasScore) ...[
                BMHPulsingDot(color: statusColor, size: 7),
                const SizedBox(width: 7),
              ],
              Text(statusText,
                  style: BMHText.bodySm.copyWith(
                      color: statusColor, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  STEPS CARD — keeps progress bar + goal %
// ─────────────────────────────────────────────────────────
class _StepsCard extends StatelessWidget {
  final BleService ble;
  const _StepsCard({required this.ble});

  @override
  Widget build(BuildContext context) {
    final steps = ble.steps;
    final goal  = ble.stepGoal;
    final prog  = ble.stepProgress.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: BMHColors.sBody.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: BMHColors.sBody.withOpacity(0.25))),
            child: Icon(Icons.directions_walk_rounded,
              color: BMHColors.sBody, size: 14)),
          const Spacer(),
          Text('ACTIVITY',
            style: BMHText.monoSm.copyWith(fontSize: 7,
              color: BMHColors.inkMute, letterSpacing: 0.5)),
        ]),
        const Spacer(),
        Text('$steps',
          style: TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 22,
            color: BMHColors.ink,
            height: 1,
            fontWeight: FontWeight.w300)),
        Text('steps',
          style: BMHText.monoSm.copyWith(
            fontSize: 8, color: BMHColors.inkMute)),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: prog,
            minHeight: 2,
            backgroundColor: BMHColors.bg4,
            valueColor: AlwaysStoppedAnimation(
              prog >= 1.0 ? BMHColors.sGut : BMHColors.sBody))),
        const SizedBox(height: 3),
        Text(prog >= 1.0
            ? 'Goal reached!'
            : '${(prog * 100).round()}% / $goal',
          style: BMHText.monoSm.copyWith(
            fontSize: 7,
            color: prog >= 1.0 ? BMHColors.sGut : BMHColors.sBody)),
      ]));
  }
}

// ─────────────────────────────────────────────────────────
//  METRIC CARD — consistent sizing, dynamic value font
// ─────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String value, unit, label;
  final Color signalColor;
  final IconData icon;
  const _MetricCard({
    required this.value, required this.unit,
    required this.label, required this.signalColor,
    required this.icon});

  // Dynamic font size so long values (112/62) fit on one line
  double get _valueFontSize {
    if (value.length >= 6) return 16; // 112/62, --/--
    if (value.length >= 4) return 19; // 34.8, 98.6
    return 22;                        // 72, 96, 98
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: BMHColors.surface,
      borderRadius: BorderRadius.circular(BMHRadius.lg),
      border: Border.all(color: BMHColors.line)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: signalColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: signalColor.withOpacity(0.25))),
          child: Icon(icon, color: signalColor, size: 14)),
        const Spacer(),
        Flexible(
          child: Text(label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: BMHText.monoSm.copyWith(
              fontSize: 7, color: BMHColors.inkMute,
              letterSpacing: 0.4))),
      ]),
      const Spacer(),
      Text(value,
        style: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: _valueFontSize,
          color: (value == '--' || value == '--/--')
              ? BMHColors.inkMute : BMHColors.ink,
          height: 1,
          fontWeight: FontWeight.w300)),
      const SizedBox(height: 2),
      Text(unit,
        style: BMHText.monoSm.copyWith(
          fontSize: 8, color: BMHColors.inkMute)),
    ]));
}

// ─────────────────────────────────────────────────────────
//  MODULE PREVIEWS
// ─────────────────────────────────────────────────────────
class _HealthModulePreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ble = BleService.instance;
    final hr  = ble.heartRate > 0 ? '${ble.heartRate}' : '--';
    final bp  = ble.bloodPressure;
    final spo = ble.spo2 > 0 ? '${ble.spo2}' : '--';
    final hrv = ble.hrv > 0 ? '${ble.hrv}' : '--';
    return Column(children: [
      const Divider(height: 20),
      BMHHealthRow(label: 'Heart Rate', value: hr, unit: 'bpm',
        signalColor: BMHColors.sCardio,
        icon: const Icon(Icons.favorite_border_rounded), onTap: () {}),
      BMHHealthRow(label: 'Blood Pressure', value: bp, unit: 'mmHg',
        signalColor: BMHColors.sOxygen,
        icon: const Icon(Icons.bloodtype_outlined), onTap: () {}),
      BMHHealthRow(label: 'SpO₂', value: spo, unit: '%',
        signalColor: BMHColors.sOxygen,
        icon: const Icon(Icons.water_drop_outlined),
        showMeasure: true, onTap: () {}),
      BMHHealthRow(label: 'HRV', value: hrv, unit: 'ms',
        signalColor: BMHColors.sGut,
        icon: const Icon(Icons.graphic_eq_rounded), onTap: () {}),
    ]);
  }
}

class _BodyModulePreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Divider(height: 20),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BMHColors.bg4,
          borderRadius: BorderRadius.circular(BMHRadius.md)),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: BMHColors.sBody.withOpacity(0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: BMHColors.sBody.withOpacity(0.2))),
            child: Icon(Icons.monitor_weight_outlined,
              color: BMHColors.sBody.withOpacity(0.5), size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BioScale not connected',
                style: BMHText.bodyMd.copyWith(
                  color: BMHColors.inkMute)),
              const SizedBox(height: 3),
              Text('Connect your BioScale to see body composition data',
                style: BMHText.monoSm.copyWith(
                  fontSize: 9, color: BMHColors.inkDim)),
            ])),
        ])),
    ]);
  }
}

// end of file

// ─────────────────────────────────────────────────────────
//  BIOMEDICAL MONITORING PREVIEW — Blood · GUT · DNA
// ─────────────────────────────────────────────────────────
class _BiomedicalMonitoringPreview extends StatelessWidget {
  const _BiomedicalMonitoringPreview();

  void _open(BuildContext context, String type) =>
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => BiomedicalMonitoringScreen(type: type)));

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Divider(height: 20),
      BMHHealthRow(label: 'Blood Analysis',
        value: '', unit: '',
        signalColor: BMHColors.sCardio,
        icon: const Icon(Icons.bloodtype_outlined),
        onTap: () => _open(context, 'Blood')),
      BMHHealthRow(label: 'GUT Microbiome',
        value: '', unit: '',
        signalColor: BMHColors.sGut,
        icon: const Icon(Icons.spa_outlined),
        onTap: () => _open(context, 'GUT')),
      BMHHealthRow(label: 'DNA Insights',
        value: '', unit: '',
        signalColor: BMHColors.sDna,
        icon: const Icon(Icons.biotech_outlined),
        onTap: () => _open(context, 'DNA')),
    ]);
  }
}
