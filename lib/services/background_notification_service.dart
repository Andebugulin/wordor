/// Background notification service.
///
/// All scheduling is now handled directly by [NotificationService]
/// using AndroidAlarmManager.periodic. This class is kept for
/// backwards compatibility so nothing breaks.
class BackgroundNotificationService {
  static Future<void> initialize() async {
    // No-op — AndroidAlarmManager.initialize() is called
    // in NotificationService.initialize()
  }

  static Future<void> scheduleBackgroundCheck() async {
    // No-op — scheduling is handled by NotificationService._scheduleAll()
  }

  static Future<void> cancelBackgroundCheck() async {
    // No-op — cancellation is handled by NotificationService._cancelAllAlarms()
  }
}
