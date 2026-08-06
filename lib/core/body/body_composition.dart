// ─────────────────────────────────────────────────────────
//  BODY COMPOSITION
//
//  The shape of one measurement from the BioScale (FG2001B-A).
//
//  WHY A MODEL FIRST
//  The scale's own numbers come out of Qingniu's algorithm, and we do
//  not have that pipeline yet. So the screen and the report are built
//  against this model with a demo fixture behind it. When the real
//  feed arrives — SDK, cloud API, or our own decode — it becomes one
//  adapter producing a BodyComposition, and nothing above it changes.
//
//  WHAT IS MEASURED AND WHAT IS INFERRED
//  A consumer scale measures two things: weight, and impedance
//  between its electrodes. Everything else on the report — fat, water,
//  protein, bone mineral, body age — is estimated from those two plus
//  height, age and sex. The manufacturer's own report says as much
//  under the segmental figures: "segmental fat analysis is an inferred
//  value". [Measured] and [Derived] are marked per field below,
//  because a patient deserves to know which numbers were read off a
//  sensor and which were calculated for them.
//
//  SAFETY
//  Impedance scales misread routinely — dry feet, socks, a recent
//  meal, a recent shower. A misread does not look like an error, it
//  looks like a number. So every value passes through [plausible]
//  before it is shown, and an implausible measurement is flagged
//  rather than displayed as fact. See [BodyCompositionWarning].
// ─────────────────────────────────────────────────────────

import 'dart:math' as math;

// ─────────────────────────────────────────────────────────
//  EVALUATION
// ─────────────────────────────────────────────────────────
enum BandStatus { low, standard, high, excellent }

extension BandStatusX on BandStatus {
  String get label => switch (this) {
        BandStatus.low => 'Low',
        BandStatus.standard => 'Standard',
        BandStatus.high => 'High',
        BandStatus.excellent => 'Excellent',
      };
}

/// A value with the range it should sit in, and what that means.
class BodyMetric {
  final String key;
  final String label;
  final String unit;
  final double value;
  final double refLow;
  final double refHigh;

  /// Share of body weight, where the report shows one.
  final double? percentOfWeight;

  /// True when sitting above the range is a good thing — muscle,
  /// protein, body water, bone mineral. For weight and fat it is not.
  final bool highIsGood;

  /// True when the number was read from the sensor rather than
  /// estimated from it.
  final bool measured;

  final String description;

  const BodyMetric({
    required this.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.refLow,
    required this.refHigh,
    this.percentOfWeight,
    this.highIsGood = false,
    this.measured = false,
    this.description = '',
  });

  BandStatus get status {
    if (value < refLow) return BandStatus.low;
    if (value > refHigh) {
      return highIsGood ? BandStatus.excellent : BandStatus.high;
    }
    return BandStatus.standard;
  }

  /// 0..1 position on a bar drawn with one range-width of headroom
  /// either side, so an out-of-range value still lands on the bar.
  double get barPosition {
    final span = refHigh - refLow;
    if (span <= 0) return 0.5;
    final min = refLow - span * 0.6;
    final max = refHigh + span * 0.6;
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }

  double get zoneStart {
    final span = refHigh - refLow;
    if (span <= 0) return 0.3;
    final min = refLow - span * 0.6;
    final max = refHigh + span * 0.6;
    return ((refLow - min) / (max - min)).clamp(0.0, 1.0);
  }

  double get zoneEnd {
    final span = refHigh - refLow;
    if (span <= 0) return 0.7;
    final min = refLow - span * 0.6;
    final max = refHigh + span * 0.6;
    return ((refHigh - min) / (max - min)).clamp(0.0, 1.0);
  }

  String get rangeLabel =>
      '${_fmt(refLow)} to ${_fmt(refHigh)}';

  String get valueLabel => _fmt(value);

  static String _fmt(double v) {
    if (v == v.roundToDouble() && v.abs() >= 10) return v.round().toString();
    return v.toStringAsFixed(1);
  }
}

