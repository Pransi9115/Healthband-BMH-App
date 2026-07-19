import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';

// ─────────────────────────────────────────────────────────
//  CHECKIN ENTRY — stored in SharedPreferences
// ─────────────────────────────────────────────────────────
class CheckInEntry {
  final DateTime date;
  final int mood;        // 1–5
  final int sleep;       // 0–3
  final int energy;      // 0–3
  final int stress;      // 0–3
  final int pain;        // 0–3
  final int? phq1;       // PHQ-2 Q1 (0–3, optional)
  final int? phq2;       // PHQ-2 Q2 (0–3, optional)
  final int? gad1;       // GAD-2 Q1 (0–3, optional)
  final int? gad2;       // GAD-2 Q2 (0–3, optional)
  final int wellnessScore; // 0–100

  const CheckInEntry({
    required this.date,
    required this.mood,
    required this.sleep,
    required this.energy,
    required this.stress,
    required this.pain,
    this.phq1,
    this.phq2,
    this.gad1,
    this.gad2,
    required this.wellnessScore,
  });

  Map<String, dynamic> toJson() => {
    't': date.millisecondsSinceEpoch,
    'mood': mood, 'sleep': sleep, 'energy': energy,
    'stress': stress, 'pain': pain,
    if (phq1 != null) 'phq1': phq1,
    if (phq2 != null) 'phq2': phq2,
    if (gad1 != null) 'gad1': gad1,
    if (gad2 != null) 'gad2': gad2,
    'score': wellnessScore,
  };

  factory CheckInEntry.fromJson(Map<String, dynamic> j) => CheckInEntry(
    date: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    mood: j['mood'] as int,
    sleep: j['sleep'] as int,
    energy: j['energy'] as int,
    stress: j['stress'] as int,
    pain: j['pain'] as int,
    phq1: j['phq1'] as int?,
    phq2: j['phq2'] as int?,
    gad1: j['gad1'] as int?,
    gad2: j['gad2'] as int?,
    wellnessScore: j['score'] as int,
  );
}

// ─────────────────────────────────────────────────────────
//  CHECKIN SERVICE — save/load history
// ─────────────────────────────────────────────────────────
class CheckInService {
  static const _key = 'checkin_history';
  static const _timeKey = 'checkin_notify_time';

  static Future<List<CheckInEntry>> loadHistory() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => CheckInEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  static Future<void> save(CheckInEntry entry) async {
    final p = await SharedPreferences.getInstance();
    final history = await loadHistory();
    // Remove today's existing entry if any
    final today = DateTime.now();
    history.removeWhere((e) =>
      e.date.year == today.year &&
      e.date.month == today.month &&
      e.date.day == today.day);
    history.add(entry);
    // Keep last 90 days
    final cutoff = today.subtract(const Duration(days: 90));
    history.removeWhere((e) => e.date.isBefore(cutoff));
    await p.setString(_key, jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  static Future<CheckInEntry?> todaysEntry() async {
    final history = await loadHistory();
    final today = DateTime.now();
    try {
      return history.lastWhere((e) =>
        e.date.year == today.year &&
        e.date.month == today.month &&
        e.date.day == today.day);
    } catch (_) { return null; }
  }

  static Future<void> saveNotifyTime(TimeOfDay time) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_timeKey, '${time.hour}:${time.minute}');
  }

  static Future<TimeOfDay> loadNotifyTime() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_timeKey) ?? '9:0';
    final parts = raw.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]));
  }

  // Compute wellness score 0–100 from answers
  static int computeScore({
    required int mood,    // 1–5
    required int sleep,   // 0–3
    required int energy,  // 0–3
    required int stress,  // 0–3
    required int pain,    // 0–3
    int? phq1, int? phq2,
    int? gad1, int? gad2,
  }) {
    // Base score from 5 core questions (max 70 points)
    int score = 0;
    score += ((mood - 1) / 4 * 25).round(); // 0–25
    score += (sleep / 3 * 15).round();       // 0–15
    score += (energy / 3 * 15).round();      // 0–15
    score += ((3 - stress) / 3 * 10).round(); // 0–10 (inverted)
    score += ((3 - pain) / 3 * 5).round();    // 0–5 (inverted)
    // PHQ-2 penalty (max 6 points, higher = worse)
    if (phq1 != null && phq2 != null) {
      final phqTotal = phq1 + phq2;
      score -= (phqTotal / 6 * 20).round();
    }
    // GAD-2 penalty
    if (gad1 != null && gad2 != null) {
      final gadTotal = gad1 + gad2;
      score -= (gadTotal / 6 * 15).round();
    }
    return score.clamp(0, 100);
  }
}

