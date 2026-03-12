import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_reminder_model.dart';
import '../services/task_reminder_service.dart';
import '../services/task_reminder_notification_service.dart';
import '../services/socket_service.dart';
import '../services/preferences_service.dart';
import '../widgets/reminder_completion_dialog.dart';

/// Screen displaying task reminders with real-time sync from web.
/// Farmers see reminders created from the web calendar, get notifications,
/// and can mark them as done/skipped which syncs back in real-time.
class RemindersScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const RemindersScreen({super.key, this.onBack});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with WidgetsBindingObserver {
  List<TaskReminder> _reminders = [];
  bool _loading = true;
  Timer? _refreshTimer;
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReminders();

    // Auto-refresh every 5 seconds for near-real-time sync
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadReminders(silent: true),
    );

    // Check for pending notification taps
    _checkPendingNotification();

    // Listen for real-time updates via Socket.IO
    _setupSocketListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadReminders(silent: true);
      _checkPendingNotification();
    }
  }

  void _setupSocketListeners() {
    final socket = SocketService.instance;

    // When a reminder status changes from web
    _subscriptions.add(
      socket.onReminderStatusChanged.listen((data) {
        final reminderId = data['reminderId']?.toString();
        final status = data['status']?.toString();
        if (reminderId != null && status != null && mounted) {
          setState(() {
            _reminders = _reminders.map((r) {
              if (r.id == reminderId) {
                return r.copyWith(
                  status: status,
                  completedFrom: data['completedFrom']?.toString(),
                );
              }
              return r;
            }).toList();
          });
        }
      }),
    );

    // When new reminders are created from web
    _subscriptions.add(
      socket.onReminderCreated.listen((_) => _loadReminders(silent: true)),
    );

    // When reminders are deleted from web
    _subscriptions.add(
      socket.onReminderDeleted.listen((_) => _loadReminders(silent: true)),
    );
  }

  Future<void> _checkPendingNotification() async {
    final payload =
        TaskReminderNotificationService.checkPendingNotification();
    if (payload != null && payload.startsWith('reminder:') && mounted) {
      final reminderId = payload.replaceFirst('reminder:', '');
      await _loadReminders();
      final reminder = _reminders.where((r) => r.id == reminderId).firstOrNull;
      if (reminder != null && mounted) {
        ReminderCompletionDialog.show(
          context,
          reminder: reminder,
          onStatusChanged: () => _loadReminders(),
          completedFrom: 'app_notification',
        );
      }
    }
  }

  Future<void> _loadReminders({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);

    final userId = await preferencesService.getUserId();
    debugPrint('RemindersScreen: loading reminders for userId=$userId');
    if (userId == null || userId.isEmpty) {
      debugPrint('RemindersScreen: no userId, skipping load');
      if (mounted) setState(() => _loading = false);
      return;
    }

    final reminders = await TaskReminderService.fetchReminders(userId);
    debugPrint('RemindersScreen: fetched ${reminders.length} reminders');
    if (mounted) {
      setState(() {
        _reminders = reminders;
        _loading = false;
      });
    }

    // Schedule notifications for upcoming reminders
    await TaskReminderNotificationService.refreshAllReminderNotifications();
  }

  void _showCompletionDialog(TaskReminder reminder) {
    ReminderCompletionDialog.show(
      context,
      reminder: reminder,
      onStatusChanged: () => _loadReminders(),
      completedFrom: 'app_screen',
    );
  }

  // Group reminders by date
  Map<String, List<TaskReminder>> get _groupedReminders {
    final Map<String, List<TaskReminder>> groups = {};
    for (final reminder in _reminders) {
      final dateKey = _formatDate(reminder.date);
      groups.putIfAbsent(dateKey, () => []).add(reminder);
    }
    return groups;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(date.year, date.month, date.day);

    if (reminderDate == today) return '📅 Today';
    if (reminderDate == today.add(const Duration(days: 1))) {
      return '📅 Tomorrow';
    }
    if (reminderDate == today.subtract(const Duration(days: 1))) {
      return '📅 Yesterday';
    }

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '📅 ${date.day} ${months[date.month - 1]} ${date.year}';
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: widget.onBack,
              )
            : null,
        title: const Row(
          children: [
            Text('🔔', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text(
              'Reminders',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: () => _loadReminders(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => _loadReminders(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _groupedReminders.length,
                    itemBuilder: (context, index) {
                      final entry = _groupedReminders.entries.toList()[index];
                      return _buildDateGroup(entry.key, entry.value);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No reminders yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reminders are created from the web calendar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildDateGroup(String dateLabel, List<TaskReminder> reminders) {
    final pendingCount = reminders.where((r) => r.isPending).length;
    final doneCount = reminders.where((r) => r.isDone).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const Spacer(),
              if (pendingCount > 0)
                _buildCountBadge('$pendingCount pending', Colors.orange),
              const SizedBox(width: 6),
              if (doneCount > 0)
                _buildCountBadge('$doneCount done', Colors.green),
            ],
          ),
        ),
        ...reminders.map((reminder) => _buildReminderCard(reminder)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCountBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildReminderCard(TaskReminder reminder) {
    final priorityColor = Color(reminder.priorityColorValue);
    final isDone = reminder.isDone;
    final isSkipped = reminder.isSkipped;
    final opacity = (isDone || isSkipped) ? 0.6 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDone
                ? Colors.green.withValues(alpha: 0.3)
                : priorityColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: reminder.isPending
              ? () => _showCompletionDialog(reminder)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDone
                            ? Colors.green.withValues(alpha: 0.1)
                            : priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          isDone
                              ? '✅'
                              : (isSkipped
                                  ? '⏭️'
                                  : _getEmoji(reminder.taskType)),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Reminder details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reminder.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration:
                                  isDone ? TextDecoration.lineThrough : null,
                              color: isDone ? Colors.grey : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildChip('🕐 ${reminder.time}', Colors.indigo),
                              if (reminder.cropName.isNotEmpty)
                                _buildChip(
                                    '🌱 ${reminder.cropName}', Colors.green),
                              _buildChip(
                                reminder.priority.toUpperCase(),
                                priorityColor,
                              ),
                              if (reminder.isRecurring)
                                _buildChip(
                                    '🔁 ${reminder.recurrencePattern}',
                                    Colors.purple),
                              if (reminder.weatherDependent)
                                _buildChip('🌤️ Weather', Colors.blue),
                              if (reminder.estimatedDuration != null)
                                _buildChip(
                                    '⏱️ ${reminder.estimatedDuration}min',
                                    Colors.teal),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tap indicator
                    if (reminder.isPending)
                      const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),

                // Show message if present
                if (reminder.message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reminder.message,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Show completion source
                if (reminder.completedFrom != null && isDone) ...[
                  const SizedBox(height: 6),
                  Text(
                    _getCompletedFromLabel(reminder.completedFrom!),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  String _getEmoji(String type) {
    const emojis = {
      'watering': '💧',
      'fertilizer': '🧪',
      'pesticide': '🛡️',
      'harvest': '🌾',
      'sowing': '🌱',
      'pruning': '✂️',
      'soil_testing': '🔬',
      'irrigation_check': '🚿',
      'weeding': '🌿',
      'mulching': '🍂',
      'market_visit': '🏪',
      'equipment_maintenance': '🔧',
      'weather_check': '🌤️',
      'seed_purchase': '🛒',
      'other': '📋',
    };
    return emojis[type] ?? '📋';
  }

  String _getCompletedFromLabel(String from) {
    switch (from) {
      case 'app_notification':
        return '✓ Completed via notification';
      case 'app_screen':
        return '✓ Completed from app';
      case 'web':
        return '✓ Completed from web dashboard';
      default:
        return '';
    }
  }
}
