import 'dart:async';
import 'package:flutter/material.dart';
import '../models/farm_task_model.dart';
import '../services/farm_task_service.dart';
import '../services/farm_task_notification_service.dart';
import '../services/preferences_service.dart';
import '../widgets/task_completion_dialog.dart';

/// Screen displaying farm tasks with pull-to-refresh and notification-linked completion.
class FarmTasksScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const FarmTasksScreen({super.key, this.onBack});

  @override
  State<FarmTasksScreen> createState() => _FarmTasksScreenState();
}

class _FarmTasksScreenState extends State<FarmTasksScreen>
    with WidgetsBindingObserver {
  List<FarmTask> _tasks = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTasks();

    // Auto-refresh every 60 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadTasks(silent: true),
    );

    // Check for pending notification taps
    _checkPendingNotification();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTasks(silent: true);
      _checkPendingNotification();
    }
  }

  Future<void> _checkPendingNotification() async {
    final taskId = FarmTaskNotificationService.checkPendingNotification();
    if (taskId != null && mounted) {
      // Find the task and show completion dialog
      await _loadTasks();
      final task = _tasks.where((t) => t.id == taskId).firstOrNull;
      if (task != null && mounted) {
        TaskCompletionDialog.show(
          context,
          task: task,
          onStatusChanged: () => _loadTasks(),
        );
      }
    }
  }

  Future<void> _loadTasks({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);

    final userId = await preferencesService.getUserId();
    if (userId == null || userId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final tasks = await FarmTaskService.fetchTasks(userId);
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    }

    // Schedule notifications for upcoming tasks
    await FarmTaskNotificationService.refreshAllNotifications();
  }

  void _showCompletionDialog(FarmTask task) {
    TaskCompletionDialog.show(
      context,
      task: task,
      onStatusChanged: () => _loadTasks(),
    );
  }

  // Group tasks by date
  Map<String, List<FarmTask>> get _groupedTasks {
    final Map<String, List<FarmTask>> groups = {};
    for (final task in _tasks) {
      final dateKey = _formatDate(task.date);
      groups.putIfAbsent(dateKey, () => []).add(task);
    }
    return groups;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);

    if (taskDate == today) return '📅 Today';
    if (taskDate == today.add(const Duration(days: 1))) return '📅 Tomorrow';
    if (taskDate == today.subtract(const Duration(days: 1))) {
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
            Text('🌾', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text(
              'Farm Tasks',
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
            onPressed: () => _loadTasks(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => _loadTasks(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _groupedTasks.length,
                    itemBuilder: (context, index) {
                      final entry = _groupedTasks.entries.toList()[index];
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
          const Text('🌱', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No farm tasks yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create tasks from the web app\nYou\'ll get reminders here!',
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

  Widget _buildDateGroup(String dateLabel, List<FarmTask> tasks) {
    // Count pending/done
    final pendingCount = tasks.where((t) => t.isPending).length;
    final doneCount = tasks.where((t) => t.isDone).length;

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
        ...tasks.map((task) => _buildTaskCard(task)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCountBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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

  Widget _buildTaskCard(FarmTask task) {
    final priorityColor = Color(task.priorityColorValue);
    final isDone = task.isDone;
    final isSkipped = task.isSkipped;
    final opacity = (isDone || isSkipped) ? 0.6 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDone
                ? Colors.green.withOpacity(0.3)
                : priorityColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: task.isPending ? () => _showCompletionDialog(task) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDone
                        ? Colors.green.withOpacity(0.1)
                        : priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      isDone ? '✅' : (isSkipped ? '⏭️' : _getEmoji(task.taskType)),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Task details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
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
                          _buildChip('🕐 ${task.time}', Colors.indigo),
                          if (task.cropName.isNotEmpty)
                            _buildChip('🌱 ${task.cropName}', Colors.green),
                          _buildChip(
                            task.priority.toUpperCase(),
                            priorityColor,
                          ),
                          if (task.isRecurring)
                            _buildChip('🔁 ${task.recurrencePattern}', Colors.purple),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status indicator
                if (task.isPending)
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
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
        color: color.withOpacity(0.08),
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
      'other': '📋',
    };
    return emojis[type] ?? '📋';
  }
}
