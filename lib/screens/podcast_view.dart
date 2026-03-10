import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import '../core/theme/app_colors.dart';
import '../services/podcast_service.dart';
import '../services/preferences_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;

class PodcastView extends StatefulWidget {
  final VoidCallback onBack;

  const PodcastView({super.key, required this.onBack});

  @override
  State<PodcastView> createState() => _PodcastViewState();
}

class _PodcastViewState extends State<PodcastView>
    with TickerProviderStateMixin {
  bool _isGenerating = false;
  bool _isSynthesizing = false;
  PodcastEpisode? _episode;
  String? _audioBase64;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _showTranscript = false;

  String _selectedCrop = 'Tomato';
  final List<String> _crops = ['Tomato', 'Potato', 'Rice', 'Grape', 'Corn'];

  late AnimationController _waveController;
  late AnimationController _pulseController;

  final List<Map<String, dynamic>> _mockForecast = [
    {'day': 'Mon', 'temp': 25, 'humidity': 60, 'wind': 8},
    {'day': 'Tue', 'temp': 27, 'humidity': 65, 'wind': 12},
    {'day': 'Wed', 'temp': 28, 'humidity': 70, 'wind': 15},
    {'day': 'Thu', 'temp': 26, 'humidity': 85, 'wind': 22},
    {'day': 'Fri', 'temp': 24, 'humidity': 80, 'wind': 18},
    {'day': 'Sat', 'temp': 25, 'humidity': 75, 'wind': 10},
    {'day': 'Sun', 'temp': 26, 'humidity': 65, 'wind': 7},
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _generatePodcast() async {
    setState(() {
      _isGenerating = true;
      _episode = null;
      _audioBase64 = null;
    });

    try {
      final region = await preferencesService.getRegion() ?? 'Tamil Nadu';
      final episode = await podcastService.generateEpisode(
        region: region,
        crop: _selectedCrop,
        forecast: _mockForecast,
      );

      if (!mounted) return;
      setState(() {
        _episode = episode;
        _isGenerating = false;
        _isSynthesizing = true;
      });

      // Now synthesize audio
      final audio = await podcastService.synthesizeAudio(
        text: episode.script,
        languageCode: 'en',
      );

      if (mounted) {
        setState(() {
          _audioBase64 = audio;
          _isSynthesizing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _isSynthesizing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else if (_audioBase64 != null) {
      final bytes = base64Decode(_audioBase64!);
      await _audioPlayer.play(BytesSource(Uint8List.fromList(bytes)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nature50,
      body: CustomScrollView(
        slivers: [
          // Premium header
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back,
                    color: AppColors.gray800, size: 20),
              ),
              onPressed: widget.onBack,
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(60, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(LucideIcons.podcast,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Daily Farm Forecast',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'AI-powered disease risk podcast',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Body
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Crop selector
                _buildCropSelector(),
                const SizedBox(height: 20),

                // Generate button or player
                if (_episode == null)
                  _buildGenerateButton()
                else ...[
                  _buildPlayerCard(),
                  const SizedBox(height: 20),
                  _buildRiskCards(),
                  const SizedBox(height: 20),
                  _buildWeatherInsights(),
                  const SizedBox(height: 20),
                  _buildTranscriptSection(),
                  const SizedBox(height: 16),
                  _buildRegenerateButton(),
                ],

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4E6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.leaf,
                color: Color(0xFFE11D48), size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Select Your Crop',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.gray700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: DropdownButton<String>(
              value: _selectedCrop,
              underline: const SizedBox(),
              isDense: true,
              style: const TextStyle(
                color: Color(0xFFE11D48),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              items: _crops
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedCrop = v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generatePodcast,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 6,
          shadowColor: const Color(0xFFE11D48).withOpacity(0.4),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isGenerating
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'AI is crafting your podcast...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.sparkles,
                          color: Colors.white, size: 24),
                      SizedBox(width: 10),
                      Text(
                        "Generate Today's Forecast",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Episode title
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE11D48)
                              .withOpacity(0.6 + _pulseController.value * 0.4),
                          const Color(0xFFF43F5E)
                              .withOpacity(0.6 + _pulseController.value * 0.4),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(LucideIcons.podcast,
                        color: Colors.white, size: 28),
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _episode?.title ?? 'Your Daily Forecast',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_episode?.crop ?? ''} • ${_episode?.region ?? ''}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Waveform visualization
          SizedBox(
            height: 40,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(double.infinity, 40),
                  painter: _WaveformPainter(
                    progress: _waveController.value,
                    isPlaying: _isPlaying,
                    color: const Color(0xFFE11D48),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSynthesizing)
                Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white54, strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Generating audio...',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 14),
                    ),
                  ],
                )
              else if (_audioBase64 != null)
                GestureDetector(
                  onTap: _togglePlayback,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                )
              else
                Text(
                  'Audio unavailable. Read the transcript below.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 13),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskCards() {
    if (_episode == null) return const SizedBox();

    final risks = _episode!.riskLevels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Risk Assessment',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.gray800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (risks.containsKey('humidity'))
              Expanded(
                child: _buildSingleRiskCard(
                  'Humidity',
                  LucideIcons.droplet,
                  risks['humidity']!,
                ),
              ),
            const SizedBox(width: 10),
            if (risks.containsKey('wind'))
              Expanded(
                child: _buildSingleRiskCard(
                  'Wind',
                  LucideIcons.wind,
                  risks['wind']!,
                ),
              ),
            const SizedBox(width: 10),
            if (risks.containsKey('disease'))
              Expanded(
                child: _buildSingleRiskCard(
                  'Disease',
                  LucideIcons.bug,
                  risks['disease']!,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleRiskCard(
      String label, IconData icon, RiskLevel riskLevel) {
    Color bgColor;
    Color textColor;
    Color iconColor;

    switch (riskLevel.level.toLowerCase()) {
      case 'high':
        bgColor = const Color(0xFFFEF2F2);
        textColor = const Color(0xFFDC2626);
        iconColor = const Color(0xFFEF4444);
        break;
      case 'medium':
        bgColor = const Color(0xFFFFFBEB);
        textColor = const Color(0xFFD97706);
        iconColor = const Color(0xFFF59E0B);
        break;
      default:
        bgColor = const Color(0xFFF0FDF4);
        textColor = const Color(0xFF16A34A);
        iconColor = const Color(0xFF22C55E);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              riskLevel.level.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            riskLevel.explanation,
            style: TextStyle(
              fontSize: 10,
              color: textColor.withOpacity(0.8),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherInsights() {
    if (_episode == null || _episode!.weatherInsights.isEmpty) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.sky100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.cloudSun,
                    color: AppColors.sky500, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Weather Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gray800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._episode!.weatherInsights.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.sky50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.sky500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.gray700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildTranscriptSection() {
    if (_episode == null) return const SizedBox();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showTranscript = !_showTranscript),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.purple50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.fileText,
                        color: AppColors.purple600, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Full Transcript',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gray800,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showTranscript ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.gray400),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                _episode!.script,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.gray600,
                  height: 1.7,
                ),
              ),
            ),
            crossFadeState: _showTranscript
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildRegenerateButton() {
    return Center(
      child: TextButton.icon(
        onPressed: _isGenerating ? null : _generatePodcast,
        icon: const Icon(LucideIcons.refreshCw, size: 16),
        label: const Text('Generate New Episode'),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFE11D48),
        ),
      ),
    );
  }
}

// ─── Waveform Painter ──────────────────────────────────────────────────────
class _WaveformPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;
  final Color color;

  _WaveformPainter({
    required this.progress,
    required this.isPlaying,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isPlaying ? color : color.withOpacity(0.3)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final barCount = 30;
    final barWidth = size.width / (barCount * 2);

    for (int i = 0; i < barCount; i++) {
      final x = (i * 2 + 1) * barWidth;
      double height;

      if (isPlaying) {
        height = (math.sin((progress * math.pi * 2) + (i * 0.5)).abs()) *
                size.height *
                0.8 +
            size.height * 0.1;
      } else {
        height = (math.sin(i * 0.4).abs()) * size.height * 0.3 +
            size.height * 0.1;
      }

      final y1 = (size.height - height) / 2;
      final y2 = y1 + height;

      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isPlaying != isPlaying;
}
