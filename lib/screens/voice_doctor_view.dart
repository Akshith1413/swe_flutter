import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/translation_service.dart';

/// Voice Doctor View - Voice-based plant diagnosis
/// Matches React's VoiceDoctor component in CropDiagnosisApp.jsx
class VoiceDoctorView extends StatefulWidget {
  final VoidCallback onBack;

  const VoiceDoctorView({
    super.key,
    required this.onBack,
  });

  @override
  State<VoiceDoctorView> createState() => _VoiceDoctorViewState();
}

class _VoiceDoctorViewState extends State<VoiceDoctorView> 
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  String _transcript = '';
  String? _response;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (!_isListening && _transcript.isNotEmpty) {
        _processQuery();
      }
    });
  }

  void _processQuery() async {
    // Simulate AI response
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _response = "Based on your description, it sounds like your tomato plant may be experiencing early blight. Early blight is caused by the fungus Alternaria solani. I recommend:\n\n1. Remove affected leaves immediately\n2. Apply a copper-based fungicide\n3. Ensure proper air circulation\n4. Water at the base of the plant";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
          color: AppColors.gray700,
        ),
        title: Text(
          context.t('voiceView.title'),
          style: const TextStyle(color: AppColors.gray800),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.purple50,
              Color(0xFFF3E8FF),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Instruction Text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _isListening 
                      ? context.t('voiceView.listening')
                      : context.t('voiceView.tapToSpeak'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.gray600,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Microphone Button
              GestureDetector(
                onTap: _toggleListening,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 140 + (_isListening ? 20 * _pulseController.value : 0),
                      height: 140 + (_isListening ? 20 * _pulseController.value : 0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isListening
                              ? [AppColors.red400, AppColors.red600]
                              : [AppColors.purple500, AppColors.purple700],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? AppColors.red400 : AppColors.purple500)
                                .withOpacity(0.4),
                            blurRadius: 30 + (_isListening ? 20 * _pulseController.value : 0),
                            spreadRadius: _isListening ? 10 * _pulseController.value : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        size: 60,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Listening Status
              if (_isListening)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 8,
                          height: 20 + (20 * _pulseController.value * (index == 1 ? 1 : 0.5)),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: AppColors.red400,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      },
                    );
                  }),
                ),

              const SizedBox(height: 40),

              // Transcript Display
              if (_transcript.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, size: 20, color: AppColors.purple500),
                            const SizedBox(width: 8),
                            Text(
                              context.t('voiceView.youSaid'),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.purple600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _transcript,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.gray700,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // AI Response
              if (_response != null) ...[
                const SizedBox(height: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.nature100, Colors.white],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.nature200),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.nature500,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.eco,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  context.t('voiceView.aiDoctor'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.nature700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _response!,
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.gray700,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
