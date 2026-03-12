import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../models/farm_task_model.dart';
import 'preferences_service.dart';

/// Service for communicating with the backend Farm Tasks API.
class FarmTaskService {
  static String get _baseUrl => '${AppConstants.baseApiUrl}/api/farm-tasks';

  static Future<Map<String, String>> get _headers async {
    final p = await preferencesService.prefs;
    final token = p.getString('jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch all tasks for a user
  static Future<List<FarmTask>> fetchTasks(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/$userId'), headers: await _headers)
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((j) => FarmTask.fromJson(j)).toList();
      }
      debugPrint('FarmTaskService.fetchTasks failed: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('FarmTaskService.fetchTasks error: $e');
      return [];
    }
  }

  /// Fetch today's tasks
  static Future<List<FarmTask>> fetchTodayTasks(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/$userId/today'), headers: await _headers)
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((j) => FarmTask.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('FarmTaskService.fetchTodayTasks error: $e');
      return [];
    }
  }

  /// Fetch upcoming tasks (next 24h) for notification scheduling
  static Future<List<FarmTask>> fetchUpcomingTasks(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/$userId/upcoming'), headers: await _headers)
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((j) => FarmTask.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('FarmTaskService.fetchUpcomingTasks error: $e');
      return [];
    }
  }

  /// Update task status (done / skipped / pending)
  static Future<FarmTask?> updateTaskStatus(
      String taskId, String status) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/$taskId/status'),
            headers: await _headers,
            body: json.encode({'status': status}),
          )
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        return FarmTask.fromJson(json.decode(response.body));
      }
      debugPrint(
          'FarmTaskService.updateTaskStatus failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('FarmTaskService.updateTaskStatus error: $e');
      return null;
    }
  }
}
