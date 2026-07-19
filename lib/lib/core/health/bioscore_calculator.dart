import '../ble/ble_service.dart';

// ─────────────────────────────────────────────────────────
//  BIOSCORE CALCULATOR
//  Single source of truth for the BioScore formula — extracted
//  from health_screen.dart's _BioScoreCard so the same exact
//  calculation can be shown on the Home hero ring too, without
//  duplicating (and risking diverging) the logic.
// ─────────────────────────────────────────────────────────
class BioScoreResult {
  final int score;       // 0-100 (clamped 40-100 once it has data)
  final bool hasScore;   // true once band connected + worn + has a reading
  final String label;    // Excellent / Good / Fair / Needs attention
  const BioScoreResult({
    required this.score,
    required this.hasScore,
    required this.label,
  });
}

class BioScoreCalculator {
  BioScoreCalculator._();

  static BioScoreResult compute(BleService ble) {
    final hasScore = ble.isBandConnected && ble.isWearing && ble.heartRate > 0;

    int score = 0;
    if (ble.isBandConnected && ble.isWearing) {
      int s = 70;
      final hr = ble.heartRate;
      final spo2 = ble.spo2;
      final hrv = ble.hrv;
      if (hr > 0) {
        if (hr >= 55 && hr <= 70) {
          s += 8;
        } else if (hr > 70 && hr <= 80) {
          s += 4;
        } else if (hr > 100) {
          s -= 8;
        }
      }
      if (spo2 > 0) {
        if (spo2 >= 98) {
          s += 6;
        } else if (spo2 < 94) {
          s -= 10;
        }
      }
      if (hrv > 0) {
        if (hrv >= 40) {
          s += 6;
        } else if (hrv >= 25) {
          s += 3;
        }
      }
      score = s.clamp(40, 100);
    }

    final label = score >= 85
        ? 'Excellent'
        : score >= 70
            ? 'Good'
            : score >= 55
                ? 'Fair'
                : 'Needs attention';

    return BioScoreResult(score: score, hasScore: hasScore, label: label);
  }
}
