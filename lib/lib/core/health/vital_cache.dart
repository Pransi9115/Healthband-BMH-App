// ─────────────────────────────────────────────────────────
//  VITAL CACHE  —  stops the "--" flicker on navigation
//
//  THE BUG
//  ───────
//  Every vital getter in ble_service.dart is gated on _isWearing:
//
//      int get heartRate => _isWearing ? _heartRate : 0;
//
//  ...and the UI renders '--' whenever the value is 0. Meanwhile
//  _startWearDetection() resets:
//
//      _wearProbeReceived = false;   // must get fresh confirmation
//
//  on EVERY connect, with hardware re-probes queued at 3s and 8s.
//  While that probe is outstanding, _isWearing is false, so all
//  vitals blank to '--' — even though the real values are still
//  sitting in memory, untouched.
//
//  So this was never a connectivity loss. The data was there the
//  whole time; the UI was hiding it and then "recovering" a few
//  seconds later when the probe landed. That is exactly the
//  behaviour you described: leave Health Vitals → home shows '--'
//  → a few seconds later the numbers come back.
//
//  THE FIX
//  ───────
//  Keep the last confirmed reading with a timestamp. During a probe
//  gap, keep showing it (flagged stale so the UI can dim it and say
//  "2m ago") instead of blanking. Only fall back to '--' when the
//  reading is genuinely old or the band is truly disconnected.
// ─────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

/// A reading plus when it was captured.
class CachedVital {
  final double value;
  final DateTime at;

  const CachedVital(this.value, this.at);

  Duration get age => DateTime.now().difference(at);

  /// Human label for the UI: "just now", "2m ago", "1h ago".
  String get ageLabel {
    final s = age.inSeconds;
    if (s < 45) return 'just now';
    final m = age.inMinutes;
    if (m < 60) return '${m}m ago';
    final h = age.inHours;
    if (h < 24) return '${h}h ago';
    return '${age.inDays}d ago';
  }
}

class VitalCache extends ChangeNotifier {
  VitalCache._();
  static final VitalCache instance = VitalCache._();

  final Map<String, CachedVital> _cache = {};

  /// How long a reading stays displayable after the band stops
  /// confirming wear. Comfortably longer than the 3s/8s probe
  /// backoff, short enough that nobody mistakes it for live data.
  static const Duration freshWindow = Duration(minutes: 5);

  /// Beyond this we stop showing the value entirely.
  static const Duration hardExpiry = Duration(hours: 6);

  /// Record a confirmed reading. Call this whenever the band delivers
  /// a real value — BEFORE any _isWearing gating is applied.
  void put(String key, double value) {
    if (value <= 0) return;
    _cache[key] = CachedVital(value, DateTime.now());
    notifyListeners();
  }

  /// Store a two-number vital such as blood pressure.
  void putPair(String key, int a, int b) {
    if (a <= 0 || b <= 0) return;
    _cache[key]        = CachedVital(a.toDouble(), DateTime.now());
    _cache['${key}_2'] = CachedVital(b.toDouble(), DateTime.now());
    notifyListeners();
  }

  CachedVital? raw(String key) {
    final c = _cache[key];
    if (c == null) return null;
    if (c.age > hardExpiry) {
      _cache.remove(key);
      return null;
    }
    return c;
  }

  /// The value to actually display.
  ///
  /// [liveValue] is what the gated getter currently returns (0 while a
  /// wear probe is outstanding). If it is real, use it. If it is 0 but
  /// we have a recent cached reading, show that instead of '--'.
  double display(String key, double liveValue) {
    if (liveValue > 0) {
      put(key, liveValue);
      return liveValue;
    }
    final c = raw(key);
    if (c == null) return 0;
    if (c.age > freshWindow) return 0;
    return c.value;
  }

  /// True when what is on screen came from cache rather than live.
  bool isStale(String key, double liveValue) {
    if (liveValue > 0) return false;
    final c = raw(key);
    return c != null && c.age <= freshWindow;
  }

  /// "2m ago" for the stale badge, or null when live.
  String? staleLabel(String key, double liveValue) {
    if (liveValue > 0) return null;
    final c = raw(key);
    if (c == null || c.age > freshWindow) return null;
    return c.ageLabel;
  }

  /// Formatted blood pressure with cache fallback.
  String displayBloodPressure(int liveSys, int liveDia) {
    if (liveSys > 0 && liveDia > 0) {
      putPair('bp', liveSys, liveDia);
      return '$liveSys/$liveDia';
    }
    final s = raw('bp');
    final d = raw('bp_2');
    if (s == null || d == null) return '--/--';
    if (s.age > freshWindow) return '--/--';
    return '${s.value.round()}/${d.value.round()}';
  }

  /// Clear everything — call on explicit user disconnect / unpair, so
  /// a new wearer never sees the previous person's numbers.
  void clearAll() {
    _cache.clear();
    notifyListeners();
  }

  /// Keys currently held — handy for debugging.
  List<String> get keys => _cache.keys.toList();
}
