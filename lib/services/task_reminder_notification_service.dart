import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/task_reminder_model.dart';
import 'task_reminder_service.dart';
import 'notification_pause_service.dart';
import 'preferences_service.dart';
import 'farm_task_notification_service.dart';
import 'web_notification_service.dart';
import 'audio_service.dart';

/// Service for scheduling local push notifications for task reminders.
///
/// Reuses the shared FlutterLocalNotificationsPlugin from FarmTaskNotificationService
/// to avoid callback overwrites (only one initialize() call is allowed).
///
/// Schedules 3 notifications per reminder:
/// - 10 minutes before
/// - 5 minutes before
/// - At the scheduled time
///
/// When tapped, shows a Done/Not-Done popup that syncs back to web in real-time.
class TaskReminderNotificationService {
  /// Reuse the same plugin instance from FarmTaskNotificationService
  static FlutterLocalNotificationsPlugin get _plugin =>
      FarmTaskNotificationService.plugin;

  static Function(String reminderId)? onNotificationTapped;
  static String? _pendingReminderId;

  /// Set the pending reminder ID (called from the unified notification handler)
  static void setPendingReminderId(String? payload) {
    _pendingReminderId = payload;
  }

  /// No-op initializer — plugin is initialized once in FarmTaskNotificationService
  static Future<void> initialize() async {
    // Plugin is already initialized by FarmTaskNotificationService in main()
    debugPrint('TaskReminderNotificationService ready (shared plugin)');
  }

  /// Check if there's a pending notification tap to handle
  static String? checkPendingNotification() {
    // First check our local state (for backward compat)
    if (_pendingReminderId != null) {
      final pending = _pendingReminderId;
      _pendingReminderId = null;
      return pending;
    }
    // Then check the unified handler in FarmTaskNotificationService
    return FarmTaskNotificationService.checkPendingReminderNotification();
  }

  /// Schedule all 3 notifications for a single reminder
  static Future<void> scheduleReminderNotifications(TaskReminder reminder) async {
    final isPaused = await NotificationPauseService.isPaused();
    if (isPaused) return;

    final scheduledTime = reminder.scheduledAt;
    final now = DateTime.now();

    final weatherNote = reminder.weatherDependent ? ' 🌤️ Check weather!' : '';
    final messageBody = reminder.message.isNotEmpty
        ? reminder.message
        : '${reminder.taskTypeLabel} ${reminder.cropName.isNotEmpty ? "- ${reminder.cropName}" : ""}';

    // 10 minutes before
    final tenMinBefore = scheduledTime.subtract(const Duration(minutes: 10));
    // 5 minutes before
    final fiveMinBefore = scheduledTime.subtract(const Duration(minutes: 5));

    if (kIsWeb) {
      // For web, use Timers for in-app scheduling since local_notifications doesn't support web scheduling
      _scheduleWebTimer(reminder.id, tenMinBefore, '⏰ In 10 min: ${reminder.title}', '$messageBody$weatherNote');
      _scheduleWebTimer(reminder.id, fiveMinBefore, '⚡ In 5 min: ${reminder.title}', '$messageBody$weatherNote');
      _scheduleWebTimer(reminder.id, scheduledTime, '🌾 Time now: ${reminder.title}', '$messageBody — Tap to mark as done!$weatherNote');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'task_reminder_channel',
      'Task Reminders',
      channelDescription: 'Notifications for scheduled task reminders from web calendar',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      showWhen: true,
      category: AndroidNotificationCategory.reminder,
      fullScreenIntent: true,
    );

    const notifDetails = NotificationDetails(android: androidDetails);

    final baseId = (reminder.id.hashCode.abs() % 50000) + 50000;

    // Schedule 10 minutes before
    if (tenMinBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        baseId,
        '⏰ In 10 min: ${reminder.title}',
        '$messageBody$weatherNote',
        tz.TZDateTime.from(tenMinBefore, tz.local),
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'reminder:${reminder.id}',
      );
    }

    // Schedule 5 minutes before
    if (fiveMinBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        baseId + 1,
        '⚡ In 5 min: ${reminder.title}',
        '$messageBody$weatherNote',
        tz.TZDateTime.from(fiveMinBefore, tz.local),
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'reminder:${reminder.id}',
      );
    }

    // Schedule at exact time
    if (scheduledTime.isAfter(now)) {
      await _plugin.zonedSchedule(
        baseId + 2,
        '🌾 Time now: ${reminder.title}',
        '$messageBody — Tap to mark as done!$weatherNote',
        tz.TZDateTime.from(scheduledTime, tz.local),
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'reminder:${reminder.id}',
      );
    }

    debugPrint('Scheduled reminder notifications for: ${reminder.title} at ${reminder.time}');
  }

  static final Map<String, Timer?> _webTimers = {};

  static void _scheduleWebTimer(String id, DateTime time, String title, String body) {
    if (!kIsWeb) return;
    final now = DateTime.now();
    if (time.isAfter(now)) {
      final delay = time.difference(now);
      final timerKey = '${id}_$title';
      _webTimers[timerKey]?.cancel();
      _webTimers[timerKey] = Timer(delay, () {
        WebNotificationService.show(title, body, 'reminder:$id');
        audioService.playSound('soft_alert');
      });
    }
  }

  /// Cancel all notifications for a reminder
  static Future<void> cancelReminderNotifications(String reminderId) async {
    final baseId = (reminderId.hashCode.abs() % 50000) + 50000;
    await _plugin.cancel(baseId);
    await _plugin.cancel(baseId + 1);
    await _plugin.cancel(baseId + 2);
  }

  /// Refresh & schedule notifications for all upcoming reminders
  static Future<void> refreshAllReminderNotifications() async {
    final userId = await preferencesService.getUserId();
    debugPrint('refreshAllReminderNotifications: userId=$userId');
    if (userId == null || userId.isEmpty) return;

    try {
      final upcoming = await TaskReminderService.fetchUpcomingReminders(userId);
      debugPrint('refreshAllReminderNotifications: ${upcoming.length} upcoming');
      
      for (final reminder in upcoming) {
        if (reminder.isPending) {
          await scheduleReminderNotifications(reminder);
        }
      }
    } catch (e) {
      debugPrint('Error refreshing reminder notifications: $e');
    }
  }
}
