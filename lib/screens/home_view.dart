import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/translation_service.dart';
import '../services/consent_service.dart';
import '../services/offline_storage_service.dart';
import '../services/preferences_service.dart';
import '../services/location_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/region_service.dart';
import '../services/alert_manager.dart';
import '../models/alert_models.dart';
import '../services/task_reminder_service.dart';
import '../services/socket_service.dart';
import '../widgets/notification_panel.dart';

/// HomeView - Main app home screen with action grid.
/// 
/// Features:
/// - Dynamic greeting based on time of day.
/// - Guest mode banner (US6).
/// - Quick actions grid for main features (Scan, Upload, Voice, Record, History, LLM Advice).
/// - Weather widget.
/// - Pest alert and quick tips.
/// 
/// Matches React's `HomeView` component in `CropDiagnosisApp.jsx`.
class HomeView extends StatefulWidget {
  final Function(String) onNavigate;
  final bool isOnline;

  const HomeView({
    super.key,
    required this.onNavigate,
    this.isOnline = true,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _isGuest = false;
  int _pendingSyncCount = 0; // US15: Pending offline sync count
  bool _showNotifications = false;
  int _pendingReminderCount = 0;
  Timer? _reminderCountTimer;
  final List<StreamSubscription> _socketSubs = [];
  
  static bool _hasShownWelcome = false;

  @override
  void initState() {
    super.initState();
    _checkGuestMode();
    _loadPendingSyncCount();
    _checkRegionSetup();
    _loadPendingReminderCount();

    // Refresh pending count every 30s
    _reminderCountTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadPendingReminderCount(),
    );

    // Listen to socket events for real-time badge updates
    _socketSubs.add(
      SocketService.instance.onReminderStatusChanged.listen((_) => _loadPendingReminderCount()),
    );
    _socketSubs.add(
      SocketService.instance.onReminderCreated.listen((_) => _loadPendingReminderCount()),
    );
    _socketSubs.add(
      SocketService.instance.onReminderDeleted.listen((_) => _loadPendingReminderCount()),
    );

    // Show welcome alert only once per session
    if (!_hasShownWelcome) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            AlertManager.showInfo(
              context,
              'Welcome to CropAId! Tap Scan to start diagnosing your plants.',
              urgency: UrgencyLevel.low,
            );
            _hasShownWelcome = true;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _reminderCountTimer?.cancel();
    for (final sub in _socketSubs) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _loadPendingReminderCount() async {
    final userId = await preferencesService.getUserId();
    if (userId == null || userId.isEmpty) return;
    final reminders = await TaskReminderService.fetchTodayReminders(userId);
    final pending = reminders.where((r) => r.status == 'pending').length;
    if (mounted) {
      setState(() => _pendingReminderCount = pending);
    }
  }

  /// Checks if the user is in guest mode to display the banner.
  Future<void> _checkGuestMode() async {
    final isGuest = await consentService.isGuestMode();
    if (mounted) {
      setState(() {
        _isGuest = isGuest;
      });
    }
  }

  /// US15: Loads the count of pending offline media items.
  Future<void> _loadPendingSyncCount() async {
    final count = await offlineStorageService.getPendingCount();
    if (mounted) {
      setState(() => _pendingSyncCount = count);
    }
  }

  /// US27: Checks if region is set, if not, prompts user.
  Future<void> _checkRegionSetup() async {
    final region = await preferencesService.getRegion();
    if (region == null) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _showRegionSetupDialog();
        }
      });
    }
  }

  Future<void> _showRegionSetupDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Localize Your Advice'),
        content: const Text(
          'To provide treatment advice specific to your regional climate, we need to know your state. Would you like to auto-detect your location or select manually?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualRegionSelection();
            },
            child: const Text('Select Manually'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _autoDetectRegion();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.nature600),
            child: const Text('Auto-detect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showManualRegionSelection() async {
    final List<String> regions = ['Tamil Nadu', 'Punjab', 'Maharashtra'];
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select State'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: regions.map((r) => ListTile(
            title: Text(r),
            onTap: () => Navigator.pop(context, r),
          )).toList(),
        ),
      ),
    );

    if (result != null && mounted) {
      await preferencesService.setRegion(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Region set to $result')),
      );
    }
  }

  Future<void> _autoDetectRegion() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detecting your location...'), duration: Duration(seconds: 2)),
      );

      final position = await LocationService.getCurrentPosition();
      final region = RegionService.getRegionFromCoordinates(position.latitude, position.longitude);

      if (region != null && mounted) {
        await preferencesService.setRegion(region);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Detected Region: $region')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not determine region. Please select manually.')),
        );
        _showManualRegionSelection();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
        _showManualRegionSelection();
      }
    }
  }

  /// Returns the translation key for the greeting based on the current hour.
  String _getGreetingKey() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'homeView.greeting.morning';
    if (hour < 17) return 'homeView.greeting.afternoon';
    return 'homeView.greeting.evening';
  }

  void _showLinkDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link with Web'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Sync Code shown on the web calendar screen to see the same reminders.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Sync Code',
                hintText: 'e.g. fd60169372f79f4e16c317a2',
                border: OutlineInputBorder(),
              ),
              maxLength: 24,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isEmpty) return;
              await preferencesService.setUserId(code);
              SocketService.instance.disconnect();
              SocketService.instance.connect(code);
              if (mounted) Navigator.pop(ctx);
              _loadPendingReminderCount();
            },
            child: const Text('Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main scrollable content
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.nature50,
                Color(0xFFD1FAE5), // emerald-50
                Color(0xFFCCFBF1), // teal-50
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(context),
                  const SizedBox(height: 24),

                  // US6: Guest Mode Banner
                  if (_isGuest) ...[
                    _buildGuestBanner(context),
                    const SizedBox(height: 24),
                  ],

                  // Main Actions Grid
                  _buildMainActionsGrid(context),
                  const SizedBox(height: 16),

                  // Pest Alert
                  _buildPestAlert(context),
                  const SizedBox(height: 16),

                  // Weather Widget
                  _buildWeatherWidget(context),
                  const SizedBox(height: 24),

                  // Quick Tip
                  _buildQuickTip(context),
                  const SizedBox(height: 16),

                  // Status Footer
                  _buildStatusFooter(context),
                ],
              ),
            ),
          ),
        ),

        // Notification panel overlay
        if (_showNotifications) ...[
          // Tap-to-close backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showNotifications = false),
              child: Container(color: Colors.black26),
            ),
          ),
          // Panel positioned below header
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0,
            right: 0,
            child: NotificationPanel(
              onClose: () => setState(() => _showNotifications = false),
              onViewAll: () {
                setState(() => _showNotifications = false);
                widget.onNavigate('reminders');
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Builds the guest mode banner prompting users to sign up.
  Widget _buildGuestBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.purple50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purple200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.purple100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_add, color: AppColors.purple600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest Mode',
                  style: TextStyle(
                    color: AppColors.purple700,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Sign up to save your diagnosis capability.',
                  style: TextStyle(
                    color: AppColors.purple600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => widget.onNavigate('login'), // Redirect to login
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }


  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              // App Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.eco,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.t(_getGreetingKey())},',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.gray500,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      context.t('homeView.userTitle'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.gray800,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            // Notification Bell Button
            Stack(
              children: [
                _buildHeaderButton(
                  context,
                  icon: _showNotifications
                      ? Icons.notifications_active
                      : Icons.notifications_outlined,
                  onTap: () {
                    setState(() => _showNotifications = !_showNotifications);
                  },
                ),
                if (_pendingReminderCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          _pendingReminderCount > 9
                              ? '9+'
                              : '$_pendingReminderCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
             // Audio Settings Button
            _buildHeaderButton(
              context,
              icon: Icons.volume_up,
              onTap: () => widget.onNavigate('audio-settings'),
            ),
            const SizedBox(width: 8),
            // Settings Button
            _buildHeaderButton(
              context,
              icon: Icons.settings,
              onTap: () => widget.onNavigate('settings'),
            ),
            const SizedBox(width: 8),
            // Profile Button
            Stack(
              children: [
                _buildHeaderButton(
                  context,
                  icon: Icons.person_outline,
                  onTap: () => widget.onNavigate('profile'),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderButton(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(50),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 20, color: AppColors.gray600),
        ),
      ),
    );
  }

  /// Builds the main grid of action buttons.
  /// 
  /// layout adapts based on screen width.
  Widget _buildMainActionsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate aspect ratio dynamically based on width
        // Wider screens -> wider columns -> can translate to efficient ratio
        // Narrow screens -> thicker columns -> need taller cards (lower ratio)
        double aspectRatio = 0.8; 
        if (constraints.maxWidth < 360) {
          aspectRatio = 0.70; // Very small devices
        } else if (constraints.maxWidth < 600) {
          aspectRatio = 0.75; // Typical phones
        } else {
          aspectRatio = 1.0; // Tablets
        }

        return Column(
          children: [
            // Scan Plant - Full Width
            _buildScanPlantCard(context),
            const SizedBox(height: 16),

            // Action Grid
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: aspectRatio,
              children: [
                _buildActionCard(
                  context,
                  icon: LucideIcons.uploadCloud,
                  label: context.t('homeView.actions.upload'),
                  color: AppColors.blue500,
                  bgColor: AppColors.blue100,
                  bgColorLight: AppColors.blue50,
                  onTap: () => widget.onNavigate('upload'),
                ),
                _buildActionCard(
                  context,
                  icon: LucideIcons.mic,
                  label: context.t('homeView.actions.voice'),
                  color: AppColors.purple600,
                  bgColor: AppColors.purple100,
                  bgColorLight: AppColors.purple50,
                  onTap: () => widget.onNavigate('voice'),
                ),
                _buildActionCard(
                  context,
                  icon: LucideIcons.video,
                  label: context.t('homeView.actions.record'),
                  color: AppColors.red500,
                  bgColor: AppColors.red100,
                  bgColorLight: AppColors.red50,
                  onTap: () => widget.onNavigate('video'),
                ),
                _buildActionCard(
                  context,
                  icon: LucideIcons.history,
                  label: context.t('homeView.actions.history'),
                  color: AppColors.amber600,
                  bgColor: AppColors.amber100,
                  bgColorLight: AppColors.amber50,
                  onTap: () => widget.onNavigate('history'),
                ),
                _buildActionCard(
                  context,
                  icon: LucideIcons.sparkles,
                  label: context.t('homeView.actions.llmAdvice'),
                  color: const Color(0xFF059669),
                  bgColor: const Color(0xFFD1FAE5),
                  bgColorLight: AppColors.teal50,
                  onTap: () => widget.onNavigate('llm-advice'),
                ),
                _buildActionCard(
                  context,
                  icon: LucideIcons.cloudLightning,
                  label: 'What-If Simulator',
                  color: AppColors.indigo600,
                  bgColor: AppColors.indigo100,
                  bgColorLight: AppColors.indigo50,
                  onTap: () => widget.onNavigate('simulator'),
                ),
                _buildActionCard(
                  context,
                  icon: LucideIcons.podcast,
                  label: 'AI Podcast',
                  color: const Color(0xFFE11D48),
                  bgColor: const Color(0xFFFFE4E6),
                  bgColorLight: const Color(0xFFFFF1F2),
                  onTap: () => widget.onNavigate('podcast'),
                ),

              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildScanPlantCard(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      shadowColor: const Color(0xFF10B981).withOpacity(0.3),
      child: InkWell(
        onTap: () => widget.onNavigate('camera'),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF10B981), Color(0xFF22C55E)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        context.t('homeView.aiPowered'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        context.t('homeView.scanPlant'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t('homeView.scanPlantDesc'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required Color bgColorLight,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12), // Reduced padding slightly
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray100),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bgColor, bgColorLight],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: AppColors.gray800,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPestAlert(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFEF3C7), Color(0xFFFED7AA)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.amber100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 24,
              color: AppColors.amber600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('homeView.pestAlert.title'),
                  style: TextStyle(
                    color: AppColors.amber700,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  context.t('homeView.pestAlert.desc'),
                  style: TextStyle(
                    color: AppColors.amber600.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherWidget(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.sky100, AppColors.sky50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud,
                  size: 40,
                  color: AppColors.sky500,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '24°C',
                    style: TextStyle(
                      color: AppColors.gray800,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Partly Cloudy',
                    style: TextStyle(
                      color: AppColors.gray500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _buildWeatherStat(Icons.water_drop, '62%'),
              const SizedBox(width: 24),
              _buildWeatherStat(Icons.air, '8km/h'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherStat(IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.blue500),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppColors.gray600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), AppColors.teal600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
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
              const Icon(Icons.auto_awesome, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                context.t('homeView.quickTip.title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.t('homeView.quickTip.desc'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatusItem(
          widget.isOnline ? Colors.green : AppColors.amber600,
          widget.isOnline ? context.t('homeView.status.online') : context.t('homeView.status.offline'),
        ),
        const SizedBox(width: 24),
        // US15: Offline sync indicator
        if (_pendingSyncCount > 0)
          _buildStatusItem(
            AppColors.amber600,
            '$_pendingSyncCount pending',
            icon: Icons.cloud_upload,
          ),
        if (_pendingSyncCount > 0)
          const SizedBox(width: 24),
        _buildStatusItem(
          AppColors.gray500,
          context.t('homeView.status.mobile'),
          icon: Icons.smartphone,
        ),
      ],
    );
  }

  Widget _buildStatusItem(Color color, String label, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: color),
        ] else ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: AppColors.gray500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
