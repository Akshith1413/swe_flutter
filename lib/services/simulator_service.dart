import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class SimulatorPrediction {
  final int survivalRate;
  final String predictedOutcome;
  final String rationale;
  final List<String> recommendedFurtherActions;

  SimulatorPrediction({
    required this.survivalRate,
    required this.predictedOutcome,
    required this.rationale,
    required this.recommendedFurtherActions,
  });

  factory SimulatorPrediction.fromJson(Map<String, dynamic> json) {
    return SimulatorPrediction(
      survivalRate: json['survivalRate'] ?? 0,
      predictedOutcome: json['predictedOutcome'] ?? 'Unknown Outcome',
      rationale: json['rationale'] ?? 'No rationale provided.',
      recommendedFurtherActions: List<String>.from(json['recommendedFurtherActions'] ?? []),
    );
  }
}

class SimulatorService {
  // Use appropriate base URL
  static const String _baseUrl = 'https://swe-ai-crop-back.onrender.com/api/simulator';

  Future<SimulatorPrediction> getPrediction({
    required String crop,
    required Map<String, dynamic> currentConditions,
    required List<Map<String, dynamic>> forecast,
    required List<String> actions,
  }) async {
    try {
      final token = await authService.getToken();
      final uri = Uri.parse('$_baseUrl/predict');
      
      // We will fallback to local port if needed, but keeping production config format for now
      final String effectiveUrl = kIsWeb && const String.fromEnvironment('FLUTTER_WEB_USE_SKIA', defaultValue: 'false') == 'false'
          ? 'http://localhost:3000/api/simulator/predict' // Local temp for dev
          : 'https://swe-ai-crop-back.onrender.com/api/simulator/predict';

      final response = await http.post(
        Uri.parse(effectiveUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'crop': crop,
          'currentConditions': currentConditions,
          'forecast': forecast,
          'actions': actions,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return SimulatorPrediction.fromJson(data['data']);
        } else {
          throw Exception(data['error'] ?? 'Prediction failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('SimulatorService Error: $e');
      rethrow;
    }
  }
}

final simulatorService = SimulatorService();
