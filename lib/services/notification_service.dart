import 'dart:convert';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single scheduled reminder (hour + minute).
class ReminderTime {
  final int hour;
  final int minute;

  const ReminderTime({required this.hour, required this.minute});

  Map<String, int> toJson() => {'hour': hour, 'minute': minute};

  factory ReminderTime.fromJson(Map<String, dynamic> json) =>
      ReminderTime(hour: json['hour'] as int, minute: json['minute'] as int);

  String format24h() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => hour * 60 + minute;
}

// ── Top-level alarm callback ────────────────────────────────────────
// Runs in a separate isolate. Shows notification, then reschedules
// itself for tomorrow.

@pragma('vm:entry-point')
Future<void> _alarmCallback(int alarmId) async {
  // 1. Show the notification
  final notifications = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await notifications.initialize(initSettings);

  await notifications.show(
    alarmId,
    'Word Recall',
    'Time to review your words!',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_recall',
        'Daily Recall',
        channelDescription: 'Daily word recall reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        channelShowBadge: true,
        visibility: NotificationVisibility.public,
      ),
    ),
  );

  // 2. Reschedule for tomorrow
  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notification_enabled') ?? false;
    if (!enabled) return;

    final raw = prefs.getString('notification_reminders');
    if (raw == null) return;

    final reminders = (jsonDecode(raw) as List)
        .map((e) => ReminderTime.fromJson(e as Map<String, dynamic>))
        .toList();

    final index = alarmId - 100;
    if (index < 0 || index >= reminders.length) return;

    final r = reminders[index];
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final nextFire = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      r.hour,
      r.minute,
    );

    await AndroidAlarmManager.oneShotAt(
      nextFire,
      alarmId,
      _alarmCallback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );
    print('✓ Rescheduled alarm $alarmId for $nextFire');
  } catch (e) {
    print('✗ Error rescheduling alarm $alarmId: $e');
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _enabledKey = 'notification_enabled';
  static const String _remindersKey = 'notification_reminders';

  static const String _legacyHourKey = 'notification_hour';
  static const String _legacyMinuteKey = 'notification_minute';

  static int _alarmId(int index) => 100 + index;

  // ── Initialization ────────────────────────────────────────────────

  static Future<void> initialize() async {
    try {
      await AndroidAlarmManager.initialize();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {},
      );

      await _migrateLegacySettings();
      await _restoreScheduledNotifications();
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  static Future<void> _migrateLegacySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyHour = prefs.getInt(_legacyHourKey);
    final legacyMinute = prefs.getInt(_legacyMinuteKey);

    if (legacyHour != null && legacyMinute != null) {
      final existing = await getReminders();
      if (existing.isEmpty) {
        await _saveReminders([
          ReminderTime(hour: legacyHour, minute: legacyMinute),
        ]);
      }
      await prefs.remove(_legacyHourKey);
      await prefs.remove(_legacyMinuteKey);
    }
  }

  static Future<void> _restoreScheduledNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_enabledKey) ?? false;
    if (!isEnabled) return;

    final reminders = await getReminders();
    await _scheduleAll(reminders);
  }

  // ── Permissions ───────────────────────────────────────────────────

  static Future<bool> checkPermissions() async {
    try {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null) {
        return await androidImpl.areNotificationsEnabled() ?? false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestPermissions() async {
    try {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null) {
        await androidImpl.requestNotificationsPermission();
      }

      final iosImpl = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosImpl != null) {
        await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  // ── Debug / Test ──────────────────────────────────────────────────

  static Future<void> showTestNotification() async {
    await _notifications.show(
      999,
      'Test Notification',
      'If you see this, notifications work!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_recall',
          'Daily Recall',
          channelDescription: 'Daily word recall reminders',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  static Future<String> showScheduledTestNotification() async {
    try {
      final fireAt = DateTime.now().add(const Duration(seconds: 15));
      final success = await AndroidAlarmManager.oneShotAt(
        fireAt,
        998,
        _alarmCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
      );
      return success
          ? 'Alarm set for $fireAt\nWait ~15 seconds.'
          : 'AlarmManager returned false.';
    } catch (e) {
      return 'ERROR: $e';
    }
  }

  static Future<Map<String, dynamic>> debugInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    final reminders = await getReminders();
    final hasPermission = await checkPermissions();
    final now = DateTime.now();

    return {
      'now': now.toString(),
      'notificationsEnabled': enabled,
      'hasPermission': hasPermission,
      'remindersCount': reminders.length,
      'reminders': reminders.map((r) => r.format24h()).toList(),
      'nextFireTimes': reminders.map((r) {
        final next = _nextInstanceOfTime(r.hour, r.minute);
        return '${r.format24h()} → $next';
      }).toList(),
    };
  }

  // ── Public API ────────────────────────────────────────────────────

  static Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  static Future<List<ReminderTime>> getReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_remindersKey);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => ReminderTime.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> addReminder(ReminderTime time) async {
    final reminders = await getReminders();
    if (reminders.contains(time)) return;
    reminders.add(time);
    await _saveReminders(reminders);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);

    await _scheduleAll(reminders);
  }

  static Future<void> removeReminder(ReminderTime time) async {
    final reminders = await getReminders();
    final idx = reminders.indexOf(time);
    if (idx >= 0) {
      await AndroidAlarmManager.cancel(_alarmId(idx));
      reminders.removeAt(idx);
    }
    await _saveReminders(reminders);

    if (reminders.isEmpty) {
      await disableNotifications();
    } else {
      await _scheduleAll(reminders);
    }
  }

  static Future<void> updateReminder(
    ReminderTime oldTime,
    ReminderTime newTime,
  ) async {
    final reminders = await getReminders();
    final index = reminders.indexOf(oldTime);
    if (index >= 0) {
      reminders[index] = newTime;
    } else {
      reminders.add(newTime);
    }
    await _saveReminders(reminders);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);

    await _scheduleAll(reminders);
  }

  static Future<void> enableNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    final reminders = await getReminders();
    await _scheduleAll(reminders);
  }

  static Future<void> disableNotifications() async {
    await _cancelAllAlarms();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  static Future<void> cancelAllNotifications() async {
    await _cancelAllAlarms();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await prefs.remove(_remindersKey);
  }

  // ── Legacy compatibility ──────────────────────────────────────────

  static Future<Map<String, int>?> getSavedNotificationTime() async {
    final reminders = await getReminders();
    if (reminders.isEmpty) return null;
    return {'hour': reminders.first.hour, 'minute': reminders.first.minute};
  }

  static Future<void> scheduleDailyNotification({
    required int hour,
    required int minute,
  }) async {
    final newTime = ReminderTime(hour: hour, minute: minute);
    final reminders = await getReminders();

    if (reminders.isEmpty) {
      await addReminder(newTime);
    } else {
      await updateReminder(reminders.first, newTime);
    }
  }

  static Future<void> cancelDailyNotification() async {
    await disableNotifications();
  }

  // ── Internals ─────────────────────────────────────────────────────

  static Future<void> _saveReminders(List<ReminderTime> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(reminders.map((r) => r.toJson()).toList());
    await prefs.setString(_remindersKey, json);
  }

  static Future<void> _cancelAllAlarms() async {
    for (int i = 0; i < 5; i++) {
      await AndroidAlarmManager.cancel(_alarmId(i));
    }
    await AndroidAlarmManager.cancel(998);
  }

  /// Schedule all reminders using oneShotAt.
  /// Each alarm reschedules itself for the next day in _alarmCallback.
  static Future<void> _scheduleAll(List<ReminderTime> reminders) async {
    await _cancelAllAlarms();

    for (int i = 0; i < reminders.length; i++) {
      final r = reminders[i];
      final nextFire = _nextInstanceOfTime(r.hour, r.minute);

      try {
        final success = await AndroidAlarmManager.oneShotAt(
          nextFire,
          _alarmId(i),
          _alarmCallback,
          exact: true,
          wakeup: true,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
        );
        print(
          '${success ? "✓" : "✗"} Alarm ${_alarmId(i)} → ${r.format24h()} (fires $nextFire)',
        );
      } catch (e) {
        print('✗ Alarm ${_alarmId(i)} error: $e');
      }
    }
  }

  static DateTime _nextInstanceOfTime(int hour, int minute) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }
}
