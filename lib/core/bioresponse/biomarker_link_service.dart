// ─────────────────────────────────────────────────────────
//  BIORESPONSE — BIOMARKER LINKS
//
//  The point of the Biomarkers area is not two separate lists.
//  It is the join: what the patient puts IN (food + supplements)
//  read against what the blood test found.
//
//  Those two sides use different units — Vitamin D intake is in
//  mcg per day, Vitamin D in blood is nmol/L — so they are never
//  added together or converted. What is compared is the STATUS of
//  each side, and the pair of statuses produces the message.
//
//  Example from a real panel: B12 intake well above target while
//  blood B12 sits above the reference top. Neither number alone
//  says much; together they say "over-supplementing, ease off".
// ─────────────────────────────────────────────────────────

import '../diet/diet_models.dart';
import '../diet/diet_service.dart';
import 'blood_report_service.dart';
import 'nutritional_score_service.dart';
import 'supplement_service.dart';

// ── INTAKE SIDE ───────────────────────────────────────────
enum IntakeLevel { none, low, adequate, high }

extension IntakeLevelX on IntakeLevel {
  String get label => switch (this) {
        IntakeLevel.none => 'Not logged',
        IntakeLevel.low => 'Below target',
        IntakeLevel.adequate => 'On target',
        IntakeLevel.high => 'Well above target',
      };
}

// ── WHAT THE PAIR MEANS ───────────────────────────────────
enum LinkVerdict { matched, dietGap, absorption, overSupplement, watch, unknown }

extension LinkVerdictX on LinkVerdict {
  String get title => switch (this) {
        LinkVerdict.matched => 'Intake and blood agree',
        LinkVerdict.dietGap => 'Low intake, low blood',
        LinkVerdict.absorption => 'Intake looks fine, blood is low',
        LinkVerdict.overSupplement => 'More going in than needed',
        LinkVerdict.watch => 'Worth watching',
        LinkVerdict.unknown => 'Not enough information',
      };
}

// ── ONE LINKED BIOMARKER ──────────────────────────────────
class BiomarkerLink {
  final String name;
  final String nutrientKey;      // Micronutrient name for the intake side
  final String bloodKey;         // BloodMarker key for the blood side
  final String why;              // why these two belong together

  const BiomarkerLink({
    required this.name,
    required this.nutrientKey,
    required this.bloodKey,
    required this.why,
  });

  static const all = <BiomarkerLink>[
    BiomarkerLink(
      name: 'Vitamin D',
      nutrientKey: 'Vitamin D',
      bloodKey: 'vitamin_d',
      why: 'Blood vitamin D reflects diet, supplements and sunlight '
          'together, so a gap between the two sides is informative.'),
    BiomarkerLink(
      name: 'Vitamin B12',
      nutrientKey: 'Vitamin B12',
      bloodKey: 'vitamin_b12',
      why: 'B12 is stored, so blood levels respond slowly to intake and '
          'rise steadily when supplements are heavy.'),
    BiomarkerLink(
      name: 'Folate',
      nutrientKey: 'Folate',
      bloodKey: 'folate',
      why: 'Serum folate tracks recent dietary intake fairly closely.'),
    BiomarkerLink(
      name: 'Iron',
      nutrientKey: 'Iron',
      bloodKey: 'ferritin',
      why: 'Ferritin shows iron stores, which build or fall over months '
          'of dietary intake rather than days.'),
    BiomarkerLink(
      name: 'Magnesium',
      nutrientKey: 'Magnesium',
      bloodKey: 'magnesium',
      why: 'Most magnesium sits inside cells, so blood magnesium moves '
          'less than intake does — read it as a broad check.'),
    BiomarkerLink(
      name: 'Calcium',
      nutrientKey: 'Calcium',
      bloodKey: 'calcium',
      why: 'Blood calcium is tightly controlled by the body, so it stays '
          'steady even when intake changes.'),
  ];
}

// ── RESULT ────────────────────────────────────────────────
class LinkResult {
  final BiomarkerLink link;
  final double intakeFromFood;
  final double intakeFromSupplements;
  final double intakeTarget;
  final String intakeUnit;
  final IntakeLevel intakeLevel;
  final BloodMarker? blood;
  final LinkVerdict verdict;
  final String message;
  final int daysWithData;

  const LinkResult({
    required this.link,
    required this.intakeFromFood,
    required this.intakeFromSupplements,
    required this.intakeTarget,
    required this.intakeUnit,
    required this.intakeLevel,
    required this.blood,
    required this.verdict,
    required this.message,
    required this.daysWithData,
  });

  double get intakeTotal => intakeFromFood + intakeFromSupplements;
  double get intakePercent =>
      intakeTarget <= 0 ? 0 : (intakeTotal / intakeTarget * 100);
  bool get hasIntake => daysWithData > 0;
  bool get needsAttention =>
      verdict == LinkVerdict.dietGap ||
      verdict == LinkVerdict.absorption ||
      verdict == LinkVerdict.overSupplement;
}

// ─────────────────────────────────────────────────────────
class BiomarkerLinkService {
  BiomarkerLinkService._();
  static final BiomarkerLinkService instance = BiomarkerLinkService._();

