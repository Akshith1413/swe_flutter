import 'dart:math';
import 'package:camera/camera.dart' show XFile;
import 'package:flutter/foundation.dart';
import '../models/analysis_result.dart';
import 'preferences_service.dart';
import 'ai_prediction_service.dart';
import 'crop_advice_service.dart';
import 'database_service.dart';

/// Service for crop disease analysis.
///
/// Sends images to the backend /analyze endpoint, which internally calls
/// the HuggingFace CNN model AND the Gemini LLM, returning everything in
/// a single response. This means a single HTTP round-trip from the app.
class CropService {
  // Fixed class labels that exactly match the CNN training order from the backend.
  static const List<String> classLabels = [
    "Apple___Apple_scab",
    "Apple___Black_rot",
    "Apple___Cedar_apple_rust",
    "Apple___healthy",
    "Blueberry___healthy",
    "Cherry_(including_sour)___Powdery_mildew",
    "Cherry_(including_sour)___healthy",
    "Corn_(maize)___Cercospora_leaf_spot",
    "Corn_(maize)___Common_rust",
    "Corn_(maize)___Northern_Leaf_Blight",
    "Corn_(maize)___healthy",
    "Grape___Black_rot",
    "Grape___Esca_(Black_Measles)",
    "Grape___Leaf_blight",
    "Grape___healthy",
    "Orange___Haunglongbing",
    "Peach___Bacterial_spot",
    "Peach___healthy",
    "Pepper,_bell___Bacterial_spot",
    "Pepper,_bell___healthy",
    "Potato___Early_blight",
    "Potato___Late_blight",
    "Potato___healthy",
    "Raspberry___healthy",
    "Soybean___healthy",
    "Squash___Powdery_mildew",
    "Strawberry___Leaf_scorch",
    "Strawberry___healthy",
    "Tomato___Bacterial_spot",
    "Tomato___Early_blight",
    "Tomato___Late_blight",
    "Tomato___Leaf_Mold",
    "Tomato___Septoria_leaf_spot",
    "Tomato___Spider_mites",
    "Tomato___Target_Spot",
    "Tomato___Yellow_Leaf_Curl_Virus",
    "Tomato___Tomato_mosaic_virus",
    "Tomato___healthy"
  ];

  /// Analyzes an image to detect crop diseases.
  ///
  /// - [imagePath]: Path to the image file.
  ///
  /// Sends the image to the Render backend's /api/crop-advice/analyze endpoint,
  /// which calls the HuggingFace CNN (Gate checks, prediction, Grad-CAM) and
  /// the Gemini LLM (advice) in a single server-side pipeline.
  ///
  /// Returns an [AnalysisResult] with all diagnostic data.
  Future<AnalysisResult> analyzeImage(String imagePath) async {
    Map<String, dynamic>? prediction;

    try {
      // 1. Read the image as bytes (Web-compatible using XFile)
      final List<int> imageBytes = await XFile(imagePath).readAsBytes();

      // 2. Send the image to the backend analyze endpoint
      //    (backend calls CNN + LLM via HuggingFace and returns merged result)
      prediction = await AIPredictionService.predict(imageBytes);
    } catch (e) {
      debugPrint('AI prediction request failed: $e');
      // Re-throw specific messages that should be shown via error bottom sheet
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('leaf') ||
          msg.contains('drawing') ||
          msg.contains('illustration') ||
          msg.contains('confidence') ||
          msg.contains('timeout') ||
          msg.contains('starting up') ||
          msg.contains('unavailable')) {
        throw Exception(msg);
      }
      throw Exception(
          'Could not connect to AI service. Please check your internet connection.');
    }

    // 3. Handle explicit AI rejection (e.g., non-leaf, low confidence)
    if (prediction != null && prediction["success"] == false) {
      // Use the specific human-readable message from the backend gates
      final errorMsg = prediction["message"] as String? ??
          prediction["error"] as String? ??
          "Could not identify a leaf in the image.";
      throw Exception(errorMsg);
    }

