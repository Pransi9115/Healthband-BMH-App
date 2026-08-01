// ─────────────────────────────────────────────────────────
//  GLP-1 RISK ENGINE TESTS
//
//  Covers the cases listed in section 23 of the build spec, plus the
//  safety invariants that must hold whatever else changes:
//
//    · an unanswered question is never read as "No"
//    · an uncertain answer to a safety question is never Green
//    · risk modifiers can raise a level but never lower one
//    · an unresolved Orange or Red survives a "same as yesterday"
//
//  These run against the real ruleset asset, so editing a threshold
//  in the JSON will fail the build here rather than in a patient's
//  hands.
//
//  Run with:  flutter test
// ─────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:biohealthcare/core/glp1/glp1_models.dart';
import 'package:biohealthcare/core/glp1/glp1_ruleset.dart';
import 'package:biohealthcare/core/glp1/glp1_risk_engine.dart';

late Ruleset ruleset;
late Glp1RiskEngine engine;

/// Builds an assessment from raw values. A key mapped to null is
/// treated as never answered.
Assessment mk(Map<String, num?> values, {CheckInMode mode = CheckInMode.edit}) {
  final now = DateTime.now();
  final responses = <String, Response>{};
  values.forEach((k, v) {
    if (v == null) return;
    responses[k] = Response(questionId: k, value: v, answeredAt: now);
  });
  return Assessment(
    id: 'test',
    startedAt: now,
    mode: mode,
    responses: responses,
    rulesetVersion: ruleset.version,
  );
}