  final _diet = DietService.instance;
  final _supps = SupplementService.instance;
  final _blood = BloodReportService.instance;
  final _score = NutritionalScoreService.instance;

  /// Food + supplement intake for one nutrient, averaged over the
  /// logged days in the range. Days with nothing logged are left
  /// out rather than counted as zero.
  ({double food, double supps, int days}) intakeFor(
      String nutrient, ScoreRange range, {DateTime? endDay}) {
    final days = _score.daysIn(range, endDay ?? DateTime.now());
    final logged = days
        .where((d) => _score.hasDataOn(d) || _supps.hasDataOn(d))
        .toList();
    if (logged.isEmpty) return (food: 0, supps: 0, days: 0);

    double food = 0, supps = 0;
    for (final d in logged) {
      food += _diet.microsFor(d)[nutrient] ?? 0;
      supps += _supps.microsFor(d)[nutrient] ?? 0;
    }
    return (
      food: food / logged.length,
      supps: supps / logged.length,
      days: logged.length,
    );
  }

  IntakeLevel _levelFor(double total, double target, int days) {
    if (days == 0) return IntakeLevel.none;
    if (target <= 0) return IntakeLevel.none;
    final pct = total / target * 100;
    if (pct < 70) return IntakeLevel.low;
    if (pct > 150) return IntakeLevel.high;
    return IntakeLevel.adequate;
  }

  // ── THE INTERPRETATION MATRIX ───────────────────────────
  (LinkVerdict, String) _interpret(
      BiomarkerLink link, IntakeLevel intake, BloodMarker? blood) {
    if (blood == null || intake == IntakeLevel.none) {
      return (
        LinkVerdict.unknown,
        blood == null
          ? 'No blood result for ${link.name} in your latest panel.'
          : 'Log food and supplements to compare your intake against '
            'this blood result.'
      );
    }

    final b = blood.status;
    final low = b == MarkerStatus.low;
    final high = b == MarkerStatus.high && !blood.highIsGood;
    final ok = !low && !high;

    if (low && intake == IntakeLevel.low) {
      return (
        LinkVerdict.dietGap,
        'Your ${link.name} intake is below target and your blood level is '
        'low as well. The two agree, which points to intake as the most '
        'likely cause and the easiest place to start.'
      );
    }
    if (low && intake != IntakeLevel.low) {
      return (
        LinkVerdict.absorption,
        'You are getting enough ${link.name} on paper, but your blood '
        'level is still low. Absorption, medication or other factors may '
        'be involved — worth raising with your care team rather than '
        'simply taking more.'
      );
    }
    if (high && intake == IntakeLevel.high) {
      return (
        LinkVerdict.overSupplement,
        'Your ${link.name} intake is well above target and your blood '
        'level is above the reference range. This pattern usually means '
        'supplementation is heavier than needed. Review it with your '
        'care team before changing anything.'
      );
    }
    if (high) {
      return (
        LinkVerdict.watch,
        'Your blood ${link.name} is above the reference range while your '
        'intake looks ordinary. Your care team should interpret this one.'
      );
    }
    if (ok && intake == IntakeLevel.low) {
      return (
        LinkVerdict.watch,
        'Blood ${link.name} is in range even though intake is below '
        'target. Stores can hold for a while — keep an eye on it and '
        'recheck at the next panel.'
      );
    }
    return (
      LinkVerdict.matched,
      'Intake is on target and blood ${link.name} sits in range. Nothing '
      'to change here.'
    );
  }

  LinkResult resultFor(BiomarkerLink link, ScoreRange range,
      {DateTime? endDay}) {
    final micro = Micronutrient.byName(link.nutrientKey);
    final target = micro?.rda ?? 0;
    final unit = micro?.unit ?? '';
    final i = intakeFor(link.nutrientKey, range, endDay: endDay);
    final total = i.food + i.supps;
    final level = _levelFor(total, target, i.days);
    final blood = _blood.report?.byKey(link.bloodKey);
    final (verdict, message) = _interpret(link, level, blood);

    return LinkResult(
      link: link,
      intakeFromFood: i.food,
      intakeFromSupplements: i.supps,
      intakeTarget: target,
      intakeUnit: unit,
      intakeLevel: level,
      blood: blood,
      verdict: verdict,
      message: message,
      daysWithData: i.days,
    );
  }

  List<LinkResult> allResults(ScoreRange range, {DateTime? endDay}) {
    final out = BiomarkerLink.all
        .map((l) => resultFor(l, range, endDay: endDay))
        .toList();
    // Anything needing attention first, then the rest.
    out.sort((a, b) {
      final aa = a.needsAttention ? 0 : 1;
      final bb = b.needsAttention ? 0 : 1;
      return aa.compareTo(bb);
    });
    return out;
  }

  /// Every nutrient the patient takes in, whether or not the blood
  /// panel covers it — this is the full Intake tab.
  List<({Micronutrient micro, double food, double supps, int days})>
      fullIntake(ScoreRange range, {DateTime? endDay}) {
    return Micronutrient.all.map((m) {
      final i = intakeFor(m.name, range, endDay: endDay);
      return (micro: m, food: i.food, supps: i.supps, days: i.days);
    }).toList();
  }
}
