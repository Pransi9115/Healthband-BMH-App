// ─────────────────────────────────────────────────────────
//  VITAL STATUS  —  single source of truth for Low / Normal / High
//
//  FIXES the "Blood Pressure always reads High" bug.
//
//  Old code did:
//      double.tryParse('116/66'.replaceAll('/', ''))  →  11666
//  ...then compared 11666 against normalMax (130) → always "High".
//
//  Blood Pressure is the only vital carrying TWO numbers, so it needs
//  its own evaluator. Every other vital keeps a simple single-number
//  band check, but each against ITS OWN min / normal / max — never a
//  shared threshold.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';

/// Where a reading sits relative to that vital's own reference range.
enum VitalLevel { noData, low, normal, high }

extension VitalLevelX on VitalLevel {
  /// Text shown in the pill on the hero card.
  String get label => switch (this) {
        VitalLevel.noData => 'No data',
        VitalLevel.low    => 'Low',
        VitalLevel.normal => 'Normal',
        VitalLevel.high   => 'High',
      };

  bool get isNoData => this == VitalLevel.noData;
  bool get isNormal => this == VitalLevel.normal;

  /// Low and High are both "out of range" — colour them as warnings.
  Color get color => switch (this) {
        VitalLevel.noData => BMHColors.inkMute,
        VitalLevel.normal => BMHColors.sGut,
        VitalLevel.low    => BMHColors.sOxygen, // below range → blue
        VitalLevel.high   => BMHColors.danger,  // above range → red
      };
}

/// Reference range for one vital. `low` / `high` are the *outer* limits
/// of what the band can meaningfully report; `normalMin`..`normalMax`
/// is the healthy band.
class VitalRange {
  final double normalMin;
  final double normalMax;
  final String unit;
  final int decimals;

  const VitalRange({
    required this.normalMin,
    required this.normalMax,
    required this.unit,
    this.decimals = 0,
  });

  String fmt(double v) => v.toStringAsFixed(decimals);
}

/// Result of evaluating a reading: the level plus a human explanation.
class VitalStatus {
  final VitalLevel level;
  final String detail;

  const VitalStatus(this.level, [this.detail = '']);

  String get label => level.label;
  Color  get color => level.color;

  static const noData = VitalStatus(VitalLevel.noData, 'Waiting for a reading');
}

// ─────────────────────────────────────────────────────────
//  REFERENCE RANGES — one entry per vital
//  Keep these aligned with VitalConfig in health_screen.dart.
// ─────────────────────────────────────────────────────────
class VitalRanges {
  VitalRanges._();

  // Blood pressure is split — each side has its own healthy band.
  static const bpSystolic  = VitalRange(normalMin: 90,  normalMax: 130, unit: 'mmHg');
  static const bpDiastolic = VitalRange(normalMin: 60,  normalMax: 85,  unit: 'mmHg');

  static const Map<String, VitalRange> _byTitle = {
    'Heart Rate':    VitalRange(normalMin: 60,   normalMax: 100,   unit: 'bpm'),
    'SpO₂':          VitalRange(normalMin: 95,   normalMax: 100,   unit: '%'),
    'HRV':           VitalRange(normalMin: 30,   normalMax: 60,    unit: 'ms'),
    'Temperature':   VitalRange(normalMin: 36.1, normalMax: 37.2,  unit: '°C', decimals: 1),
    'Stress Level':  VitalRange(normalMin: 0,    normalMax: 40,    unit: '/100'),
    'Sleep Quality': VitalRange(normalMin: 7,    normalMax: 9,     unit: 'hrs', decimals: 1),
    'Steps Today':   VitalRange(normalMin: 7000, normalMax: 10000, unit: 'steps'),
    'Blood Glucose': VitalRange(normalMin: 70,   normalMax: 100,   unit: 'mg/dL'),
  };

  static VitalRange? of(String title) => _byTitle[title];

  /// True when this vital carries two numbers ("116/66").
  static bool isDual(String title) => title == 'Blood Pressure';

  // ───────────────────────────────────────────────────────
  //  MAIN ENTRY POINT
  //  Pass the raw display string exactly as shown in the UI.
  // ───────────────────────────────────────────────────────
  static VitalStatus evaluate(String title, String raw) {
    final v = raw.trim();
    if (v.isEmpty || v == '--' || v == '--/--' || v == '0') {
      return VitalStatus.noData;
    }

    if (isDual(title)) return _evaluateBloodPressure(v);

    final range = of(title);
    if (range == null) return VitalStatus.noData;

    final num = double.tryParse(v);
    if (num == null || num <= 0) return VitalStatus.noData;

    return _band(num, range, title);
  }

