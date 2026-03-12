import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Web implementation for notifications.
class WebNotificationService {
  static Future<void> show(String title, String body, String payload) async {
    if (!kIsWeb) return;
    
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body, tag: payload);
      debugPrint('WebNotificationService: notification shown');
    } else if (html.Notification.permission != 'denied') {
      final permission = await html.Notification.requestPermission();
      if (permission == 'granted') {
        html.Notification(title, body: body, tag: payload);
        debugPrint('WebNotificationService: notification shown after permission');
      }
    } else {
      debugPrint('WebNotificationService: permission denied');
    }
  }
}