// ─────────────────────────────────────────────────────────
//  DAILY CHECK-IN SCREEN
// ─────────────────────────────────────────────────────────
class DailyCheckInScreen extends StatefulWidget {
  const DailyCheckInScreen({super.key});
  @override
  State<DailyCheckInScreen> createState() => _DailyCheckInScreenState();
}

class _DailyCheckInScreenState extends State<DailyCheckInScreen>
    with TickerProviderStateMixin {

  late final PageController _pageCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  int _page = 0;

  // Answers
  int? _mood;    // 1–5
  int? _sleep;   // 0–3
  int? _energy;  // 0–3
  int? _stress;  // 0–3
  int? _pain;    // 0–3

  // PHQ-2 / GAD-2 (only shown if mood ≤ 2 or stress ≥ 2)
  int? _phq1;
  int? _phq2;
  int? _gad1;
  int? _gad2;

  bool _showClinical = false;
  bool _done = false;
  int _wellnessScore = 0;

  bool get _needsClinical =>
    (_mood != null && _mood! <= 2) ||
    (_stress != null && _stress! >= 2);

  // Total pages: 5 core + (2 PHQ + 2 GAD if needed) + 1 result
  int get _totalPages => _showClinical ? 10 : 6;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _next() {
    // After page 4 (all 5 core questions answered)
    // decide whether to show PHQ-2/GAD-2
    if (_page == 4) {
      _showClinical = _needsClinical;
    }
    // After last clinical question or if no clinical, go to result
    final isLastQuestion = _showClinical ? _page == 8 : _page == 4;
    if (isLastQuestion) {
      _submit();
      return;
    }
    _fadeCtrl.reverse().then((_) {
      setState(() => _page++);
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut);
      _fadeCtrl.forward();
    });
  }

  void _submit() {
    _wellnessScore = CheckInService.computeScore(
      mood: _mood ?? 3,
      sleep: _sleep ?? 1,
      energy: _energy ?? 1,
      stress: _stress ?? 1,
      pain: _pain ?? 0,
      phq1: _phq1, phq2: _phq2,
      gad1: _gad1, gad2: _gad2,
    );

    final entry = CheckInEntry(
      date: DateTime.now(),
      mood: _mood ?? 3,
      sleep: _sleep ?? 1,
      energy: _energy ?? 1,
      stress: _stress ?? 1,
      pain: _pain ?? 0,
      phq1: _phq1, phq2: _phq2,
      gad1: _gad1, gad2: _gad2,
      wellnessScore: _wellnessScore,
    );

    CheckInService.save(entry);

    _fadeCtrl.reverse().then((_) {
      setState(() {
        _page = _showClinical ? 9 : 5;
        _done = true;
      });
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut);
      _fadeCtrl.forward();
      HapticFeedback.heavyImpact();
    });
  }

  String get _progressLabel {
    if (_done) return 'Complete';
    return 'Question ${_page + 1} of ${_showClinical ? 9 : 5}';
  }

  double get _progress {
    if (_done) return 1.0;
    return (_page + 1) / (_showClinical ? 9 : 5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 0),
      appBar: AppBar(
        backgroundColor: BMHColors.bg0,
        elevation: 0,
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
        title: Column(children: [
          Text(_done ? 'Check-In Complete' : 'Daily Check-In',
            style: BMHText.heading2.copyWith(fontSize: 15)),
          const SizedBox(height: 4),
          Text(_progressLabel,
            style: BMHText.monoSm.copyWith(
              fontSize: 9, color: BMHColors.inkMute)),
        ]),
        centerTitle: true,
      ),
      body: Column(children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BMHSpacing.screenH, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 4,
              backgroundColor: BMHColors.bg4,
              valueColor: const AlwaysStoppedAnimation(BMHColors.cyan)))),

        // Questions
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _MoodQuestion(
                  selected: _mood,
                  onSelect: (v) { setState(() => _mood = v); _next(); }),
                _OptionQuestion(
                  icon: Icons.bedtime_outlined,
                  color: BMHColors.sSleep,
                  title: 'How did you\nsleep last night?',
                  options: const ['Very poor', 'Poor', 'Good', 'Excellent'],
                  emojis: const ['😫', '😔', '😊', '😄'],
                  selected: _sleep,
                  onSelect: (v) { setState(() => _sleep = v); _next(); }),
                _OptionQuestion(
                  icon: Icons.bolt_outlined,
                  color: BMHColors.sGut,
                  title: 'How is your\nenergy level today?',
                  options: const ['Very low', 'Low', 'Good', 'High'],
                  emojis: const ['😴', '😐', '🙂', '⚡'],
                  selected: _energy,
                  onSelect: (v) { setState(() => _energy = v); _next(); }),
                _OptionQuestion(
                  icon: Icons.psychology_outlined,
                  color: BMHColors.sMetabolic,
                  title: 'How stressed or\nanxious do you feel?',
                  options: const ['Not at all', 'A little', 'Moderate', 'Very stressed'],
                  emojis: const ['😌', '🙂', '😟', '😰'],
                  selected: _stress,
                  onSelect: (v) { setState(() => _stress = v); _next(); }),
                _OptionQuestion(
                  icon: Icons.healing_outlined,
                  color: BMHColors.sCardio,
                  title: 'Any physical pain\nor discomfort today?',
                  options: const ['None', 'Mild', 'Moderate', 'Severe'],
                  emojis: const ['✅', '😐', '😟', '😣'],
                  selected: _pain,
                  onSelect: (v) { setState(() => _pain = v); _next(); }),

                // PHQ-2 Q1
                _ClinicalQuestion(
                  badge: 'PHQ-2 Screening',
                  badgeColor: BMHColors.sSleep,
                  title: 'Over the past 2 days, have you felt down, depressed or hopeless?',
                  options: const [
                    'Not at all', 'Several days',
                    'More than half the days', 'Nearly every day'],
                  selected: _phq1,
                  onSelect: (v) { setState(() => _phq1 = v); _next(); }),

                // PHQ-2 Q2
                _ClinicalQuestion(
                  badge: 'PHQ-2 Screening',
                  badgeColor: BMHColors.sSleep,
                  title: 'Have you had little interest or pleasure in doing things?',
                  options: const [
                    'Not at all', 'Several days',
                    'More than half the days', 'Nearly every day'],
                  selected: _phq2,
                  onSelect: (v) { setState(() => _phq2 = v); _next(); }),

                // GAD-2 Q1
                _ClinicalQuestion(
                  badge: 'GAD-2 Screening',
                  badgeColor: BMHColors.sMetabolic,
                  title: 'Have you been feeling nervous, anxious or on edge?',
                  options: const [
                    'Not at all', 'Several days',
                    'More than half the days', 'Nearly every day'],
                  selected: _gad1,
                  onSelect: (v) { setState(() => _gad1 = v); _next(); }),

                // GAD-2 Q2
                _ClinicalQuestion(
                  badge: 'GAD-2 Screening',
                  badgeColor: BMHColors.sMetabolic,
                  title: 'Have you been unable to stop or control worrying?',
                  options: const [
                    'Not at all', 'Several days',
                    'More than half the days', 'Nearly every day'],
                  selected: _gad2,
                  onSelect: (v) { setState(() => _gad2 = v); _next(); }),

                // Results
                _ResultPage(
                  score: _wellnessScore,
                  mood: _mood ?? 3,
                  phqTotal: (_phq1 ?? 0) + (_phq2 ?? 0),
                  gadTotal: (_gad1 ?? 0) + (_gad2 ?? 0),
                  showClinical: _showClinical,
                  onDone: () => Navigator.pop(context)),
              ]))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  MOOD QUESTION — 5 emoji scale
