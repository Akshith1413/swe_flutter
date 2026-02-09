import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'preferences_service.dart';

/// Service for managing audio feedback
/// Equivalent to React's audioService.js
class AudioService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _soundEnabled = true;
  bool _voiceEnabled = true;
  bool _isInitialized = false;
  String _currentLanguage = 'en-IN';

  /// Initialize audio service
  Future<void> init() async {
    if (_isInitialized) return;

    // Load preferences
    _soundEnabled = await preferencesService.isSoundEnabled();
    _voiceEnabled = await preferencesService.isVoiceEnabled();

    // Configure TTS
    await _tts.setLanguage(_currentLanguage);
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _isInitialized = true;
  }

  /// Set TTS language
  Future<void> setLanguage(String speechCode) async {
    _currentLanguage = speechCode;
    await _tts.setLanguage(speechCode);
  }

  /// Enable/disable sound effects
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await preferencesService.setSoundEnabled(enabled);
  }

  /// Enable/disable voice feedback
  Future<void> setVoiceEnabled(bool enabled) async {
    _voiceEnabled = enabled;
    await preferencesService.setVoiceEnabled(enabled);
  }

  /// Get sound enabled status
  bool get isSoundEnabled => _soundEnabled;

  /// Get voice enabled status
  bool get isVoiceEnabled => _voiceEnabled;

  /// Speak text
  Future<void> speak(String text) async {
    if (!_voiceEnabled || text.isEmpty) return;
    
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  /// Play click sound
  Future<void> playClick() async {
    if (!_soundEnabled) return;
    // TODO: Add actual click sound asset
    // await _audioPlayer.play(AssetSource('sounds/click.mp3'));
  }

  /// Play success sound
  Future<void> playSuccess() async {
    if (!_soundEnabled) return;
    // TODO: Add actual success sound asset
    // await _audioPlayer.play(AssetSource('sounds/success.mp3'));
  }

  /// Play error sound
  Future<void> playError() async {
    if (!_soundEnabled) return;
    // TODO: Add actual error sound asset
    // await _audioPlayer.play(AssetSource('sounds/error.mp3'));
  }

  /// Confirm action with sound and optional voice
  Future<void> confirmAction(String type, {String? message}) async {
    switch (type) {
      case 'success':
        await playSuccess();
        break;
      case 'error':
        await playError();
        break;
      default:
        await playClick();
    }

    if (message != null) {
      await speak(message);
    }
  }

  /// Speak localized message
  Future<void> speakLocalized(String key, String langCode) async {
    // Set language and speak
    await setLanguage('$langCode-IN');
    // TODO: Get localized string and speak
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _tts.stop();
    await _audioPlayer.dispose();
  }
}

/// Global singleton instance
final audioService = AudioService();
