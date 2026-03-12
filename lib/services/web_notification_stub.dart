import 'package:flutter/foundation.dart';

/// Stub implementation for web notifications on non-web platforms.
class WebNotificationService {
  static Future<void> show(String title, String body, String payload) async {
    debugPrint('WebNotificationService: Notification skipped (non-web platform)');
  }
}
