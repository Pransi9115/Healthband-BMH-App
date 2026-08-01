// ─────────────────────────────────────────────────────────
//  GLP-1 MONITORING — RULESET
//
//  Loads the versioned clinical configuration and evaluates its
//  condition language. Nothing here knows what nausea is or what
//  counts as severe: it reads questions, thresholds and messages
//  from the ruleset file and applies them mechanically.
//
//  That separation is the point. Changing a threshold, reordering a
//  branch or rewording a patient message is a change to the JSON,
//  reviewed and approved by the clinical team, not a code release.
//
//  CONDITION LANGUAGE
//    {"q":"nausea","op":"gte","value":7}     one comparison
//    {"all":[ ... ]}                          every child true
//    {"any":[ ... ]}                          at least one true
//    {"not": { ... }}                         negation
//    {"persisted":{"q":..,"op":..,"value":..,"days":3}}
//                                             true on N consecutive days
//    {"unanswered_mandatory": true}           a required answer missing
//
//  Operators: eq ne gt gte lt lte in notIn answered unanswered
//
//  A question that was never answered makes its comparison false,
//  with one exception: `unanswered` tests for exactly that. An
//  absent answer is never treated as a No.
// ─────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import 'glp1_models.dart';

const String kRulesetAsset = 'assets/glp1/glp1_ruleset_v1.json';

/// Reading of the data a condition is evaluated against. Keeps the
/// evaluator independent of where values come from, so the same code
/// serves a live assessment and a replayed history.
abstract class AnswerSource {
  num? valueFor(String questionId);
  bool isAnswered(String questionId);

  /// Values for [questionId] on the [days] most recent submitted
  /// assessments, most recent first. Used by `persisted`.
  List<num?> historyFor(String questionId, int days);
}

/// Straightforward source backed by one map of answers.
class MapAnswerSource implements AnswerSource {
  final Map<String, num?> values;
  final List<Map<String, num?>> history;

  const MapAnswerSource(this.values, {this.history = const []});

  @override
  num? valueFor(String q) => values[q];

  @override
  bool isAnswered(String q) => values.containsKey(q) && values[q] != null;

  @override
  List<num?> historyFor(String q, int days) =>
      history.take(days).map((m) => m[q]).toList();
}

class Ruleset {
  final String version;
  final int schemaVersion;
  final String name;
  final String approvalStatus;
  final String? approvedBy;
  final String? approvalDate;
  final String governanceNote;
  final Map<String, dynamic> config;
  final List<Question> questions;
  final List<ClinicalRule> rules;
  final List<RiskModifier> modifiers;

  late final Map<String, Question> _byId = {
    for (final q in questions) q.id: q
  };

  Ruleset({
    required this.version,
    required this.schemaVersion,
    required this.name,
    required this.approvalStatus,
    required this.approvedBy,
    required this.approvalDate,
    required this.governanceNote,
    required this.config,
    required this.questions,
    required this.rules,
    required this.modifiers,
  });