// ─────────────────────────────────────────────────────────
class _MoodQuestion extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onSelect;
  const _MoodQuestion({required this.selected, required this.onSelect});

  static const _emojis = ['😞', '😔', '😐', '🙂', '😄'];
  static const _labels = ['Very bad', 'Bad', 'Okay', 'Good', 'Great'];
  static const _colors = [
    Color(0xFFFF4444), Color(0xFFFF8C44),
    Color(0xFFFFCC44), Color(0xFF88DD44), Color(0xFF44CC88),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wb_sunny_outlined,
            color: BMHColors.cyan, size: 40),
          const SizedBox(height: 24),
          Text('How are you\nfeeling today?',
            textAlign: TextAlign.center,
            style: BMHText.displaySm.copyWith(
              fontFamily: 'Fraunces', fontSize: 28,
              color: BMHColors.ink, height: 1.2)),
          const SizedBox(height: 8),
          Text('Tap to select your mood',
            style: BMHText.monoSm.copyWith(
              color: BMHColors.inkMute, fontSize: 10)),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final val = i + 1;
              final isSelected = selected == val;
              return GestureDetector(
                onTap: () => onSelect(val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 68 : 56,
                  height: isSelected ? 80 : 68,
                  decoration: BoxDecoration(
                    color: isSelected
                      ? _colors[i].withOpacity(0.15)
                      : BMHColors.surface,
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(
                      color: isSelected ? _colors[i] : BMHColors.line,
                      width: isSelected ? 2 : 1)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_emojis[i],
                        style: TextStyle(
                          fontSize: isSelected ? 30 : 24)),
                      const SizedBox(height: 4),
                      Text(_labels[i],
                        style: BMHText.monoSm.copyWith(
                          fontSize: 7,
                          color: isSelected ? _colors[i] : BMHColors.inkMute,
                          fontWeight: isSelected
                            ? FontWeight.w700 : FontWeight.w400)),
                    ])));
            })),
        ]));
  }
}

