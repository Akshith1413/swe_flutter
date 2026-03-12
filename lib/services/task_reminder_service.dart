import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../models/task_reminder_model.dart';
import 'preferences_service.dart';

/// Service for communicating with the backend Task Reminders API.
class TaskReminderService {
  static String get _baseUrl => '${AppConstants.baseApiUrl}/api/task-reminders';

  static Future<Map<String, String>> get _headers async {
    final p = await preferencesService.prefs;
    final token = p.getString('jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch all reminders for a user
  static Future<List<TaskReminder>> fetchReminders(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/$userId'), headers: await _headers)
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((j) => TaskReminder.fromJson(j)).toList();
      }
      debugPrint('TaskReminderService.fetchReminders failed: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('TaskReminderService.fetchReminders error: $e');
      return [];
    }
  }

  /// Fetch today's reminders
  static Future<List<TaskReminder>> fetchTodayReminders(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/$userId/today'), headers: await _headers)
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((j) => TaskReminder.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('TaskReminderService.fetchTodayReminders error: $e');
      return [];
    }
  }

  /// Fetch upcoming reminders (next 24h) for notification scheduling
  static Future<List<TaskReminder>> fetchUpcomingReminders(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/$userId/upcoming'), headers: await _headers)
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((j) => TaskReminder.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('TaskReminderService.fetchUpcomingReminders error: $e');
      return [];
    }
  }

  /// Update reminder status (done / skipped / pending / snoozed)
  static Future<TaskReminder?> updateReminderStatus(
    String reminderId, 
    String status, 
    {String completedFrom = 'app_screen'}
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/$reminderId/status'),
            headers: await _headers,
            body: json.encode({
              'status': status,
              'completedFrom': completedFrom,
            }),
          )
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        return TaskReminder.fromJson(json.decode(response.body));
      }
      debugPrint('TaskReminderService.updateStatus failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('TaskReminderService.updateStatus error: $e');
      return null;
    }
  }

  /// Mark notification as sent
  static Future<void> markNotificationSent(String reminderId, String type) async {
    try {
      await http
          .put(
            Uri.parse('$_baseUrl/$reminderId/notification'),
            headers: await _headers,
            body: json.encode({'type': type}),
          )
          .timeout(AppConstants.apiTimeout);
    } catch (e) {
      debugPrint('TaskReminderService.markNotificationSent error: $e');
    }
  }
}