// ─────────────────────────────────────────────────────────
//  SEGMENTS
// ─────────────────────────────────────────────────────────
enum BodySegment { leftArm, rightArm, trunk, leftLeg, rightLeg }

extension BodySegmentX on BodySegment {
  String get label => switch (this) {
        BodySegment.leftArm => 'Left arm',
        BodySegment.rightArm => 'Right arm',
        BodySegment.trunk => 'Trunk',
        BodySegment.leftLeg => 'Left leg',
        BodySegment.rightLeg => 'Right leg',
      };

  String get shortLabel => switch (this) {
        BodySegment.leftArm => 'L arm',
        BodySegment.rightArm => 'R arm',
        BodySegment.trunk => 'Trunk',
        BodySegment.leftLeg => 'L leg',
        BodySegment.rightLeg => 'R leg',
      };

  /// The manufacturer applies a wider band to the limbs than to the
  /// trunk, which is why the printed report carries two ranges.
  bool get isLimbUpper =>
      this == BodySegment.leftArm || this == BodySegment.rightArm;
}

/// One segment's mass and how it compares with what is expected for
/// this body. Percentages are of the expected value, not of weight —
/// 131% means "a third more muscle here than expected", which is how
/// the printed report reads.
class SegmentReading {
  final BodySegment segment;
  final double massKg;
  final double percentOfExpected;

  const SegmentReading({
    required this.segment,
    required this.massKg,
    required this.percentOfExpected,
  });

  /// Fat uses one band for every segment; muscle uses a wider band for
  /// the arms than for trunk and legs.
  BandStatus statusFat() {
    if (percentOfExpected < 80) return BandStatus.low;
    if (percentOfExpected > 160) return BandStatus.high;
    return BandStatus.standard;
  }

  BandStatus statusMuscle() {
    final lo = segment.isLimbUpper ? 80.0 : 90.0;
    final hi = segment.isLimbUpper ? 120.0 : 110.0;
    if (percentOfExpected < lo) return BandStatus.low;
    if (percentOfExpected > hi) return BandStatus.excellent;
    return BandStatus.standard;
  }
}

/// Raw impedance, the one thing besides weight the scale actually
/// measures. Shown because it is the evidence behind everything else.
class ImpedanceReading {
  final BodySegment segment;
  final double ohms20kHz;
  final double ohms100kHz;

  const ImpedanceReading({
    required this.segment,
    required this.ohms20kHz,
    required this.ohms100kHz,
  });
}

// ─────────────────────────────────────────────────────────
//  BODY TYPE
// ─────────────────────────────────────────────────────────
enum BodyType {
  athletes, muscularFat, overweight,
  muscle, fit, slightlyFat,
  muscularSlim, slim, invisibleFat,
  tooThin, thin,
}

extension BodyTypeX on BodyType {
  String get label => switch (this) {
        BodyType.athletes => 'Athletic',
        BodyType.muscularFat => 'Muscular fat',
        BodyType.overweight => 'Overweight',
        BodyType.muscle => 'Muscular',
        BodyType.fit => 'Fit',
        BodyType.slightlyFat => 'Slightly fat',
        BodyType.muscularSlim => 'Muscular slim',
        BodyType.slim => 'Slim',
        BodyType.invisibleFat => 'Invisible fat',
        BodyType.tooThin => 'Very lean',
        BodyType.thin => 'Lean',
      };

