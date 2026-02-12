import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'dart:ui';

/// Background callback function that checks for due words and sends notifications
/// This function runs in a background isolate and must be a top-level function
@pragma('vm:entry-point')
void checkDueWordsCallback() async {
  try {
    // Initialize Flutter bindings for background isolate
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // Check if notifications are enabled in preferences
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('notification_enabled') ?? false;

    if (!isEnabled) {
      print('Background check: Notifications disabled, skipping');
      return;
    }

    // Open database and check for due words
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'word_recall.sqlite'));

    if (!file.existsSync()) {
      print('Background check: Database does not exist');
      return;
    }

    final db = sqlite3.open(file.path);

    try {
      // Query due words count using Unix timestamp
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final result = db.select(
        'SELECT COUNT(*) as count FROM recalls WHERE next_review <= ?',
        [now],
      );

      final dueCount = result.isNotEmpty ? result.first['count'] as int : 0;

      print('Background check: Found $dueCount due words');

      if (dueCount > 0) {
        // Check if we already notified today to avoid spam
        final lastNotificationDate = prefs.getString(
          'last_background_notification',
        );
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final todayString = today.toIso8601String().split('T')[0];

        if (lastNotificationDate != todayString) {
          // Initialize notifications plugin for background context
          final notifications = FlutterLocalNotificationsPlugin();

          const androidSettings = AndroidInitializationSettings(
            '@mipmap/ic_launcher',
          );
          const initSettings = InitializationSettings(android: androidSettings);
          await notifications.initialize(initSettings);

          // Send notification about due words
          await notifications.show(
            999,
            'Word Recall',
            '$dueCount ${dueCount == 1 ? 'word' : 'words'} waiting for review',
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
          print('Background check: Notification sent successfully');
        } else {
          print('Background check: Already notified today, skipping');
        }
      }
    } finally {
      db.dispose();
    }
  } catch (e, stackTrace) {
    print('Background check error: $e');
    print('Stack trace: $stackTrace');
  }
}

/// Service for managing background notification checks using AndroidAlarmManager
class BackgroundNotificationService {
  static const int _alarmId = 0;

  /// Initialize the Android Alarm Manager
  static Future<void> initialize() async {
    try {
      await AndroidAlarmManager.initialize();
      print('Background notification service initialized');
    } catch (e) {
      print('Failed to initialize background notification service: $e');
    }
  }

  /// Schedule periodic background checks for due words
  /// Runs every 6 hours and survives app restarts and device reboots
  static Future<void> scheduleBackgroundCheck() async {
    try {
      // Cancel any existing alarms first
      await AndroidAlarmManager.cancel(_alarmId);

      // Schedule periodic check every 6 hours
      // exact: true ensures it runs at the scheduled time
      // wakeup: true allows waking the device if needed
      // rescheduleOnReboot: true re-schedules after device restart
      await AndroidAlarmManager.periodic(
        const Duration(hours: 6),
        _alarmId,
        checkDueWordsCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      print('Background check scheduled successfully');
    } catch (e) {
      print('Failed to schedule background check: $e');
    }
  }

  /// Cancel all background notification checks
  static Future<void> cancelBackgroundCheck() async {
    try {
      await AndroidAlarmManager.cancel(_alarmId);
      print('Background check cancelled');
    } catch (e) {
      print('Failed to cancel background check: $e');
    }
  }
}
