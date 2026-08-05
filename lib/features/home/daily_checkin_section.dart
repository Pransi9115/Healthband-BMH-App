// ─────────────────────────────────────────────────────────
//  DAILY CHECK-IN — HOME ENTRY
//
//  One line on Home. Both questionnaires live behind it in
//  DailyCheckInHubScreen.
//
//  It carries the count, so "am I done today?" is answered without
//  opening anything, and it surfaces GLP-1 urgency directly: an
//  unresolved orange or red recolours this line and overrides the
//  count, because that is not something a patient should have to open
//  a screen to discover.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import 'daily_checkin_hub_screen.dart';

class DailyCheckInSection extends StatefulWidget {
  final bool moodDone;

  /// Called after the hub closes, so Home can re-read today's state.
  final VoidCallback onChanged;

  const DailyCheckInSection({
    super.key,
    required this.moodDone,
    required this.onChanged,
  });

  @override
  State<DailyCheckInSection> createState() => _DailyCheckInSectionState();
}

class _DailyCheckInSectionState extends State<DailyCheckInSection> {
  bool _ready = false;
  Glp1Status _glp1 = const Glp1Status();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await Glp1Status.load();
    if (!mounted) return;
    setState(() {
      _ready = true;
      _glp1 = s;
    });
  }

  Future<void> _open() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => const DailyCheckInHubScreen()));
    await _refresh();
    widget.onChanged();
  }

  int get _done =>
      (widget.moodDone ? 1 : 0) + (_glp1.settled ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const BMHSkeleton(height: 92);

    final allDone = _done == 2;
    final urgent = _glp1.urgent;

    final accent = urgent
        ? _glp1.accent
        : allDone
          ? BMHColors.sGut
          : BMHColors.cyan;

    final line = urgent
        ? 'A GLP-1 symptom needs review'
        : allDone
          ? 'Both done for today'
          : _done == 1
            ? '1 of 2 done · one left'
            : 'Mental Mood and GLP-1 Monitoring';

    return GestureDetector(
      onTap: _open,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [accent.withOpacity(0.12), accent.withOpacity(0.02)]),
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          border: Border.all(
            color: allDone && !urgent
              ? accent.withOpacity(0.4)
              : BMHColors.lineBright)),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (urgent) ...[
                  Icon(_glp1.icon, size: 13, color: accent),
                  const SizedBox(width: 6),
                ],
                Expanded(child: BMHEyebrow(
                  urgent ? 'Needs review' : 'Daily check-in',
                  showDot: !allDone && !urgent)),
                Text(
                  allDone ? 'All done ✓' : '$_done of 2',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 9, letterSpacing: 0.8,
                    color: allDone ? BMHColors.sGut : BMHColors.inkDim,
                    fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 9),
              Text.rich(TextSpan(
                style: BMHText.heading2.copyWith(
                  fontFamily: 'Fraunces', fontSize: 19),
                children: [
                  const TextSpan(text: 'How are you '),
                  TextSpan(text: 'feeling',
                    style: TextStyle(
                      fontStyle: FontStyle.italic, color: accent)),
                  const TextSpan(text: ' today?'),
                ])),
              const SizedBox(height: 5),
              Text(line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BMHText.bodySm.copyWith(
                  fontSize: 11.5, color: BMHColors.inkDim)),
            ])),
          const SizedBox(width: 14),
          Container(
            width: 40, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: allDone && !urgent
                ? accent.withOpacity(0.18) : accent,
              shape: BoxShape.circle,
              boxShadow: allDone && !urgent ? null : BMHShadows.cyan),
            child: Icon(
              allDone && !urgent
                ? Icons.check_rounded
                : Icons.arrow_forward_rounded,
              size: 16,
              color: allDone && !urgent ? accent : BMHColors.bg0)),
        ])));
  }
}
