// ─────────────────────────────────────────────────────────
//  BATTERY SERVICE
//  Singleton + ChangeNotifier, same pattern as BleService and
//  DietService, so it drops straight into the app.
//
//  What it does:
//   · Mirrors the phone's real battery level + charging state
//     (battery_plus), refreshed on every OS battery event and
//     on a 60-second poll as a safety net.
//   · At ≤ 25% and discharging → in-app alert (showLowBanner),
//     shown once per discharge cycle.
//   · At ≤ 20% and discharging → local notification to the
//     patient AND a single server call that fans out to their
//     saved carers (max 5). Edge-triggered: fires once, then
//     re-arms only after charging or climbing back above 40%.
//   · Carer contacts persist in SharedPreferences.
//
//  pubspec.yaml additions required:
//    battery_plus: ^6.0.2
//    flutter_local_notifications: ^17.2.2
//
//  Carer server endpoint (optional — feature degrades safely
//  to local-only alerts if unset):
//    flutter run --dart-define=BMH_NOTIFY_URL=https://your.server/notify_battery.php
// ─────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────
//  CARER CONTACT — someone notified when the battery runs low
// ─────────────────────────────────────────────────────────
class CarerContact {
  final String id;
  final String name;
  final String relation;   // e.g. Son, Daughter, Nurse
  final String phone;      // E.164 preferred, e.g. +9198…
  final String email;      // optional

