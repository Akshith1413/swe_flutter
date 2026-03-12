/// TaskReminder model matching the backend TaskReminder schema.
/// Separate from FarmTask — used for notification-based reminders.
/// Created from the web calendar, delivered as notifications on the app.

class TaskReminder {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String taskType;
  final String cropName;
  final DateTime date;
  final String time; // HH:mm 24hr format
  final DateTime scheduledAt;
  final String priority;
  final bool isRecurring;
  final String recurrencePattern;
  final DateTime? recurrenceEndDate;
  final List<int> customRecurrenceDays;
  final String? parentReminderId;
  final String status; // pending, done, skipped, overdue, snoozed
  final DateTime? completedAt;
  final String? completedFrom; // app_notification, app_screen, web
  final NotificationStatus notificationSent;
  final bool weatherDependent;
  final String notes;
  final int? estimatedDuration;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskReminder({
    required this.id,
    required this.userId,
    required this.title,
    this.message = '',
    this.taskType = 'other',
    this.cropName = '',
    required this.date,
    required this.time,
    required this.scheduledAt,
    this.priority = 'medium',
    this.isRecurring = false,
    this.recurrencePattern = 'none',
    this.recurrenceEndDate,
    this.customRecurrenceDays = const [],
    this.parentReminderId,
    this.status = 'pending',
    this.completedAt,
    this.completedFrom,
    NotificationStatus? notificationSent,
    this.weatherDependent = false,
    this.notes = '',
    this.estimatedDuration,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : notificationSent = notificationSent ?? NotificationStatus(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory TaskReminder.fromJson(Map<String, dynamic> json) {
    return TaskReminder(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['user'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
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
      customRecurrenceDays: json['customRecurrenceDays'] != null
          ? List<int>.from(json['customRecurrenceDays'])
          : [],
      parentReminderId: json['parentReminderId'],
      status: json['status'] ?? 'pending',
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      completedFrom: json['completedFrom'],
      notificationSent: json['notificationSent'] != null
          ? NotificationStatus.fromJson(json['notificationSent'])
          : NotificationStatus(),
      weatherDependent: json['weatherDependent'] ?? false,
      notes: json['notes'] ?? '',
      estimatedDuration: json['estimatedDuration'],
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
        'message': message,
        'taskType': taskType,
        'cropName': cropName,
        'date': date.toIso8601String(),
        'time': time,
        'scheduledAt': scheduledAt.toIso8601String(),
        'priority': priority,
        'isRecurring': isRecurring,
        'recurrencePattern': recurrencePattern,
        'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
        'customRecurrenceDays': customRecurrenceDays,
        'parentReminderId': parentReminderId,
        'status': status,
        'completedAt': completedAt?.toIso8601String(),
        'completedFrom': completedFrom,
        'notificationSent': notificationSent.toJson(),
        'weatherDependent': weatherDependent,
        'notes': notes,
        'estimatedDuration': estimatedDuration,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  TaskReminder copyWith({String? status, DateTime? completedAt, String? completedFrom}) {
    return TaskReminder(
      id: id,
      userId: userId,
      title: title,
      message: message,
      taskType: taskType,
      cropName: cropName,
      date: date,
      time: time,
      scheduledAt: scheduledAt,
      priority: priority,
      isRecurring: isRecurring,
      recurrencePattern: recurrencePattern,
      recurrenceEndDate: recurrenceEndDate,
      customRecurrenceDays: customRecurrenceDays,
      parentReminderId: parentReminderId,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      completedFrom: completedFrom ?? this.completedFrom,
      notificationSent: notificationSent,
      weatherDependent: weatherDependent,
      notes: notes,
      estimatedDuration: estimatedDuration,
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
      'market_visit': '🏪 Market Visit',
      'equipment_maintenance': '🔧 Equipment',
      'weather_check': '🌤️ Weather Check',
      'seed_purchase': '🛒 Seed Purchase',
      'other': '📋 Other',
    };
    return labels[taskType] ?? '📋 $taskType';
  }

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
  bool get isSnoozed => status == 'snoozed';
}

class NotificationStatus {
  final bool tenMin;
  final bool fiveMin;
  final bool atTime;

  NotificationStatus({
    this.tenMin = false,
    this.fiveMin = false,
    this.atTime = false,
  });

  factory NotificationStatus.fromJson(Map<String, dynamic> json) {
    return NotificationStatus(
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
