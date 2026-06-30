import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../home/daily_checkin_screen.dart';

// ─────────────────────────────────────────────────────────
//  BATTERY INTENT HELPER
//  Mimics "Complete action using" — Battery Details vs
//  Battery & Performance, with a "Remember my choice" option
// ─────────────────────────────────────────────────────────
enum _BatteryAction { details, performance }

class _BatteryActionSheet extends StatefulWidget {
  const _BatteryActionSheet({super.key});
  @override
  State<_BatteryActionSheet> createState() => _BatteryActionSheetState();
}

class _BatteryActionSheetState extends State<_BatteryActionSheet> {
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BMHColors.bg2,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20)),
        border: Border.all(color: BMHColors.line)),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Container(width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: BMHColors.line,
            borderRadius: BorderRadius.circular(2))),

        Text('Complete action using',
          style: BMHText.heading2.copyWith(fontSize: 16)),
        const SizedBox(height: 24),

        // Two option tiles
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _ActionTile(
            icon: Icons.battery_charging_full_rounded,
            label: 'Battery\nDetails',
            color: BMHColors.cyan,
            onTap: () => Navigator.pop(context, _BatteryAction.details),
          ),
          _ActionTile(
            icon: Icons.speed_rounded,
            label: 'Battery &\nperformance',
            color: BMHColors.sGut,
            onTap: () => Navigator.pop(context, _BatteryAction.performance),
          ),
        ]),

        const SizedBox(height: 20),

        // Remember toggle
        GestureDetector(
          onTap: () => setState(() => _remember = !_remember),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40, height: 24,
              decoration: BoxDecoration(
                color: _remember ? BMHColors.cyan : BMHColors.bg4,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _remember ? BMHColors.cyan : BMHColors.line)),
              child: Align(
                alignment: _remember
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 20, height: 20,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: BMHColors.bg0,
                    shape: BoxShape.circle)))),
            const SizedBox(width: 12),
            Text('Remember my choice',
              style: BMHText.bodyMd.copyWith(
                color: _remember ? BMHColors.ink : BMHColors.inkMute)),
          ]),
        ),

        const SizedBox(height: 20),

        // Cancel
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () => Navigator.pop(context, null),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: BMHColors.bg4,
                borderRadius: BorderRadius.circular(BMHRadius.full),
                border: Border.all(color: BMHColors.line)),
              child: Text('Cancel',
                textAlign: TextAlign.center,
                style: BMHText.labelLg.copyWith(
                  color: BMHColors.inkMute))))),
      ]),
    );
  }

  bool get rememberChoice => _remember;
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon, required this.label,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 120, height: 100,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 24)),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center,
          style: BMHText.monoSm.copyWith(
            fontSize: 10, color: BMHColors.ink,
            fontWeight: FontWeight.w600)),
      ])));
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  // ── Unit preferences ──────────────────────────────────
  String _tempUnit     = '°C';
  String _distUnit     = 'km';
  String _heightUnit   = 'Cm';
  String _weightUnit   = 'Kg';
  String _glucoseUnit  = 'mg/dL';

  // ── Battery action preference ─────────────────────────
  // null = not remembered yet; 'details' or 'performance'
  String? _rememberedBatteryAction;
  static const _batteryPrefKey = 'battery_action_choice';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _tempUnit    = p.getString('unit_temp')    ?? '°C';
      _distUnit    = p.getString('unit_dist')    ?? 'km';
      _heightUnit  = p.getString('unit_height')  ?? 'Cm';
      _weightUnit  = p.getString('unit_weight')  ?? 'Kg';
      _glucoseUnit = p.getString('unit_glucose') ?? 'mg/dL';
      _rememberedBatteryAction = p.getString(_batteryPrefKey);
    });
  }

  // ── Open Battery Settings — with action sheet ─────────
  Future<void> _openBatterySettings() async {
    HapticFeedback.lightImpact();

    // If user previously chose "Remember", skip the dialog
    if (_rememberedBatteryAction != null) {
      await _launchBatteryAction(_rememberedBatteryAction!);
      return;
    }

    // Show the action sheet
    final sheetKey = GlobalKey<_BatteryActionSheetState>();
    final result = await showModalBottomSheet<_BatteryAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BatteryActionSheet(key: sheetKey),
    );

    if (result == null) return; // user cancelled

    // Save remembered choice if toggle was on
    final remember = sheetKey.currentState?.rememberChoice ?? false;
    if (remember) {
      final choice = result == _BatteryAction.details ? 'details' : 'performance';
      final p = await SharedPreferences.getInstance();
      await p.setString(_batteryPrefKey, choice);
      setState(() => _rememberedBatteryAction = choice);
    }

    await _launchBatteryAction(
      result == _BatteryAction.details ? 'details' : 'performance');
  }

  Future<void> _launchBatteryAction(String action) async {
    // Both actions open the app's settings page.
    // On most Android phones (MIUI, OxygenOS, ColorOS) this is the
    // same entry point — the OS then shows Battery Details or
    // Battery & Performance depending on the manufacturer.
    // For a fully custom deep-link you would need platform channels
    // with Intent.ACTION_POWER_USAGE_SUMMARY or similar.
    await openAppSettings();
  }

  Future<void> _save(String key, String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, value);
  }

  // ── Toggle button builder ─────────────────────────────
  Widget _toggle({
    required String label,
    required List<String> options,
    required String selected,
    required void Function(String) onSelect,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(children: [
        Expanded(
          child: Text(label,
            style: BMHText.bodyMd.copyWith(
              color: BMHColors.ink,
              fontWeight: FontWeight.w500))),
        Row(children: options.map((opt) {
          final isSelected = opt == selected;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => onSelect(opt));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? BMHColors.cyan
                    : BMHColors.bg4,
                borderRadius: BorderRadius.circular(BMHRadius.full),
                border: Border.all(
                  color: isSelected
                      ? BMHColors.cyan
                      : BMHColors.line,
                  width: 1)),
              child: Text(opt,
                style: BMHText.monoSm.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? BMHColors.bg0
                      : BMHColors.inkMute))));
        }).toList()),
      ]),
    );
  }

  // ── Section card ──────────────────────────────────────
  Widget _card(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: BMHColors.surface,
      borderRadius: BorderRadius.circular(BMHRadius.xl),
      border: Border.all(color: BMHColors.line)),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18, vertical: 4),
      child: Column(
        children: children.expand((w) sync* {
          yield w;
          if (w != children.last)
            yield Divider(height: 1,
              color: BMHColors.line.withOpacity(0.5));
        }).toList())));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      appBar: AppBar(
        backgroundColor: BMHColors.bg0,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BMHColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: BMHColors.line)),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 14, color: BMHColors.ink))),
        title: Text('General Settings',
          style: BMHText.heading2.copyWith(
            fontSize: 16, letterSpacing: 0.2)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: BMHSpacing.screenH,
          vertical: 12),
        children: [

          // ── UNIT SETTINGS ──────────────────────────
          _SectionLabel('Unit Settings'),
          const SizedBox(height: 10),
          _card([
            _toggle(
              label: 'Temperature Unit',
              options: ['°C', '°F'],
              selected: _tempUnit,
              onSelect: (v) {
                _tempUnit = v;
                _save('unit_temp', v);
              }),
            _toggle(
              label: 'Distance Unit',
              options: ['km', 'Miles'],
              selected: _distUnit,
              onSelect: (v) {
                _distUnit = v;
                _save('unit_dist', v);
              }),
            _toggle(
              label: 'Height Unit',
              options: ['Cm', 'Ft'],
              selected: _heightUnit,
              onSelect: (v) {
                _heightUnit = v;
                _save('unit_height', v);
              }),
            _toggle(
              label: 'Weight Unit',
              options: ['Kg', 'Lb'],
              selected: _weightUnit,
              onSelect: (v) {
                _weightUnit = v;
                _save('unit_weight', v);
              }),
            _toggle(
              label: 'Blood Glucose',
              options: ['mg/dL', 'mmol/L'],
              selected: _glucoseUnit,
              onSelect: (v) {
                _glucoseUnit = v;
                _save('unit_glucose', v);
              }),
          ]),

          const SizedBox(height: 28),

          // ── DAILY CHECK-IN NOTIFICATION ───────────────
          _SectionLabel('Daily Check-In'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: BMHColors.surface,
              borderRadius: BorderRadius.circular(BMHRadius.lg),
              border: Border.all(color: BMHColors.line)),
            child: ListTile(
              leading: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: BMHColors.cyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: BMHColors.cyan.withOpacity(0.3))),
                child: const Icon(Icons.notifications_outlined,
                  color: BMHColors.cyan, size: 18)),
              title: Text('Reminder Notification',
                style: BMHText.bodyMd),
              subtitle: Text('Set daily check-in reminder time',
                style: BMHText.monoSm.copyWith(
                  fontSize: 9, color: BMHColors.inkMute)),
              trailing: const Icon(Icons.chevron_right_rounded,
                color: BMHColors.inkMute, size: 18),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => const CheckInNotificationSheet());
              })),

          const SizedBox(height: 28),

          // ── BACKGROUND SETTINGS ────────────────────
          _SectionLabel('Background Settings'),
          const SizedBox(height: 10),

          // Battery Optimization
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BMHColors.surface,
              borderRadius: BorderRadius.circular(BMHRadius.xl),
              border: Border.all(color: BMHColors.line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('Battery Optimization Whitelist',
                style: BMHText.heading2.copyWith(fontSize: 14)),
              const SizedBox(height: 6),
              Text(
                'To ensure all exercise data is captured, please add the app to the battery protection list.',
                style: BMHText.bodySm.copyWith(
                  color: BMHColors.inkDim)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BMHColors.cyan,
                    foregroundColor: BMHColors.bg0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        BMHRadius.full)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12)),
                  icon: const Icon(Icons.battery_saver_outlined, size: 18),
                  onPressed: _openBatterySettings,
                  label: Text('Open Battery Settings',
                    style: BMHText.labelLg.copyWith(
                      color: BMHColors.bg0,
                      fontWeight: FontWeight.w700)))),
            ])),

          const SizedBox(height: 12),

          // Background Settings
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BMHColors.surface,
              borderRadius: BorderRadius.circular(BMHRadius.xl),
              border: Border.all(color: BMHColors.line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(children: [
                Text('Background Settings',
                  style: BMHText.heading2.copyWith(fontSize: 14)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: BMHColors.sCardio.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(BMHRadius.full),
                    border: Border.all(
                      color: BMHColors.sCardio.withOpacity(0.3))),
                  child: Text('Not Yet Set',
                    style: BMHText.monoSm.copyWith(
                      fontSize: 8,
                      color: BMHColors.sCardio))),
              ]),
              const SizedBox(height: 6),
              Text(
                'Enable "Allow Auto Start" and "Allow Background Activity". Not doing this can lead to bluetooth disconnection, abnormal readings, and inaccurate data capture.',
                style: BMHText.bodySm.copyWith(
                  color: BMHColors.inkDim)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BMHColors.cyan,
                    foregroundColor: BMHColors.bg0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        BMHRadius.full)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12)),
                  icon: const Icon(Icons.app_settings_alt_outlined, size: 18),
                  onPressed: () async {
                    // Opens App Info page → user enables Auto Start
                    // and Background Activity (manufacturer-specific)
                    await openAppSettings();
                  },
                  label: Text('Open App Permissions',
                    style: BMHText.labelLg.copyWith(
                      color: BMHColors.bg0,
                      fontWeight: FontWeight.w700)))),
            ])),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: BMHText.monoSm.copyWith(
      fontSize: 10,
      color: BMHColors.inkMute,
      letterSpacing: 0.8));
}
