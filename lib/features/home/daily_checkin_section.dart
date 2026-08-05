// ─────────────────────────────────────────────────────────
//  DAILY CHECK-IN SECTION
//
//  Both questionnaires under one heading. They were two full-width
//  cards stacked on top of each other, which pushed everything below
//  them off the fold and made a patient with GLP-1 monitoring feel
//  like they had two unrelated chores.
//
//  They are related: both are "tell us how today went". So they sit
//  in one section as two rows — Mental Mood first, GLP-1 second — and
//  the header carries the count so the answer to "am I done?" is
//  visible without reading either row.
//
//  The GLP-1 row keeps its own urgency logic. An unresolved orange or
//  red symptom outranks everything and colours the row, because a
//  patient who tapped through a serious result yesterday must not
//  open the app to a clean slate today.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/glp1/glp1_models.dart';
import '../../core/glp1/glp1_service.dart';
import '../glp1/glp1_widgets.dart';
import '../glp1/glp1_checkin_screen.dart';
import 'daily_checkin_screen.dart';

class DailyCheckInSection extends StatefulWidget {
  final bool moodDone;

  /// Called after either questionnaire closes, so Home can re-read
  /// today's state.
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
  final _glp1 = Glp1Service.instance;

  bool _ready = false;
  bool _glp1Done = false;
  bool _hasBaseline = false;
  bool _weeklyDue = false;
  RiskLevel? _openRisk;
  RiskLevel? _lastLevel;

  @override
  void initState() {
    super.initState();
    _refreshGlp1();
  }

  Future<void> _refreshGlp1() async {
    try {
      await _glp1.init();
      final open = await _glp1.unresolvedRisk();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _glp1Done = _glp1.doneToday;
        _hasBaseline = _glp1.hasBaseline;
        _weeklyDue = _glp1.weeklyReviewDue();
        _openRisk = open;
        _lastLevel = _glp1.latest?.risk?.level;
      });
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  Future<void> _openMood() async {
    if (widget.moodDone) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => const DailyCheckInScreen()));
    widget.onChanged();
  }

  Future<void> _openGlp1() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => const Glp1CheckInScreen()));
    await _refreshGlp1();
    widget.onChanged();
  }

  bool get _urgent =>
      _openRisk == RiskLevel.red || _openRisk == RiskLevel.orange;

  int get _doneCount =>
      (widget.moodDone ? 1 : 0) + (_glp1Done && !_urgent ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const BMHSkeleton(height: 168);

    final allDone = _doneCount == 2;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: allDone
            ? [BMHColors.sGut.withOpacity(0.10),
               BMHColors.sGut.withOpacity(0.02)]
            : [BMHColors.cyan.withOpacity(0.10),
               BMHColors.cyan.withOpacity(0.02)]),
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(
          color: allDone
            ? BMHColors.sGut.withOpacity(0.35)
            : BMHColors.lineBright)),
      child: Column(children: [
        // ── HEADER ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 11),
          child: Row(children: [
            Expanded(child: BMHEyebrow(
              'Daily check-in',
              showDot: !allDone)),
            Text(
              allDone ? 'All done ✓' : '$_doneCount of 2 done',
              style: BMHText.monoSm.copyWith(
                fontSize: 9,
                letterSpacing: 0.8,
                color: allDone ? BMHColors.sGut : BMHColors.inkDim,
                fontWeight: FontWeight.w700)),
          ])),

        Divider(height: 1, color: BMHColors.line.withOpacity(0.6)),

        // ── MENTAL MOOD ───────────────────────────────
        _CheckInRow(
          icon: Icons.self_improvement_rounded,
          accent: widget.moodDone ? BMHColors.sGut : BMHColors.cyan,
          title: 'Mental Mood',
          subtitle: widget.moodDone
            ? 'Recorded for today'
            : 'How are you feeling today?',
          done: widget.moodDone,
          onTap: _openMood),

        Divider(height: 1, color: BMHColors.line.withOpacity(0.6)),

        // ── GLP-1 ─────────────────────────────────────
        _CheckInRow(
          icon: _urgent
            ? riskIcon(_openRisk!)
            : Icons.medication_liquid_rounded,
          accent: _urgent
            ? riskColor(_openRisk!)
            : _glp1Done
              ? BMHColors.sGut
              : BMHColors.cyan,
          title: 'GLP-1 Monitoring',
          subtitle: _glp1Subtitle(),
          done: _glp1Done && !_urgent,
          flag: _urgent
            ? 'Needs review'
            : !_hasBaseline
              ? 'Set up'
              : _weeklyDue
                ? 'Weekly review'
                : null,
          onTap: _openGlp1),
      ]));
  }

  String _glp1Subtitle() {
    if (_urgent) {
      return 'A symptom from an earlier check-in is unresolved.';
    }
    if (!_hasBaseline) {
      return 'A one-off set of questions, then seconds a day.';
    }
    if (_weeklyDue) {
      return 'Time to review your answers so the record stays accurate.';
    }
    if (_glp1Done) {
      return _lastLevel == null
        ? 'Recorded for today'
        : 'Recorded · ${_lastLevel!.label}';
    }
    return 'How are your symptoms today?';
  }
}

// ─────────────────────────────────────────────────────────
class _CheckInRow extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final bool done;
  final String? flag;
  final VoidCallback onTap;

  const _CheckInRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onTap,
    this.flag,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: accent.withOpacity(0.3))),
          child: Icon(icon, color: accent, size: 18)),
        const SizedBox(width: 13),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BMHText.heading2.copyWith(
                  fontSize: 16, color: BMHColors.ink))),
              if (flag != null) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(BMHRadius.full),
                    border: Border.all(color: accent.withOpacity(0.4))),
                  child: Text(flag!.toUpperCase(),
                    style: BMHText.monoSm.copyWith(
                      fontSize: 7, letterSpacing: 0.7, color: accent,
                      fontWeight: FontWeight.w700))),
              ],
            ]),
            const SizedBox(height: 3),
            Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BMHText.bodySm.copyWith(
                fontSize: 11.5, color: BMHColors.inkDim, height: 1.4)),
          ])),
        const SizedBox(width: 10),
        Container(
          width: 30, height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withOpacity(done ? 0.16 : 1),
            shape: BoxShape.circle,
            boxShadow: done ? null : BMHShadows.cyan),
          child: Icon(
            done ? Icons.check_rounded : Icons.arrow_forward_rounded,
            size: 15,
            color: done ? accent : BMHColors.bg0)),
      ])));
}
