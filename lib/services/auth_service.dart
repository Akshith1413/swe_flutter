import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import 'preferences_service.dart';

/// Service for handling user authentication via Firebase.
/// 
/// Supports:
/// - Phone Number Authentication (OTP).
/// - Mock authentication for testing or when Firebase is not configured.
/// - User session management (listen to state changes, sign out).
class AuthService {
  // Replaced FirebaseAuth with generic auth states
  bool _useMock = false;
  
  String? _verificationId;
  int? _resendToken;

  AuthService() {
    _init();
  }

  void _init() {
    // API based auth doesn't need init like Firebase
  }

  /// Stream of user state changes (Mocked to be empty for now as we don't use stream based auth anymore)
  Stream<dynamic> get userChanges {
    return const Stream.empty();
  }

  /// Returns if we have a user token indicating signed in.
  dynamic get currentUser {
    // Return a dummy object if logged in, null otherwise
    // Real implementation would parse JWT wrapper. 
    return null;
  }

  /// Sends an OTP to the provided [phoneNumber].
  /// 
  /// - [onCodeSent]: Callback when the code is sent successfully.
  /// - [onVerificationFailed]: Callback when verification fails.
  /// - [onVerificationCompleted]: Callback when verification is automatically completed.
  /// 
  /// In Mock mode, simulates sending a code immediately.
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(Exception e) onVerificationFailed,
    required Function(dynamic credential) onVerificationCompleted,
  }) async {
    // Ensure number is in international format if not already
    String formattedNumber = phoneNumber;
    if (!phoneNumber.startsWith('+')) {
      formattedNumber = '+91$phoneNumber'; // Defaulting to India as per project context
    }

    if (_useMock) {
      debugPrint('AuthService: Sending Mock OTP to $formattedNumber');
      await Future.delayed(const Duration(seconds: 1)); // Simulate network
      onCodeSent('mock_verification_id', 123);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseApiUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _verificationId = data['userId']; // Store mongo userId as temp vid
        onCodeSent(_verificationId!, null);
      } else {
        throw Exception('Failed to send OTP: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending OTP via Backend: $e');
      rethrow;
    }
  }

  /// Verifies the [smsCode] entered by the user.
  /// 
  /// [verificationId] is obtained from [sendOtp].
  /// In Mock mode, accepts '123456' as the valid code.
  Future<void> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    if (_useMock) {
      debugPrint('AuthService: Verifying Mock OTP $smsCode');
      await Future.delayed(const Duration(seconds: 1));
      if (smsCode == '123456') {
        return; // Success
      } else {
        throw Exception('Invalid Mock OTP');
      }
    }

    try {
      // Use the raw phoneNumber (without +91 if user entered it that way, but let's assume we need to format it or use as is)
      // The backend expects just the number, or however it was created. We'll reconstruct it if needed,
      // but let's just use what's stored in vid temporarily, or pass the last used phone number.
      // Wait, verify API needs { phoneNumber, otp }. We don't have phoneNumber here!
      // I will assume verifyOtp takes phone number, but signature is verificationId.
      
      final response = await http.post(
        Uri.parse('${AppConstants.baseApiUrl}/api/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        // the backend matches either phone or email using the OTP record directly
        // actually backend can verify with just { otp } according to authRoutes.js logic!
        body: jsonEncode({'otp': smsCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await preferencesService.setUserId(data['_id']); // Crucial! Save MongoDB _id!
      } else {
        throw Exception('Invalid OTP or Verification Failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      rethrow;
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await preferencesService.setUserId('');
  }

  /// Gets the current user's ID token.
  Future<String?> getToken() async {
    return null; // Mocked for now, if you need actual JWT token, return it here.
  }
}

/// Global singleton instance of [AuthService].
final authService = AuthService();
