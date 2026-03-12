import 'package:flutter/material.dart';
import '../models/farm_task_model.dart';
import '../services/farm_task_service.dart';

/// A popup dialog for marking a farm task as Done or Not Done (Skipped).
/// Shown when the user taps a notification or taps a task in the list.
class TaskCompletionDialog extends StatefulWidget {
  final FarmTask task;
  final VoidCallback? onStatusChanged;

  const TaskCompletionDialog({
    super.key,
    required this.task,
    this.onStatusChanged,
  });

  /// Show the dialog and return the new status or null if dismissed
  static Future<String?> show(
    BuildContext context, {
    required FarmTask task,
    VoidCallback? onStatusChanged,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TaskCompletionDialog(
        task: task,
        onStatusChanged: onStatusChanged,
      ),
    );
  }

  @override
  State<TaskCompletionDialog> createState() => _TaskCompletionDialogState();
}

class _TaskCompletionDialogState extends State<TaskCompletionDialog> {
  bool _loading = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _loading = true);
    final result =
        await FarmTaskService.updateTaskStatus(widget.task.id, status);
    setState(() => _loading = false);

    if (result != null) {
      widget.onStatusChanged?.call();
      if (mounted) Navigator.of(context).pop(status);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update task. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final priorityColor = Color(task.priorityColorValue);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getTaskTypeEmoji(task.taskType),
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Task title
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Task details
            if (task.cropName.isNotEmpty)
              _buildDetailChip('🌱 ${task.cropName}', Colors.green),
            const SizedBox(height: 4),
            _buildDetailChip('🕐 ${task.time}', Colors.indigo),
            const SizedBox(height: 4),
            _buildDetailChip(
              task.taskTypeLabel,
              Colors.blue,
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                task.description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: priorityColor.withOpacity(0.3)),
              ),
              child: Text(
                '${task.priority.toUpperCase()} PRIORITY',
                style: TextStyle(
                  color: priorityColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            if (_loading)
              const CircularProgressIndicator()
            else
              Row(
                children: [
                  // Skip / Not Done button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateStatus('skipped'),
                      icon: const Text('❌', style: TextStyle(fontSize: 18)),
                      label: const Text('Not Done'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange[700],
                        side: BorderSide(color: Colors.orange[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Done button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus('done'),
                      icon: const Text('✅', style: TextStyle(fontSize: 18)),
                      label: const Text('Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.shade700,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getTaskTypeEmoji(String type) {
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

extension _ColorShade on Color {
  Color get shade700 {
    return Color.fromARGB(
      alpha.toInt(),
      (red * 0.7).toInt(),
      (green * 0.7).toInt(),
      (blue * 0.7).toInt(),
    );
  }
}
