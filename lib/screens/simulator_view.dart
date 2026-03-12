import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/simulator_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;

class SimulatorView extends StatefulWidget {
  final VoidCallback onBack;

  const SimulatorView({super.key, required this.onBack});

  @override
  State<SimulatorView> createState() => _SimulatorViewState();
}

class _SimulatorViewState extends State<SimulatorView>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  SimulatorResult? _result;

  String _selectedCrop = 'Tomato';
  final List<String> _crops = ['Tomato', 'Potato', 'Rice', 'Grape', 'Corn'];
  final List<String> _availableActions = [
    'Apply Fungicide',
    'Increase Irrigation',
    'Provide Shade',
    'Apply Fertilizer',
    'Prune Affected Leaves',
    'Improve Drainage',
  ];
  final Set<String> _selectedActions = {};

  final Map<String, dynamic> _currentConditions = {
    'temperature': 24,
    'humidity': 62,
    'soilMoisture': 'Normal',
  };

  final List<Map<String, dynamic>> _mockForecast = [
    {'day': 'Mon', 'temp': 25, 'humidity': 60, 'icon': Icons.wb_sunny},
    {'day': 'Tue', 'temp': 27, 'humidity': 65, 'icon': Icons.wb_cloudy},
    {'day': 'Wed', 'temp': 28, 'humidity': 70, 'icon': Icons.cloud},
    {'day': 'Thu', 'temp': 26, 'humidity': 85, 'icon': Icons.water_drop},
    {'day': 'Fri', 'temp': 24, 'humidity': 80, 'icon': Icons.water_drop},
    {'day': 'Sat', 'temp': 25, 'humidity': 75, 'icon': Icons.wb_cloudy},
    {'day': 'Sun', 'temp': 26, 'humidity': 65, 'icon': Icons.wb_sunny},
  ];

  late AnimationController _gaugeController;
  late Animation<double> _gaugeAnimation;

  @override
  void initState() {
    super.initState();
    _gaugeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _gaugeAnimation =
        CurvedAnimation(parent: _gaugeController, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _gaugeController.dispose();
    super.dispose();
  }

  Future<void> _runSimulation() async {
    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      // Map forecast to remove non-encodable IconData
      final forecastForBackend = _mockForecast.map((d) => {
        'day': d['day'],
        'temp': d['temp'],
        'humidity': d['humidity'],
      }).toList();

      final result = await simulatorService.getPrediction(
        crop: _selectedCrop,
        currentConditions: _currentConditions,
        forecast: forecastForBackend,
        actions: _selectedActions.toList(),
      );

      setState(() {
        _result = result;
      });
      _gaugeController.forward(from: 0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Simulation Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleAction(String action) {
    setState(() {
      if (_selectedActions.contains(action)) {
        _selectedActions.remove(action);
      } else {
        _selectedActions.add(action);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nature50,
      body: CustomScrollView(
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 120,
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
                child: const Icon(Icons.arrow_back, color: AppColors.gray800, size: 20),
              ),
              onPressed: widget.onBack,
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(60, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(LucideIcons.cloudLightning,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Micro-Climate Simulator',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Predict crop survival with What-If scenarios',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13),
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
                _buildCropSelector(),
                const SizedBox(height: 20),
                _buildSectionTitle('7-Day Humidity Forecast'),
                const SizedBox(height: 12),
                _buildHumidityChart(),
                const SizedBox(height: 24),
                _buildSectionTitle('Remediation Actions'),
                const SizedBox(height: 12),
                _buildActionsChips(),
                const SizedBox(height: 28),
                _buildRunButton(),
                const SizedBox(height: 28),
                if (_result != null && !_isLoading) ...[
                  _buildSectionTitle('Simulation Results'),
                  const SizedBox(height: 16),
                  _buildComparisonCards(),
                  const SizedBox(height: 20),
                  if (_result!.withRemediation.recommendedFurtherActions
                      .isNotEmpty)
                    _buildFurtherAdvice(),
                ],
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.gray800,
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.nature100, AppColors.teal50],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.leaf, color: AppColors.nature600),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Select Crop',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.gray700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.nature50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.nature200),
            ),
            child: DropdownButton<String>(
              value: _selectedCrop,
              underline: const SizedBox(),
              isDense: true,
              style: const TextStyle(
                color: AppColors.nature700,
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

  Widget _buildHumidityChart() {
    final maxHumidity = _mockForecast
        .map((d) => (d['humidity'] as int))
        .reduce((a, b) => a > b ? a : b);

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
        children: [
          // Chart bars
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _mockForecast.map((day) {
                final humidity = day['humidity'] as int;
                final fraction = humidity / (maxHumidity + 10);
                final isHigh = humidity > 75;
                final isMed = humidity > 65;

                Color barColor = isHigh
                    ? AppColors.error
                    : isMed
                        ? AppColors.amber500
                        : AppColors.nature500;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$humidity%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: barColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          height: 100 * fraction,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                barColor.withOpacity(0.7),
                                barColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Day labels
          Row(
            children: _mockForecast.map((day) {
              return Expanded(
                child: Column(
                  children: [
                    Icon(day['icon'] as IconData,
                        size: 16, color: AppColors.gray400),
                    const SizedBox(height: 2),
                    Text(
                      day['day'],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(AppColors.nature500, 'Safe (<65%)'),
              const SizedBox(width: 16),
              _buildLegendDot(AppColors.amber500, 'Caution (65-75%)'),
              const SizedBox(width: 16),
              _buildLegendDot(AppColors.error, 'High Risk (>75%)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.gray500)),
      ],
    );
  }

  Widget _buildActionsChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _availableActions.map((action) {
        final isSelected = _selectedActions.contains(action);
        return FilterChip(
          label: Text(action),
          selected: isSelected,
          onSelected: (_) => _toggleAction(action),
          selectedColor: AppColors.indigo100,
          checkmarkColor: AppColors.indigo600,
          backgroundColor: Colors.white,
          elevation: isSelected ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? AppColors.indigo600 : AppColors.gray200,
            ),
          ),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.indigo600 : AppColors.gray700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRunButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _runSimulation,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: const Color(0xFF4F46E5).withOpacity(0.4),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.play, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Run Simulation',
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

  // ─── Comparison Cards ────────────────────────────────────────────────
  Widget _buildComparisonCards() {
    return Row(
      children: [
        Expanded(
          child: _buildScenarioCard(
            title: 'No Action',
            icon: LucideIcons.alertTriangle,
            prediction: _result!.noAction,
            headerGradient: const [Color(0xFFEF4444), Color(0xFFF87171)],
            cardColor: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFECACA),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildScenarioCard(
            title: 'With Remediation',
            icon: LucideIcons.shieldCheck,
            prediction: _result!.withRemediation,
            headerGradient: const [Color(0xFF059669), Color(0xFF10B981)],
            cardColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFFA7F3D0),
          ),
        ),
      ],
    );
  }

  Widget _buildScenarioCard({
    required String title,
    required IconData icon,
    required ScenarioPrediction prediction,
    required List<Color> headerGradient,
    required Color cardColor,
    required Color borderColor,
  }) {
    final rate = prediction.survivalRate;
    final rateColor = rate >= 70
        ? AppColors.nature600
        : (rate >= 45 ? AppColors.amber600 : AppColors.error);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: headerGradient),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Animated gauge
                AnimatedBuilder(
                  animation: _gaugeAnimation,
                  builder: (context, _) {
                    return SizedBox(
                      width: 100,
                      height: 100,
                      child: CustomPaint(
                        painter: _GaugePainter(
                          progress: _gaugeAnimation.value * rate / 100,
                          color: rateColor,
                          bgColor: AppColors.gray200,
                        ),
                        child: Center(
                          child: Text(
                            '${(_gaugeAnimation.value * rate).round()}%',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: rateColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Survival Rate',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.gray500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  prediction.predictedOutcome,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray800,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  prediction.rationale,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.gray500,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFurtherAdvice() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.nature200),
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
                  color: AppColors.nature100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(LucideIcons.lightbulb, color: AppColors.nature600, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Further Advice',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gray800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._result!.withRemediation.recommendedFurtherActions.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    child: const Icon(Icons.check_circle,
                        size: 18, color: AppColors.nature600),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      a,
                      style: const TextStyle(
                        color: AppColors.gray700,
                        fontSize: 14,
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
}

// ─── Gauge Painter ──────────────────────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _GaugePainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;

    // Background arc
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