/// A day with every safety question answered No and no symptoms.
Map<String, num?> base([Map<String, num?> overrides = const {}]) {
  final v = <String, num?>{};
  for (final q in ruleset.safetyQuestions) {
    v[q.id] = 0;
  }
  v.addAll({
    'nausea': 0, 'vomiting_count': 0, 'diarrhea': 0, 'constipation': 0,
    'appetite': 0, 'meals_ability': 0, 'abd_pain_severity': 0,
    'urine_color': 1, 'dizzy_standing': 0, 'injection_site': 0,
    'missed_dose': 0, 'right_rib_pain': 0, 'rash_hives': 0,
    'mood': 6, 'anxiety': 3, 'shaky_sweaty': 0, 'confusion': 0,
    'dose_increased': 0,
  });
  v.addAll(overrides);
  return v;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = File('assets/glp1/glp1_ruleset_v1.json').readAsStringSync();
    ruleset = Ruleset.fromRawJson(raw);
    engine = Glp1RiskEngine(ruleset);
  });

  group('ruleset integrity', () {
    test('loads questions, rules and modifiers', () {
      expect(ruleset.questions, isNotEmpty);
      expect(ruleset.rules, isNotEmpty);
      expect(ruleset.modifiers, isNotEmpty);
    });

    test('question ids are unique', () {
      final ids = ruleset.questions.map((q) => q.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every rule references questions that exist', () {
      final ids = ruleset.questions.map((q) => q.id).toSet();
      final missing = <String>{};
      void walk(Map<String, dynamic> c) {
        if (c['all'] is List) {
          for (final x in c['all'] as List) {
            walk((x as Map).cast<String, dynamic>());
          }
        }
        if (c['any'] is List) {
          for (final x in c['any'] as List) {
            walk((x as Map).cast<String, dynamic>());
          }
        }
        if (c['not'] is Map) {
          walk((c['not'] as Map).cast<String, dynamic>());
        }
        if (c['persisted'] is Map) {
          final q = (c['persisted'] as Map)['q'] as String;
          if (!ids.contains(q)) missing.add(q);
        }
        if (c['q'] is String && !ids.contains(c['q'])) {
          missing.add(c['q'] as String);
        }
      }

      for (final r in ruleset.rules) {
        walk(r.when);
        if (r.unless != null) walk(r.unless!);
      }
      expect(missing, isEmpty, reason: 'unknown question ids: $missing');
    });

    test('ruleset is flagged as unapproved until a clinician signs it', () {
      // Guards against shipping draft thresholds as validated guidance.
      expect(ruleset.isClinicallyApproved, isFalse);
    });

    test('safety questions are mandatory and cannot be carried forward', () {
      for (final q in ruleset.safetyQuestions) {
        expect(q.mandatory, isTrue, reason: '${q.id} must be mandatory');
        expect(ruleset.canCarryForward(q), isFalse,
            reason: '${q.id} must never carry forward');
      }
    });
  });

  group('risk levels', () {
    test('a settled day is green', () {
      expect(engine.evaluate(mk(base())).level, RiskLevel.green);
    });

    test('mild nausea is yellow', () {
      expect(engine.evaluate(mk(base({'nausea': 3}))).level,
          RiskLevel.yellow);
    });

    test('severe nausea is orange', () {
      final r = engine.evaluate(mk(base({'nausea': 9})));
      expect(r.level, RiskLevel.orange);
      expect(r.triggered.map((t) => t.ruleId), contains('R-ORG-011'));
    });

    test('severe abdominal pain is red', () {
      final r = engine.evaluate(
          mk(base({'abd_pain_severity': 3, 'safety_abd_pain': 1})));
      expect(r.level, RiskLevel.red);
      expect(r.triggered.map((t) => t.ruleId), contains('R-RED-001'));
      expect(r.hasTag('pancreatitis_pattern'), isTrue);
    });

    test('pain radiating to the back is red', () {
      final r = engine.evaluate(mk(base({
        'abd_pain_severity': 2, 'safety_abd_pain': 1,
        'safety_pain_back': 1, 'pain_back': 2,
      })));
      expect(r.level, RiskLevel.red);
      expect(r.triggered.map((t) => t.ruleId), contains('R-RED-002'));
    });

    test('severe pain with repeated vomiting is red', () {
      final r = engine.evaluate(mk(base({
        'abd_pain_severity': 3, 'vomiting_count': 3,
        'safety_abd_pain': 1, 'safety_vomiting_repeated': 1,
      })));
      expect(r.level, RiskLevel.red);
    });

    test('unable to keep fluids down with faintness is red', () {
      final r = engine.evaluate(
          mk(base({'safety_fluids_down': 1, 'safety_weak_faint': 1})));
      expect(r.level, RiskLevel.red);
      expect(r.triggered.map((t) => t.ruleId), contains('R-RED-007'));
    });

    test('airway swelling is red and tagged allergic', () {
      final r = engine.evaluate(mk(base({'safety_breathing': 1})));
      expect(r.level, RiskLevel.red);
      expect(r.hasTag('allergic_reaction'), isTrue);
    });

    test('jaundice with abdominal pain is red', () {
      final r = engine.evaluate(mk(base({
        'safety_jaundice': 1, 'right_rib_pain': 1, 'abd_pain_severity': 1,
      })));
      expect(r.level, RiskLevel.red);
    });

    test('patient asking for immediate help is red', () {
      expect(engine.evaluate(mk(base({'safety_urgent_help': 1}))).level,
          RiskLevel.red);
    });

    test('hypoglycaemia on insulin is orange', () {
      final r = engine.evaluate(mk(base({
        'bl_insulin': 1, 'shaky_sweaty': 2, 'confusion': 2,
      })));
      expect(r.level, RiskLevel.orange);
      expect(r.hasTag('hypoglycaemia'), isTrue);
    });

    test('gallbladder pattern is orange', () {
      final r = engine.evaluate(
          mk(base({'right_rib_pain': 1, 'pain_fatty_meals': 1})));
      expect(r.level, RiskLevel.orange);
      expect(r.hasTag('gallbladder'), isTrue);
    });

    test('dehydration pattern is orange', () {
      expect(
          engine.evaluate(mk(base({'urine_color': 4, 'dizzy_standing': 3})))
              .level,
          RiskLevel.orange);
    });

    test('symptoms after dose escalation are orange', () {
      final r =
          engine.evaluate(mk(base({'dose_increased': 1, 'nausea': 7})));
      expect(r.level, RiskLevel.orange);
      expect(r.hasTag('dose_escalation'), isTrue);
    });
  });

  group('incomplete and uncertain answers', () {
    test('not sure about abdominal pain is undetermined, never green', () {
      final r = engine.evaluate(mk(base({'safety_abd_pain': -1})));
      expect(r.level, RiskLevel.undetermined);
      expect(r.triggered.map((t) => t.ruleId), contains('R-UND-001'));
    });

    test('every safety question answered "not sure" avoids green', () {
      for (final q in ruleset.safetyQuestions) {
        final r = engine.evaluate(mk(base({q.id: -1})));
        expect(r.level, isNot(RiskLevel.green),
            reason: '${q.id} answered uncertain must not be green');
      }
    });

    test('a skipped mandatory question is undetermined', () {
      final v = base();
      v.remove('safety_abd_pain');
      final r = engine.evaluate(mk(v));
      expect(r.level, RiskLevel.undetermined);
      expect(r.missingMandatory, contains('safety_abd_pain'));
      expect(r.isComplete, isFalse);
    });

    test('an unanswered question is never treated as No', () {
      // safety_breathing absent must not satisfy "eq 0" anywhere.
      final v = base();
      v.remove('safety_breathing');
      expect(engine.evaluate(mk(v)).level, RiskLevel.undetermined);
    });

    test('engine unavailable is undetermined, not green', () {
      expect(Glp1RiskEngine.unavailable('1.0.0').level,
          RiskLevel.undetermined);
    });
  });

  group('carry forward safety', () {
    test('an unresolved orange survives a quiet day', () {
      final r = engine.evaluate(mk(base()),
          unresolvedRisk: RiskLevel.orange);
      expect(r.level, RiskLevel.orange);
      expect(r.calculatedLevel, RiskLevel.green);
      expect(r.carriedRisk, RiskLevel.orange);
    });

    test('an unresolved red survives a quiet day', () {
      final r =
          engine.evaluate(mk(base()), unresolvedRisk: RiskLevel.red);
      expect(r.level, RiskLevel.red);
      expect(r.carriedRisk, RiskLevel.red);
    });

    test('today can still escalate above what was carried', () {
      final r = engine.evaluate(
          mk(base({'abd_pain_severity': 3, 'safety_abd_pain': 1})),
          unresolvedRisk: RiskLevel.orange);
      expect(r.level, RiskLevel.red);
      expect(r.calculatedLevel, RiskLevel.red);
    });
  });

  group('risk modifiers', () {
    test('modifiers are recorded without changing the level', () {
      final without = engine.evaluate(
          mk(base({'abd_pain_severity': 3, 'safety_abd_pain': 1})));
      final with_ = engine.evaluate(mk(base({
        'abd_pain_severity': 3, 'safety_abd_pain': 1,
        'bl_prior_pancreatitis': 1, 'bl_gallstones': 1,
      })));
      expect(without.level, RiskLevel.red);
      expect(with_.level, RiskLevel.red);
      expect(with_.modifierScore, greaterThan(without.modifierScore));
      expect(with_.modifiers, contains('Previous pancreatitis'));
    });

    test('modifiers alone never raise a settled day', () {
      final r = engine.evaluate(mk(base({
        'bl_prior_pancreatitis': 1, 'bl_gallstones': 1, 'bl_alcohol': 3,
      })));
      expect(r.level, RiskLevel.green);
      expect(r.modifiers, isNotEmpty);
    });
  });

  group('persistence', () {
    test('nausea on three consecutive days is orange', () {
      final prior = [
        mk(base({'nausea': 6})).copyWith(submittedAt: DateTime.now()),
        mk(base({'nausea': 7})).copyWith(submittedAt: DateTime.now()),
      ];
      final r = engine.evaluate(mk(base({'nausea': 6})), previous: prior);
      expect(r.level, RiskLevel.orange);
      expect(r.triggered.map((t) => t.ruleId), contains('R-PER-001'));
    });

    test('two days of nausea does not trigger persistence', () {
      final prior = [
        mk(base({'nausea': 6})).copyWith(submittedAt: DateTime.now()),
      ];
      final r = engine.evaluate(mk(base({'nausea': 6})), previous: prior);
      expect(r.triggered.map((t) => t.ruleId),
          isNot(contains('R-PER-001')));
      expect(r.level, RiskLevel.yellow);
    });
  });

  group('clinical summary', () {
    test('states the level and ruleset without naming a diagnosis', () {
      final a = mk(base({'abd_pain_severity': 3, 'safety_abd_pain': 1}));
      final r = engine.evaluate(a);
      final s = engine.clinicalSummary(a, r).toLowerCase();
      expect(s, contains('red'));
      expect(s, contains(ruleset.version));
      expect(s, contains('patient-reported'));
      // Must never assert a diagnosis.
      expect(s, isNot(contains('has pancreatitis')));
      expect(s, isNot(contains('diagnosed with')));
    });

    test('records that answers were carried forward', () {
      final now = DateTime.now();
      final a = Assessment(
        id: 't2', startedAt: now, mode: CheckInMode.same,
        rulesetVersion: ruleset.version,
        responses: {
          'nausea': Response(
              questionId: 'nausea', value: 3, previousValue: 3,
              carriedForward: true, answeredAt: now),
          for (final q in ruleset.safetyQuestions)
            q.id: Response(questionId: q.id, value: 0, answeredAt: now),
        },
      );
      final r = engine.evaluate(a);
      expect(engine.clinicalSummary(a, r), contains('carried forward'));
    });
  });
}
