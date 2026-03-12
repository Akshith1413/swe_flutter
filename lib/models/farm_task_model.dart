/// Farm Task model matching the backend FarmTask schema.
/// Used for task scheduling, notifications, and status tracking.

class FarmTask {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String taskType;
  final String cropName;
  final DateTime date;
  final String time; // HH:mm 24hr format
  final DateTime scheduledAt;
  final String priority;
  final bool isRecurring;
  final String recurrencePattern;
  final DateTime? recurrenceEndDate;
  final String? parentTaskId;
  final String status; // pending, done, skipped, overdue
  final DateTime? completedAt;
  final NotificationSent notificationSent;
  final DateTime createdAt;
  final DateTime updatedAt;

  FarmTask({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.taskType = 'other',
    this.cropName = '',
    required this.date,
    required this.time,
    required this.scheduledAt,
    this.priority = 'medium',
    this.isRecurring = false,
    this.recurrencePattern = 'none',
    this.recurrenceEndDate,
    this.parentTaskId,
    this.status = 'pending',
    this.completedAt,
    NotificationSent? notificationSent,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : notificationSent = notificationSent ?? NotificationSent(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory FarmTask.fromJson(Map<String, dynamic> json) {
    return FarmTask(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['user'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      taskType: json['taskType'] ?? 'other',
      cropName: json['cropName'] ?? '',
      date: DateTime.parse(json['date']),
      time: json['time'] ?? '00:00',
      scheduledAt: DateTime.parse(json['scheduledAt']),
      priority: json['priority'] ?? 'medium',
      isRecurring: json['isRecurring'] ?? false,
      recurrencePattern: json['recurrencePattern'] ?? 'none',
      recurrenceEndDate: json['recurrenceEndDate'] != null
          ? DateTime.parse(json['recurrenceEndDate'])
          : null,
      parentTaskId: json['parentTaskId'],
      status: json['status'] ?? 'pending',
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      notificationSent: json['notificationSent'] != null
          ? NotificationSent.fromJson(json['notificationSent'])
          : NotificationSent(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'user': userId,
        'title': title,
        'description': description,
        'taskType': taskType,
        'cropName': cropName,
        'date': date.toIso8601String(),
        'time': time,
        'scheduledAt': scheduledAt.toIso8601String(),
        'priority': priority,
        'isRecurring': isRecurring,
        'recurrencePattern': recurrencePattern,
        'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
        'parentTaskId': parentTaskId,
        'status': status,
        'completedAt': completedAt?.toIso8601String(),
        'notificationSent': notificationSent.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  FarmTask copyWith({String? status, DateTime? completedAt}) {
    return FarmTask(
      id: id,
      userId: userId,
      title: title,
      description: description,
      taskType: taskType,
      cropName: cropName,
      date: date,
      time: time,
      scheduledAt: scheduledAt,
      priority: priority,
      isRecurring: isRecurring,
      recurrencePattern: recurrencePattern,
      recurrenceEndDate: recurrenceEndDate,
      parentTaskId: parentTaskId,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      notificationSent: notificationSent,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Human-readable task type label
  String get taskTypeLabel {
    const labels = {
      'watering': '💧 Watering',
      'fertilizer': '🧪 Fertilizer',
      'pesticide': '🛡️ Pesticide',
      'harvest': '🌾 Harvest',
      'sowing': '🌱 Sowing',
      'pruning': '✂️ Pruning',
      'soil_testing': '🔬 Soil Testing',
      'irrigation_check': '🚿 Irrigation Check',
      'weeding': '🌿 Weeding',
      'mulching': '🍂 Mulching',
      'other': '📋 Other',
    };
    return labels[taskType] ?? '📋 $taskType';
  }

  /// Priority color mapping
  int get priorityColorValue {
    const colors = {
      'low': 0xFF4CAF50,
      'medium': 0xFFFFC107,
      'high': 0xFFFF9800,
      'urgent': 0xFFF44336,
    };
    return colors[priority] ?? 0xFFFFC107;
  }

  bool get isDone => status == 'done';
  bool get isPending => status == 'pending';
  bool get isOverdue => status == 'overdue';
  bool get isSkipped => status == 'skipped';
}

class NotificationSent {
  final bool tenMin;
  final bool fiveMin;
  final bool atTime;

  NotificationSent({
    this.tenMin = false,
    this.fiveMin = false,
    this.atTime = false,
  });

  factory NotificationSent.fromJson(Map<String, dynamic> json) {
    return NotificationSent(
      tenMin: json['tenMin'] ?? false,
      fiveMin: json['fiveMin'] ?? false,
      atTime: json['atTime'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'tenMin': tenMin,
        'fiveMin': fiveMin,
        'atTime': atTime,
      };
}