  String get blurb => switch (this) {
        BodyType.athletes =>
          'High muscle with low fat — the pattern seen in trained '
          'athletes.',
        BodyType.muscularFat =>
          'Plenty of muscle carried alongside a higher fat share.',
        BodyType.overweight =>
          'Fat share and body mass both above the usual band.',
        BodyType.muscle => 'Muscle above average with fat in the '
          'expected band.',
        BodyType.fit => 'Muscle and fat both sitting where they are '
          'expected to.',
        BodyType.slightlyFat =>
          'Body mass in band, with fat a little above it.',
        BodyType.muscularSlim =>
          'A light frame carrying more muscle than expected for it.',
        BodyType.slim => 'A light frame with muscle and fat both in '
          'their expected bands.',
        BodyType.invisibleFat =>
          'Body mass looks unremarkable while the fat share sits high — '
          'the pattern that hides behind a normal BMI.',
        BodyType.tooThin =>
          'Body mass well below the expected band.',
        BodyType.thin => 'Body mass below the expected band.',
      };
}

// ─────────────────────────────────────────────────────────
//  PLAUSIBILITY
// ─────────────────────────────────────────────────────────
class BodyCompositionWarning {
  final String field;
  final String message;
  const BodyCompositionWarning(this.field, this.message);
}

// ─────────────────────────────────────────────────────────
//  THE MEASUREMENT
// ─────────────────────────────────────────────────────────
class BodyComposition {
  final DateTime measuredAt;
  final String source;          // 'BioScale FG2001B-A' or 'Demo'

  // Profile the estimates were computed against.
  final bool isFemale;
  final int age;
  final double heightCm;

  // [Measured]
  final double weightKg;

  // [Derived] core composition
  final double bodyFatKg;
  final double bodyFatPct;
  final double boneMineralKg;   // the report calls this inorganic salt
  final double proteinKg;
  final double bodyWaterKg;
  final double muscleKg;
  final double skeletalMuscleKg;

  // [Derived] indicators
  final int visceralGrade;
  final double bmrKcal;
  final double subcutaneousPct;
  final double smi;             // skeletal muscle index, kg/m2
  final int bodyAge;
  final double whr;             // waist-to-hip, needs a tape or estimate

  // [Derived] segments
  final List<SegmentReading> segmentFat;
  final List<SegmentReading> segmentMuscle;

  // [Measured]
  final List<ImpedanceReading> impedance;

  const BodyComposition({
    required this.measuredAt,
    required this.source,
    required this.isFemale,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.bodyFatKg,
    required this.bodyFatPct,
    required this.boneMineralKg,
    required this.proteinKg,
    required this.bodyWaterKg,
    required this.muscleKg,
    required this.skeletalMuscleKg,
    required this.visceralGrade,
    required this.bmrKcal,
    required this.subcutaneousPct,
    required this.smi,
    required this.bodyAge,
    required this.whr,
    this.segmentFat = const [],
    this.segmentMuscle = const [],
    this.impedance = const [],
  });

  double get heightM => heightCm / 100;
  double get bmi => weightKg / (heightM * heightM);
  double get fatFreeMassKg => weightKg - bodyFatKg;
  double get bodyWaterPct => weightKg == 0 ? 0 : bodyWaterKg / weightKg * 100;

  // ── REFERENCE RANGES ──────────────────────────────────
  //
  // Ranges follow the same construction the printed report uses:
  // a healthy BMI band scaled to this person's height, and the
  // component ranges derived from that band by sex.

  double get weightLow => 18.5 * heightM * heightM;
  double get weightHigh => 25.0 * heightM * heightM;

  /// Target weight the report recommends — the midpoint of the
  /// healthy BMI band, nudged by sex as the manufacturer does.
  double get targetWeightKg => (isFemale ? 21.0 : 22.0) * heightM * heightM;

  double get fatPctLow => isFemale ? 21.0 : 11.0;
  double get fatPctHigh => isFemale ? 34.0 : 22.0;

  double get fatKgLow => weightKg * fatPctLow / 100;
  double get fatKgHigh => weightKg * fatPctHigh / 100;

  double get proteinLow => weightKg * 0.14;
  double get proteinHigh => weightKg * 0.18;

  double get waterLow => weightKg * (isFemale ? 0.45 : 0.50);
  double get waterHigh => weightKg * (isFemale ? 0.60 : 0.65);

  double get boneLow => weightKg * 0.040;
  double get boneHigh => weightKg * 0.055;

