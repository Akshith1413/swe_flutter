import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_colors.dart';
import '../services/audio_service.dart';
import '../core/localization/translation_service.dart';

/// Voice Doctor View - A premium voice AI interface matching React's sophisticated UI.
class VoiceDoctorView extends StatefulWidget {
  final VoidCallback? onBack;

  const VoiceDoctorView({
    super.key,
    this.onBack,
  });

  @override
  State<VoiceDoctorView> createState() => _VoiceDoctorViewState();
}

class _VoiceDoctorViewState extends State<VoiceDoctorView> with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _transcript = '';
  String _response = '';
  bool _isAnalyzing = false;
  bool _isInitialized = false;
  
  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;

  // US14: Language selection
  String _selectedLocale = 'en_US';
  final Map<String, String> _localeOptions = {
    'en_US': 'English',
    'hi_IN': 'Hindi',
    'te_IN': 'Telugu',
    'ta_IN': 'Tamil',
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (error) => debugPrint('STT Error: $error'),
      );
      if (mounted) setState(() => _isInitialized = available);
    } catch (e) {
      debugPrint('STT Init Error: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_transcript.isNotEmpty) _analyzeSymptoms();
    } else {
      if (!_isInitialized) return;
      
      setState(() {
        _isListening = true;
        _transcript = '';
        _response = '';
      });
      audioService.playClick();

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _transcript = result.recognizedWords;
          });
        },
        localeId: _selectedLocale,
      );
    }
  }

  void _analyzeSymptoms() async {
    setState(() => _isAnalyzing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    setState(() {
      _isAnalyzing = false;
      _response = _generateResponse(_transcript);
    });
    audioService.confirmAction('success');
    audioService.speak(_response);
  }

  String _generateResponse(String symptoms) {
    if (symptoms.toLowerCase().contains('yellow')) {
      return "Based on your description of yellowing leaves, I recommend checking for nutrient deficiency. Ensure proper fertilization and irrigation.";
    }
    return "I've analyzed your description. It sounds like potential environmental stress. Try capturing a photo for a more precise diagnosis.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Cool gray background
      body: Column(
        children: [
          // 1. Premium Header
          _buildHeader(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 2. Main Mic Card (Glassmorphism inspired)
                  _buildMicCard(),

                  const SizedBox(height: 24),

                  // 3. Example Questions (Matching React)
                  if (_transcript.isEmpty && _response.isEmpty) _buildExamples(),

                  // 4. Analysis Results
                  if (_isAnalyzing) const CircularProgressIndicator(color: AppColors.nature600),
                  if (_response.isNotEmpty) _buildResponseCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 50, bottom: 20, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF059669), // Emerald 600
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
            onPressed: widget.onBack ?? () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(context.t('voiceView.title'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMicCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
        border: Border.all(color: const Color(0xFFECFDF5)),
      ),
      child: Column(
        children: [
          // Pulsing Mic Button
          GestureDetector(
            onTap: _toggleListening,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = _isListening ? (1.0 + 0.1 * _pulseController.value) : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? Colors.red : const Color(0xFF10B981)).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(_isListening ? LucideIcons.square : LucideIcons.mic, color: Colors.white, size: 40),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isListening ? context.t('voiceView.listening') : context.t('voiceView.tapToSpeak'),
            style: const TextStyle(fontSize: 18, color: Color(0xFF475569), fontWeight: FontWeight.w500),
          ),

          // Voice Waves (React style)
          if (_isListening)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => _buildWaveBar(index)),
              ),
            ),

          // Transcript
          if (_transcript.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
              child: Text(_transcript, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16)),
            ),
        ],
      ),
    );
  }

  Widget _buildWaveBar(int index) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final height = 12 + (math.sin(_waveController.value * 6.28 + (index * 0.5)) * 10).abs();
        return Container(
          width: 4,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(color: const Color(0xFFF87171), borderRadius: BorderRadius.circular(2)),
        );
      },
    );
  }

  Widget _buildExamples() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Try asking:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _exampleItem("My tomato leaves are turning yellow with brown spots."),
        _exampleItem("There are white powdery patches on my plant."),
        _exampleItem("The stems of my potato plant are wilting."),
      ],
    );
  }

  Widget _exampleItem(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Text('"$text"', style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontStyle: FontStyle.italic)),
    );
  }

  Widget _buildResponseCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.sparkles, color: Color(0xFF059669), size: 18),
              SizedBox(width: 8),
              Text("AI Doctor Analysis", style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_response, style: const TextStyle(color: Color(0xFF047857), fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }
}
