import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Holds both scenario predictions from the simulator.
class SimulatorResult {
  final ScenarioPrediction noAction;
  final ScenarioPrediction withRemediation;

  SimulatorResult({required this.noAction, required this.withRemediation});

  factory SimulatorResult.fromJson(Map<String, dynamic> json) {
    return SimulatorResult(
      noAction: ScenarioPrediction.fromJson(json['noAction'] ?? {}),
      withRemediation: ScenarioPrediction.fromJson(json['withRemediation'] ?? {}),
    );
  }
}

class ScenarioPrediction {
  final int survivalRate;
  final String predictedOutcome;
  final String rationale;
  final List<String> recommendedFurtherActions;

  ScenarioPrediction({
    required this.survivalRate,
    required this.predictedOutcome,
    required this.rationale,
    required this.recommendedFurtherActions,
  });

  factory ScenarioPrediction.fromJson(Map<String, dynamic> json) {
    return ScenarioPrediction(
      survivalRate: (json['survivalRate'] ?? 0) is int
          ? json['survivalRate']
          : (json['survivalRate'] as num).toInt(),
      predictedOutcome: json['predictedOutcome'] ?? 'Unknown',
      rationale: json['rationale'] ?? '',
      recommendedFurtherActions:
          List<String>.from(json['recommendedFurtherActions'] ?? []),
    );
  }
}

// Backward-compatible alias
typedef SimulatorPrediction = ScenarioPrediction;

class SimulatorService {
  static const String _baseUrl =
      'https://swe-ai-crop-back.onrender.com/api/simulator';

  Future<SimulatorResult> getPrediction({
    required String crop,
    required Map<String, dynamic> currentConditions,
    required List<Map<String, dynamic>> forecast,
    required List<String> actions,
  }) async {
    try {
      final token = await authService.getToken();

      final String effectiveUrl = kIsWeb &&
              const String.fromEnvironment('FLUTTER_WEB_USE_SKIA',
                      defaultValue: 'false') ==
                  'false'
          ? 'http://localhost:3000/api/simulator/predict'
          : '$_baseUrl/predict';

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
          return SimulatorResult.fromJson(data['data']);
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
