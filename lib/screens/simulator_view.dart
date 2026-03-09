import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/simulator_service.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SimulatorView extends StatefulWidget {
  final VoidCallback onBack;

  const SimulatorView({super.key, required this.onBack});

  @override
  State<SimulatorView> createState() => _SimulatorViewState();
}

class _SimulatorViewState extends State<SimulatorView> {
  bool _isLoading = false;
  SimulatorPrediction? _prediction;

  // Mock initial state for simulation
  String _selectedCrop = 'Tomato';
  final List<String> _availableActions = [
    'Apply Fungicide',
    'Increase Irrigation',
    'Provide Shade',
    'Apply Fertilizer'
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
    {'day': 'Thu', 'temp': 26, 'humidity': 85, 'icon': Icons.water_drop}, // Rain expected
    {'day': 'Fri', 'temp': 24, 'humidity': 80, 'icon': Icons.water_drop},
    {'day': 'Sat', 'temp': 25, 'humidity': 75, 'icon': Icons.wb_cloudy},
    {'day': 'Sun', 'temp': 26, 'humidity': 65, 'icon': Icons.wb_sunny},
  ];

  Future<void> _runSimulation() async {
    setState(() {
      _isLoading = true;
      _prediction = null;
    });

    try {
      final prediction = await simulatorService.getPrediction(
        crop: _selectedCrop,
        currentConditions: _currentConditions,
        forecast: _mockForecast,
        actions: _selectedActions.toList(),
      );

      setState(() {
        _prediction = prediction;
      });
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
        setState(() {
          _isLoading = false;
        });
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
      // Running simulation automatically when toggling could be a nice effect,
      // but to save API calls, we require an explicit Run button.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nature50,
      appBar: AppBar(
        title: const Text('Micro-Climate Simulator', style: TextStyle(color: AppColors.gray800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray800),
          onPressed: widget.onBack,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            Text(
              '7-Day Forecast',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildForecastRow(),
            const SizedBox(height: 24),
            Text(
              'Remediation Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildActionsList(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _runSimulation,
                icon: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.play),
                label: const Text('Run Simulation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.nature600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_prediction != null && !_isLoading) _buildPredictionResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.nature100, AppColors.teal50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.nature200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.leaf, color: AppColors.nature600),
              const SizedBox(width: 8),
              Text(
                'Crop: $_selectedCrop',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Test "What-if" scenarios by selecting actions to prevent crop damage before bad weather hits.',
            style: TextStyle(color: AppColors.gray600),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _mockForecast.map((day) {
          final isRain = day['humidity'] > 75;
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: isRain ? AppColors.blue50 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isRain ? AppColors.blue200 : AppColors.gray200),
            ),
            child: Column(
              children: [
                Text(day['day'], style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.gray700)),
                const SizedBox(height: 8),
                Icon(day['icon'], color: isRain ? AppColors.blue500 : AppColors.amber500),
                const SizedBox(height: 8),
                Text('${day['temp']}°C', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${day['humidity']}% H', style: TextStyle(fontSize: 12, color: AppColors.gray500)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionsList() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _availableActions.map((action) {
        final isSelected = _selectedActions.contains(action);
        return FilterChip(
          label: Text(action),
          selected: isSelected,
          onSelected: (_) => _toggleAction(action),
          selectedColor: AppColors.nature100,
          checkmarkColor: AppColors.nature600,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? AppColors.nature600 : AppColors.gray300)),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.nature700 : AppColors.gray700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPredictionResult() {
    final rate = _prediction!.survivalRate;
    final color = rate >= 80 ? AppColors.nature600 : (rate >= 50 ? AppColors.amber600 : AppColors.error);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Survival Odds', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$rate%',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: rate / 100,
            backgroundColor: AppColors.gray200,
            color: color,
            minHeight: 12,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 24),
          const Text('Predicted Outcome', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gray700)),
          const SizedBox(height: 4),
          Text(_prediction!.predictedOutcome, style: const TextStyle(fontSize: 16, color: AppColors.gray800)),
          const SizedBox(height: 16),
          const Text('Rationale', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gray700)),
          const SizedBox(height: 4),
          Text(_prediction!.rationale, style: const TextStyle(fontSize: 15, color: AppColors.gray600, height: 1.5)),
          if (_prediction!.recommendedFurtherActions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Further Advice', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gray700)),
            const SizedBox(height: 8),
            ..._prediction!.recommendedFurtherActions.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4, right: 8),
                        child: Icon(Icons.check_circle_outline, size: 16, color: AppColors.nature600),
                      ),
                      Expanded(child: Text(a, style: const TextStyle(color: AppColors.gray700))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
