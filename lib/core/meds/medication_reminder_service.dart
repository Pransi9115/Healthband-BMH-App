// ─────────────────────────────────────────────────────────
//  MEDICATION REMINDERS
//
//  One repeating local notification per dose, per day. A medication
//  taken twice a day gets two reminders, not one — the whole point of
//  per-dose tracking is that the evening tablet is its own event.
//
//  Notification IDs are derived from the medication id and the dose
//  index, so rescheduling is idempotent: cancel by id, schedule again,
//  never accumulate duplicates.
//
//  PUBSPEC REQUIREMENT
//    flutter_local_notifications: ^17.2.2   (already present —
//                                            core/battery/battery_service.dart)
//    timezone: ^0.9.4                       (add this)
//
//  ANDROID MANIFEST
//    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
//    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
//    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
//
//  Everything here fails soft. If permission is refused or the platform
//  refuses an exact alarm, the schedule still shows in the app and the
//  patient can still tick doses by hand — they simply do not get a
//  buzz. A reminder that cannot fire must never break the screen.
// ─────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../bioresponse/medication_service.dart';

class MedicationReminderService {
  MedicationReminderService._();
  static final MedicationReminderService instance =
      MedicationReminderService._();

  // FlutterLocalNotificationsPlugin is a singleton, so this is the same
  // underlying instance BatteryService uses. That is fine — initialize
  // is idempotent and the last tap handler registered wins. This service
  // initialises after BatteryService in main(), and battery alerts do
  // not register a tap handler, so nothing is lost.
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _permitted = false;

  bool get isReady => _ready;
  bool get hasPermission => _permitted;

  /// Reminder notification ids live in their own block so they can
  /// never collide with the battery alerts already using this plugin.
  static const _idBase = 700000;

  static int _idFor(String medId, int doseIndex) {
    // Stable, bounded hash. Android notification ids must fit in int32.
    var h = 0;
    for (final unit in medId.codeUnits) {
      h = (h * 31 + unit) & 0x7fffff;
    }
    return _idBase + h * 8 + (doseIndex % 8);
  }

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true);

      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onTap);

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();

      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final iosGranted = await iosImpl?.requestPermissions(
        alert: true, badge: true, sound: true);

      _permitted = granted ?? iosGranted ?? true;
      _ready = true;
    } catch (e) {
      debugPrint('Medication reminders unavailable: $e');
      _ready = false;
      _permitted = false;
    }
  }

  /// Tapping a reminder marks that dose taken, which is the whole
  /// interaction most people want at 8 in the morning.
  static void _onTap(NotificationResponse r) {
    final payload = r.payload;
    if (payload == null || !payload.contains('#')) return;
    final parts = payload.split('#');
    if (parts.length != 2) return;
    final index = int.tryParse(parts[1]);
    if (index == null) return;
    MedicationService.instance
        .setDoseTaken(DateTime.now(), parts[0], index, true);
  }

  // ── SCHEDULING ──────────────────────────────────────────

  /// Rebuilds reminders for one medication: cancel everything it owns,
  /// then schedule only what it currently needs.
  Future<void> sync(Medication m) async {
    if (!_ready) await init();
    if (!_ready) return;

    for (var i = 0; i < 8; i++) {
      await _cancel(_idFor(m.id, i));
    }

    if (!m.remind || !m.active) return;
    if (m.endDate != null && m.endDate!.isBefore(DateTime.now())) return;

    final times = m.resolvedTimes;
    for (var i = 0; i < times.length; i++) {
      await _scheduleDaily(
        id: _idFor(m.id, i),
        hour: times[i] ~/ 60,
        minute: times[i] % 60,
        title: m.displayName,
        body: _bodyFor(m),
        payload: '${m.id}#$i');
    }
  }

  static String _bodyFor(Medication m) {
    final bits = <String>[];
    if (m.quantity.isNotEmpty) bits.add(m.quantity);
    if (m.dose.isNotEmpty) bits.add(m.dose);
    if (m.foodTiming != FoodTiming.anytime) {
      bits.add(m.foodTiming.label.toLowerCase());
    }
    if (m.withWater) bits.add('with water');
    return bits.isEmpty ? 'Time for your dose' : 'Time for ${bits.join(' · ')}';
  }

  /// Re-schedules everything. Called at startup so reminders survive a
  /// reinstall of the notification channel or a permission change.
  Future<void> syncAll() async {
    if (!_ready) await init();
    if (!_ready) return;
    for (final m in MedicationService.instance.all) {
      await sync(m);
    }
  }

  Future<void> cancelFor(String medId) async {
    if (!_ready) return;
    for (var i = 0; i < 8; i++) {
      await _cancel(_idFor(medId, i));
    }
  }

  Future<void> _cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {/* nothing scheduled under that id */}
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'bmh_medication_reminders',
          'Medication reminders',
          channelDescription: 'Reminds you when a dose is due',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentSound: true));

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOf(hour, minute),
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time);
    } catch (e) {
      // Exact alarms can be refused by the OS. Fall back to an inexact
      // schedule rather than losing the reminder entirely.
      debugPrint('Exact reminder refused, retrying inexact: $e');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          _nextInstanceOf(hour, minute),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'bmh_medication_reminders',
              'Medication reminders',
              importance: Importance.high,
              priority: Priority.high)),
         payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time);
      } catch (e2) {
        debugPrint('Reminder could not be scheduled: $e2');
      }
    }
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    return when;
  }
}
