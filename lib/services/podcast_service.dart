import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Model for a generated podcast episode.
class PodcastEpisode {
  final String title;
  final String date;
  final String region;
  final String crop;
  final String script;
  final Map<String, RiskLevel> riskLevels;
  final List<String> weatherInsights;

  PodcastEpisode({
    required this.title,
    required this.date,
    required this.region,
    required this.crop,
    required this.script,
    required this.riskLevels,
    required this.weatherInsights,
  });

  factory PodcastEpisode.fromJson(Map<String, dynamic> json) {
    final risksJson = json['riskLevels'] as Map<String, dynamic>? ?? {};
    final Map<String, RiskLevel> risks = {};
    risksJson.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        risks[key] = RiskLevel.fromJson(value);
      }
    });

    return PodcastEpisode(
      title: json['title'] ?? 'Farm Forecast',
      date: json['date'] ?? '',
      region: json['region'] ?? '',
      crop: json['crop'] ?? '',
      script: json['script'] ?? '',
      riskLevels: risks,
      weatherInsights: List<String>.from(json['weatherInsights'] ?? []),
    );
  }
}

class RiskLevel {
  final String level; // 'high', 'medium', 'low'
  final String explanation;

  RiskLevel({required this.level, required this.explanation});

  factory RiskLevel.fromJson(Map<String, dynamic> json) {
    return RiskLevel(
      level: json['level'] ?? 'low',
      explanation: json['explanation'] ?? '',
    );
  }
}

class PodcastService {
  static const String _baseUrl =
      'https://swe-ai-crop-back.onrender.com/api/podcast';
  static const String _ttsBaseUrl =
      'https://swe-ai-crop-back.onrender.com/api/tts';

  /// Generate a daily podcast episode from AI.
  Future<PodcastEpisode> generateEpisode({
    required String region,
    required String crop,
    required List<Map<String, dynamic>> forecast,
  }) async {
    try {
      final token = await authService.getToken();

      final String effectiveUrl = kIsWeb &&
              const String.fromEnvironment('FLUTTER_WEB_USE_SKIA',
                      defaultValue: 'false') ==
                  'false'
          ? 'http://127.0.0.1:5000/api/podcast/generate'
          : '$_baseUrl/generate';

      final response = await http.post(
        Uri.parse(effectiveUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'region': region,
          'crop': crop,
          'forecast': forecast,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return PodcastEpisode.fromJson(data['data']);
        } else {
          throw Exception(data['error'] ?? 'Failed to generate podcast');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('PodcastService Error: $e');
      rethrow;
    }
  }

  /// Synthesize podcast script to audio via TTS endpoint.
  /// Returns base64-encoded WAV audio.
  Future<String?> synthesizeAudio({
    required String text,
    String languageCode = 'en',
  }) async {
    try {
      final String effectiveUrl = kIsWeb &&
              const String.fromEnvironment('FLUTTER_WEB_USE_SKIA',
                      defaultValue: 'false') ==
                  'false'
          ? 'http://127.0.0.1:5000/api/tts/synthesize'
          : '$_ttsBaseUrl/synthesize';

      // Truncate to 2500 chars (Sarvam limit)
      final trimmed = text.length > 2500 ? text.substring(0, 2500) : text;

      final response = await http.post(
        Uri.parse(effectiveUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': trimmed,
          'languageCode': languageCode,
          'pace': 0.9,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['audioBase64'] as String?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('PodcastService TTS Error: $e');
      return null;
    }
  }
}

final podcastService = PodcastService();
