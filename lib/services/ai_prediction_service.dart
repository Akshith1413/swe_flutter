import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

/// Service for communicating with the crop disease prediction pipeline.
///
/// Routes requests through the deployed Render backend (/api/crop-advice/analyze),
/// which in turn forwards to the Hugging Face AI service (CNN + Grad-CAM).
/// This ensures the app works on real devices where localhost is not accessible.
class AIPredictionService {
  /// The backend analyze endpoint that proxies to the HuggingFace AI model.
  static String get analyzeUrl => '${AppConstants.baseApiUrl}/api/crop-advice/analyze';

  /// Sends [imageBytes] to the backend analyze pipeline and returns the
  /// full prediction map.
  ///
  /// Response fields (when success == true):
  /// - `crop` (String) — e.g. "Tomato"
  /// - `disease` (String) — e.g. "Late blight"
  /// - `confidence` (double)
  /// - `severity` (Map) — { level, label, description }
  /// - `topPredictions` (List) — top-5 predictions with names+scores
  /// - `heatmapBase64` (String?) — Grad-CAM overlay as base64 PNG
  /// - `advice` (Map) — LLM-generated treatment advice
  ///
  /// The response is normalized to match the expected schema used by
  /// [CropService.analyzeImage].
  static Future<Map<String, dynamic>> predict(List<int> imageBytes) async {
    final uri = Uri.parse(analyzeUrl);
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'leaf.jpg',
      ),
    );

    print('Sending image to backend analyze endpoint: $analyzeUrl');

    // Use a long timeout: Render + HuggingFace can have cold starts (60-90s)
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 120),
      onTimeout: () => throw Exception(
        'Request timed out. The AI service may be starting up — please try again in a moment.',
      ),
    );

    final responseBody = await streamedResponse.stream.bytesToString();
    print('Backend analyze response (${streamedResponse.statusCode}), length: ${responseBody.length}');

    if (streamedResponse.statusCode != 200) {
      throw Exception(
        'AI analysis failed (HTTP ${streamedResponse.statusCode}). Please try again.',
      );
    }

    final raw = jsonDecode(responseBody) as Map<String, dynamic>;

    // If the backend returned success:false (e.g. low confidence, no leaf)
    // surface the error message directly so CropService can show it to the user.
    if (raw['success'] == false) {
      print('Backend returned failure: ${raw['message'] ?? raw['error']}');
      return {
        'success': false,
        'message': raw['message'] ?? raw['error'] ?? 'Could not identify a leaf in the image.',
        'error':   raw['error'],
      };
    }

    // Normalize the backend response so that CropService sees the same schema
    // as it did when calling the AI service directly.
    //
    // Backend /analyze returns:
    //   { success, crop, disease, confidence, severity, topPredictions,
    //     heatmapBase64, advice }
    // CropService expects:
    //   { success, class_index, class_name, crop_name, disease_name,
    //     confidence, top_predictions, severity, heatmap_base64 }
    final cropName    = raw['crop']    as String? ?? '';
    final diseaseName = raw['disease'] as String? ?? '';
    final className   = '${cropName.replaceAll(' ', '_')}___${diseaseName.replaceAll(' ', '_')}';

    final normalized = <String, dynamic>{
      'success':         true,
      'class_index':     0,           // Not needed downstream — class_name takes priority
      'class_name':      className,
      'crop_name':       cropName,
      'disease_name':    diseaseName,
      'confidence':      raw['confidence'],
      'severity':        raw['severity'],
      'top_predictions': raw['topPredictions'] ?? [],
      'heatmap_base64':  raw['heatmapBase64'],
      // Carry advice through so CropService can skip the second LLM call if desired
      '_advice':         raw['advice'],
    };

    print('AI crop_name: $cropName');
    print('AI disease_name: $diseaseName');
    print('AI confidence: ${raw['confidence']}');
    print('AI severity: ${(raw['severity'] as Map?)?.values.first}');
    print('AI top_predictions count: ${(raw['topPredictions'] as List?)?.length ?? 0}');
    print('AI heatmap_base64 present: ${raw['heatmapBase64'] != null}');

    return normalized;
  }
}