  double get muscleLow => weightKg * (isFemale ? 0.60 : 0.68);
  double get muscleHigh => weightKg * (isFemale ? 0.74 : 0.82);

  double get skeletalLow => weightKg * (isFemale ? 0.36 : 0.44);
  double get skeletalHigh => weightKg * (isFemale ? 0.46 : 0.54);

  /// The composition table, in the order the printed report uses.
  List<BodyMetric> get compositionTable => [
        BodyMetric(
          key: 'weight', label: 'Weight', unit: 'kg',
          value: weightKg, refLow: weightLow, refHigh: weightHigh,
          percentOfWeight: 100, measured: true,
          description: 'What the scale read, before anything is '
            'estimated from it.'),
        BodyMetric(
          key: 'fat', label: 'Body fat', unit: 'kg',
          value: bodyFatKg, refLow: fatKgLow, refHigh: fatKgHigh,
          percentOfWeight: bodyFatPct,
          description: 'Stored energy. Some is essential — it '
            'cushions organs and carries the fat soluble vitamins.'),
        BodyMetric(
          key: 'bone', label: 'Bone mineral', unit: 'kg',
          value: boneMineralKg, refLow: boneLow, refHigh: boneHigh,
          percentOfWeight:
            weightKg == 0 ? 0 : boneMineralKg / weightKg * 100,
          highIsGood: true,
          description: 'The mineral content of your skeleton. Moves '
            'very slowly, so treat sudden changes as noise.'),
        BodyMetric(
          key: 'protein', label: 'Protein', unit: 'kg',
          value: proteinKg, refLow: proteinLow, refHigh: proteinHigh,
          percentOfWeight:
            weightKg == 0 ? 0 : proteinKg / weightKg * 100,
          highIsGood: true,
          description: 'The structural material of muscle, organs and '
            'enzymes.'),
        BodyMetric(
          key: 'water', label: 'Body water', unit: 'kg',
          value: bodyWaterKg, refLow: waterLow, refHigh: waterHigh,
          percentOfWeight: bodyWaterPct,
          highIsGood: true,
          description: 'Total water in the body. This is the reading '
            'most affected by hydration, so it moves between mornings.'),
        BodyMetric(
          key: 'muscle', label: 'Muscle', unit: 'kg',
          value: muscleKg, refLow: muscleLow, refHigh: muscleHigh,
          percentOfWeight:
            weightKg == 0 ? 0 : muscleKg / weightKg * 100,
          highIsGood: true,
          description: 'All muscle including smooth muscle and the '
            'water held inside it.'),
        BodyMetric(
          key: 'skeletal', label: 'Skeletal muscle', unit: 'kg',
          value: skeletalMuscleKg,
          refLow: skeletalLow, refHigh: skeletalHigh,
          percentOfWeight:
            weightKg == 0 ? 0 : skeletalMuscleKg / weightKg * 100,
          highIsGood: true,
          description: 'The muscle you can train — the part that '
            'responds to resistance work.'),
      ];

  // ── CONTROL TARGETS ───────────────────────────────────
  double get weightControlKg => targetWeightKg - weightKg;

  /// How much of the weight change should come from fat. Muscle
  /// control takes whatever is left, so the two always reconcile.
  double get fatControlKg {
    final idealFat = weightKg * (fatPctLow + fatPctHigh) / 2 / 100;
    return idealFat - bodyFatKg;
  }

  double get muscleControlKg {
    final v = weightControlKg - fatControlKg;
    return v.abs() < 0.1 ? 0 : v;
  }

  // ── ASSESSMENTS ───────────────────────────────────────
  BandStatus get bmiStatus {
    if (bmi < 18.5) return BandStatus.low;
    if (bmi >= 30) return BandStatus.high;
    if (bmi >= 25) return BandStatus.high;
    return BandStatus.standard;
  }

