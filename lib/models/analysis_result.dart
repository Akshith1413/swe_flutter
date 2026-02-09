import 'dart:convert';

class AnalysisResult {
  final String id;
  final DateTime date;
  final String imageUrl;
  final String crop;
  final String disease;
  final double confidence;
  final String severity;
  final String cause;
  final String symptoms;
  final String immediate;
  final String chemical;
  final String organic;
  final String prevention;

  AnalysisResult({
    required this.id,
    required this.date,
    required this.imageUrl,
    required this.crop,
    required this.disease,
    required this.confidence,
    required this.severity,
    required this.cause,
    required this.symptoms,
    required this.immediate,
    required this.chemical,
    required this.organic,
    required this.prevention,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'imageUrl': imageUrl,
      'crop': crop,
      'disease': disease,
      'confidence': confidence,
      'severity': severity,
      'cause': cause,
      'symptoms': symptoms,
      'immediate': immediate,
      'chemical': chemical,
      'organic': organic,
      'prevention': prevention,
    };
  }

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      id: json['id'],
      date: DateTime.parse(json['date']),
      imageUrl: json['imageUrl'],
      crop: json['crop'],
      disease: json['disease'],
      confidence: json['confidence'].toDouble(),
      severity: json['severity'],
      cause: json['cause'] ?? '',
      symptoms: json['symptoms'] ?? '',
      immediate: json['immediate'] ?? '',
      chemical: json['chemical'] ?? '',
      organic: json['organic'] ?? '',
      prevention: json['prevention'] ?? '',
    );
  }
}
