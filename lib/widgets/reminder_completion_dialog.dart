import 'package:flutter/material.dart';
import '../models/task_reminder_model.dart';
import '../services/task_reminder_service.dart';

/// A popup dialog for marking a task reminder as Done or Not Done (Skipped).
/// Shown when the user taps a reminder notification or taps a reminder in the list.
/// Status change is synced back to the web dashboard in real-time via Socket.IO.
class ReminderCompletionDialog extends StatefulWidget {
  final TaskReminder reminder;
  final VoidCallback? onStatusChanged;
  final String completedFrom;

  const ReminderCompletionDialog({
    super.key,
    required this.reminder,
    this.onStatusChanged,
    this.completedFrom = 'app_screen',
  });

  /// Show the dialog and return the new status or null if dismissed
  static Future<String?> show(
    BuildContext context, {
    required TaskReminder reminder,
    VoidCallback? onStatusChanged,
    String completedFrom = 'app_screen',
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReminderCompletionDialog(
        reminder: reminder,
        onStatusChanged: onStatusChanged,
        completedFrom: completedFrom,
      ),
    );
  }

  @override
  State<ReminderCompletionDialog> createState() =>
      _ReminderCompletionDialogState();
}

class _ReminderCompletionDialogState extends State<ReminderCompletionDialog> {
  bool _loading = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _loading = true);
    final result = await TaskReminderService.updateReminderStatus(
      widget.reminder.id,
      status,
      completedFrom: widget.completedFrom,
    );
    setState(() => _loading = false);

    if (result != null) {
      widget.onStatusChanged?.call();
      if (mounted) Navigator.of(context).pop(status);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminder = widget.reminder;
    final priorityColor = Color(reminder.priorityColorValue);

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
                color: priorityColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getTaskTypeEmoji(reminder.taskType),
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Reminder title
            Text(
              reminder.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Notification message
            if (reminder.message.isNotEmpty) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Text('💬', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reminder.message,
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Detail chips
            if (reminder.cropName.isNotEmpty)
              _buildDetailChip('🌱 ${reminder.cropName}', Colors.green),
            const SizedBox(height: 4),
            _buildDetailChip('🕐 ${reminder.time}', Colors.indigo),
            const SizedBox(height: 4),
            _buildDetailChip(reminder.taskTypeLabel, Colors.blue),
            if (reminder.weatherDependent) ...[
              const SizedBox(height: 4),
              _buildDetailChip('🌤️ Check weather first!', Colors.orange),
            ],
            if (reminder.estimatedDuration != null) ...[
              const SizedBox(height: 4),
              _buildDetailChip(
                  '⏱️ ~${reminder.estimatedDuration} minutes', Colors.teal),
            ],
            if (reminder.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                reminder.notes,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),

            // Priority badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: priorityColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${reminder.priority.toUpperCase()} PRIORITY',
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: HSLColor.fromColor(color).withLightness(0.3).toColor(),
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
      'market_visit': '🏪',
      'equipment_maintenance': '🔧',
      'weather_check': '🌤️',
      'seed_purchase': '🛒',
      'other': '📋',
    };
    return emojis[type] ?? '📋';
  }
}