// ─────────────────────────────────────────────────────────
//  OPTION QUESTION — 4 choices
// ─────────────────────────────────────────────────────────
class _OptionQuestion extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> options;
  final List<String> emojis;
  final int? selected;
  final ValueChanged<int> onSelect;

  const _OptionQuestion({
    required this.icon, required this.color,
    required this.title, required this.options,
    required this.emojis, required this.selected,
    required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3))),
            child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 24),
          Text(title,
            textAlign: TextAlign.center,
            style: BMHText.displaySm.copyWith(
              fontFamily: 'Fraunces', fontSize: 24,
              color: BMHColors.ink, height: 1.3)),
          const SizedBox(height: 32),
          ...List.generate(options.length, (i) {
            final isSelected = selected == i;
            return GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                    ? color.withOpacity(0.12) : BMHColors.surface,
                  borderRadius: BorderRadius.circular(BMHRadius.lg),
                  border: Border.all(
                    color: isSelected ? color : BMHColors.line,
                    width: isSelected ? 2 : 1)),
                child: Row(children: [
                  Text(emojis[i],
                    style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 14),
                  Text(options[i],
                    style: BMHText.bodyMd.copyWith(
                      color: isSelected ? color : BMHColors.ink,
                      fontWeight: isSelected
                        ? FontWeight.w600 : FontWeight.w400)),
                  const Spacer(),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded,
                      color: color, size: 18),
                ])));
          }),
        ]));
  }
}

// ─────────────────────────────────────────────────────────
//  CLINICAL QUESTION — PHQ-2 / GAD-2
// ─────────────────────────────────────────────────────────
class _ClinicalQuestion extends StatelessWidget {
  final String badge;
  final Color badgeColor;
  final String title;
  final List<String> options;
  final int? selected;
  final ValueChanged<int> onSelect;

  const _ClinicalQuestion({
    required this.badge, required this.badgeColor,
    required this.title, required this.options,
    required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Clinical badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(BMHRadius.full),
              border: Border.all(color: badgeColor.withOpacity(0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.medical_services_outlined,
                color: badgeColor, size: 12),
              const SizedBox(width: 6),
              Text(badge,
                style: BMHText.monoSm.copyWith(
                  color: badgeColor, fontSize: 9,
                  fontWeight: FontWeight.w600)),
            ])),
          const SizedBox(height: 20),
          Text(title,
            textAlign: TextAlign.center,
            style: BMHText.displaySm.copyWith(
              fontFamily: 'Fraunces', fontSize: 20,
              color: BMHColors.ink, height: 1.4)),
          const SizedBox(height: 8),
          Text('This is a standard clinical screening question',
            textAlign: TextAlign.center,
            style: BMHText.monoSm.copyWith(
              color: BMHColors.inkMute, fontSize: 9,
              fontStyle: FontStyle.italic)),
          const SizedBox(height: 28),
          ...List.generate(options.length, (i) {
            final isSelected = selected == i;
            return GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                    ? badgeColor.withOpacity(0.10) : BMHColors.surface,
                  borderRadius: BorderRadius.circular(BMHRadius.lg),
                  border: Border.all(
                    color: isSelected ? badgeColor : BMHColors.line,
                    width: isSelected ? 2 : 1)),
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? badgeColor : BMHColors.line,
                        width: 2),
                      color: isSelected
                        ? badgeColor : Colors.transparent),
                    child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 12)
                      : null),
                  const SizedBox(width: 14),
                  Expanded(child: Text(options[i],
                    style: BMHText.bodyMd.copyWith(
                      color: isSelected ? badgeColor : BMHColors.ink,
                      fontWeight: isSelected
                        ? FontWeight.w600 : FontWeight.w400))),
                ])));
          }),
        ]));
  }
}

