import '../../../core/health/health_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/theme/bmh_tokens.dart';
import '../../../shared/widgets/bmh_widgets.dart';
import '../../../core/ble/ble_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _ble = BleService.instance;

  bool _healthConnected = false;
  bool _healthSyncing   = false;
  bool _healthSyncDone  = false;
  DateTime? _lastSynced;

  bool _appleHealthConnected = false;
  bool _appleHealthSyncing   = false;
  bool _appleHealthSyncDone  = false;
  DateTime? _appleLastSynced;

  String _name   = 'BMH User';
  int    _age    = 30;
  String _gender = 'Male';
  double _height = 170;
  double _weight = 70;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _name   = p.getString('profile_name')   ?? 'BMH User';
      _age    = p.getInt('profile_age')        ?? 30;
      _gender = p.getString('profile_gender')  ?? 'Male';
      _height = p.getDouble('profile_height')  ?? 170;
      _weight = p.getDouble('profile_weight')  ?? 70;
    });
  }

  Future<void> _saveProfile() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('profile_name',   _name);
    await p.setInt('profile_age',       _age);
    await p.setString('profile_gender', _gender);
    await p.setDouble('profile_height', _height);
    await p.setDouble('profile_weight', _weight);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  BMHEyebrow('Account'),
                  const SizedBox(height: 4),
                  Text('Profile', style: BMHText.heading1),
                ])),
              ]),
              const SizedBox(height: 24),
              // Profile card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      BMHColors.cyan.withOpacity(0.08),
                      BMHColors.cyan.withOpacity(0.02)]),
                  borderRadius: BorderRadius.circular(BMHRadius.xl),
                  border: Border.all(color: BMHColors.cyan.withOpacity(0.2))),
                child: Row(children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BMHColors.cyan.withOpacity(0.12),
                      border: Border.all(
                        color: BMHColors.cyan.withOpacity(0.3), width: 2)),
                    child: const Center(
                      child: Text('👤', style: TextStyle(fontSize: 28)))),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(_name, style: BMHText.heading2),
                    const SizedBox(height: 4),
                    Text('$_age yrs · $_gender · ${_height.toInt()}cm · ${_weight.toInt()}kg',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 9, color: BMHColors.inkDim)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _showEditProfile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: BMHColors.cyan.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(BMHRadius.full),
                          border: Border.all(
                            color: BMHColors.cyan.withOpacity(0.3))),
                        child: Text('Edit Profile',
                          style: BMHText.monoSm.copyWith(
                            fontSize: 9, color: BMHColors.cyan)))),
                  ])),
                ])),
              const SizedBox(height: 24),
              BMHSectionTitle('Integrations'),
              const SizedBox(height: 14),
              // Show only the relevant platform's health integration
              if (Platform.isAndroid) _buildHealthCard()
              else if (Platform.isIOS) _buildAppleHealthCard(),
              const SizedBox(height: 24),
              BMHSectionTitle('Settings'),
              const SizedBox(height: 14),
              _buildSettingsCard([
                _buildTile(Icons.directions_walk_rounded, BMHColors.sBody,
                  'Step Goal', '${_ble.stepGoal} steps', _showStepGoal),
                _buildTile(Icons.notifications_outlined, BMHColors.sMetabolic,
                  'Notifications', 'On', () {}),
                _buildTile(Icons.dark_mode_outlined, BMHColors.sSleep,
                  'Theme', 'Dark', () {}),
                _buildTile(Icons.language_outlined, BMHColors.sOxygen,
                  'Units', 'Metric', () {}, last: true),
              ]),
              const SizedBox(height: 16),
              _buildSettingsCard([
                _buildTile(Icons.info_outline_rounded, BMHColors.cyan,
                  'About BMH', 'v1.0.0', () {}),
                _buildTile(Icons.privacy_tip_outlined, BMHColors.inkMute,
                  'Privacy Policy', '', () {}),
                _buildTile(Icons.description_outlined, BMHColors.inkMute,
                  'Terms of Service', '', () {}, last: true),
              ]),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: BMHColors.surface,
      borderRadius: BorderRadius.circular(BMHRadius.lg),
      border: Border.all(color: BMHColors.line)),
    child: Column(children: children));

  Widget _buildTile(IconData icon, Color color, String title, String value,
      VoidCallback onTap, {bool last = false}) {
    return Column(children: [
      GestureDetector(
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.2))),
              child: Icon(icon, color: color, size: 16)),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: BMHText.bodyMd)),
            if (value.isNotEmpty)
              Text(value, style: BMHText.monoSm.copyWith(
                color: BMHColors.inkMute, fontSize: 9)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
              color: BMHColors.inkMute, size: 16),
          ]))),
      if (!last)
        const Divider(height: 1, color: BMHColors.line,
          indent: 66, endIndent: 16),
    ]);
  }

  Widget _buildHealthCard() {
    const blue = Color(0xFF4285F4);
    return Container(
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.xl),
        border: Border.all(
          color: _healthConnected ? blue.withOpacity(0.3) : BMHColors.line)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                blue.withOpacity(_healthConnected ? 0.10 : 0.04),
                blue.withOpacity(0.01)]),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(BMHRadius.xl))),
          child: Row(children: [
            // Clean Google Health icon — no emoji
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF4285F4),
                    const Color(0xFF34A853)]),
                borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('Google Health Connect', style: BMHText.heading2),
              const SizedBox(height: 4),
              Text(
                _healthConnected
                    ? _lastSynced != null
                        ? 'Last synced: ${_timeAgo(_lastSynced!)}'
                        : 'Connected — tap Sync Now'
                    : 'Sync your BMH data to Google Health',
                style: BMHText.monoSm.copyWith(
                  fontSize: 9,
                  color: _healthConnected ? blue : BMHColors.inkDim)),
            ])),
            if (_healthConnected)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(BMHRadius.full),
                  border: Border.all(color: blue.withOpacity(0.3))),
                child: Text('Connected',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 8, color: blue))),
          ])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Wrap(spacing: 6, runSpacing: 6,
            children: ['❤️ HR', '👣 Steps', '🩸 SpO2',
              '💉 BP', '😴 Sleep', '🌡️ Temp', '🧬 HRV', '🔬 Glucose']
              .map((d) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BMHColors.bg4,
                  borderRadius: BorderRadius.circular(BMHRadius.full),
                  border: Border.all(color: BMHColors.line)),
                child: Text(d,
                  style: BMHText.monoSm.copyWith(fontSize: 8))))
              .toList())),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: _healthConnected
              ? Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _healthSyncing
                              ? blue.withOpacity(0.5) : blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              BMHRadius.full)),
                          elevation: 0),
                        onPressed: _healthSyncing
                            ? null : _syncToGoogleHealth,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          if (_healthSyncing)
                            const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                          else if (_healthSyncDone)
                            const Icon(Icons.check_rounded, size: 16)
                          else
                            const Icon(Icons.sync_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text(_healthSyncing ? 'Syncing...'
                              : _healthSyncDone ? 'Synced!' : 'Sync Now',
                            style: BMHText.labelLg.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(height: 44, width: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: BMHColors.danger.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            BMHRadius.full)),
                        padding: EdgeInsets.zero),
                      onPressed: () => setState(
                        () => _healthConnected = false),
                      child: const Icon(Icons.link_off_rounded,
                        color: BMHColors.danger, size: 18))),
                ])
              : SizedBox(
                  width: double.infinity, height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BMHRadius.full)),
                      elevation: 0),
                    onPressed: _connectGoogleHealth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const Icon(Icons.link_rounded,
                        color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('Connect Google Health',
                        style: BMHText.labelLg.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                    ])))),
      ]));
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _connectGoogleHealth() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BMHColors.bg3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BMHRadius.xl),
          side: const BorderSide(color: BMHColors.lineBright)),
        title: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF34A853)]),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 16)),
          const SizedBox(width: 10),
          Text('Google Health', style: BMHText.heading2),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('BMH will sync your health data to Google Health Connect.',
            style: BMHText.bodySm.copyWith(color: BMHColors.inkDim)),
          const SizedBox(height: 16),
          ...['❤️ Heart Rate', '👣 Steps', '🩸 SpO2',
            '💉 Blood Pressure', '😴 Sleep', '🌡️ Temperature',
            '🧬 HRV', '🔬 Blood Glucose']
            .map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Text(d, style: BMHText.bodySm),
                const Spacer(),
                const Icon(Icons.check_rounded,
                  color: BMHColors.sGut, size: 14),
              ]))),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
              style: BMHText.labelLg.copyWith(color: BMHColors.inkMute))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BMHRadius.full)),
              elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Connect')),
        ]));

    if (result == true && mounted) {
      setState(() => _healthConnected = true);
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Connected to Google Health! ✅',
          style: BMHText.monoSm.copyWith(color: BMHColors.bg0)),
        backgroundColor: const Color(0xFF4285F4),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BMHRadius.full))));
    }
  }

  Future<void> _syncToGoogleHealth() async {
  if (!_ble.isBandConnected) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Connect your health band first',
        style: BMHText.monoSm.copyWith(color: BMHColors.bg0)),
      backgroundColor: BMHColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
    return;
  }

  setState(() => _healthSyncing = true);

  final success = await HealthService().syncAll(
  heartRate: _ble.heartRate.toDouble(),
  spo2: _ble.spo2.toDouble(),
  systolic: _ble.bpSystolic.toDouble(),
  diastolic: _ble.bpDiastolic.toDouble(),
  temperature: _ble.temperature,
);

  if (!mounted) return;
  setState(() {
    _healthSyncing = false;
    _healthSyncDone = success;
    if (success) _lastSynced = DateTime.now();
  });

  HapticFeedback.heavyImpact();
}

  // ── APPLE HEALTH CARD ─────────────────────────────────
  Widget _buildAppleHealthCard() {
    const apple = Color(0xFFFA2D48);
    return Container(
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.xl),
        border: Border.all(
          color: _appleHealthConnected
              ? apple.withOpacity(0.3) : BMHColors.line)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                apple.withOpacity(_appleHealthConnected ? 0.10 : 0.04),
                apple.withOpacity(0.01)]),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(BMHRadius.xl))),
          child: Row(children: [
            // Clean Apple Health icon — white heart on red gradient
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFFFF2D55), Color(0xFFFA2D48)]),
                borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('Apple Health', style: BMHText.heading2),
              const SizedBox(height: 4),
              Text(
                _appleHealthConnected
                    ? _appleLastSynced != null
                        ? 'Last synced: ${_timeAgo(_appleLastSynced!)}'
                        : 'Connected — tap Sync Now'
                    : 'Sync your BMH data to Apple Health',
                style: BMHText.monoSm.copyWith(
                  fontSize: 9,
                  color: _appleHealthConnected
                      ? apple : BMHColors.inkDim)),
            ])),
            if (_appleHealthConnected)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: apple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(BMHRadius.full),
                  border: Border.all(color: apple.withOpacity(0.3))),
                child: Text('Connected',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 8, color: apple))),
          ])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Wrap(spacing: 6, runSpacing: 6,
            children: ['❤️ HR', '👣 Steps', '🩸 SpO2',
              '💉 BP', '😴 Sleep', '🌡️ Temp', '🧬 HRV', '🔬 Glucose']
              .map((d) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BMHColors.bg4,
                  borderRadius: BorderRadius.circular(BMHRadius.full),
                  border: Border.all(color: BMHColors.line)),
                child: Text(d,
                  style: BMHText.monoSm.copyWith(fontSize: 8))))
              .toList())),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: _appleHealthConnected
              ? Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _appleHealthSyncing
                              ? apple.withOpacity(0.5) : apple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              BMHRadius.full)),
                          elevation: 0),
                        onPressed: _appleHealthSyncing
                            ? null : _syncToAppleHealth,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          if (_appleHealthSyncing)
                            const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                          else if (_appleHealthSyncDone)
                            const Icon(Icons.check_rounded, size: 16)
                          else
                            const Icon(Icons.sync_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text(_appleHealthSyncing ? 'Syncing...'
                              : _appleHealthSyncDone ? 'Synced!' : 'Sync Now',
                            style: BMHText.labelLg.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(height: 44, width: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: BMHColors.danger.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            BMHRadius.full)),
                        padding: EdgeInsets.zero),
                      onPressed: () => setState(
                        () => _appleHealthConnected = false),
                      child: const Icon(Icons.link_off_rounded,
                        color: BMHColors.danger, size: 18))),
                ])
              : SizedBox(
                  width: double.infinity, height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: apple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BMHRadius.full)),
                      elevation: 0),
                    onPressed: _connectAppleHealth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const Icon(Icons.link_rounded,
                        color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('Connect Apple Health',
                        style: BMHText.labelLg.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                    ])))),
      ]));
  }

  Future<void> _connectAppleHealth() async {
    const apple = Color(0xFFFA2D48);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BMHColors.bg3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BMHRadius.xl),
          side: const BorderSide(color: BMHColors.lineBright)),
        title: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF2D55), Color(0xFFFA2D48)]),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 16)),
          const SizedBox(width: 10),
          Text('Apple Health', style: BMHText.heading2),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('BMH will sync your health data to Apple Health.',
            style: BMHText.bodySm.copyWith(color: BMHColors.inkDim)),
          const SizedBox(height: 16),
          ...['❤️ Heart Rate', '👣 Steps', '🩸 SpO2',
            '💉 Blood Pressure', '😴 Sleep', '🌡️ Temperature',
            '🧬 HRV', '🔬 Blood Glucose']
            .map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Text(d, style: BMHText.bodySm),
                const Spacer(),
                const Icon(Icons.check_rounded,
                  color: BMHColors.sGut, size: 14),
              ]))),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
              style: BMHText.labelLg.copyWith(color: BMHColors.inkMute))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: apple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BMHRadius.full)),
              elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Connect')),
        ]));

    if (result == true && mounted) {
      setState(() => _appleHealthConnected = true);
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Connected to Apple Health! ✅',
          style: BMHText.monoSm.copyWith(color: BMHColors.bg0)),
        backgroundColor: apple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BMHRadius.full))));
    }
  }

  Future<void> _syncToAppleHealth() async {
    if (!_ble.isBandConnected) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Connect your health band first',
          style: BMHText.monoSm.copyWith(color: BMHColors.bg0)),
        backgroundColor: BMHColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _appleHealthSyncing = true);
    // Simulate sync — same data as Google Health
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _appleHealthSyncing = false;
      _appleHealthSyncDone = true;
      _appleLastSynced = DateTime.now();
    });
    HapticFeedback.heavyImpact();
  }
  void _showEditProfile() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BMHColors.bg3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BMHRadius.xl),
          side: const BorderSide(color: BMHColors.line)),
        title: Text('Edit Profile', style: BMHText.heading2),
        content: StatefulBuilder(builder: (c, setS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          TextField(
            style: BMHText.bodyMd,
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle: BMHText.monoSm.copyWith(color: BMHColors.inkMute),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BMHRadius.md))),
            controller: TextEditingController(text: _name),
            onChanged: (v) => _name = v),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(
              style: BMHText.bodyMd,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Age',
                labelStyle: BMHText.monoSm.copyWith(color: BMHColors.inkMute),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BMHRadius.md))),
              controller: TextEditingController(text: '$_age'),
              onChanged: (v) => _age = int.tryParse(v) ?? _age)),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(
              value: _gender,
              dropdownColor: BMHColors.bg3,
              style: BMHText.bodyMd,
              decoration: InputDecoration(
                labelText: 'Gender',
                labelStyle: BMHText.monoSm.copyWith(color: BMHColors.inkMute),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BMHRadius.md))),
              items: ['Male', 'Female', 'Other'].map((g) =>
                DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setS(() => _gender = v ?? _gender))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(
              style: BMHText.bodyMd,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Height (cm)',
                labelStyle: BMHText.monoSm.copyWith(color: BMHColors.inkMute),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BMHRadius.md))),
              controller: TextEditingController(
                text: _height.toInt().toString()),
              onChanged: (v) => _height = double.tryParse(v) ?? _height)),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              style: BMHText.bodyMd,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Weight (kg)',
                labelStyle: BMHText.monoSm.copyWith(color: BMHColors.inkMute),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BMHRadius.md))),
              controller: TextEditingController(
                text: _weight.toInt().toString()),
              onChanged: (v) => _weight = double.tryParse(v) ?? _weight)),
          ]),
        ])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
              style: BMHText.labelLg.copyWith(color: BMHColors.inkMute))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BMHColors.cyan,
              foregroundColor: BMHColors.bg0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BMHRadius.full)),
              elevation: 0),
            onPressed: () { setState(() {}); _saveProfile(); Navigator.pop(ctx); },
            child: const Text('Save')),
        ]));
  }

  void _showStepGoal() {
    int newGoal = _ble.stepGoal;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BMHColors.bg3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BMHRadius.xl),
          side: const BorderSide(color: BMHColors.line)),
        title: Text('Step Goal', style: BMHText.heading2),
        content: StatefulBuilder(builder: (c, setS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Text('$newGoal steps',
            style: BMHText.displayMd.copyWith(
              color: BMHColors.sBody, fontSize: 36, height: 1)),
          const SizedBox(height: 12),
          Slider(
            value: newGoal.toDouble(), min: 1000, max: 30000,
            divisions: 58, activeColor: BMHColors.sBody,
            inactiveColor: BMHColors.bg4,
            onChanged: (v) => setS(() => newGoal = v.round())),
          Wrap(spacing: 8, runSpacing: 8,
            children: [5000, 8000, 10000, 15000].map((g) =>
              GestureDetector(
                onTap: () => setS(() => newGoal = g),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: newGoal == g
                        ? BMHColors.sBody.withOpacity(0.15)
                        : BMHColors.bg4,
                    borderRadius: BorderRadius.circular(BMHRadius.full),
                    border: Border.all(color: newGoal == g
                        ? BMHColors.sBody : BMHColors.line)),
                  child: Text('${g ~/ 1000}k',
                    style: BMHText.monoSm.copyWith(
                      color: newGoal == g
                          ? BMHColors.sBody : BMHColors.inkMute))))).toList()),
        ])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
              style: BMHText.labelLg.copyWith(color: BMHColors.inkMute))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BMHColors.sBody,
              foregroundColor: BMHColors.bg0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BMHRadius.full)),
              elevation: 0),
            onPressed: () {
              _ble.setStepGoal(newGoal);
              Navigator.pop(ctx);
            },
            child: const Text('Save')),
        ]));
  }
}