  const CarerContact({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
    this.email = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relation': relation,
        'phone': phone,
        'email': email,
      };

  factory CarerContact.fromJson(Map<String, dynamic> j) => CarerContact(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        relation: j['relation'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        email: j['email'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────────────
class BatteryService extends ChangeNotifier {
  BatteryService._();
  static final BatteryService instance = BatteryService._();

  // Thresholds — single source of truth, referenced by the UI too.
  static const int warnAt   = 25;  // in-app alert
  static const int notifyAt = 20;  // patient notification + carers
  static const int rearmAt  = 40;  // climbing back past this re-arms alerts
  static const int maxCarers = 5;

  static const _kCarers = 'bmh_battery_carers';

  /// Server endpoint that fans out to carers (SMS / email / WhatsApp
  /// is the server's job). Left empty → carer step is skipped and the
  /// feature still works locally.
  static const _notifyUrl =
      String.fromEnvironment('BMH_NOTIFY_URL', defaultValue: '');

  final Battery _battery = Battery();
  final _notifications = FlutterLocalNotificationsPlugin();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  SharedPreferences? _prefs;
  StreamSubscription<BatteryState>? _stateSub;
  Timer? _poll;
  bool _ready = false;

  // ── Live state the UI reads ────────────────────────────
  int level = -1;                       // -1 until first read
  BatteryState state = BatteryState.unknown;
  bool get charging =>
      state == BatteryState.charging ||
      state == BatteryState.connectedNotCharging ||
      state == BatteryState.full;

  /// True while the in-app low-battery alert should be visible.
  bool showLowBanner = false;

  /// 'warn' (≤25) or 'notify' (≤20) — drives banner colour/wording.
  String bannerLevel = 'warn';

  DateTime? lastCarerAlertAt;           // shown in the alerts screen

  List<CarerContact> _carers = [];
  List<CarerContact> get carers => List.unmodifiable(_carers);

  // Once-per-discharge-cycle latches.
  bool _warned = false;
  bool _notified = false;

  bool get isReady => _ready;

  // ── INIT ───────────────────────────────────────────────
  Future<void> init() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();
    _loadCarers();

    await _initNotifications();

    // First read immediately so the profile shows a real number
    // the moment it opens.
    await _refresh();

    // OS battery events (plug/unplug, level buckets)…
    _stateSub = _battery.onBatteryStateChanged.listen((s) {
      state = s;
      _refresh();
    });
    // …plus a slow poll, since Android only streams *state* changes,
    // not every percentage tick.
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());

    _ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios));

    // Android 13+ needs runtime permission for notifications.
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── CORE LOOP ──────────────────────────────────────────
  Future<void> _refresh() async {
    try {
      level = await _battery.batteryLevel;
      state = await _battery.batteryState;
    } catch (_) {
      return; // emulator without battery info etc. — keep last values
    }
    _evaluate();
    notifyListeners();
  }

  void _evaluate() {
    // Charging, or recovered above the re-arm line → reset everything.
    if (charging || level >= rearmAt) {
      _warned = false;
      _notified = false;
      showLowBanner = false;
      return;
    }

    // ≤ 20%: patient notification + carer fan-out, once per cycle.
    if (level <= notifyAt && !_notified) {
      _notified = true;
      _warned = true;
      showLowBanner = true;
      bannerLevel = 'notify';
      _notifyPatient();
      _notifyCarers();
      return;
    }

    // ≤ 25%: in-app alert only, once per cycle.
    if (level <= warnAt && !_warned) {
      _warned = true;
      showLowBanner = true;
      bannerLevel = 'warn';
    }
  }

  /// Patient taps the X on the in-app banner.
  void dismissBanner() {
    showLowBanner = false;
    notifyListeners();
  }

  // ── PATIENT NOTIFICATION (local, works offline) ────────
  Future<void> _notifyPatient() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'bmh_battery', 'Battery alerts',
        channelDescription:
            'Warns when the phone battery is too low for health monitoring',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true, presentSound: true, presentBadge: true),
    );
    await _notifications.show(
      9001,
      'Battery low — $level%',
      'Please put your phone on charge so BioHealthcare can keep '
      'monitoring you. Your carers have been informed.',
      details,
    );
  }

  // ── CARER FAN-OUT (server does SMS/email/WhatsApp) ─────
  Future<void> _notifyCarers() async {
    if (_carers.isEmpty || _notifyUrl.isEmpty) return;
    try {
      final name = _prefs?.getString('profile_name') ?? 'BMH User';
      await _dio.post(_notifyUrl, data: jsonEncode({
        'type': 'battery_low',
        'patient_name': name,
        'level': level,
        'charging': charging,
        'threshold': notifyAt,
        'timestamp': DateTime.now().toIso8601String(),
        'contacts': _carers.map((c) => c.toJson()).toList(),
      }));
      lastCarerAlertAt = DateTime.now();
      notifyListeners();
    } catch (_) {
      // Offline / server down: the patient's local notification has
      // already fired, so the elder is still warned. The latch stays
      // set — no retry storm on a dying battery.
    }
  }

  /// "Send test alert" in the carer screen — verifies the whole
  /// pipeline without waiting for a real low battery.
  Future<bool> sendTestAlert() async {
    if (_carers.isEmpty || _notifyUrl.isEmpty) return false;
    try {
      final name = _prefs?.getString('profile_name') ?? 'BMH User';
      await _dio.post(_notifyUrl, data: jsonEncode({
        'type': 'battery_test',
        'patient_name': name,
        'level': level,
        'charging': charging,
        'timestamp': DateTime.now().toIso8601String(),
        'contacts': _carers.map((c) => c.toJson()).toList(),
      }));
      lastCarerAlertAt = DateTime.now();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── CARER CRUD (max 5) ─────────────────────────────────
  bool get canAddCarer => _carers.length < maxCarers;

  Future<bool> addCarer(CarerContact c) async {
    if (!canAddCarer) return false;
    _carers = [..._carers, c];
    await _saveCarers();
    notifyListeners();
    return true;
  }

  Future<void> updateCarer(CarerContact c) async {
    final i = _carers.indexWhere((e) => e.id == c.id);
    if (i < 0) return;
    _carers[i] = c;
    await _saveCarers();
    notifyListeners();
  }

  Future<void> removeCarer(String id) async {
    _carers = _carers.where((c) => c.id != id).toList();
    await _saveCarers();
    notifyListeners();
  }

  void _loadCarers() {
    final raw = _prefs?.getString(_kCarers);
    if (raw == null) return;
    try {
      _carers = (jsonDecode(raw) as List)
          .map((e) =>
              CarerContact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      _carers = [];
    }
  }

  Future<void> _saveCarers() async {
    await _prefs?.setString(
      _kCarers,
      jsonEncode(_carers.map((c) => c.toJson()).toList()),
    );
  }
}
