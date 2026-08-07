// ─────────────────────────────────────────────────────────
//  BIOSCALE PAIRING
//
//  The scale is paired here rather than through the generic Bluetooth
//  flow, and that separation is deliberate.
//
//  WHY THE OLD PATH COULD NEVER WORK
//  This screen used to drive Qingniu's native SDK, on the assumption
//  that the FG2001B-A was a Yolanda scale. It is not. It is a Lefu
//  OEM unit speaking the Fitdays FFB0 protocol, so Qingniu's SDK
//  discarded it during scanning and reported nothing — no device, no
//  error, forever. See lefu_scale_service.dart for the evidence.
//
//  The scale is now read directly over flutter_blue_plus, the same
//  stack as the Health Band. No native plugin, no appId, no vendor
//  configuration file.
//
//  WEIGHT IS MEASURED, COMPOSITION IS ESTIMATED
//  Nobody outside Lefu has decoded the impedance frame, so body fat
//  and the rest are computed from published equations rather than
//  measured. Whatever this screen and Bio Body Track show must make
//  that distinction visible — BodyComposition.source carries it.
//
//  A SCALE IS NOT A WATCH
//  It wakes when stood on, advertises for a few seconds, transmits,
//  and powers down. Every instruction and timeout here is built around
//  that, and the screen says what it is waiting for rather than
//  showing an unexplained spinner — the failure that sent us round in
//  circles for a day.
// ─────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';

import '../../../shared/theme/bmh_tokens.dart';
import '../../../shared/widgets/bmh_widgets.dart';
import '../../../core/body/lefu_scale_service.dart';
import '../body_track_screen.dart';

const _accent = BMHColors.sGut;

class ScalePairingScreen extends StatefulWidget {
  const ScalePairingScreen({super.key});

  @override
  State<ScalePairingScreen> createState() => _ScalePairingScreenState();
}

class _ScalePairingScreenState extends State<ScalePairingScreen> {
  final _qn = LefuScaleService.instance;

  Timer? _scanTimeout;
  bool _scanExpired = false;
  bool _autoConnected = false;

  @override
  void initState() {
    super.initState();
    _qn.addListener(_onChange);
    _begin();
  }