  factory Ruleset.fromJson(Map<String, dynamic> j) => Ruleset(
        version: j['ruleset_version'] as String,
        schemaVersion: j['schema_version'] as int? ?? 1,
        name: j['name'] as String? ?? 'GLP-1 monitoring',
        approvalStatus:
            j['approval_status'] as String? ?? 'UNAPPROVED_DRAFT',
        approvedBy: j['approved_by'] as String?,
        approvalDate: j['approval_date'] as String?,
        governanceNote: j['governance_note'] as String? ?? '',
        config: (j['config'] as Map?)?.cast<String, dynamic>() ?? {},
        questions: ((j['questions'] as List?) ?? [])
            .map((q) => Question.fromJson(q as Map<String, dynamic>))
            .toList(),
        rules: ((j['rules'] as List?) ?? [])
            .map((r) => ClinicalRule.fromJson(r as Map<String, dynamic>))
            .toList(),
        modifiers: ((j['risk_modifiers'] as List?) ?? [])
            .map((m) => RiskModifier.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  /// True once a named clinician has signed the configuration off.
  /// Until then the UI should not present this to a patient as
  /// clinically validated guidance.
  bool get isClinicallyApproved =>
      approvalStatus == 'APPROVED' &&
      approvedBy != null &&
      approvalDate != null;

  Question? question(String id) => _byId[id];

  List<Question> get dailyQuestions =>
      questions.where((q) => !q.isBaseline && !q.isOpener).toList();

  List<Question> get baselineQuestions =>
      questions.where((q) => q.isBaseline).toList();

  List<Question> get safetyQuestions =>
      questions.where((q) => q.isSafety).toList();

  List<Question> get openerQuestions =>
      questions.where((q) => q.isOpener).toList();

  List<Question> sectionQuestions(String section) =>
      questions.where((q) => q.section == section).toList();

  int get weeklyReviewDays => (config['weekly_review_days'] as int?) ?? 7;

  bool get unresolvedRiskCarries =>
      config['unresolved_risk_carries'] as bool? ?? true;

  /// Sections whose answers must never be copied from a previous day.
  Set<String> get blockedFromCarryForward =>
      ((config['carry_forward_blocked_sections'] as List?) ?? [])
          .cast<String>()
          .toSet();

  bool canCarryForward(Question q) =>
      !q.neverCarryForward && !blockedFromCarryForward.contains(q.section);

  // ── LOADING ─────────────────────────────────────────────
  static Ruleset? _cached;

  /// Reads the bundled ruleset. Swap this one method for a network
  /// fetch when the clinical configuration service exists; nothing
  /// else in the module needs to change.
  static Future<Ruleset> load({bool force = false}) async {
    if (_cached != null && !force) return _cached!;
    final raw = await rootBundle.loadString(kRulesetAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return _cached = Ruleset.fromJson(json);
  }

  /// For tests and for a future server response.
  static Ruleset fromRawJson(String raw) =>
      Ruleset.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  static void resetCache() => _cached = null;

  // ── SHOULD A QUESTION BE SHOWN? ─────────────────────────
  bool shouldShow(Question q, AnswerSource src) =>
      q.showIf == null || evaluate(q.showIf!, src);

  /// Every question the patient should see, in ruleset order, given
  /// what they have answered so far.
  List<Question> visibleQuestions(AnswerSource src,
      {bool includeBaseline = false}) {
    return questions.where((q) {
      if (q.isBaseline && !includeBaseline) return false;
      if (q.isOpener) return false;
      return shouldShow(q, src);
    }).toList();
  }

  /// Mandatory questions still unanswered. Drives both the submit
  /// gate and the Unable to Determine rule.
  List<Question> missingMandatory(AnswerSource src) => questions
      .where((q) => q.mandatory && shouldShow(q, src) && !src.isAnswered(q.id))
      .toList();

  // ── CONDITION EVALUATION ────────────────────────────────
  bool evaluate(Map<String, dynamic> cond, AnswerSource src) {
    if (cond.containsKey('all')) {
      final list = (cond['all'] as List).cast<Map<String, dynamic>>();
      return list.every((c) => evaluate(c, src));
    }
    if (cond.containsKey('any')) {
      final list = (cond['any'] as List).cast<Map<String, dynamic>>();
      return list.any((c) => evaluate(c, src));
    }
    if (cond.containsKey('not')) {
      return !evaluate(cond['not'] as Map<String, dynamic>, src);
    }
    if (cond.containsKey('persisted')) {
      return _persisted(cond['persisted'] as Map<String, dynamic>, src);
    }
    if (cond.containsKey('unanswered_mandatory')) {
      final want = cond['unanswered_mandatory'] as bool? ?? true;
      return missingMandatory(src).isNotEmpty == want;
    }
    if (cond.containsKey('q')) return _compare(cond, src);
    return false;
  }

  bool _compare(Map<String, dynamic> cond, AnswerSource src) {
    final qid = cond['q'] as String;
    final op = cond['op'] as String;
    final target = cond['value'];

    if (op == 'answered') return src.isAnswered(qid);
    if (op == 'unanswered') return !src.isAnswered(qid);

    final v = src.valueFor(qid);
    // No answer means no comparison can be true. An unasked question
    // must never read as a denial.
    if (v == null) return false;

    switch (op) {
      case 'eq':
        return v == target;
      case 'ne':
        return v != target;
      case 'gt':
        return v > (target as num);
      case 'gte':
        return v >= (target as num);
      case 'lt':
        return v < (target as num);
      case 'lte':
        return v <= (target as num);
      case 'in':
        return (target as List).contains(v);
      case 'notIn':
        return !(target as List).contains(v);
      default:
        return false;
    }
  }

  bool _persisted(Map<String, dynamic> spec, AnswerSource src) {
    final qid = spec['q'] as String;
    final op = spec['op'] as String;
    final target = spec['value'] as num;
    final days = spec['days'] as int;

    final hist = src.historyFor(qid, days);
    if (hist.length < days) return false;

    bool test(num? v) {
      if (v == null) return false;
      return switch (op) {
        'eq' => v == target,
        'ne' => v != target,
        'gt' => v > target,
        'gte' => v >= target,
        'lt' => v < target,
        'lte' => v <= target,
        _ => false,
      };
    }

    return hist.every(test);
  }
}
