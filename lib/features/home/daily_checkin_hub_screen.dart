// ─────────────────────────────────────────────────────────
//  DAILY CHECK-IN HUB
//
//  Home carries one entry, "Daily check-in", and it opens here. Both
//  questionnaires live under this roof: Mental Mood first, then GLP-1
//  Monitoring.
//
//  They were two full-width cards on Home, then one section with two
//  rows — either way they took the whole fold before the patient saw
//  a single vital. One line on Home, both questionnaires one tap
//  away, and the count answers "am I done?" without opening anything.
//
//  GLP-1 keeps its own urgency. An unresolved orange or red outranks
//  "done today" and shows on the Home line too, because a patient who
//  tapped through a serious symptom yesterday must not be able to
//  miss it today.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/glp1/glp1_models.dart';
import '../../core/glp1/glp1_service.dart';
import '../glp1/glp1_widgets.dart';
import '../glp1/glp1_checkin_screen.dart';
import 'daily_checkin_screen.dart';

// ─────────────────────────────────────────────────────────
//  SHARED STATE
//
//  Home and the hub both need to know where GLP-1 stands. Loading it
//  in one place keeps the two from disagreeing about whether today is
//  done.
// ─────────────────────────────────────────────────────────
class Glp1Status {
  final bool done;
  final bool hasBaseline;
  final bool weeklyDue;
  final RiskLevel? openRisk;
  final RiskLevel? lastLevel;

  const Glp1Status({
    this.done = false,
    this.hasBaseline = false,
    this.weeklyDue = false,
    this.openRisk,
    this.lastLevel,
  });

  bool get urgent =>
      openRisk == RiskLevel.red || openRisk == RiskLevel.orange;

  /// Counts as complete only when nothing urgent is outstanding.
  bool get settled => done && !urgent;

  static Future<Glp1Status> load() async {
    final svc = Glp1Service.instance;
    try {
      await svc.init();
      final open = await svc.unresolvedRisk();
      return Glp1Status(
        done: svc.doneToday,
        hasBaseline: svc.hasBaseline,
        weeklyDue: svc.weeklyReviewDue(),
        openRisk: open,
        lastLevel: svc.latest?.risk?.level);
    } catch (_) {
      // The ruleset asset can fail to load. Report "not done" rather
      // than crashing Home — the questionnaire screen explains why.
      return const Glp1Status();
    }
  }

  String get flag => urgent
      ? 'Needs review'
      : !hasBaseline
        ? 'Set up'
        : weeklyDue
          ? 'Weekly review'
          : '';

  String get subtitle {
    if (urgent) return 'A symptom from an earlier check-in is unresolved.';
    if (!hasBaseline) {
      return 'A one-off set of questions, then seconds a day.';
    }
    if (weeklyDue) {
      return 'Time to review your answers so the record stays accurate.';
    }
    if (done) {
      return lastLevel == null
        ? 'Recorded for today'
        : 'Recorded · ${lastLevel!.label}';
    }
    return 'How are your symptoms today?';
  }

  Color get accent => urgent
      ? riskColor(openRisk!)
      : done
        ? BMHColors.sGut
        : BMHColors.cyan;

  IconData get icon =>
      urgent ? riskIcon(openRisk!) : Icons.medication_liquid_rounded;
}

// ─────────────────────────────────────────────────────────
//  THE HUB SCREEN
// ─────────────────────────────────────────────────────────
class DailyCheckInHubScreen extends StatefulWidget {
  const DailyCheckInHubScreen({super.key});

  @override
  State<DailyCheckInHubScreen> createState() =>
      _DailyCheckInHubScreenState();
}

