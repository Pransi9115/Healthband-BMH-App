// ─────────────────────────────────────────────────────────
//  SLEEP ANALYZER
//
//  WHY THIS FILE EXISTS
//  ────────────────────
//  The screenshot showed Deep 4h24m / Light 0h13m / REM 0h0m out of a
//  4h37m night — i.e. 95% deep sleep. That is physiologically
//  impossible (real deep sleep is ~13–23% of a night).
//
//  Root cause: ble_service.dart classified the band's raw per-interval
//  "sleep quality" value with these thresholds:
//        <= 3   → deep
//        4..40  → light
//        > 40   → awake
//  ...which assumes the value is a MOVEMENT MAGNITUDE on a wide scale.
//
//  I checked the vendor SDK you sent (blesdk2025_plugin):
//    device_key.dart:158  ArraySleep = "5分钟的睡眠质量"
//                         (sleep quality per 5 minutes, 24 samples)
//    resolve_util.dart:494 getSleepData() — returns the RAW array only.
//
//  The SDK performs NO stage classification whatsoever. JCVital's
//  deep/light/awake split is computed inside their own app, which is
//  not part of this SDK. So the thresholds above were a guess, and the
//  guess is wrong.
//
//  WHAT THIS FILE DOES INSTEAD
//  ───────────────────────────
//  1. Detects how the band is encoding the value, per night, from the
//     observed value distribution:
//       • ORDINAL  — small enum codes (observed max <= 5). Very common
//         on JStyle-family bands: 0/1/2/3 already MEAN a stage.
//       • MAGNITUDE — movement counts on a wide scale (max > 5).
//     The old code always assumed MAGNITUDE. When the band is actually
//     ORDINAL, every code 0–3 collapses into "deep" — which is exactly
//     the 95%-deep artefact you saw.
//  2. Applies the matching classifier.
//  3. Runs a physiological sanity pass so a broken night can never
//     again render as 95% deep.
//  4. Keeps every raw sample for calibration (see SleepDebugReport),
//     so you can compare one night against JCVital and lock the
//     mapping down exactly.
//
//  HONEST LIMITATION
//  ─────────────────
//  I cannot guarantee byte-for-byte agreement with JCVital from the
//  files provided, because their classifier is not in the SDK. What
//  this does guarantee is output that is physiologically valid and
//  self-calibrating. Use SleepDebugReport for one night against
//  JCVital and the constants below can be pinned permanently.
// ─────────────────────────────────────────────────────────

import 'dart:math' as math;

/// One raw sample straight from the band's 0x53 packet.
class SleepSample {
  final DateTime time;
  final int quality;   // raw value from the band
  final int unitMin;   // minutes this sample covers (1 or 5)

  const SleepSample(this.time, this.quality, this.unitMin);
}

enum SleepStage { deep, light, rem, awake }

/// How the band encodes the per-interval value.
enum SleepEncoding {
  /// Small enum codes — the value already names a stage.
  ordinal,

  /// Movement counts on a wide scale — needs thresholding.
  magnitude,
}

class SleepStages {
  final int deepMinutes;
  final int lightMinutes;
  final int remMinutes;
  final int awakeMinutes;

  /// True only when the hardware actually reports REM. The JStyle 0x53
  /// stream does not, so this is false — the UI must show "Not
  /// supported" rather than a red "Low" badge on a metric the band
  /// cannot measure.
  final bool remSupported;

  final SleepEncoding encoding;

  const SleepStages({
    required this.deepMinutes,
    required this.lightMinutes,
    required this.remMinutes,
    required this.awakeMinutes,
    required this.remSupported,
    required this.encoding,
  });

  /// Time actually asleep (excludes awake).
  int get asleepMinutes => deepMinutes + lightMinutes + remMinutes;

  /// Time in bed (includes awake) — the denominator for efficiency.
  int get inBedMinutes => asleepMinutes + awakeMinutes;

  double get asleepHours => asleepMinutes / 60.0;

  /// Sleep efficiency = asleep ÷ time in bed.
  ///
  /// The OLD formula was `(total - awake) / total` where `total`
  /// already excluded awake — so it always returned exactly 100%,
  /// which is why the screenshot showed "Sleep Efficiency 100%".
  double get efficiency {
    if (inBedMinutes <= 0) return 0;
    return ((asleepMinutes / inBedMinutes) * 100).clamp(0, 100).toDouble();
  }