// ─────────────────────────────────────────────────────────
//  RESULT PAGE
// ─────────────────────────────────────────────────────────
class _ResultPage extends StatelessWidget {
  final int score;
  final int mood;
  final int phqTotal;
  final int gadTotal;
  final bool showClinical;
  final VoidCallback onDone;

  const _ResultPage({
    required this.score, required this.mood,
    required this.phqTotal, required this.gadTotal,
    required this.showClinical, required this.onDone});

  Color get _scoreColor {
    if (score >= 70) return BMHColors.sGut;
    if (score >= 45) return BMHColors.sMetabolic;
    return BMHColors.sCardio;
  }

  String get _scoreLabel {
    if (score >= 70) return 'Thriving';
    if (score >= 55) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs attention';
  }

  String get _insight {
    if (score >= 70) return 'You\'re in a great place today. Keep maintaining your healthy routines.';
    if (score >= 55) return 'You\'re doing well. Small mindful moments can help maintain your energy.';
    if (score >= 40) return 'Today seems a bit tough. Consider a short walk or a moment of calm breathing.';
    return 'It sounds like you\'re having a difficult day. Be kind to yourself and consider reaching out to someone you trust.';
  }

  bool get _showAlert =>
    showClinical && (phqTotal >= 3 || gadTotal >= 3);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: BMHSpacing.screenH, vertical: 24),
      child: Column(children: [
        // Score circle
        Container(
          width: 140, height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _scoreColor.withOpacity(0.15),
              _scoreColor.withOpacity(0.03),
            ]),
            border: Border.all(color: _scoreColor.withOpacity(0.4), width: 2)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$score',
              style: BMHText.displayXl.copyWith(
                fontSize: 52, color: _scoreColor, height: 1)),
            Text('/100',
              style: BMHText.monoSm.copyWith(
                color: BMHColors.inkMute, fontSize: 12)),
          ])),
        const SizedBox(height: 16),
        Text(_scoreLabel,
          style: BMHText.heading1.copyWith(color: _scoreColor)),
        const SizedBox(height: 4),
        Text('Mental Wellness Score',
          style: BMHText.monoSm.copyWith(
            color: BMHColors.inkMute, fontSize: 10)),
        const SizedBox(height: 24),

        // Insight card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: BMHColors.surface,
            borderRadius: BorderRadius.circular(BMHRadius.lg),
            border: Border.all(color: BMHColors.line)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lightbulb_outline_rounded,
              color: BMHColors.cyan, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(_insight,
              style: BMHText.bodyMd.copyWith(
                color: BMHColors.ink, height: 1.5))),
          ])),
        const SizedBox(height: 16),

        // Clinical alert if PHQ/GAD high
        if (_showAlert)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BMHColors.sCardio.withOpacity(0.08),
              borderRadius: BorderRadius.circular(BMHRadius.lg),
              border: Border.all(
                color: BMHColors.sCardio.withOpacity(0.4))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(children: [
                Icon(Icons.favorite_outline_rounded,
                  color: BMHColors.sCardio, size: 18),
                const SizedBox(width: 8),
                Text('A gentle note',
                  style: BMHText.labelLg.copyWith(
                    color: BMHColors.sCardio)),
              ]),
              const SizedBox(height: 10),
              Text(
                'Your responses suggest you may benefit from speaking with a mental health professional or a trusted person in your life. You\'re not alone — reaching out is a sign of strength.',
                style: BMHText.bodySm.copyWith(
                  color: BMHColors.ink, height: 1.5)),
              const SizedBox(height: 10),
              Text('If you need immediate support, please contact a helpline in your country.',
                style: BMHText.monoSm.copyWith(
                  color: BMHColors.inkMute, fontSize: 9,
                  fontStyle: FontStyle.italic)),
            ])),
        const SizedBox(height: 16),

        // Quick stats row
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BMHColors.surface,
            borderRadius: BorderRadius.circular(BMHRadius.lg),
            border: Border.all(color: BMHColors.line)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
            _StatCell('Mood', mood == 5 ? '😄' : mood == 4 ? '🙂' : mood == 3 ? '😐' : mood == 2 ? '😔' : '😞'),
            _StatCell('Logged', '✅'),
            _StatCell('Streak', '🔥'),
          ])),
        const SizedBox(height: 24),

        // Done button
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BMHColors.cyan,
              foregroundColor: BMHColors.bg0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BMHRadius.full)),
              elevation: 0),
            onPressed: onDone,
            child: Text('Done',
              style: BMHText.labelLg.copyWith(
                color: BMHColors.bg0,
                fontWeight: FontWeight.w600)))),
      ]));
  }
}

