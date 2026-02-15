import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

/// Background notification service.
///
/// The primary daily notifications are handled by
/// [NotificationService.scheduleDailyNotification] using the OS-level
/// `zonedSchedule` + `matchDateTimeComponents`, which repeats reliably
/// without needing AlarmManager.
///
/// This service is kept as a minimal wrapper so existing code that
/// references [BackgroundNotificationService] still compiles.
class BackgroundNotificationService {
  /// Initialize the Android Alarm Manager (no-op if not needed).
  static Future<void> initialize() async {
    try {
      await AndroidAlarmManager.initialize();
    } catch (e) {
      // Non-critical — daily notifications work without this.
      print('Background service init skipped: $e');
    }
  }

  /// Schedule background check — currently a no-op because the OS-level
  /// zonedSchedule handles repeating daily notifications.
  static Future<void> scheduleBackgroundCheck() async {
    // Intentionally empty.
    // Notifications are scheduled via flutter_local_notifications
    // zonedSchedule with DateTimeComponents.time (repeats daily).
  }

  /// Cancel background check.
  static Future<void> cancelBackgroundCheck() async {
    try {
      await AndroidAlarmManager.cancel(0);
    } catch (_) {}
  }
}