  void _onChange() {
    if (!mounted) return;

    // Exactly one scale in range is the normal case, and making
    // someone tap it when it is the only option wastes the few
    // seconds of advertising they have.
    if (!_autoConnected &&
        _qn.state == ScaleState.scanning &&
        _qn.found.length == 1) {
      _autoConnected = true;
      _connect(_qn.found.first);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _scanTimeout?.cancel();
    _qn.removeListener(_onChange);
    super.dispose();
  }

  Future<void> _begin() async {
    setState(() {
      _scanExpired = false;
      _autoConnected = false;
    });

    await _qn.init();
    if (!mounted || !_qn.isAvailable) return;

    await _qn.startScan();

    // A silent give-up is what made this impossible to diagnose. Now
    // the screen says what happened and offers a retry.
    _scanTimeout?.cancel();
    _scanTimeout = Timer(const Duration(seconds: 20), () {
      if (!mounted) return;
      if (_qn.state == ScaleState.scanning) {
        _qn.stopScan();
        setState(() => _scanExpired = true);
      }
    });
  }

  Future<void> _connect(ScaleDevice d) async {
    _scanTimeout?.cancel();
    await _qn.stopScan();
    await _qn.connect(d.mac);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: Stack(children: [
        Positioned(top: -160, right: -110,
          child: Container(width: 420, height: 420,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _accent.withOpacity(0.09), Colors.transparent])))),

        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.s5, vertical: 8),
            child: Row(children: [
              BMHIconButton(
                onTap: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded,
                  color: BMHColors.ink, size: 16)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BMHEyebrow('DEVICE SETUP'),
                  Text('BioScale', style: BMHText.heading1),
                ])),
            ])),

          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BMHSpacing.s5, 8, BMHSpacing.s5, 40),
            children: [_body()])),
        ])),
      ]));
  }

  Widget _body() {
    if (!_qn.isAvailable) return _unavailable();

    switch (_qn.state) {
      case ScaleState.done:      return _done();
      case ScaleState.measuring: return _measuring();
      case ScaleState.connected: return _standOn();
      case ScaleState.connecting:return _connecting();
      case ScaleState.error:     return _error();
      default:
        if (_scanExpired) return _notFound();
        return _scanning();
    }
  }

  // ── STATES ──────────────────────────────────────────────
  Widget _scanning() => Column(children: [
    _hero(Icons.bluetooth_searching_rounded, pulse: true),
    const SizedBox(height: 22),
    Text('Looking for your BioScale',
      textAlign: TextAlign.center,
      style: BMHText.heading2.copyWith(fontSize: 20)),
    const SizedBox(height: 8),
    Text(
      'Step on the scale now to wake it. It only broadcasts for a few '
      'seconds at a time.',
      textAlign: TextAlign.center,
      style: BMHText.bodySm.copyWith(
        fontSize: 12.5, color: BMHColors.inkDim, height: 1.5)),
    const SizedBox(height: 20),

    if (_qn.found.isEmpty)
      _foundCount(0)
    else ...[
      _foundCount(_qn.found.length),
      const SizedBox(height: 12),
      for (final d in _qn.found) _deviceTile(d),
    ],
  ]);

  Widget _connecting() => Column(children: [
    _hero(Icons.bluetooth_connected_rounded, pulse: true),
    const SizedBox(height: 22),
    Text('Connecting to your scale',
      textAlign: TextAlign.center,
      style: BMHText.heading2.copyWith(fontSize: 20)),
    const SizedBox(height: 8),
    Text('Stay close to it while this finishes.',
      textAlign: TextAlign.center,
      style: BMHText.bodySm.copyWith(
        fontSize: 12.5, color: BMHColors.inkDim, height: 1.5)),
  ]);

  Widget _notFound() => Column(children: [
    _hero(Icons.search_off_rounded, tone: BMHColors.warn),
    const SizedBox(height: 22),
    Text('No scale found',
      textAlign: TextAlign.center,
      style: BMHText.heading2.copyWith(fontSize: 20)),
    const SizedBox(height: 10),
    Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tip('1', 'Step on the scale, then tap retry within a few '
                    'seconds. It sleeps quickly.'),
          _tip('2', 'Stand on it with bare feet — socks give weight '
                    'only, with no body composition.'),
          _tip('3', 'Keep your phone within about half a metre.'),
          _tip('4', 'If the scale is showing a weight in another app, '
                    'close that app first. Only one can hold it.'),
        ])),
    const SizedBox(height: 18),
    _button('Try again', _begin),
  ]);

  Widget _standOn() => Column(children: [
    _hero(Icons.monitor_weight_outlined, pulse: true),
    const SizedBox(height: 22),
    Text('Connected — step on now',
      textAlign: TextAlign.center,
      style: BMHText.heading2.copyWith(fontSize: 20)),
    const SizedBox(height: 8),
    Text(
      'Stand still on the scale with bare feet. Bare skin on the metal '
      'is what lets it measure body composition rather than weight '
      'alone.',
      textAlign: TextAlign.center,
      style: BMHText.bodySm.copyWith(
        fontSize: 12.5, color: BMHColors.inkDim, height: 1.5)),
    const SizedBox(height: 20),
    _liveWeight(),
  ]);

  Widget _measuring() => Column(children: [
    _hero(Icons.graphic_eq_rounded, pulse: true),
    const SizedBox(height: 22),
    Text('Measuring',
      textAlign: TextAlign.center,
      style: BMHText.heading2.copyWith(fontSize: 20)),
    const SizedBox(height: 8),
    Text('Hold still. This takes a few seconds.',
      textAlign: TextAlign.center,
      style: BMHText.bodySm.copyWith(
        fontSize: 12.5, color: BMHColors.inkDim, height: 1.5)),
    const SizedBox(height: 20),
    _liveWeight(),
  ]);

  Widget _done() {
    final c = _qn.last;
    return Column(children: [
      _hero(Icons.check_rounded, tone: _accent),
      const SizedBox(height: 22),
      Text('Measurement complete',
        textAlign: TextAlign.center,
        style: BMHText.heading2.copyWith(fontSize: 20)),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          border: Border.all(color: _accent.withOpacity(0.32))),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text((c?.weightKg ?? _qn.liveWeight).toStringAsFixed(1),
                style: BMHText.displayMd.copyWith(
                  fontSize: 46, color: _accent, height: 1)),
              Padding(
                padding: const EdgeInsets.only(bottom: 7, left: 5),
                child: Text('kg',
                  style: BMHText.bodySm.copyWith(
                    fontSize: 14, color: BMHColors.inkDim))),
            ]),
          if (c != null && c.bodyFatPct > 0) ...[
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat('${c.bodyFatPct.toStringAsFixed(1)}%', 'BODY FAT'),
                _stat('${c.muscleKg.toStringAsFixed(1)} kg', 'MUSCLE'),
                _stat(c.bmi.toStringAsFixed(1), 'BMI'),
              ]),
          ] else ...[
            const SizedBox(height: 12),
            // Weight without composition almost always means socks.
            Text(
              'Weight only this time. Body composition needs bare feet '
              'on the metal contacts.',
              textAlign: TextAlign.center,
              style: BMHText.bodySm.copyWith(
                fontSize: 11, color: BMHColors.inkMute, height: 1.45)),
          ],
        ])),
      const SizedBox(height: 18),
      _button('See your full report', () {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => const BodyTrackScreen()));
      }),
      const SizedBox(height: 10),
      TextButton(
        onPressed: _begin,
        child: Text('Measure again',
          style: BMHText.labelMd.copyWith(color: BMHColors.inkDim))),
    ]);
  }

  Widget _error() => Column(children: [
    _hero(Icons.error_outline_rounded, tone: BMHColors.danger),
    const SizedBox(height: 22),
    Text('Something went wrong',
      textAlign: TextAlign.center,
      style: BMHText.heading2.copyWith(fontSize: 20)),
    const SizedBox(height: 10),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(color: BMHColors.line)),
      child: Text(_qn.error ?? 'Unknown error',
        textAlign: TextAlign.center,
        style: BMHText.bodySm.copyWith(
          fontSize: 11.5, color: BMHColors.ink2, height: 1.5))),
    const SizedBox(height: 18),
    _button('Try again', _begin),
  ]);

  Widget _unavailable() => Column(children: [
    _hero(Icons.extension_off_rounded, tone: BMHColors.warn),
    const SizedBox(height: 22),
    Text('Scale support unavailable',
      textAlign: TextAlign.center,
      style: BMHText.heading2.copyWith(fontSize: 20)),
    const SizedBox(height: 10),
    Text(_qn.error ?? 'This build cannot read from the BioScale.',
      textAlign: TextAlign.center,
      style: BMHText.bodySm.copyWith(
        fontSize: 12, color: BMHColors.inkDim, height: 1.5)),
  ]);

  // ── PIECES ──────────────────────────────────────────────
  /// [pulse] marks the states where the app is waiting on the scale
  /// rather than on the person. The breathing glow is the difference
  /// between "still working" and "stuck", which matters on a screen
  /// where the honest answer is sometimes twenty seconds of nothing.
  Widget _hero(IconData icon, {Color tone = _accent, bool pulse = false}) =>
    Center(child: TweenAnimationBuilder<double>(
      key: ValueKey('${icon.codePoint}_$pulse'),
      tween: Tween(begin: pulse ? 0.55 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (ctx, t, child) => Container(
        width: 116, height: 116,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tone.withOpacity(0.10),
          border: Border.all(
            color: tone.withOpacity(0.4), width: 1.5),
          boxShadow: [BoxShadow(
            color: tone.withOpacity(0.22 * t),
            blurRadius: 34 * t,
            spreadRadius: 2 * t)]),
        child: child),
      child: Icon(icon, color: tone, size: 44)));

  Widget _foundCount(int n) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: BMHColors.bg2,
      borderRadius: BorderRadius.circular(BMHRadius.full),
      border: Border.all(color: BMHColors.line)),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      BMHPulsingDot(color: n > 0 ? _accent : BMHColors.inkDim, size: 6),
      const SizedBox(width: 9),
      // The count is deliberately visible. Zero means the SDK's scan
      // is returning nothing, which is a different problem from a
      // scale that is found but will not connect.
      Text(n == 0
          ? 'Scanning — nothing found yet'
          : n == 1 ? '1 scale found' : '$n scales found',
        style: BMHText.monoSm.copyWith(
          fontSize: 10, color: n > 0 ? _accent : BMHColors.inkDim)),
    ]));

  Widget _deviceTile(ScaleDevice d) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: GestureDetector(
      onTap: () => _connect(d),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          border: Border.all(color: _accent.withOpacity(0.35))),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _accent.withOpacity(0.32))),
            child: const Icon(Icons.monitor_weight_outlined,
              color: _accent, size: 20)),
          const SizedBox(width: 13),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.name.isEmpty ? 'BioScale' : d.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BMHText.labelLg.copyWith(color: BMHColors.ink)),
              const SizedBox(height: 3),
              Text(d.mac,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BMHText.monoSm.copyWith(
                  fontSize: 9, color: BMHColors.inkMute)),
            ])),
          const Icon(Icons.chevron_right_rounded,
            color: _accent, size: 20),
        ]))));

  Widget _liveWeight() => Container(
    padding: const EdgeInsets.symmetric(vertical: 20),
    decoration: BoxDecoration(
      color: BMHColors.surface,
      borderRadius: BorderRadius.circular(BMHRadius.lg),
      border: Border.all(color: _accent.withOpacity(0.28))),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_qn.liveWeight > 0
              ? _qn.liveWeight.toStringAsFixed(1) : '—',
            style: BMHText.displayMd.copyWith(
              fontSize: 46, color: _accent, height: 1)),
          Padding(
            padding: const EdgeInsets.only(bottom: 7, left: 5),
            child: Text('kg',
              style: BMHText.bodySm.copyWith(
                fontSize: 14, color: BMHColors.inkDim))),
        ]),
      const SizedBox(height: 8),
      Text('Live from the scale',
        style: BMHText.monoSm.copyWith(
          fontSize: 9, color: BMHColors.inkMute)),
    ]));

  Widget _stat(String value, String label) => Column(children: [
    Text(value,
      style: BMHText.labelLg.copyWith(fontSize: 15, color: BMHColors.ink)),
    const SizedBox(height: 3),
    Text(label,
      style: BMHText.monoSm.copyWith(
        fontSize: 8, letterSpacing: 0.8, color: BMHColors.inkMute)),
  ]);

  Widget _tip(String n, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 20, height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _accent.withOpacity(0.14),
          shape: BoxShape.circle,
          border: Border.all(color: _accent.withOpacity(0.3))),
        child: Text(n,
          style: BMHText.monoSm.copyWith(fontSize: 9, color: _accent))),
      const SizedBox(width: 11),
      Expanded(child: Text(text,
        style: BMHText.bodySm.copyWith(
          fontSize: 11.5, color: BMHColors.ink2, height: 1.45))),
    ]));

  Widget _button(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(BMHRadius.full)),
      child: Text(label,
        textAlign: TextAlign.center,
        style: BMHText.labelLg.copyWith(
          color: BMHColors.bg0, fontWeight: FontWeight.w600))));
}