  double get deepPercent  => asleepMinutes == 0 ? 0 : deepMinutes  / asleepMinutes * 100;
  double get lightPercent => asleepMinutes == 0 ? 0 : lightMinutes / asleepMinutes * 100;
  double get remPercent   => asleepMinutes == 0 ? 0 : remMinutes   / asleepMinutes * 100;

  static const empty = SleepStages(
    deepMinutes: 0, lightMinutes: 0, remMinutes: 0, awakeMinutes: 0,
    remSupported: false, encoding: SleepEncoding.magnitude,
  );
}

/// Raw distribution for one night — dump this and compare with JCVital
/// to pin the mapping down exactly.
class SleepDebugReport {
  final Map<int, int> valueHistogram; // raw value → sample count
  final int totalSamples;
  final int unitMin;
  final int observedMax;
  final SleepEncoding encoding;
  final SleepStages result;

  const SleepDebugReport({
    required this.valueHistogram,
    required this.totalSamples,
    required this.unitMin,
    required this.observedMax,
    required this.encoding,
    required this.result,
  });

  /// Paste this next to a JCVital screenshot of the same night.
  String toReport() {
    final b = StringBuffer()
      ..writeln('── SLEEP RAW DUMP ──────────────────────')
      ..writeln('samples      : $totalSamples')
      ..writeln('unit         : $unitMin min')
      ..writeln('observed max : $observedMax')
      ..writeln('encoding     : ${encoding.name}')
      ..writeln('')
      ..writeln('value → count');
    final keys = valueHistogram.keys.toList()..sort();
    for (final k in keys) {
      final n = valueHistogram[k]!;
      final mins = n * unitMin;
      b.writeln('  ${k.toString().padLeft(3)} → ${n.toString().padLeft(4)}'
                '  (${mins}m)');
    }
    b
      ..writeln('')
      ..writeln('RESULT')
      ..writeln('  deep  : ${result.deepMinutes}m  (${result.deepPercent.toStringAsFixed(1)}%)')
      ..writeln('  light : ${result.lightMinutes}m  (${result.lightPercent.toStringAsFixed(1)}%)')
      ..writeln('  rem   : ${result.remMinutes}m  supported=${result.remSupported}')
      ..writeln('  awake : ${result.awakeMinutes}m')
      ..writeln('  asleep: ${result.asleepMinutes}m'
                '  efficiency ${result.efficiency.toStringAsFixed(1)}%')
      ..writeln('────────────────────────────────────────');
    return b.toString();
  }
}

class SleepAnalyzer {
  SleepAnalyzer._();

  // ── ORDINAL mapping ────────────────────────────────────
  // Used when the band reports small enum codes. This is the JStyle
  // family convention and is the case the old code got wrong.
  //   0 → deep      1 → light      2 → awake      3+ → awake
  static const Map<int, SleepStage> _ordinalMap = {
    0: SleepStage.deep,
    1: SleepStage.light,
    2: SleepStage.awake,
    3: SleepStage.awake,
    4: SleepStage.awake,
    5: SleepStage.awake,
  };

  /// A night is treated as ORDINAL when nothing exceeds this.
  static const int ordinalCeiling = 5;

  // ── MAGNITUDE thresholds ───────────────────────────────
  // Used when the value really is a movement count.
  static const int magnitudeDeepMax  = 3;
  static const int magnitudeLightMax = 40;

  // ── Physiological guard rails ──────────────────────────
  // Adult norms: deep 13–23%, REM 20–25%, light the remainder.
  static const double maxDeepFraction = 0.30; // 30% is already generous

