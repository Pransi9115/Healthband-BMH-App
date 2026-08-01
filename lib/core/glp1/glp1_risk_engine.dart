// ─────────────────────────────────────────────────────────
//  GLP-1 MONITORING — RISK ENGINE
//
//  Runs an assessment against the ruleset and returns a level plus
//  the rules that produced it. Three behaviours here are safety
//  properties rather than conveniences, and each is enforced in one
//  place so it cannot be forgotten at a call site:
//
//  1. Missing or uncertain answers never resolve downward. An
//     unanswered mandatory safety question, or an "I am not sure"
//     against a red flag, gives Unable to Determine — never Green.
//
//  2. Risk modifiers never reduce a level. Having no history of
//     pancreatitis does not make severe abdominal pain less urgent.
//     Modifiers are recorded for the clinician and can only add.
//
//  3. An unresolved Orange or Red carries. Saying "same as
//     yesterday" while a serious symptom is still open cannot clear
//     it: only a clinician resolving it, or the patient actively
//     reporting improvement, does that.
// ─────────────────────────────────────────────────────────

import 'glp1_models.dart';
import 'glp1_ruleset.dart';

/// Answer source over a live assessment plus prior submitted ones.
class AssessmentAnswerSource implements AnswerSource {
  final Assessment assessment;

  /// Earlier submitted assessments, most recent first. The current
  /// assessment counts as day one for persistence checks.
  final List<Assessment> previous;

  const AssessmentAnswerSource(this.assessment, {this.previous = const []});

  @override
  num? valueFor(String q) => assessment.responses[q]?.value;

  @override
  bool isAnswered(String q) => assessment.responses[q]?.isAnswered ?? false;

  @override
  List<num?> historyFor(String q, int days) {
    final out = <num?>[valueFor(q)];
    for (final a in previous) {
      if (out.length >= days) break;
      out.add(a.responses[q]?.value);
    }
    return out;
  }
}

class Glp1RiskEngine {
  final Ruleset ruleset;
  const Glp1RiskEngine(this.ruleset);

  /// Evaluates [assessment]. [previous] should be earlier submitted
  /// assessments, most recent first, so duration rules can fire.
  /// [unresolvedRisk] is the highest level still open from an earlier
  /// day that no clinician has cleared.
  RiskResult evaluate(
    Assessment assessment, {
    List<Assessment> previous = const [],
    RiskLevel? unresolvedRisk,
  }) {
    final src = AssessmentAnswerSource(assessment, previous: previous);

    // ── which rules fire ────────────────────────────────
    final fired = <TriggeredRule>[];
    for (final rule in ruleset.rules) {
      if (!ruleset.evaluate(rule.when, src)) continue;
      if (rule.unless != null && ruleset.evaluate(rule.unless!, src)) {
        continue;
      }
      fired.add(TriggeredRule(
        ruleId: rule.id,
        ruleVersion: rule.version,
        name: rule.name,
        risk: rule.risk,
        patientMessage: rule.patientMessage,
        clinicianMessage: rule.clinicianMessage,
        action: rule.action,
        tags: rule.tags,
      ));
    }

    // ── modifiers: recorded, additive only ──────────────
    final mods = <String>[];
    var modScore = 0;
    for (final m in ruleset.modifiers) {
      final v = src.valueFor(m.question);
      if (v == null) continue;
      final hit = switch (m.op) {
        'eq' => v == m.value,
        'ne' => v != m.value,
        'gt' => v > m.value,
        'gte' => v >= m.value,
        'lt' => v < m.value,
        'lte' => v <= m.value,
        _ => false,
      };
      if (hit) {
        mods.add(m.label);
        modScore += m.weight;
      }
    }

    // ── level from today's answers ──────────────────────
    var calculated = RiskLevel.green;
    for (final t in fired) {
      calculated = maxRisk(calculated, t.risk);
    }

    // Incomplete mandatory answers can never read as Green.
    final missing =
        ruleset.missingMandatory(src).map((q) => q.id).toList();
    if (missing.isNotEmpty && calculated == RiskLevel.green) {
      calculated = RiskLevel.undetermined;
    }

    // ── fold in anything still open from earlier ────────
    var level = calculated;
    RiskLevel? carried;
    if (ruleset.unresolvedRiskCarries &&
        unresolvedRisk != null &&
        unresolvedRisk.severity > calculated.severity) {
      level = unresolvedRisk;
      carried = unresolvedRisk;
    }

    return RiskResult(
      level: level,
      calculatedLevel: calculated,
      carriedRisk: carried,
      triggered: fired,
      modifiers: mods,
      modifierScore: modScore,
      rulesetVersion: ruleset.version,
      missingMandatory: missing,
    );
  }

