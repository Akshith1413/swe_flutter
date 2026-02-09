
class PendingMedia {
  final String id;
  final String filePath; // Local path to file
  final String fileType; // 'video' or 'image'
  final String? voiceTranscription;
  final int durationSeconds;
  final int createdAt;

  PendingMedia({
    required this.id,
    required this.filePath,
    required this.fileType,
    this.voiceTranscription,
    this.durationSeconds = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'fileType': fileType,
      'voiceTranscription': voiceTranscription,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt,
    };
  }

  factory PendingMedia.fromJson(Map<String, dynamic> json) {
    return PendingMedia(
      id: json['id'],
      filePath: json['filePath'],
      fileType: json['fileType'],
      voiceTranscription: json['voiceTranscription'],
      durationSeconds: json['durationSeconds'] ?? 0,
      createdAt: json['createdAt'],
    );
  }
}