  /// Convenience overload when you already hold a numeric value.
  static VitalStatus evaluateValue(String title, double value) {
    if (value <= 0) return VitalStatus.noData;
    final range = of(title);
    if (range == null) return VitalStatus.noData;
    return _band(value, range, title);
  }

  static VitalStatus _band(double v, VitalRange r, String title) {
    if (v < r.normalMin) {
      return VitalStatus(
        VitalLevel.low,
        'Below the normal range of ${r.fmt(r.normalMin)}–${r.fmt(r.normalMax)} ${r.unit}',
      );
    }
    if (v > r.normalMax) {
      return VitalStatus(
        VitalLevel.high,
        'Above the normal range of ${r.fmt(r.normalMin)}–${r.fmt(r.normalMax)} ${r.unit}',
      );
    }
    return VitalStatus(
      VitalLevel.normal,
      'Within the normal range of ${r.fmt(r.normalMin)}–${r.fmt(r.normalMax)} ${r.unit}',
    );
  }

  // ───────────────────────────────────────────────────────
  //  BLOOD PRESSURE — evaluated as a PAIR
  //
  //  Clinical convention: the worse of the two sides decides the
  //  overall label. 116/66 → systolic normal, diastolic normal
  //  → "Normal"  (the old code reported "High" here).
  //  145/70 → systolic high → "High".
  //  100/55 → diastolic low → "Low".
  // ───────────────────────────────────────────────────────
  static VitalStatus _evaluateBloodPressure(String raw) {
    final parts = raw.split('/');
    if (parts.length != 2) return VitalStatus.noData;

    final sys = double.tryParse(parts[0].trim());
    final dia = double.tryParse(parts[1].trim());
    if (sys == null || dia == null || sys <= 0 || dia <= 0) {
      return VitalStatus.noData;
    }

    final sysHigh = sys > bpSystolic.normalMax;
    final diaHigh = dia > bpDiastolic.normalMax;
    final sysLow  = sys < bpSystolic.normalMin;
    final diaLow  = dia < bpDiastolic.normalMin;

    // High takes priority over Low — an elevated side is the greater
    // clinical concern when the two disagree (e.g. 150/55).
    if (sysHigh || diaHigh) {
      final which = sysHigh && diaHigh
          ? 'Both systolic and diastolic are'
          : sysHigh
              ? 'Systolic (${sys.toStringAsFixed(0)}) is'
              : 'Diastolic (${dia.toStringAsFixed(0)}) is';
      return VitalStatus(VitalLevel.high,
          '$which above the normal range '
          '(${bpSystolic.fmt(bpSystolic.normalMin)}–${bpSystolic.fmt(bpSystolic.normalMax)}'
          ' / ${bpDiastolic.fmt(bpDiastolic.normalMin)}–${bpDiastolic.fmt(bpDiastolic.normalMax)} mmHg)');
    }

    if (sysLow || diaLow) {
      final which = sysLow && diaLow
          ? 'Both systolic and diastolic are'
          : sysLow
              ? 'Systolic (${sys.toStringAsFixed(0)}) is'
              : 'Diastolic (${dia.toStringAsFixed(0)}) is';
      return VitalStatus(VitalLevel.low, '$which below the normal range');
    }

    return const VitalStatus(VitalLevel.normal,
        'Systolic and diastolic are both within the normal range');
  }

  // ───────────────────────────────────────────────────────
  //  DISPLAY HELPERS for the Min / Normal / Max strip
  //
  //  The old UI printed normalMin under "Min" and normalMax under
  //  "Max", which read as "Min 110 / Normal 110–130 / Max 130".
  //  These return correctly-labelled text instead.
  // ───────────────────────────────────────────────────────
  static String minLabel(String title) {
    if (isDual(title)) return '${bpSystolic.fmt(bpSystolic.normalMin)}/${bpDiastolic.fmt(bpDiastolic.normalMin)}';
    final r = of(title);
    return r == null ? '--' : '${r.fmt(r.normalMin)} ${r.unit}';
  }

  static String normalLabel(String title) {
    if (isDual(title)) {
      return '${bpSystolic.fmt(bpSystolic.normalMin)}–${bpSystolic.fmt(bpSystolic.normalMax)}'
             ' / ${bpDiastolic.fmt(bpDiastolic.normalMin)}–${bpDiastolic.fmt(bpDiastolic.normalMax)}';
    }
    final r = of(title);
    return r == null ? '--' : '${r.fmt(r.normalMin)}–${r.fmt(r.normalMax)}';
  }

  static String maxLabel(String title) {
    if (isDual(title)) return '${bpSystolic.fmt(bpSystolic.normalMax)}/${bpDiastolic.fmt(bpDiastolic.normalMax)}';
    final r = of(title);
    return r == null ? '--' : '${r.fmt(r.normalMax)} ${r.unit}';
  }
}