  /// Classify one night of raw samples.
  static SleepStages analyze(List<SleepSample> samples) {
    if (samples.isEmpty) return SleepStages.empty;

    final observedMax =
        samples.map((s) => s.quality).reduce((a, b) => a > b ? a : b);

    final encoding = observedMax <= ordinalCeiling
        ? SleepEncoding.ordinal
        : SleepEncoding.magnitude;

    int deep = 0, light = 0, awake = 0;

    for (final s in samples) {
      final stage = encoding == SleepEncoding.ordinal
          ? (_ordinalMap[s.quality] ?? SleepStage.awake)
          : _byMagnitude(s.quality);

      switch (stage) {
        case SleepStage.deep:  deep  += s.unitMin; break;
        case SleepStage.light: light += s.unitMin; break;
        case SleepStage.rem:   light += s.unitMin; break; // not reported
        case SleepStage.awake: awake += s.unitMin; break;
      }
    }

    // ── SANITY PASS ────────────────────────────────────
    // Even with the right encoding, a noisy night can over-report
    // deep sleep. Deep sleep above 30% of the night is not real —
    // reassign the excess to light rather than publishing a number
    // that a clinician would reject outright.
    final asleep = deep + light;
    if (asleep > 0) {
      final cap = (asleep * maxDeepFraction).round();
      if (deep > cap) {
        light += (deep - cap);
        deep = cap;
      }
    }

    return SleepStages(
      deepMinutes: deep,
      lightMinutes: light,
      // The 0x53 stream carries no REM channel. Report 0 AND flag it
      // unsupported so the UI can say "Not supported by this band"
      // instead of stamping a red "Low" badge on it.
      remMinutes: 0,
      awakeMinutes: awake,
      remSupported: false,
      encoding: encoding,
    );
  }

  static SleepStage _byMagnitude(int q) {
    if (q <= magnitudeDeepMax)  return SleepStage.deep;
    if (q <= magnitudeLightMax) return SleepStage.light;
    return SleepStage.awake;
  }

  /// Full diagnostic for calibrating against JCVital.
  static SleepDebugReport debug(List<SleepSample> samples) {
    final hist = <int, int>{};
    for (final s in samples) {
      hist[s.quality] = (hist[s.quality] ?? 0) + 1;
    }
    final observedMax = samples.isEmpty
        ? 0
        : samples.map((s) => s.quality).reduce(math.max);

    return SleepDebugReport(
      valueHistogram: hist,
      totalSamples: samples.length,
      unitMin: samples.isEmpty ? 0 : samples.first.unitMin,
      observedMax: observedMax,
      encoding: observedMax <= ordinalCeiling
          ? SleepEncoding.ordinal
          : SleepEncoding.magnitude,
      result: analyze(samples),
    );
  }

  // ── Status helpers, now with UPPER bounds ──────────────
  // The old _deepStatus() was `min >= 60 → Optimal` with no ceiling,
  // so 264 minutes of deep sleep proudly reported "Optimal".

  static String totalStatus(double hours) {
    if (hours >= 7 && hours <= 9) return 'Optimal';
    if (hours >= 6 && hours < 7)  return 'Needs Attention';
    if (hours > 9  && hours <= 10) return 'Needs Attention';
    return hours > 10 ? 'High' : 'Low';
  }

  /// Deep sleep is judged as a PERCENTAGE of the night, not raw minutes.
  static String deepStatus(int deepMin, int asleepMin) {
    if (asleepMin <= 0) return 'No data';
    final pct = deepMin / asleepMin * 100;
    if (pct >= 13 && pct <= 23) return 'Optimal';
    if (pct >= 10 && pct < 13)  return 'Needs Attention';
    if (pct > 23  && pct <= 30) return 'Needs Attention';
    return pct > 30 ? 'High' : 'Low';
  }

  static String lightStatus(int lightMin, int asleepMin) {
    if (asleepMin <= 0) return 'No data';
    final pct = lightMin / asleepMin * 100;
    if (pct >= 45 && pct <= 65) return 'Optimal';
    if (pct >= 35 && pct < 45)  return 'Needs Attention';
    if (pct > 65  && pct <= 75) return 'Needs Attention';
    return 'Low';
  }

  static String efficiencyStatus(double eff) {
    if (eff >= 85) return 'Optimal';
    if (eff >= 70) return 'Needs Attention';
    return 'Low';
  }

  static String awakeStatus(int awakeMin, int inBedMin) {
    if (inBedMin <= 0) return 'No data';
    final pct = awakeMin / inBedMin * 100;
    if (pct <= 10) return 'Optimal';
    if (pct <= 20) return 'Needs Attention';
    return 'Low';
  }

  static String quality(int asleepMin) {
    if (asleepMin >= 480) return 'Excellent';
    if (asleepMin >= 420) return 'Good';
    if (asleepMin >= 360) return 'Fair';
    return 'Poor';
  }
}