class _DailyCheckInHubScreenState extends State<DailyCheckInHubScreen> {
  bool _ready = false;
  bool _moodDone = false;
  Glp1Status _glp1 = const Glp1Status();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final mood = await CheckInService.todaysEntry();
    final glp1 = await Glp1Status.load();
    if (!mounted) return;
    setState(() {
      _ready = true;
      _moodDone = mood != null;
      _glp1 = glp1;
    });
  }

  Future<void> _openMood() async {
    if (_moodDone) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => const DailyCheckInScreen()));
    await _refresh();
  }

  Future<void> _openGlp1() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => const Glp1CheckInScreen()));
    await _refresh();
  }

  int get _done => (_moodDone ? 1 : 0) + (_glp1.settled ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final allDone = _done == 2;

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: Stack(children: [
        Positioned(top: -150, right: -100,
          child: Container(width: 400, height: 400,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                (allDone ? BMHColors.sGut : BMHColors.cyan)
                  .withOpacity(0.08),
                Colors.transparent])))),

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
                  const BMHEyebrow('TODAY'),
                  Text('Daily check-in', style: BMHText.heading1),
                ])),
            ])),

          if (!_ready)
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: BMHSpacing.s5, vertical: 20),
              child: BMHSkeleton(height: 200))
          else
            Expanded(child: ListView(
              padding: const EdgeInsets.fromLTRB(
                BMHSpacing.s5, 8, BMHSpacing.s5, 40),
              children: [
                // ── PROGRESS ──────────────────────────
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: (allDone ? BMHColors.sGut : BMHColors.cyan)
                      .withOpacity(0.09),
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(
                      color: (allDone ? BMHColors.sGut : BMHColors.cyan)
                        .withOpacity(0.3))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allDone
                          ? 'ALL DONE FOR TODAY'
                          : '$_done OF 2 COMPLETE',
                        style: BMHText.monoSm.copyWith(
                          fontSize: 10, letterSpacing: 1.2,
                          color: allDone
                            ? BMHColors.sGut : BMHColors.cyan)),
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius:
                          BorderRadius.circular(BMHRadius.full),
                        child: LinearProgressIndicator(
                          value: _done / 2,
                          minHeight: 4,
                          backgroundColor: BMHColors.bg4,
                          valueColor: AlwaysStoppedAnimation(
                            allDone
                              ? BMHColors.sGut : BMHColors.cyan))),
                      const SizedBox(height: 9),
                      Text(
                        allDone
                          ? 'Nothing left to answer. Come back tomorrow.'
                          : 'A minute now keeps your record accurate.',
                        style: BMHText.bodySm.copyWith(
                          fontSize: 11, color: BMHColors.inkDim)),
                    ])),

                const SizedBox(height: 20),

                CheckInEntryCard(
                  icon: Icons.self_improvement_rounded,
                  accent: _moodDone ? BMHColors.sGut : BMHColors.cyan,
                  title: 'Mental Mood',
                  subtitle: _moodDone
                    ? 'Recorded for today'
                    : 'How are you feeling today?',
                  done: _moodDone,
                  onTap: _openMood),

                const SizedBox(height: 12),

                CheckInEntryCard(
                  icon: _glp1.icon,
                  accent: _glp1.accent,
                  title: 'GLP-1 Monitoring',
                  subtitle: _glp1.subtitle,
                  done: _glp1.settled,
                  flag: _glp1.flag.isEmpty ? null : _glp1.flag,
                  onTap: _openGlp1),
              ])),
        ])),
      ]));
  }
}

// ─────────────────────────────────────────────────────────
//  ONE QUESTIONNAIRE, AS A CARD
// ─────────────────────────────────────────────────────────
class CheckInEntryCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final bool done;
  final String? flag;
  final VoidCallback onTap;

  const CheckInEntryCard({
    super.key,
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
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [accent.withOpacity(0.12), accent.withOpacity(0.02)]),
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: accent.withOpacity(0.4))),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withOpacity(0.32))),
          child: Icon(icon, color: accent, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BMHText.heading2.copyWith(
                  fontSize: 17, color: BMHColors.ink))),
              if (flag != null) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(BMHRadius.full),
                    border: Border.all(color: accent.withOpacity(0.45))),
                  child: Text(flag!.toUpperCase(),
                    style: BMHText.monoSm.copyWith(
                      fontSize: 7, letterSpacing: 0.7, color: accent,
                      fontWeight: FontWeight.w700))),
              ],
            ]),
            const SizedBox(height: 4),
            Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BMHText.bodySm.copyWith(
                fontSize: 11.5, color: BMHColors.inkDim, height: 1.4)),
          ])),
        const SizedBox(width: 10),
        Container(
          width: 34, height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? accent.withOpacity(0.18) : accent,
            shape: BoxShape.circle),
          child: Icon(
            done ? Icons.check_rounded : Icons.arrow_forward_rounded,
            size: 16,
            color: done ? accent : BMHColors.bg0)),
      ])));
}
