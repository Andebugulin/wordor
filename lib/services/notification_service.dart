import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'background_notification_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _hourKey = 'notification_hour';
  static const String _minuteKey = 'notification_minute';
  static const String _notificationEnabledKey = 'notification_enabled';

  static Future<void> initialize() async {
    try {
      print('🔔 Initializing notification service...');
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

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          print('✅ Notification tapped: ${details.payload}');
        },
      );

      print('🔔 Notification plugin initialized: $initialized');

      // Initialize background notification service
      await BackgroundNotificationService.initialize();
      print('🔔 Background service initialized');

      // Check if notifications are enabled and restore saved time
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_notificationEnabledKey) ?? false;

      print('🔔 Notifications enabled: $isEnabled');

      if (isEnabled) {
        final hour = prefs.getInt(_hourKey);
        final minute = prefs.getInt(_minuteKey);

        if (hour != null && minute != null) {
          print('🔔 Restoring notification time: $hour:$minute');
          await scheduleDailyNotification(hour: hour, minute: minute);
        }
      }
    } catch (e, stack) {
      print('❌ Error initializing notifications: $e');
      print('Stack trace: $stack');
    }
  }

  static Future<bool> checkPermissions() async {
    try {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        final granted = await androidImplementation.areNotificationsEnabled();
        print('🔔 Android notifications enabled: $granted');
        return granted ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Error checking permissions: $e');
      return false;
    }
  }

  static Future<void> requestPermissions() async {
    try {
      print('🔔 Requesting notification permissions...');

      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        final notifResult = await androidImplementation
            .requestNotificationsPermission();
        print('🔔 Notification permission result: $notifResult');

        final alarmResult = await androidImplementation
            .requestExactAlarmsPermission();
        print('🔔 Exact alarm permission result: $alarmResult');
      }

      final iosImplementation = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      if (iosImplementation != null) {
        final result = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        print('🔔 iOS permissions result: $result');
      }
    } catch (e, stack) {
      print('❌ Error requesting permissions: $e');
      print('Stack trace: $stack');
    }
  }

  static Future<void> scheduleDailyNotification({
    required int hour,
    required int minute,
  }) async {
    try {
      print('🔔 Scheduling daily notification for $hour:$minute');

      // Save the time and enable notifications
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_hourKey, hour);
      await prefs.setInt(_minuteKey, minute);
      await prefs.setBool(_notificationEnabledKey, true);
      print('🔔 Saved notification settings');

      // Cancel any existing notifications first
      await _notifications.cancel(0);
      print('🔔 Cancelled existing notifications');

      final scheduledDate = _nextInstanceOfTime(hour, minute);

      print('🔔 Scheduling notification for: $scheduledDate');
      print('🔔 Current time: ${tz.TZDateTime.now(tz.local)}');

      await _notifications.zonedSchedule(
        0,
        'Word Recall',
        'Time to review your words! 📚',
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
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print('✅ Daily notification scheduled successfully!');

      // Schedule background checks
      try {
        await BackgroundNotificationService.scheduleBackgroundCheck();
        print('✅ Background check scheduled');
      } catch (e) {
        print('⚠️ Error scheduling background check: $e');
      }
    } catch (e, stack) {
      print('❌ Error scheduling daily notification: $e');
      print('Stack trace: $stack');
      rethrow;
    }
  }

  static Future<Map<String, int>?> getSavedNotificationTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hour = prefs.getInt(_hourKey);
      final minute = prefs.getInt(_minuteKey);

      if (hour != null && minute != null) {
        return {'hour': hour, 'minute': minute};
      }
      return null;
    } catch (e) {
      print('❌ Error getting saved notification time: $e');
      return null;
    }
  }

  static Future<bool> areNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_notificationEnabledKey) ?? false;
    } catch (e) {
      print('❌ Error checking notification status: $e');
      return false;
    }
  }

  static Future<void> showImmediateNotification(int dueCount) async {
    try {
      print('🔔 Attempting to show immediate notification for $dueCount words');

      // Check permissions first
      final hasPermission = await checkPermissions();
      print('🔔 Has notification permission: $hasPermission');

      if (!hasPermission) {
        print('⚠️ No notification permission - requesting...');
        await requestPermissions();
      }

      await _notifications.show(
        1,
        'Word Recall',
        '$dueCount ${dueCount == 1 ? 'word' : 'words'} waiting for review! 📖',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'immediate_recall',
            'Immediate Recall',
            channelDescription: 'Immediate word recall notifications',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            channelShowBadge: true,
            visibility: NotificationVisibility.public,
            ticker: 'Word Recall',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );

      print('✅ Immediate notification sent!');
    } catch (e, stack) {
      print('❌ Error showing immediate notification: $e');
      print('Stack trace: $stack');
    }
  }

  static Future<void> showDueWordsNotification(int dueCount) async {
    if (dueCount > 0) {
      await showImmediateNotification(dueCount);
    }
  }

  static Future<void> cancelAllNotifications() async {
    try {
      print('🔔 Cancelling all notifications');
      await _notifications.cancelAll();

      // Disable notifications in preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationEnabledKey, false);

      // Cancel background checks
      try {
        await BackgroundNotificationService.cancelBackgroundCheck();
        print('✅ Background check cancelled');
      } catch (e) {
        print('⚠️ Error canceling background check: $e');
      }

      print('✅ All notifications cancelled');
    } catch (e) {
      print('❌ Error canceling notifications: $e');
    }
  }

  static Future<void> cancelDailyNotification() async {
    try {
      print('🔔 Cancelling daily notification');
      await _notifications.cancel(0);

      // Disable notifications but keep the time saved
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationEnabledKey, false);

      // Cancel background checks
      try {
        await BackgroundNotificationService.cancelBackgroundCheck();
      } catch (e) {
        print('⚠️ Error canceling background check: $e');
      }

      print('✅ Daily notification cancelled');
    } catch (e) {
      print('❌ Error canceling daily notification: $e');
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

  static Future<void> checkAndNotifyDueWords(int dueCount) async {
    try {
      print('🔔 Checking due words: $dueCount');

      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_notificationEnabledKey) ?? false;

      print('🔔 Notifications enabled: $isEnabled');

      if (isEnabled && dueCount > 0) {
        final lastNotificationDate = prefs.getString('last_due_notification');
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        print('🔔 Last notification: $lastNotificationDate');
        print('🔔 Today: ${today.toIso8601String().split('T')[0]}');

        if (lastNotificationDate == null ||
            lastNotificationDate != today.toIso8601String().split('T')[0]) {
          print('🔔 Sending due words notification...');
          await showDueWordsNotification(dueCount);
          await prefs.setString(
            'last_due_notification',
            today.toIso8601String().split('T')[0],
          );
          print('✅ Due words notification sent');
        } else {
          print('ℹ️ Already notified today');
        }
      }
    } catch (e, stack) {
      print('❌ Error checking and notifying due words: $e');
      print('Stack trace: $stack');
    }
  }
}
