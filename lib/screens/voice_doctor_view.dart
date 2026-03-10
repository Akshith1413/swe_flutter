import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:lucide_icons/lucide_icons.dart';
import '../core/utils/responsive_layout.dart';
import '../services/audio_service.dart';
import '../services/chat_service.dart';
import '../core/localization/translation_service.dart';
import '../core/theme/app_colors.dart';

/// Voice Doctor View — Redesigned with AgriTech Light theme.
///
/// US14: Voice input for symptom description.
/// US16: Confirmation of captured input.
class VoiceDoctorView extends StatefulWidget {
  final VoidCallback? onBack;

  const VoiceDoctorView({super.key, this.onBack});

  @override
  State<VoiceDoctorView> createState() => _VoiceDoctorViewState();
}

class _VoiceDoctorViewState extends State<VoiceDoctorView> with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _transcript = '';
  String _response = '';
  bool _isAnalyzing = false;
  bool _isInitialized = false;
  late AnimationController _pulseController;

  String _selectedLocale = 'en_US';

  final Map<String, String> _localeOptions = {
    'en_US': 'English',
    'hi_IN': 'Hindi',
    'te_IN': 'Telugu',
    'ta_IN': 'Tamil',
    'kn_IN': 'Kannada',
    'mr_IN': 'Marathi',
    'bn_IN': 'Bengali',
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
        onError: (error) {
          debugPrint('STT Error: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Speech error: ${error.errorMsg}')),
            );
          }
        },
      );

      if (available) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('STT Init Error: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_transcript.isNotEmpty) _analyzeSymptoms();
    } else {
      if (!_isInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
        return;
      }

      setState(() {
        _isListening = true;
        _transcript = '';
        _response = '';
      });

      await _speech.listen(
        onResult: (result) {
          setState(() => _transcript = result.recognizedWords);
        },
        localeId: _selectedLocale,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _analyzeSymptoms() async {
    setState(() => _isAnalyzing = true);

    try {
      final aiResponse = await ChatService.getResponse(
        "A farmer describes the following crop symptoms: '$_transcript'. "
        "Provide a brief diagnosis and recommended treatment in 3-4 sentences."
      );
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _response = aiResponse;
        });
        audioService.confirmAction('success');
        audioService.speak(_response);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _response = "I couldn't analyze that right now. Please try again or describe your symptoms differently.";
        });
      }
    }
  }

  void _clearAndRetry() {
    setState(() {
      _transcript = '';
      _response = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ResponsiveBody(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildLanguageSelector(),
                          const SizedBox(height: 60),
                          _buildMicSection(),
                          const SizedBox(height: 50),
                          if (_transcript.isNotEmpty) _buildTranscriptCard(),
                          if (_isAnalyzing)
                            Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Column(
                                children: [
                                  const CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 3,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Analyzing your symptoms...',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_response.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildResponseCard(),
                            const SizedBox(height: 32),
                            _buildActionButtons(),
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, size: 28),
            onPressed: widget.onBack ?? () => Navigator.pop(context),
            color: AppColors.textPrimary,
          ),
          Expanded(
            child: Text(
              context.t('voiceView.title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary, 
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance for leading icon
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(100),
        boxShadow: AppColors.softShadow,
        border: Border.all(color: AppColors.primary.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.languages, color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          Text(
            'Language:', 
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _selectedLocale,
            underline: const SizedBox(),
            dropdownColor: AppColors.surface,
            elevation: 8,
            style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w900),
            icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.primary),
            onChanged: (value) {
              if (value != null) setState(() => _selectedLocale = value);
            },
            items: _localeOptions.entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMicSection() {
    return Column(
      children: [
        _buildMicButton(),
        const SizedBox(height: 32),
        Text(
          _isListening
              ? "Listening to you..."
              : (_isInitialized ? "Tap to speak symptoms" : "Initializing engine..."),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _isListening ? AppColors.error : AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        if (_isListening) ...[
          const SizedBox(height: 16),
          _buildWaveformIndicator(),
        ],
      ],
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = _isListening ? (1.0 + 0.15 * _pulseController.value) : 1.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (_isListening)
                ...List.generate(3, (i) {
                  final s = 1.0 + (i + 1) * 0.4 * _pulseController.value;
                  return Transform.scale(
                    scale: s,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.3 * (1 - _pulseController.value)),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }),
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isListening 
                        ? [AppColors.error, const Color(0xFFF87171)]
                        : [AppColors.primary, AppColors.nature600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? AppColors.error : AppColors.primary).withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isListening ? LucideIcons.square : LucideIcons.mic,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWaveformIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(15, (i) {
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final offset = (i - 7).abs() * 0.1;
            final height = 8 + 32 * ((_pulseController.value + offset) % 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildTranscriptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.softShadow,
        border: Border.all(color: AppColors.primary.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.forest100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.user, size: 16, color: AppColors.forest600),
              ),
              const SizedBox(width: 12),
              const Text(
                'YOUR DESCRIPTION',
                style: TextStyle(
                  fontWeight: FontWeight.w900, 
                  color: AppColors.forest600, 
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _transcript,
            style: const TextStyle(
              fontSize: 16, 
              color: AppColors.textPrimary, 
              height: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.mediumShadow,
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.sparkles, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              const Text(
                'AI ASSESSMENT',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _response,
            style: const TextStyle(
              fontSize: 17, 
              color: AppColors.textPrimary, 
              height: 1.7,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton.icon(
            onPressed: _clearAndRetry,
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            label: const Text(
              'ASK ANOTHER QUESTION', 
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.3),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Go back to home',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