    // 4. Check if we have a valid AI response with class_name
    if (prediction != null && prediction.containsKey("class_name")) {
      // 5. Extract prediction fields
      final double confidence =
          (prediction["confidence"] as num).toDouble();

      // 6. Use server-provided class name
      final String diseaseName =
          prediction["class_name"] as String? ?? 'Unknown___Unknown';

      print("Predicted disease: $diseaseName");
      print("Confidence: $confidence");

      // 7. Extract crop name
      final String cropName = prediction["crop_name"] as String? ??
          diseaseName.split('___').first.replaceAll('_', ' ');

      // 8. Extract enhanced fields
      final List<Map<String, dynamic>> topPredictions =
          prediction["top_predictions"] != null
              ? List<Map<String, dynamic>>.from(
                  (prediction["top_predictions"] as List)
                      .map((e) => Map<String, dynamic>.from(e as Map)))
              : [];

      final String? heatmapBase64 =
          prediction["heatmap_base64"] as String?;

      // 9. Severity
      final Map<String, dynamic>? severityData =
          prediction["severity"] is Map
              ? Map<String, dynamic>.from(prediction["severity"] as Map)
              : null;

      final String severityLevel =
          severityData?["level"] as String? ?? "moderate";
      final String severityLabel = severityData?["label"] as String? ??
          (confidence > 0.8
              ? "High"
              : (confidence > 0.6 ? "Moderate" : "Low"));
      final String severityDescription =
          severityData?["description"] as String? ?? "";

      // 10. Build result from the embedded advice (backend already called LLM).
      //     Falls back to a second CropAdviceService call only if advice is missing.
      AnalysisResult result;

      final prebuiltAdvice =
          prediction["_advice"] as Map<String, dynamic>?;

      if (prebuiltAdvice != null) {
        // ✅ Happy path: use advice embedded in the analyze response
        result = AnalysisResult(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
          date: DateTime.now(),
          imageUrl: imagePath,
          crop: cropName,
          disease: diseaseName,
          severity: severityLabel,
          confidence: confidence,
          cause: prebuiltAdvice['cause'] as String? ?? '',
          symptoms: prebuiltAdvice['symptoms'] as String? ?? '',
          immediate: prebuiltAdvice['immediate'] as String? ?? '',
          chemical: prebuiltAdvice['chemical'] as String? ?? '',
          organic: prebuiltAdvice['organic'] as String? ?? '',
          prevention: prebuiltAdvice['prevention'] as String? ?? '',
          treatmentSteps: [
            prebuiltAdvice['immediate'] as String? ?? '',
            prebuiltAdvice['chemical'] as String? ?? '',
            prebuiltAdvice['organic'] as String? ?? '',
            prebuiltAdvice['prevention'] as String? ?? '',
          ].where((s) => s.isNotEmpty).toList(),
          organicSteps: [
            prebuiltAdvice['organic'] as String? ?? ''
          ].where((s) => s.isNotEmpty).toList(),
          chemicalSteps: [
            prebuiltAdvice['chemical'] as String? ?? ''
          ].where((s) => s.isNotEmpty).toList(),
          recoveryTimeline: prebuiltAdvice['recoveryTimeline'] != null
              ? Map<String, dynamic>.from(
                  prebuiltAdvice['recoveryTimeline'] as Map)
              : {
                  'initialDays': '3-5',
                  'fullRecoveryDays': '14-21',
                  'monitoringDays': '30',
                  'description': ''
                },
          preventionChecklist:
              prebuiltAdvice['preventionChecklist'] != null
                  ? List<String>.from(
                      prebuiltAdvice['preventionChecklist'] as List)
                  : [prebuiltAdvice['prevention'] as String? ?? ''],
          topPredictions: topPredictions,
          heatmapBase64: heatmapBase64,
          severityLevel: severityLevel,
          severityDescription: severityDescription,
        );
      } else {
        // ⚠️ Fallback: call CropAdviceService separately
        // (used during local dev or if backend response doesn't include advice)
        final adviceResult = await CropAdviceService.getCropAdvice(
          crop: cropName,
          disease: diseaseName,
          severity: severityLabel,
          confidence: confidence,
        );
        result = adviceResult.copyWith(
          imageUrl: imagePath,
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          date: DateTime.now(),
          topPredictions: topPredictions,
          heatmapBase64: heatmapBase64,
          severityLevel: severityLevel,
          severityDescription: severityDescription,
        );
      }

      // 11. Save to history
      if (!kIsWeb) {
        await databaseService.saveDiagnosis(result);
      }

      // Keep SharedPreferences save for current session
      await preferencesService.saveAnalysisResult(result.toJson());

      return result;
    }

    // 12. Final fallback for unexpected states
    throw Exception(
        'An unexpected error occurred during analysis. Please try again.');
  }
}

final cropService = CropService();
