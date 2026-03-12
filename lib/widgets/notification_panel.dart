import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_reminder_model.dart';
import '../services/task_reminder_service.dart';
import '../services/task_reminder_notification_service.dart';
import '../services/socket_service.dart';
import '../services/preferences_service.dart';
import '../widgets/reminder_completion_dialog.dart';

/// A dropdown notification panel that slides down from the bell icon.
/// Shows pending + today's reminders with inline Done/Skip actions.
class NotificationPanel extends StatefulWidget {
  final VoidCallback? onClose;
  final VoidCallback? onViewAll;

  const NotificationPanel({
    super.key,
    this.onClose,
    this.onViewAll,
  });

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel>
    with SingleTickerProviderStateMixin {
  List<TaskReminder> _reminders = [];
  bool _loading = true;
  Timer? _refreshTimer;
  final List<StreamSubscription> _subscriptions = [];
  late AnimationController _animController;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<double>(begin: -20, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();

    _loadReminders();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadReminders(silent: true),
    );
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _animController.dispose();
    _refreshTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _setupSocketListeners() {
    final socket = SocketService.instance;
    _subscriptions.add(
      socket.onReminderStatusChanged.listen((_) => _loadReminders(silent: true)),
    );
    _subscriptions.add(
      socket.onReminderCreated.listen((_) => _loadReminders(silent: true)),
    );
    _subscriptions.add(
      socket.onReminderDeleted.listen((_) => _loadReminders(silent: true)),
    );
  }

  Future<void> _loadReminders({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);

    final userId = await preferencesService.getUserId();
    if (userId == null || userId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Fetch today's reminders for the dropdown
    final reminders = await TaskReminderService.fetchTodayReminders(userId);
    if (mounted) {
      setState(() {
        _reminders = reminders;
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(TaskReminder reminder, String status) async {
    final result = await TaskReminderService.updateReminderStatus(
      reminder.id,
      status,
      completedFrom: 'app_screen',
    );
    if (result != null) {
      _loadReminders(silent: true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update. Check connection.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFullDialog(TaskReminder reminder) {
    ReminderCompletionDialog.show(
      context,
      reminder: reminder,
      onStatusChanged: () => _loadReminders(silent: true),
      completedFrom: 'app_screen',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingReminders = _reminders.where((r) => r.isPending).toList();
    final doneReminders = _reminders.where((r) => r.isDone || r.isSkipped).toList();

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) => Opacity(
        opacity: _fadeAnim.value,
        child: Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Today's Tasks",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (pendingReminders.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pendingReminders.length} pending',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Content
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              else if (_reminders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  child: Column(
                    children: [
                      const Text('🔔', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      Text(
                        'No tasks for today',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create reminders from the web calendar',
                        style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    children: [
                      // Pending reminders first
                      ...pendingReminders.map((r) => _buildReminderTile(r)),
                      // Done/skipped reminders
                      if (doneReminders.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[400],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...doneReminders.map((r) => _buildReminderTile(r)),
                      ],
                    ],
                  ),
                ),

              // Footer actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade100),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // TextButton.icon for Link Web removed
                    TextButton.icon(
                      onPressed: widget.onViewAll,
                      icon: const Icon(Icons.list, size: 16),
                      label: const Text('View All', style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderTile(TaskReminder reminder) {
    final isDone = reminder.isDone;
    final isSkipped = reminder.isSkipped;
    final isComplete = isDone || isSkipped;
    final priorityColor = Color(reminder.priorityColorValue);

    return Opacity(
      opacity: isComplete ? 0.5 : 1.0,
      child: InkWell(
        onTap: reminder.isPending ? () => _showFullDialog(reminder) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isComplete
                ? Colors.grey.shade50
                : priorityColor.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isComplete
                  ? Colors.grey.shade200
                  : priorityColor.withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              // Emoji icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isComplete
                      ? Colors.grey.shade100
                      : priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    isDone
                        ? '✅'
                        : isSkipped
                            ? '⏭️'
                            : _getEmoji(reminder.taskType),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Title + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isComplete ? Colors.grey : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '🕐 ${reminder.time}',
                          style: TextStyle(fontSize: 11, color: Colors.indigo[400]),
                        ),
                        if (reminder.cropName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '🌱 ${reminder.cropName}',
                            style: TextStyle(fontSize: 11, color: Colors.green[500]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons (only for pending)
              if (reminder.isPending) ...[
                const SizedBox(width: 4),
                _buildMiniAction(
                  icon: '❌',
                  color: Colors.orange,
                  onTap: () => _updateStatus(reminder, 'skipped'),
                  tooltip: 'Skip',
                ),
                const SizedBox(width: 4),
                _buildMiniAction(
                  icon: '✅',
                  color: Colors.green,
                  onTap: () => _updateStatus(reminder, 'done'),
                  tooltip: 'Done',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniAction({
    required String icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 14)),
          ),
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
}
