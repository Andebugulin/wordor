import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
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

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _enabledKey = 'notification_enabled';
  static const String _remindersKey = 'notification_reminders'; // JSON list

  // Legacy keys for migration
  static const String _legacyHourKey = 'notification_hour';
  static const String _legacyMinuteKey = 'notification_minute';

  // ── Initialization ────────────────────────────────────────────────

  static Future<void> initialize() async {
    try {
      tz.initializeTimeZones();

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
        onDidReceiveNotificationResponse: (details) {
          // Handle notification tap (could navigate to recall screen)
        },
      );

      // Migrate legacy single-time to new multi-time format
      await _migrateLegacySettings();

      // Restore scheduled notifications
      await _restoreScheduledNotifications();
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  /// Migrate old hour/minute prefs to the new reminders list.
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
      // Clean up legacy keys
      await prefs.remove(_legacyHourKey);
      await prefs.remove(_legacyMinuteKey);
    }
  }

  /// Re-schedule all saved reminders on cold start.
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
        await androidImpl.requestExactAlarmsPermission();
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

  // ── Public API ────────────────────────────────────────────────────

  /// Whether the user has turned reminders on.
  static Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// Get all configured reminder times.
  static Future<List<ReminderTime>> getReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_remindersKey);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => ReminderTime.fromJson(e as Map<String, dynamic>))
          .toList();
      // Sort by time of day
      list.sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Add a new reminder time. Schedules notification immediately.
  static Future<void> addReminder(ReminderTime time) async {
    final reminders = await getReminders();
    if (reminders.contains(time)) return; // duplicate guard
    reminders.add(time);
    await _saveReminders(reminders);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);

    await _scheduleAll(reminders);
  }

  /// Remove a specific reminder time.
  static Future<void> removeReminder(ReminderTime time) async {
    final reminders = await getReminders();
    reminders.remove(time);
    await _saveReminders(reminders);

    if (reminders.isEmpty) {
      await disableNotifications();
    } else {
      // Re-schedule remaining
      await _scheduleAll(reminders);
    }
  }

  /// Replace an existing reminder with a new time.
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

  /// Enable notifications and schedule all saved reminders.
  static Future<void> enableNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    final reminders = await getReminders();
    await _scheduleAll(reminders);
  }

  /// Cancel everything and mark as disabled.
  static Future<void> disableNotifications() async {
    await _notifications.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  /// Cancel all and clear stored reminders completely.
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await prefs.remove(_remindersKey);
  }

  // ── Legacy compatibility helpers (used by settings_screen) ────────

  /// Get saved notification time (returns first reminder for backwards compat).
  static Future<Map<String, int>?> getSavedNotificationTime() async {
    final reminders = await getReminders();
    if (reminders.isEmpty) return null;
    return {'hour': reminders.first.hour, 'minute': reminders.first.minute};
  }

  /// Schedule a single daily notification (adds/replaces the first reminder).
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

  /// Cancel the daily notification (disables everything).
  static Future<void> cancelDailyNotification() async {
    await disableNotifications();
  }

  // ── Internals ─────────────────────────────────────────────────────

  static Future<void> _saveReminders(List<ReminderTime> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(reminders.map((r) => r.toJson()).toList());
    await prefs.setString(_remindersKey, json);
  }

  /// Cancel all pending and re-schedule from scratch.
  static Future<void> _scheduleAll(List<ReminderTime> reminders) async {
    await _notifications.cancelAll();

    for (int i = 0; i < reminders.length; i++) {
      final r = reminders[i];
      final scheduledDate = _nextInstanceOfTime(r.hour, r.minute);

      await _notifications.zonedSchedule(
        i, // unique ID per reminder slot
        'Word Recall',
        'Time to review your words',
        scheduledDate,
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
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeats daily
      );
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}
