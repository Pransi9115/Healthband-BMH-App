// ─────────────────────────────────────────────────────────
//  BODY COMPOSITION SERVICE
//
//  Holds the latest measurement and the history behind it.
//
//  Right now it serves a demo fixture. The seam for real data is
//  [ingest] — whatever eventually talks to the FG2001B-A (Qingniu
//  SDK, a partner cloud API, or our own BLE decode) builds a
//  BodyComposition and calls it. Nothing above this line needs to
//  know which of those it was.
// ─────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'body_composition.dart';

/// A single point on the weight trend.
class WeightPoint {
  final DateTime at;
  final double weightKg;
  final double fatPct;
  final double muscleKg;

  const WeightPoint({
    required this.at,
    required this.weightKg,
    required this.fatPct,
    required this.muscleKg,
  });

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'w': weightKg, 'f': fatPct, 'm': muscleKg,
      };

  factory WeightPoint.fromJson(Map<String, dynamic> j) => WeightPoint(
        at: DateTime.parse(j['at'] as String),
        weightKg: (j['w'] as num).toDouble(),
        fatPct: (j['f'] as num).toDouble(),
        muscleKg: (j['m'] as num).toDouble(),
      );
}

class BodyCompositionService extends ChangeNotifier {
  BodyCompositionService._();
  static final BodyCompositionService instance = BodyCompositionService._();

  static const _kTrend = 'bmh_body_trend_v1';

  SharedPreferences? _prefs;
  BodyComposition? _latest;
  List<WeightPoint> _trend = [];
  bool _ready = false;

  bool get isReady => _ready;

  /// True while we are still showing the fixture rather than a real
  /// measurement. The UI says so plainly rather than passing demo
  /// numbers off as the patient's own.
  bool get isDemo => _latest == null || _latest!.source == 'Demo data';

  /// Never null — falls back to the fixture so the screen and the
  /// report can be built and reviewed before the scale feed lands.
  BodyComposition get latest => _latest ?? BodyComposition.demo();

  List<WeightPoint> get trend => List.unmodifiable(_trend);

  Future<void> init() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();

    final raw = _prefs!.getString(_kTrend);
    if (raw != null) {
      try {
        _trend = (jsonDecode(raw) as List)
            .map((e) =>
                WeightPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
      } catch (_) {
        _trend = [];
      }
    }
    if (_trend.isEmpty) _trend = _demoTrend();

    _ready = true;
    notifyListeners();
  }

  /// THE SEAM. Whatever reads the scale calls this.
  ///
  /// An implausible measurement is still stored — a patient who takes
  /// three bad readings should be able to see that something is wrong
  /// with how they are standing on it — but it does not join the
  /// trend, because one misread would distort the line for months.
  Future<void> ingest(BodyComposition c) async {
    _latest = c;
    if (c.isPlausible) {
      _trend = [..._trend, WeightPoint(
        at: c.measuredAt,
        weightKg: c.weightKg,
        fatPct: c.bodyFatPct,
        muscleKg: c.muscleKg)]
        ..sort((a, b) => a.at.compareTo(b.at));
      if (_trend.length > 400) {
        _trend = _trend.sublist(_trend.length - 400);
      }
      await _save();
    }
    notifyListeners();
  }

  Future<void> _save() async => _prefs?.setString(
      _kTrend, jsonEncode(_trend.map((p) => p.toJson()).toList()));

  Future<void> clear() async {
    _trend = [];
    _latest = null;
    await _prefs?.remove(_kTrend);
    notifyListeners();
  }

  /// Change over the window, or null when there is not enough history
  /// to say anything honest about a direction.
  double? weightChange({int days = 30}) {
    if (_trend.length < 2) return null;
    final since = DateTime.now().subtract(Duration(days: days));
    final window = _trend.where((p) => p.at.isAfter(since)).toList();
    if (window.length < 2) return null;
    return window.last.weightKg - window.first.weightKg;
  }

  double? fatChange({int days = 30}) {
    if (_trend.length < 2) return null;
    final since = DateTime.now().subtract(Duration(days: days));
    final window = _trend.where((p) => p.at.isAfter(since)).toList();
    if (window.length < 2) return null;
    return window.last.fatPct - window.first.fatPct;
  }

  static List<WeightPoint> _demoTrend() {
    final now = DateTime.now();
    const w = [76.8, 76.4, 76.1, 75.6, 75.4, 75.0, 74.7, 74.2];
    const f = [20.4, 20.1, 19.8, 19.4, 19.1, 18.8, 18.4, 18.1];
    const m = [56.3, 56.5, 56.6, 56.8, 57.0, 57.1, 57.3, 57.5];
    return [
      for (var i = 0; i < w.length; i++)
        WeightPoint(
          at: now.subtract(Duration(days: (w.length - 1 - i) * 7)),
          weightKg: w[i], fatPct: f[i], muscleKg: m[i]),
    ];
  }
}