class _StatCell extends StatelessWidget {
  final String label, value;
  const _StatCell(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 24)),
    const SizedBox(height: 4),
    Text(label, style: BMHText.monoSm.copyWith(
      color: BMHColors.inkMute, fontSize: 9)),
  ]);
}

// ─────────────────────────────────────────────────────────
//  CHECKIN NOTIFICATION SETTINGS DIALOG
//  (Called from Settings screen)
// ─────────────────────────────────────────────────────────
class CheckInNotificationSheet extends StatefulWidget {
  const CheckInNotificationSheet({super.key});
  @override
  State<CheckInNotificationSheet> createState() =>
    _CheckInNotificationSheetState();
}

class _CheckInNotificationSheetState
    extends State<CheckInNotificationSheet> {

  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    CheckInService.loadNotifyTime().then((t) {
      if (mounted) setState(() => _time = t);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BMHColors.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: BMHColors.line)),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: BMHColors.line,
            borderRadius: BorderRadius.circular(2))),
        Row(children: [
          const Icon(Icons.notifications_outlined,
            color: BMHColors.cyan, size: 20),
          const SizedBox(width: 10),
          Text('Daily Check-In Reminder',
            style: BMHText.heading2.copyWith(fontSize: 15)),
          const Spacer(),
          Switch(
            value: _enabled,
            activeColor: BMHColors.cyan,
            onChanged: (v) => setState(() => _enabled = v)),
        ]),
        const SizedBox(height: 6),
        Text('Get a daily reminder to complete your mental health check-in.',
          style: BMHText.bodySm.copyWith(color: BMHColors.inkMute)),
        const SizedBox(height: 20),
        if (_enabled) ...[
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context, initialTime: _time);
              if (picked != null) {
                setState(() => _time = picked);
                await CheckInService.saveNotifyTime(picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BMHColors.surface,
                borderRadius: BorderRadius.circular(BMHRadius.lg),
                border: Border.all(color: BMHColors.line)),
              child: Row(children: [
                const Icon(Icons.access_time_rounded,
                  color: BMHColors.cyan, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text('Reminder Time',
                    style: BMHText.bodyMd),
                  Text('Tap to change',
                    style: BMHText.monoSm.copyWith(
                      color: BMHColors.inkMute, fontSize: 9)),
                ])),
                Text(_time.format(context),
                  style: BMHText.displaySm.copyWith(
                    fontSize: 20, color: BMHColors.cyan,
                    fontFamily: 'Fraunces', fontWeight: FontWeight.w300)),
              ])),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BMHColors.cyanSoft,
              borderRadius: BorderRadius.circular(BMHRadius.md),
              border: Border.all(color: BMHColors.lineBright)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                color: BMHColors.cyan, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Note: Daily notifications require flutter_local_notifications package. Add it to pubspec.yaml to enable.',
                style: BMHText.monoSm.copyWith(
                  color: BMHColors.inkDim, fontSize: 8))),
            ])),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BMHColors.cyan,
              foregroundColor: BMHColors.bg0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BMHRadius.full)),
              elevation: 0),
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'))),
      ]));
  }
}