  String get bmiBand {
    if (bmi < 18.5) return 'Thin';
    if (bmi < 25) return 'Standard';
    if (bmi < 30) return 'High';
    return 'Too high';
  }

  String get fatBand {
    if (bodyFatPct < fatPctLow) return 'Thin';
    if (bodyFatPct <= fatPctHigh) return 'Standard';
    if (bodyFatPct <= fatPctHigh + 8) return 'High';
    return 'Too high';
  }

  /// Current weight as a share of target, which is how the printed
  /// report expresses "obesity".
  double get weightVsTargetPct =>
      targetWeightKg == 0 ? 0 : weightKg / targetWeightKg * 100;

  String get weightVsTargetBand {
    final p = weightVsTargetPct;
    if (p < 90) return 'Low';
    if (p <= 110) return 'Normal';
    return 'High';
  }

  /// The BMI against body-fat matrix from the printed report.
  BodyType get bodyType {
    final lowFat = bodyFatPct < fatPctLow;
    final highFat = bodyFatPct > fatPctHigh;

    if (bmi >= 25) {
      if (lowFat) return BodyType.athletes;
      if (highFat) return BodyType.overweight;
      return BodyType.muscularFat;
    }
    if (bmi >= 18.5) {
      if (lowFat) return BodyType.muscle;
      if (highFat) return BodyType.slightlyFat;
      return BodyType.fit;
    }
    if (lowFat) return BodyType.muscularSlim;
    if (highFat) return BodyType.invisibleFat;
    return bmi < 16 ? BodyType.tooThin : BodyType.slim;
  }

  // ── BODY SCORE ────────────────────────────────────────
  //
  // One number out of 100. Built from how close each component sits
  // to its own band rather than from weight alone, so a lean, well
  // muscled person is not punished for being heavy.
  int get bodyScore {
    var total = 0.0;
    var weightSum = 0.0;

    void add(BodyMetric m, double w) {
      weightSum += w;
      final span = m.refHigh - m.refLow;
      if (span <= 0) return;
      if (m.value >= m.refLow && m.value <= m.refHigh) {
        total += w * 100;
      } else if (m.value > m.refHigh) {
        // Above band scores well when above is good, and decays when
        // it is not.
        final over = (m.value - m.refHigh) / span;
        total += w * (m.highIsGood
          ? 100
          : math.max(40, 100 - over * 60));
      } else {
        final under = (m.refLow - m.value) / span;
        total += w * math.max(30, 100 - under * 70);
      }
    }

    final t = compositionTable;
    add(t[1], 2.0); // fat
    add(t[6], 2.0); // skeletal muscle
    add(t[4], 1.0); // water
    add(t[3], 1.0); // protein
    add(t[2], 0.5); // bone
    add(t[0], 1.5); // weight

    if (weightSum == 0) return 0;
    final score = total / weightSum;
    return score.round().clamp(0, 100);
  }

  // ── PLAUSIBILITY ──────────────────────────────────────
  //
  // An impedance scale misreads for ordinary reasons — dry skin,
  // socks, a recent meal, standing off-centre. The failure does not
  // look like an error, it looks like a number, and a patient shown
  // "7.3% body fat, Low" next to "gain 9.3 kg" is being handed
  // alarming and wrong information by an app they trust.
  List<BodyCompositionWarning> get warnings {
    final out = <BodyCompositionWarning>[];

    // Below essential fat is not survivable, so it is a misread.
    final essential = isFemale ? 10.0 : 3.0;
    if (bodyFatPct < essential) {
      out.add(BodyCompositionWarning('fat',
        'A body fat reading of ${bodyFatPct.toStringAsFixed(1)}% is '
        'below the level the body needs to function, so this is '
        'almost certainly a misread rather than a real result. Bare, '
        'clean, slightly damp feet on the electrodes give the best '
        'reading. Take it again before drawing any conclusion.'));
    }
    if (bodyFatPct > 60) {
      out.add(BodyCompositionWarning('fat',
        'This body fat reading is outside the range these scales can '
        'measure reliably. Take it again with bare feet.'));
    }
    if (bodyWaterPct > 75 || (bodyWaterPct < 35 && bodyWaterPct > 0)) {
      out.add(BodyCompositionWarning('water',
        'The body water share looks outside the plausible range, '
        'which usually points to poor contact with the electrodes.'));
    }
    if (weightKg > 0 && (weightKg < 20 || weightKg > 180)) {
      out.add(BodyCompositionWarning('weight',
        'The weight reading is outside what this scale measures.'));
    }
    if (fatFreeMassKg > 0 && muscleKg > fatFreeMassKg) {
      out.add(BodyCompositionWarning('muscle',
        'Muscle came back higher than total fat free mass, which '
        'cannot be right. Take the measurement again.'));
    }
    return out;
  }

