import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/constants/app_constants.dart';

/// Real-time socket service for receiving live updates from backend.
/// Uses Socket.IO to listen for reminder status changes, etc.
class SocketService {
  static SocketService? _instance;
  static SocketService get instance => _instance ??= SocketService._();
  SocketService._();

  io.Socket? _socket;
  String? _currentUserId;

  // Stream controllers for various events
  final _reminderStatusChanged = StreamController<Map<String, dynamic>>.broadcast();
  final _reminderCreated = StreamController<Map<String, dynamic>>.broadcast();
  final _reminderDeleted = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of reminder status changes (from web or other devices)
  Stream<Map<String, dynamic>> get onReminderStatusChanged => _reminderStatusChanged.stream;
  Stream<Map<String, dynamic>> get onReminderCreated => _reminderCreated.stream;
  Stream<Map<String, dynamic>> get onReminderDeleted => _reminderDeleted.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Connect to the Socket.IO server and join the user room
  void connect(String userId) {
    if (_socket?.connected == true && _currentUserId == userId) return;

    // Disconnect existing connection if any
    disconnect();

    _currentUserId = userId;

    _socket = io.io(
      AppConstants.baseApiUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('✓ Socket connected: ${_socket!.id}');
      _socket!.emit('join', userId);
    });

    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
    });

    _socket!.onConnectError((err) {
      debugPrint('Socket connection error: $err');
    });

    // Listen for real-time events
    _socket!.on('reminder:statusChanged', (data) {
      debugPrint('Socket: reminder:statusChanged → $data');
      if (data is Map<String, dynamic>) {
        _reminderStatusChanged.add(data);
      }
    });

    _socket!.on('reminder:created', (data) {
      debugPrint('Socket: reminder:created');
      if (data is Map<String, dynamic>) {
        _reminderCreated.add(data);
      }
    });

    _socket!.on('reminder:deleted', (data) {
      debugPrint('Socket: reminder:deleted');
      if (data is Map<String, dynamic>) {
        _reminderDeleted.add(data);
      }
    });

    _socket!.on('reminder:deletedAll', (data) {
      debugPrint('Socket: reminder:deletedAll');
      if (data is Map<String, dynamic>) {
        _reminderDeleted.add(data);
      }
    });

    _socket!.on('reminder:updated', (data) {
      debugPrint('Socket: reminder:updated');
      if (data is Map<String, dynamic>) {
        _reminderCreated.add(data); // Reuse created stream to trigger reload
      }
    });
  }

  /// Disconnect from the server
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _currentUserId = null;
  }

  /// Clean up resources
  void dispose() {
    disconnect();
    _reminderStatusChanged.close();
    _reminderCreated.close();
    _reminderDeleted.close();
  }
}
