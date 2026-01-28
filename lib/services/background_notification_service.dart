import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'dart:ui';

// Background callback - must be a top-level function
@pragma('vm:entry-point')
void checkDueWordsCallback() async {
  try {
    // This runs in background isolate
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // Check if notifications are enabled
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('notification_enabled') ?? false;

    if (!isEnabled) {
      return;
    }

    // Open database and check for due words
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'word_recall.sqlite'));

    if (!file.existsSync()) {
      return;
    }

    final db = sqlite3.open(file.path);

    try {
      // Query due words count
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final result = db.select(
        'SELECT COUNT(*) as count FROM recalls WHERE next_review <= ?',
        [now],
      );

      final dueCount = result.isNotEmpty ? result.first['count'] as int : 0;

      if (dueCount > 0) {
        // Check if we already notified today
        final lastNotificationDate = prefs.getString(
          'last_background_notification',
        );
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final todayString = today.toIso8601String().split('T')[0];

        if (lastNotificationDate != todayString) {
          // Send notification
          final notifications = FlutterLocalNotificationsPlugin();

          const androidSettings = AndroidInitializationSettings(
            '@mipmap/ic_launcher',
          );
          const initSettings = InitializationSettings(android: androidSettings);
          await notifications.initialize(initSettings);

          await notifications.show(
            999,
            'Word Recall',
            '$dueCount ${dueCount == 1 ? 'word' : 'words'} waiting for review! 📚',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'background_recall',
                'Background Recall',
                channelDescription: 'Background word recall reminders',
                importance: Importance.high,
                priority: Priority.high,
                playSound: true,
                enableVibration: true,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );

          // Mark that we sent notification today
          await prefs.setString('last_background_notification', todayString);
        }
      }
    } finally {
      db.dispose();
    }
  } catch (e) {
    print('Background check error: $e');
  }
}

class BackgroundNotificationService {
  static const int _alarmId = 0;

  static Future<void> initialize() async {
    await AndroidAlarmManager.initialize();
  }

  static Future<void> scheduleBackgroundCheck() async {
    // Cancel any existing alarms
    await AndroidAlarmManager.cancel(_alarmId);

    // Schedule periodic check every N hours
    // This will survive app restarts and device reboots
    await AndroidAlarmManager.periodic(
      const Duration(hours: 6),
      _alarmId,
      checkDueWordsCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  static Future<void> cancelBackgroundCheck() async {
    await AndroidAlarmManager.cancel(_alarmId);
  }
}
