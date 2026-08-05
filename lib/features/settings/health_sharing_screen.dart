// ─────────────────────────────────────────────────────────
//  SETTINGS — SHARE WITH APPLE HEALTH / HEALTH CONNECT
//
//  One master switch, then a metric list underneath. Health data is
//  exactly where people want to share steps but not blood pressure,
//  so the granular controls are not an afterthought.
//
//  The copy names the real product — "Apple Health" on iOS, "Health
//  Connect" on Android — because telling an iPhone user their data
//  went to Health Connect is how you lose their trust in one screen.
// ─────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/health/health_share_service.dart';

const _accent = BMHColors.sCardio;

class HealthSharingScreen extends StatefulWidget {
  const HealthSharingScreen({super.key});

  @override
  State<HealthSharingScreen> createState() => _HealthSharingScreenState();
}

class _HealthSharingScreenState extends State<HealthSharingScreen> {
  final _svc = HealthShareService.instance;
  int _backfillDone = 0;
  int _backfillTotal = 0;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_refresh);
    _svc.init().then((_) => _svc.refreshAvailability());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _svc.removeListener(_refresh);
    super.dispose();
  }

  void _snack(String msg, {bool bad = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: bad ? BMHColors.danger : BMHColors.bg3,
      behavior: SnackBarBehavior.floating,
      content: Text(msg,
        style: BMHText.bodySm.copyWith(
          color: bad ? BMHColors.bg0 : BMHColors.ink))));
  }

  Future<void> _toggleMaster(bool on) async {
    if (!on) {
      await _svc.setEnabled(false);
      _snack('Sharing turned off. Data already sent stays in '
             '${HealthShareService.storeName}.');
      return;
    }

    await _svc.refreshAvailability();
    if (!_svc.isStoreAvailable && Platform.isAndroid) {
      await _showInstallPrompt();
      return;
    }
    final ok = await _svc.setEnabled(true);
    _snack(ok
      ? 'Sharing with ${HealthShareService.storeName} is on'
      : 'Permission was not granted', bad: !ok);
  }

  Future<void> _showInstallPrompt() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BMHColors.bg3,
        title: Text('Health Connect needed', style: BMHText.heading3),
        content: Text(
          'Android shares health data through the Health Connect app. '
          'It is not installed, or needs an update, on this phone.',
          style: BMHText.bodySm.copyWith(
            color: BMHColors.inkDim, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Not now',
              style: BMHText.labelMd.copyWith(color: BMHColors.inkDim))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Open Play Store',
              style: BMHText.labelMd.copyWith(color: _accent))),
        ]));
    if (go == true) await _svc.openStoreInstall();
  }

  Future<void> _syncNow() async {
    final r = await _svc.pushNow();
    if (!r.ok) {
      _snack(r.error ?? 'Sync failed', bad: true);
    } else if (r.written == 0) {
      _snack(r.skipped > 0
        ? 'Already up to date — nothing new since the last sync'
        : 'No readings to send yet. Wear the band for a few minutes.');
    } else {
      _snack('Sent ${r.written} '
             'reading${r.written == 1 ? "" : "s"} to '
             '${HealthShareService.storeName}');
    }
  }

  Future<void> _runBackfill() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BMHColors.bg3,
        title: Text('Send the last 7 days?', style: BMHText.heading3),
        content: Text(
          'Pushes stored heart rate, blood oxygen, temperature and HRV '
          'readings into ${HealthShareService.storeName} with their '
          'original timestamps. This can take a minute and writes a lot '
          'of samples. Anything already sent is skipped.',
          style: BMHText.bodySm.copyWith(
            color: BMHColors.inkDim, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
              style: BMHText.labelMd.copyWith(color: BMHColors.inkDim))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Send',
              style: BMHText.labelMd.copyWith(color: _accent))),
        ]));
    if (go != true) return;

    setState(() { _backfillDone = 0; _backfillTotal = 0; });
    final r = await _svc.backfill(days: 7, onProgress: (d, t) {
      if (mounted) setState(() { _backfillDone = d; _backfillTotal = t; });
    });
    if (mounted) setState(() { _backfillDone = 0; _backfillTotal = 0; });

    if (!r.ok) {
      _snack(r.error ?? 'Backfill failed', bad: true);
    } else {
      _snack(r.written == 0
        ? 'Nothing new to send — already up to date'
        : 'Sent ${r.written} historical readings');
    }
  }

  // ── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final store = HealthShareService.storeName;
    final on = _svc.isEnabled;

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
        title: Text('Connected apps',
          style: BMHText.heading2.copyWith(
            fontSize: 16, letterSpacing: 0.2))),

      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: BMHSpacing.screenH, vertical: 12),
        children: [
          // ── MASTER TOGGLE ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BMHColors.surface,
              borderRadius: BorderRadius.circular(BMHRadius.lg),
              border: Border.all(
                color: on ? _accent.withOpacity(0.4) : BMHColors.line)),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(on ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: _accent.withOpacity(on ? 0.4 : 0.2))),
                  child: Icon(
                    Platform.isIOS
                      ? Icons.favorite_rounded
                      : Icons.health_and_safety_outlined,
                    color: _accent, size: 19)),
                const SizedBox(width: 13),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Share with $store', style: BMHText.bodyMd),
                    const SizedBox(height: 3),
                    Text(
                      on ? 'Your band data is available to other apps'
                         : 'Off — nothing leaves BMH',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 9,
                        color: on ? _accent : BMHColors.inkMute)),
                  ])),
                _switch(on, _toggleMaster),
              ]),
              const SizedBox(height: 12),
              Text(
                'Whatever you share here appears in $store. Any other '
                'app you have given read access to $store can then see '
                'it — that is what makes your band data usable outside '
                'BMH.',
                style: BMHText.bodySm.copyWith(
                  fontSize: 11, color: BMHColors.inkMute, height: 1.5)),
            ])),

          if (on) ...[
            const SizedBox(height: 10),
            _statusStrip(),

            const SizedBox(height: 24),
            _sectionLabel('What to share'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: BMHColors.surface,
                borderRadius: BorderRadius.circular(BMHRadius.lg),
                border: Border.all(color: BMHColors.line)),
              child: Column(children: [
                for (final m in _svc.metrics) ...[
                  _metricRow(m),
                  if (m != _svc.metrics.last)
                    Divider(height: 1,
                      color: BMHColors.line.withOpacity(0.5)),
                ],
              ])),

            const SizedBox(height: 24),
            _sectionLabel('Fill gaps from other apps'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: BMHColors.surface,
                borderRadius: BorderRadius.circular(BMHRadius.lg),
                border: Border.all(color: BMHColors.line)),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Read steps and sleep back',
                        style: BMHText.bodyMd),
                      const SizedBox(height: 3),
                      Text('Only when the band recorded none',
                        style: BMHText.monoSm.copyWith(
                          fontSize: 9, color: BMHColors.inkMute)),
                    ])),
                  _switch(_svc.pullGaps, (v) => _svc.setPullGaps(v)),
                ]),
                const SizedBox(height: 10),
                Text(
                  'On the days the band sits on the charger, your phone '
                  'or another app usually still counted your steps. This '
                  'fills that gap and never overwrites a band reading.',
                  style: BMHText.bodySm.copyWith(
                    fontSize: 10.5, color: BMHColors.inkMute, height: 1.45)),
                if (!_svc.pulled.isEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: BMHColors.bg2,
                      borderRadius: BorderRadius.circular(BMHRadius.md),
                      border: Border.all(color: BMHColors.line)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FOUND TODAY',
                          style: BMHText.monoSm.copyWith(
                            fontSize: 8, letterSpacing: 1.2,
                            color: BMHColors.inkDim)),
                        const SizedBox(height: 7),
                        if (_svc.pulled.steps != null)
                          _pulledRow('Steps',
                            '${_svc.pulled.steps}',
                            _svc.pulled.stepsSource ?? store),
                        if (_svc.pulled.sleepMinutes != null)
                          _pulledRow('Sleep',
                            _hm(_svc.pulled.sleepMinutes!),
                            _svc.pulled.sleepSource ?? store),
                      ])),
                ],
              ])),

            const SizedBox(height: 24),
            _sectionLabel('History'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: BMHColors.surface,
                borderRadius: BorderRadius.circular(BMHRadius.lg),
                border: Border.all(color: BMHColors.line)),
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.history_rounded,
                    color: BMHColors.inkDim, size: 19),
                  title: Text('Send the last 7 days',
                    style: BMHText.bodyMd),
                  subtitle: Text(
                    _backfillTotal > 0
                      ? 'Sending $_backfillDone of $_backfillTotal…'
                      : _svc.lastBackfill == null
                        ? 'Push stored readings with their real times'
                        : 'Last done ${_ago(_svc.lastBackfill!)}',
                    style: BMHText.monoSm.copyWith(
                      fontSize: 9, color: BMHColors.inkMute)),
                  trailing: _svc.isBusy
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: _accent))
                    : const Icon(Icons.chevron_right_rounded,
                        color: BMHColors.inkMute, size: 18),
                  onTap: _svc.isBusy ? null : _runBackfill),
                Divider(height: 1, color: BMHColors.line.withOpacity(0.5)),
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded,
                    color: BMHColors.inkDim, size: 19),
                  title: Text('Resend everything',
                    style: BMHText.bodyMd),
                  subtitle: Text(
                    'Forgets what was already sent. May create duplicates.',
                    style: BMHText.monoSm.copyWith(
                      fontSize: 9, color: BMHColors.inkMute)),
                  onTap: () async {
                    await _svc.resetMarks();
                    _snack('Sync history cleared');
                  }),
              ])),

            const SizedBox(height: 24),
            GestureDetector(
              onTap: _svc.isBusy ? null : _syncNow,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: _svc.isBusy ? BMHColors.bg4 : _accent,
                  borderRadius: BorderRadius.circular(BMHRadius.full)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_svc.isBusy)
                      const SizedBox(width: 15, height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: BMHColors.ink))
                    else
                      const Icon(Icons.sync_rounded,
                        color: BMHColors.bg0, size: 18),
                    const SizedBox(width: 9),
                    Text(_svc.isBusy ? 'Syncing…' : 'Sync now',
                      style: BMHText.labelLg.copyWith(
                        color: _svc.isBusy ? BMHColors.ink : BMHColors.bg0,
                        fontWeight: FontWeight.w600)),
                  ]))),

            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: BMHColors.bg2,
                borderRadius: BorderRadius.circular(BMHRadius.md),
                border: Border.all(color: BMHColors.line)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                    color: BMHColors.inkDim, size: 14),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'Only band vitals are shared. Your meals, medication, '
                    'supplements and lab results never leave BMH. You can '
                    'revoke access at any time from $store itself.',
                    style: BMHText.bodySm.copyWith(
                      fontSize: 10.5, color: BMHColors.inkMute,
                      height: 1.45))),
                ])),
          ],

          const SizedBox(height: 40),
        ]),
    );
  }

  // ── PIECES ──────────────────────────────────────────────
  Widget _statusStrip() {
    final ok = _svc.isStoreAvailable && _svc.hasPermission;
    final color = ok ? BMHColors.sGut : BMHColors.warn;
    final text = !_svc.isStoreAvailable
      ? (Platform.isAndroid
          ? 'Health Connect is missing or needs an update'
          : '${HealthShareService.storeName} is unavailable')
      : !_svc.hasPermission
        ? 'Permission not granted yet — tap to allow'
        : _svc.lastSync == null
          ? 'Connected. Nothing sent yet.'
          : 'Last synced ${_ago(_svc.lastSync!)}';

    return GestureDetector(
      onTap: ok ? null : () async {
        if (!_svc.isStoreAvailable && Platform.isAndroid) {
          await _showInstallPrompt();
        } else {
          await _svc.requestPermission();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(BMHRadius.md),
          border: Border.all(color: color.withOpacity(0.3))),
        child: Row(children: [
          Icon(ok ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
            color: color, size: 15),
          const SizedBox(width: 9),
          Expanded(child: Text(text,
            style: BMHText.monoSm.copyWith(
              fontSize: 9.5, color: color, height: 1.4))),
          if (!ok)
            const Icon(Icons.chevron_right_rounded,
              color: BMHColors.inkMute, size: 16),
        ])));
  }

  Widget _metricRow(ShareMetric m) {
    final on = _svc.metricEnabled(m.key);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.label, style: BMHText.bodyMd.copyWith(
              color: on ? BMHColors.ink : BMHColors.inkDim)),
            const SizedBox(height: 2),
            Text(m.unitLabel,
              style: BMHText.monoSm.copyWith(
                fontSize: 9, color: BMHColors.inkMute)),
          ])),
        _switch(on, (v) => _svc.setMetric(m.key, v)),
      ]));
  }

  Widget _pulledRow(String label, String value, String source) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      Expanded(child: Text(label,
        style: BMHText.bodySm.copyWith(
          fontSize: 11, color: BMHColors.ink2))),
      Text(value,
        style: BMHText.monoSm.copyWith(
          fontSize: 10, color: BMHColors.ink)),
      const SizedBox(width: 7),
      Flexible(child: Text('· $source',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: BMHText.monoSm.copyWith(
          fontSize: 9, color: BMHColors.inkMute))),
    ]));

  Widget _sectionLabel(String s) => Text(s.toUpperCase(),
    style: BMHText.monoSm.copyWith(
      fontSize: 9, letterSpacing: 1.4, color: BMHColors.inkDim));

  Widget _switch(bool value, ValueChanged<bool> onChanged) =>
    GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 42, height: 24,
        decoration: BoxDecoration(
          color: value ? _accent : BMHColors.bg4,
          borderRadius: BorderRadius.circular(BMHRadius.full)),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20, height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle)))));

  static String _hm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h == 0 ? '${m}m' : '${h}h ${m}m';
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
