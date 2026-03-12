/// Unified service for web notifications with platform-specific implementations.
/// Uses conditional exports to provide the correct implementation at compile-time.
export 'web_notification_stub.dart'
    if (dart.library.html) 'web_notification_web.dart';
