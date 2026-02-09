import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user consent
/// Equivalent to React's consentService.js
class ConsentService {
  static const String _consentKey = 'user_consent';
  static const String _guestModeKey = 'guest_mode';

  SharedPreferences? _prefs;

  /// Initialize service
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get SharedPreferences instance
  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Check if user has given consent
  Future<bool> hasConsent() async {
    final p = await prefs;
    return p.getBool(_consentKey) ?? false;
  }

  /// Give consent
  Future<void> giveConsent() async {
    final p = await prefs;
    await p.setBool(_consentKey, true);
  }

  /// Revoke consent
  Future<void> revokeConsent() async {
    final p = await prefs;
    await p.setBool(_consentKey, false);
  }

  /// Check if in guest mode
  Future<bool> isGuestMode() async {
    final p = await prefs;
    return p.getBool(_guestModeKey) ?? false;
  }

  /// Set guest mode
  Future<void> setGuestMode(bool isGuest) async {
    final p = await prefs;
    await p.setBool(_guestModeKey, isGuest);
  }

  /// Clear all consent data
  Future<void> clear() async {
    final p = await prefs;
    await p.remove(_consentKey);
    await p.remove(_guestModeKey);
  }
}

/// Global singleton instance
final consentService = ConsentService();
