import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/farm_task_model.dart';
import 'farm_task_service.dart';
import 'notification_pause_service.dart';
import 'preferences_service.dart';

/// Unified callback for ALL notification taps — routes by payload prefix.
@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse response) {
  final payload = response.payload ?? '';
  if (payload.startsWith('reminder:')) {
    // Reminder notification — forward to TaskReminderNotificationService
    // Import can't reference the class here (top-level function),
    // so store in both places for safety
    _FarmTaskNotificationService._pendingPayload = payload;
    debugPrint('Reminder notification tapped with payload: $payload');
  } else {
    // Farm task notification
    _FarmTaskNotificationService._pendingPayload = payload;
    debugPrint('Farm task notification tapped with payload: $payload');
  }
}

/// Service for scheduling local push notifications for farm tasks.
///
/// Also owns the shared FlutterLocalNotificationsPlugin used by both
/// farm task and reminder notification services.
class FarmTaskNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Expose the shared plugin so TaskReminderNotificationService can reuse it
  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static bool _initialized = false;
  static Function(String taskId)? onNotificationTapped;

  /// Initialize the notification plugin
  static Future<void> initialize() async {
    if (_initialized) return;

    // flutter_local_notifications doesn't support web
    if (kIsWeb) {
      _initialized = true;
      debugPrint('FarmTaskNotificationService: skipped init (web platform)');
      return;
    }

    // Initialize timezone
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('FarmTaskNotificationService initialized');
  }

  /// Check if there's a pending notification tap to handle (farm task only)
  static String? checkPendingNotification() {
    final pending = _FarmTaskNotificationService._pendingPayload;
    if (pending != null && !pending.startsWith('reminder:')) {
      _FarmTaskNotificationService._pendingPayload = null;
      return pending;
    }
    return null;
  }

  /// Check if there's a pending reminder notification tap
  static String? checkPendingReminderNotification() {
    final pending = _FarmTaskNotificationService._pendingPayload;
    if (pending != null && pending.startsWith('reminder:')) {
      _FarmTaskNotificationService._pendingPayload = null;
      return pending;
    }
    return null;
  }

  /// Schedule all 3 notifications for a single task
  static Future<void> scheduleTaskNotifications(FarmTask task) async {
    if (kIsWeb) return; // Notifications not supported on web
    if (!_initialized) await initialize();

    // Check if notifications are paused
    final isPaused = await NotificationPauseService.isPaused();
    if (isPaused) return;

    final scheduledTime = task.scheduledAt;
    final now = DateTime.now();

    // Notification channel details
    const androidDetails = AndroidNotificationDetails(
      'farm_task_channel',
      'Farm Task Reminders',
      channelDescription: 'Notifications for scheduled farm tasks',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      showWhen: true,
      category: AndroidNotificationCategory.reminder,
    );

    const notifDetails = NotificationDetails(android: androidDetails);

    // Generate unique IDs per task (use hashCode as base)
    // Range: 0–49999 (reminders use 50000–99999)
    final baseId = task.id.hashCode.abs() % 50000;

    // Schedule 10 minutes before
    final tenMinBefore = scheduledTime.subtract(const Duration(minutes: 10));
    if (tenMinBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        baseId,
        '⏰ In 10 min: ${task.title}',
        '${task.taskTypeLabel} ${task.cropName.isNotEmpty ? "- ${task.cropName}" : ""} at ${task.time}',
        tz.TZDateTime.from(tenMinBefore, tz.local),
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: task.id,
      );
    }

    // Schedule 5 minutes before
    final fiveMinBefore = scheduledTime.subtract(const Duration(minutes: 5));
    if (fiveMinBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        baseId + 1,
        '⚡ In 5 min: ${task.title}',
        '${task.taskTypeLabel} ${task.cropName.isNotEmpty ? "- ${task.cropName}" : ""} at ${task.time}',
        tz.TZDateTime.from(fiveMinBefore, tz.local),
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: task.id,
      );
    }

    // Schedule at exact time
    if (scheduledTime.isAfter(now)) {
      await _plugin.zonedSchedule(
        baseId + 2,
        '🌾 Time now: ${task.title}',
        '${task.taskTypeLabel} ${task.cropName.isNotEmpty ? "- ${task.cropName}" : ""} — Tap to mark as done!',
        tz.TZDateTime.from(scheduledTime, tz.local),
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: task.id,
      );
    }

    debugPrint('Scheduled notifications for task: ${task.title} at ${task.time}');
  }

  /// Cancel all notifications for a task
  static Future<void> cancelTaskNotifications(String taskId) async {
    if (kIsWeb) return;
    final baseId = taskId.hashCode.abs() % 50000;
    await _plugin.cancel(baseId);
    await _plugin.cancel(baseId + 1);
    await _plugin.cancel(baseId + 2);
  }

  /// Refresh & schedule notifications for all upcoming tasks
  static Future<void> refreshAllNotifications() async {
    final userId = await preferencesService.getUserId();
    if (userId == null || userId.isEmpty) return;

    try {
      final upcomingTasks = await FarmTaskService.fetchUpcomingTasks(userId);

      // Cancel existing farm task notifications (not reminders)
      for (final task in upcomingTasks) {
        await cancelTaskNotifications(task.id);
      }

      // Re-schedule pending ones
      for (final task in upcomingTasks) {
        if (task.isPending) {
          await scheduleTaskNotifications(task);
        }
      }
      debugPrint(
          'Refreshed notifications: ${upcomingTasks.length} upcoming tasks');
    } catch (e) {
      debugPrint('Error refreshing notifications: $e');
    }
  }
}

/// Internal helper for storing pending notification taps (unified for all types).
class _FarmTaskNotificationService {
  static String? _pendingPayload;
}
