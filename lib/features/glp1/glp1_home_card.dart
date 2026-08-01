// ─────────────────────────────────────────────────────────
//  GLP-1 HOME CARD
//
//  Second entry point on Home, below the wellness check-in. Shows
//  today's state and, once a check-in exists, the current status.
//
//  When an Orange or Red is still open the card says so, because a
//  patient who tapped through an urgent result yesterday should not
//  open the app today to a clean slate.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/glp1/glp1_models.dart';
import '../../core/glp1/glp1_service.dart';
import 'glp1_widgets.dart';
import 'glp1_checkin_screen.dart';

class Glp1HomeCard extends StatefulWidget {
  const Glp1HomeCard({super.key});
  @override
  State<Glp1HomeCard> createState() => _Glp1HomeCardState();
}

class _Glp1HomeCardState extends State<Glp1HomeCard> {
  final _svc = Glp1Service.instance;

  bool _ready = false;
  bool _doneToday = false;
  bool _hasBaseline = false;
  bool _weeklyDue = false;
  RiskLevel? _open;
  RiskLevel? _lastLevel;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      await _svc.init();
      final open = await _svc.unresolvedRisk();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _doneToday = _svc.doneToday;
        _hasBaseline = _svc.hasBaseline;
        _weeklyDue = _svc.weeklyReviewDue();
        _open = open;
        _lastLevel = _svc.latest?.risk?.level;
      });
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  Future<void> _open_() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => const Glp1CheckInScreen()));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const BMHSkeleton(height: 118);
    }

    // An unresolved serious symptom outranks "done for today".
    final urgent = _open == RiskLevel.red || _open == RiskLevel.orange;
    final accent = urgent
        ? riskColor(_open!)
        : _doneToday
            ? BMHColors.sGut
            : BMHColors.cyan;

    final eyebrow = urgent
        ? 'Needs review'
        : !_hasBaseline
            ? 'First check-in'
            : _weeklyDue
                ? 'Weekly review due'
                : _doneToday
                    ? 'Completed today ✓'
                    : 'GLP-1 check-in';

    final title = !_hasBaseline
        ? 'Set up your GLP-1 monitoring'
        : _doneToday
            ? 'Checked in today'
            : 'How are your symptoms today?';

    final sub = urgent
        ? 'A symptom from an earlier check-in has not been resolved.'
        : !_hasBaseline
            ? 'A one-off set of questions about your medication and '
              'history, then a few seconds a day.'
            : _weeklyDue
                ? 'Time to review all your answers so your record stays '
                  'accurate.'
                : _doneToday
                    ? _lastLevel == null
                        ? 'Recorded.'
                        : 'Status: ${_lastLevel!.label}.'
                    : 'If nothing has changed this takes a few seconds.';

    return GestureDetector(
      onTap: _open_,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [accent.withOpacity(0.12), accent.withOpacity(0.02)]),
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          border: Border.all(color: accent.withOpacity(0.45))),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (urgent) ...[
                  Icon(riskIcon(_open!), size: 13, color: accent),
                  const SizedBox(width: 6),
                ],
                Flexible(child: BMHEyebrow(
                  eyebrow,
                  showDot: !_doneToday && !urgent)),
              ]),
              const SizedBox(height: 8),
              Text(title,
                style: BMHText.heading2.copyWith(fontSize: 18)),
              const SizedBox(height: 5),
              Text(sub,
                style: BMHText.bodySm.copyWith(
                  fontSize: 12.5, color: BMHColors.inkDim, height: 1.45)),
            ])),
          const SizedBox(width: 12),
          Container(
            width: 38, height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.16),
              shape: BoxShape.circle),
            child: Icon(
              _doneToday && !urgent
                  ? Icons.check_rounded
                  : Icons.arrow_forward_rounded,
              size: 17, color: accent)),
        ])));
  }
}