  bool get isPlausible => warnings.isEmpty;

  // ── DEMO FIXTURE ──────────────────────────────────────
  //
  // Used to build the screen and the report before the scale feed
  // exists. Deliberately a plausible adult so the layout is exercised
  // with realistic values — the manufacturer's own sample sheet
  // carries a 7.3% body fat reading for a 39 year old woman, which is
  // physiologically impossible and would be useless for testing how a
  // real result looks.
  static BodyComposition demo() {
    final now = DateTime.now();
    return BodyComposition(
      measuredAt: DateTime(now.year, now.month, now.day, 7, 42),
      source: 'Demo data',
      isFemale: false,
      age: 39,
      heightCm: 178,
      weightKg: 74.2,
      bodyFatKg: 13.4,
      bodyFatPct: 18.1,
      boneMineralKg: 3.3,
      proteinKg: 12.6,
      bodyWaterKg: 44.9,
      muscleKg: 57.5,
      skeletalMuscleKg: 33.1,
      visceralGrade: 7,
      bmrKcal: 1712,
      subcutaneousPct: 13.9,
      smi: 10.4,
      bodyAge: 36,
      whr: 0.86,
      segmentFat: const [
        SegmentReading(segment: BodySegment.leftArm,
          massKg: 0.8, percentOfExpected: 96),
        SegmentReading(segment: BodySegment.rightArm,
          massKg: 0.8, percentOfExpected: 98),
        SegmentReading(segment: BodySegment.trunk,
          massKg: 7.4, percentOfExpected: 112),
        SegmentReading(segment: BodySegment.leftLeg,
          massKg: 2.2, percentOfExpected: 89),
        SegmentReading(segment: BodySegment.rightLeg,
          massKg: 2.2, percentOfExpected: 90),
      ],
      segmentMuscle: const [
        SegmentReading(segment: BodySegment.leftArm,
          massKg: 3.4, percentOfExpected: 104),
        SegmentReading(segment: BodySegment.rightArm,
          massKg: 3.5, percentOfExpected: 108),
        SegmentReading(segment: BodySegment.trunk,
          massKg: 25.8, percentOfExpected: 101),
        SegmentReading(segment: BodySegment.leftLeg,
          massKg: 9.1, percentOfExpected: 97),
        SegmentReading(segment: BodySegment.rightLeg,
          massKg: 9.2, percentOfExpected: 99),
      ],
      impedance: const [
        ImpedanceReading(segment: BodySegment.rightArm,
          ohms20kHz: 331.6, ohms100kHz: 302.4),
        ImpedanceReading(segment: BodySegment.leftArm,
          ohms20kHz: 336.2, ohms100kHz: 306.1),
        ImpedanceReading(segment: BodySegment.trunk,
          ohms20kHz: 21.4, ohms100kHz: 16.8),
        ImpedanceReading(segment: BodySegment.rightLeg,
          ohms20kHz: 248.7, ohms100kHz: 224.3),
        ImpedanceReading(segment: BodySegment.leftLeg,
          ohms20kHz: 251.2, ohms100kHz: 226.9),
      ],
    );
  }
}