  /// The level to use when the engine cannot run at all — a corrupt
  /// ruleset, a failed load. Deliberately not Green.
  static RiskResult unavailable(String rulesetVersion) => RiskResult(
        level: RiskLevel.undetermined,
        calculatedLevel: RiskLevel.undetermined,
        triggered: const [],
        modifiers: const [],
        modifierScore: 0,
        rulesetVersion: rulesetVersion,
        missingMandatory: const ['__engine_unavailable__'],
      );

  /// Emergency-only pass for the significant-change screen, run
  /// before the routine questionnaire is shown.
  RiskResult evaluateUrgentOnly(Assessment assessment) {
    final src = AssessmentAnswerSource(assessment);
    final fired = <TriggeredRule>[];
    for (final rule in ruleset.rules) {
      if (rule.risk != RiskLevel.red) continue;
      if (!ruleset.evaluate(rule.when, src)) continue;
      fired.add(TriggeredRule(
        ruleId: rule.id,
        ruleVersion: rule.version,
        name: rule.name,
        risk: rule.risk,
        patientMessage: rule.patientMessage,
        clinicianMessage: rule.clinicianMessage,
        action: rule.action,
        tags: rule.tags,
      ));
    }
    final level = fired.isEmpty ? RiskLevel.green : RiskLevel.red;
    return RiskResult(
      level: level,
      calculatedLevel: level,
      triggered: fired,
      modifiers: const [],
      modifierScore: 0,
      rulesetVersion: ruleset.version,
    );
  }

  // ── CHANGE SUMMARY ──────────────────────────────────────
  /// Fields the patient edited, for the confirm-before-submit screen.
  List<FieldChange> changesIn(Assessment a) {
    final out = <FieldChange>[];
    for (final r in a.responses.values) {
      if (!r.manuallyChanged) continue;
      final q = ruleset.question(r.questionId);
      if (q == null) continue;
      out.add(FieldChange(question: q, from: r.previousValue, to: r.value));
    }
    out.sort((x, y) {
      if (x.isWorse != y.isWorse) return x.isWorse ? -1 : 1;
      return x.question.id.compareTo(y.question.id);
    });
    return out;
  }

  /// Plain-language account of what the rules did, for the clinician
  /// view. States what was reported and which rules fired; it does
  /// not name a diagnosis.
  String clinicalSummary(Assessment a, RiskResult r) {
    final b = StringBuffer();
    final when = a.submittedAt ?? a.startedAt;
    b.write('Patient-reported check-in at '
        '${when.toIso8601String()}. ');
    b.write('Mode: ${a.mode.key}. ');

    final carriedCount =
        a.responses.values.where((x) => x.carriedForward).length;
    if (carriedCount > 0) {
      b.write('$carriedCount answers carried forward from a previous '
          'assessment. ');
    }

    final changes = changesIn(a);
    if (changes.isNotEmpty) {
      b.write('Changed today: ');
      b.write(changes.map((c) => c.sentence).join('; '));
      b.write('. ');
    }

    if (r.triggered.isEmpty) {
      b.write('No rules triggered. ');
    } else {
      b.write('Rules triggered: ');
      b.write(r.topRules.map((t) => '${t.ruleId} ${t.name}').join('; '));
      b.write('. ');
    }

    if (r.modifiers.isNotEmpty) {
      b.write('Risk modifiers on record: ${r.modifiers.join(", ")}. ');
    }

    b.write('Classified ${r.level.key.toUpperCase()} '
        'by ruleset ${r.rulesetVersion}');
    if (r.carriedRisk != null) {
      b.write(', raised from ${r.calculatedLevel.key} by an unresolved '
          '${r.carriedRisk!.key} from an earlier assessment');
    }
    b.write('. ');

    if (r.missingMandatory.isNotEmpty) {
      b.write('Incomplete: ${r.missingMandatory.length} mandatory '
          'answers missing. ');
    }
    return b.toString();
  }
}
