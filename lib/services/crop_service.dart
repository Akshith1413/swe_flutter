import 'dart:math';
import 'package:camera/camera.dart' show XFile;
import 'package:flutter/foundation.dart';
import '../models/analysis_result.dart';
import 'preferences_service.dart';
import 'ai_prediction_service.dart';
import 'crop_advice_service.dart';

/// Service for simulating crop disease analysis.
/// 
/// In a real application, this would upload images to a backend model.
/// Currently, it mocks the analysis process with random results.
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

  // Mock data for simulation fallback
  final List<String> _crops = ['Tomato', 'Potato', 'Wheat', 'Rice', 'Corn'];
  final Map<String, List<String>> _diseases = {
    'Tomato': ['Early Blight', 'Late Blight', 'Leaf Mold', 'Healthy'],
    'Potato': ['Early Blight', 'Late Blight', 'Healthy'],
    'Wheat': ['Rust', 'Leaf Spot', 'Healthy'],
    'Rice': ['Bacterial Blight', 'Blast', 'Healthy'],
    'Corn': ['Rust', 'Leaf Blight', 'Healthy'],
  };

  /// Analyzes an image to detect crop diseases.
  /// 
  /// - [imagePath]: Path to the image file.
  /// 
  /// Returns an [AnalysisResult] with diagnostic data.
  /// Also saves the result to local history via [PreferencesService].
  Future<AnalysisResult> analyzeImage(String imagePath) async {
    Map<String, dynamic>? prediction;

    try {
      // 1. Read the image as bytes (Web-compatible using XFile)
      final List<int> imageBytes = await XFile(imagePath).readAsBytes();

      // 2. Send the image bytes to the AI model
      prediction = await AIPredictionService.predict(imageBytes);
    } catch (e) {
      debugPrint('AI prediction request failed: $e');
      throw Exception('Could not connect to AI service. Please check your internet connection.');
    }

    // 3. Handle explicit AI rejection (e.g., non-leaf)
    if (prediction != null && prediction["success"] == false) {
      final errorMsg = prediction["error"] ?? "Could not identify a leaf in the image.";
      throw Exception(errorMsg);
    }

    // 4. Check if we have a valid AI response with class_index
    if (prediction != null && prediction.containsKey("class_index")) {
      // 5. Extract the prediction
      final int classIndex = prediction["class_index"];
      final double confidence = prediction["confidence"];

      // 6. Strict Confidence Threshold (User-requested feature)
      // If confidence is too low, it's likely not a leaf or a very ambiguous case.
      if (confidence < 0.50) {
        throw Exception("Low confidence detection (${(confidence * 100).toStringAsFixed(0)}%). Please retake the photo with better lighting and ensure the leaf is centered.");
      }

      // 7. Map class_index to deterministic disease name
      final String diseaseName = classLabels[classIndex];
      
      print("Predicted disease: $diseaseName");
      print("Confidence: $confidence");

      // 8. Extract crop name for context
      final String cropName = diseaseName.split('___').first.replaceAll('_', ' ');

      // 9. Call the CropAdviceService with mapped disease name
      final result = await CropAdviceService.getCropAdvice(
        crop: cropName,
        disease: diseaseName,
        severity: confidence > 0.8 ? "High" : (confidence > 0.6 ? "Moderate" : "Low"),
        confidence: confidence,
      );

      // 10. Update image URL to the local path and finalize details
      final finalResult = result.copyWith(
        imageUrl: imagePath,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
      );

      // Save to history
      await preferencesService.saveAnalysisResult(finalResult.toJson());

      return finalResult;
    }

    // 11. Final fallback for unexpected states
    throw Exception('An unexpected error occurred during analysis. Please try again.');
  }
}

final cropService = CropService();
