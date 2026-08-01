// ─────────────────────────────────────────────────────────
//  GLP-1 MONITORING — STORE
//
//  Assessment history on the device, plus the operations the daily
//  flow needs: starting a check-in, copying yesterday forward,
//  editing a pre-populated answer, and submitting.
//
//  NO ALERTS LEAVE THIS DEVICE. There is no backend yet, so nothing
//  here notifies a clinician, and no screen built on it may tell a
//  patient that their care team has been informed. Red results must
//  direct the patient to seek help themselves. Every record already
//  carries the audit fields a sync would need, so wiring a server in
//  later is an addition rather than a rewrite.
// ─────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'glp1_models.dart';
import 'glp1_ruleset.dart';
import 'glp1_risk_engine.dart';

class Glp1Service {
  Glp1Service._();
  static final Glp1Service instance = Glp1Service._();

  static const _historyKey = 'glp1_assessments';
  static const _resolvedKey = 'glp1_resolved_through';

  Ruleset? _ruleset;
  Glp1RiskEngine? _engine;
  List<Assessment> _history = [];
  bool _loaded = false;

  Ruleset get ruleset {
    final r = _ruleset;
    if (r == null) {
      throw StateError('Glp1Service.init() must complete before use.');
    }
    return r;
  }

  Glp1RiskEngine get engine => _engine!;
  bool get isReady => _loaded;

  /// Most recent first.
  List<Assessment> get history => List.unmodifiable(_history);

  // ── SETUP ───────────────────────────────────────────────
  Future<void> init() async {
    if (_loaded) return;
    _ruleset = await Ruleset.load();
    _engine = Glp1RiskEngine(_ruleset!);
    await _loadHistory();
    _loaded = true;
  }

  Future<void> _loadHistory() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_historyKey);
    if (raw == null) {
      _history = [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      _history = list
          .map((e) => Assessment.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    } catch (_) {
      _history = [];
    }
  }

  Future<void> _saveHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _historyKey, jsonEncode(_history.map((a) => a.toJson()).toList()));
  }

  // ── QUERIES ─────────────────────────────────────────────
  List<Assessment> get submitted =>
      _history.where((a) => a.isSubmitted).toList();

  Assessment? get latest => submitted.isEmpty ? null : submitted.first;

  bool get hasBaseline =>
      submitted.any((a) => a.mode == CheckInMode.baseline);

  bool doneOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return submitted.any((a) => a.day == d);
  }

  bool get doneToday => doneOn(DateTime.now());

  Assessment? assessmentOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    for (final a in submitted) {
      if (a.day == d) return a;
    }
    return null;
  }

  /// The highest Orange or Red still open. A carried-forward answer
  /// must never let one of these quietly disappear, so it is
  /// recomputed from history rather than stored as a flag.
  Future<RiskLevel?> unresolvedRisk() async {
    if (!ruleset.unresolvedRiskCarries) return null;
    final p = await SharedPreferences.getInstance();
    final through = p.getInt(_resolvedKey) ?? 0;

    RiskLevel? worst;
    for (final a in submitted) {
      if (a.resolved) continue;
      if (a.startedAt.millisecondsSinceEpoch <= through) continue;
      final lvl = a.risk?.level;
      if (lvl == null) continue;
      if (lvl == RiskLevel.orange ||
          lvl == RiskLevel.red ||
          lvl == RiskLevel.undetermined) {
        worst = worst == null ? lvl : maxRisk(worst, lvl);
      }
    }
    return worst;
  }

  /// Clears open risk up to now. Intended for a clinician action or
  /// an explicit patient report of improvement — not for routine
  /// submission, and never automatic.
  Future<void> markResolvedThroughNow({String by = 'patient'}) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_resolvedKey, DateTime.now().millisecondsSinceEpoch);
    _history = _history
        .map((a) => a.isSubmitted && !a.resolved
            ? a.copyWith(
                resolved: true,
                resolvedAt: DateTime.now(),
                resolvedBy: by)
            : a)
        .toList();
    await _saveHistory();
  }

  /// True when a full review is due — no baseline yet, nothing
  /// logged, or the configured interval has elapsed.
  bool weeklyReviewDue() {
    if (!hasBaseline) return true;
    final last = submitted.where((a) => a.isWeeklyReview).toList();
    if (last.isEmpty) {
      final base = submitted.where((a) => a.mode == CheckInMode.baseline);
      if (base.isEmpty) return true;
      return DateTime.now().difference(base.first.startedAt).inDays >=
          ruleset.weeklyReviewDays;
    }
    return DateTime.now().difference(last.first.startedAt).inDays >=
        ruleset.weeklyReviewDays;
  }

  /// Which flow the opener should offer. First-timers must complete
  /// the baseline; everyone else may carry forward.
  List<CheckInMode> availableModes() {
    if (!hasBaseline) return [CheckInMode.baseline];
    return [
      CheckInMode.same,
      CheckInMode.edit,
      CheckInMode.significant,
    ];
  }

  // ── STARTING A CHECK-IN ─────────────────────────────────
  String _newId() =>
      'a${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  /// Blank assessment, nothing pre-filled.
  Assessment startFresh(CheckInMode mode) => Assessment(
        id: _newId(),
        startedAt: DateTime.now(),
        mode: mode,
        responses: {},
        rulesetVersion: ruleset.version,
        isWeeklyReview: weeklyReviewDue(),
      );

  /// Copies the previous assessment forward. Safety and opener
  /// answers are deliberately left blank: carrying one of those
  /// would record the patient denying a red flag they were never
  /// asked about today. The source assessment is untouched and its
  /// id is kept on the new record.
  Assessment startCarriedForward(CheckInMode mode) {
    final prev = latest;
    if (prev == null) return startFresh(mode);

    final now = DateTime.now();
    final copied = <String, Response>{};

    for (final entry in prev.responses.entries) {
      final q = ruleset.question(entry.key);
      if (q == null) continue;
      if (!ruleset.canCarryForward(q)) continue;
      // Free text is not re-asserted as a fresh statement.
      if (q.type == QuestionType.text) continue;

      copied[q.id] = Response(
        questionId: q.id,
        value: entry.value.value,
        previousValue: entry.value.value,
        carriedForward: true,
        manuallyChanged: false,
        answeredAt: now,
      );
    }

    return Assessment(
      id: _newId(),
      startedAt: now,
      mode: mode,
      sourceAssessmentId: prev.id,
      responses: copied,
      rulesetVersion: ruleset.version,
      isWeeklyReview: weeklyReviewDue(),
    );
  }

  // ── ANSWERING ───────────────────────────────────────────
  /// Records an answer, preserving what was there before and marking
  /// whether the patient actually changed a pre-filled value.
  Assessment answer(
    Assessment a,
    String questionId, {
    num? value,
    String? text,
  }) {
    final existing = a.responses[questionId];
    final wasCarried = existing?.carriedForward ?? false;
    final prior = existing?.previousValue ?? existing?.value;
    final changed = wasCarried && existing?.value != value;

    final updated = Map<String, Response>.from(a.responses);
    updated[questionId] = Response(
      questionId: questionId,
      value: value,
      textValue: text,
      previousValue: prior,
      carriedForward: wasCarried && !changed,
      manuallyChanged: changed || (existing?.manuallyChanged ?? false),
      answeredAt: DateTime.now(),
    );
    return a.copyWith(responses: updated);
  }

  /// Evaluates without saving — for live feedback as the patient
  /// answers, and for the urgent screen in significant-change mode.
  Future<RiskResult> preview(Assessment a) async {
    final open = await unresolvedRisk();
    return engine.evaluate(a,
        previous: submitted.take(14).toList(), unresolvedRisk: open);
  }

  // ── SUBMITTING ──────────────────────────────────────────
  /// Scores and stores the assessment. Returns the result so the UI
  /// can show the right screen.
  ///
  /// Submission does not clear an earlier unresolved Orange or Red;
  /// only markResolvedThroughNow does that.
  Future<RiskResult> submit(Assessment a) async {
    final open = await unresolvedRisk();
    final result = engine.evaluate(a,
        previous: submitted.take(14).toList(), unresolvedRisk: open);

    final done = a.copyWith(submittedAt: DateTime.now(), risk: result);
    _history = [done, ..._history.where((x) => x.id != a.id)]
      ..sort((x, y) => y.startedAt.compareTo(x.startedAt));
    await _saveHistory();
    return result;
  }

  /// Mandatory questions still outstanding. The UI must block
  /// submission while this is non-empty.
  List<Question> blockingQuestions(Assessment a) =>
      ruleset.missingMandatory(AssessmentAnswerSource(a));

  bool canSubmit(Assessment a) => blockingQuestions(a).isEmpty;

  // ── TRENDS ──────────────────────────────────────────────
  /// Values for one question over the last [days] submitted
  /// assessments, oldest first, for a sparkline.
  List<num?> trend(String questionId, {int days = 14}) {
    final out = submitted
        .take(days)
        .map((a) => a.responses[questionId]?.value)
        .toList()
        .reversed
        .toList();
    return out;
  }

  Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_historyKey);
    await p.remove(_resolvedKey);
    _history = [];
  }
}
