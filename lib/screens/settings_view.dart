import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Settings View - App settings
/// Matches React's settings components
class SettingsView extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onLanguageChange;

  const SettingsView({
    super.key,
    required this.onBack,
    this.onLanguageChange,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _pushNotifications = true;
  bool _pestAlerts = true;
  bool _soundEnabled = true;
  bool _darkMode = false;

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
        title: const Text(
          'Settings',
          style: TextStyle(color: AppColors.gray800),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.nature50, Color(0xFFD1FAE5)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // General Section
              _buildSectionTitle('General'),
              const SizedBox(height: 12),
              _buildSettingsCard([
                _buildSettingsItem(
                  icon: Icons.language,
                  title: 'Language',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'English',
                        style: TextStyle(color: AppColors.gray500),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: AppColors.gray400),
                    ],
                  ),
                  onTap: widget.onLanguageChange,
                ),
                _buildDivider(),
                _buildSwitchItem(
                  icon: Icons.dark_mode,
                  title: 'Dark Mode',
                  value: _darkMode,
                  onChanged: (val) => setState(() => _darkMode = val),
                ),
              ]),

              const SizedBox(height: 24),

              // Notifications Section
              _buildSectionTitle('Notifications'),
              const SizedBox(height: 12),
              _buildSettingsCard([
                _buildSwitchItem(
                  icon: Icons.notifications,
                  title: 'Push Notifications',
                  value: _pushNotifications,
                  onChanged: (val) => setState(() => _pushNotifications = val),
                ),
                _buildDivider(),
                _buildSwitchItem(
                  icon: Icons.warning_amber,
                  title: 'Pest Alerts',
                  value: _pestAlerts,
                  onChanged: (val) => setState(() => _pestAlerts = val),
                ),
              ]),

              const SizedBox(height: 24),

              // Audio Section
              _buildSectionTitle('Audio'),
              const SizedBox(height: 12),
              _buildSettingsCard([
                _buildSwitchItem(
                  icon: Icons.volume_up,
                  title: 'Sound Effects',
                  value: _soundEnabled,
                  onChanged: (val) => setState(() => _soundEnabled = val),
                ),
                _buildDivider(),
                _buildSettingsItem(
                  icon: Icons.record_voice_over,
                  title: 'Voice Settings',
                  trailing: Icon(Icons.chevron_right, color: AppColors.gray400),
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 24),

              // About Section
              _buildSectionTitle('About'),
              const SizedBox(height: 12),
              _buildSettingsCard([
                _buildSettingsItem(
                  icon: Icons.info_outline,
                  title: 'App Version',
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(color: AppColors.gray500),
                  ),
                ),
                _buildDivider(),
                _buildSettingsItem(
                  icon: Icons.description,
                  title: 'Terms of Service',
                  trailing: Icon(Icons.chevron_right, color: AppColors.gray400),
                  onTap: () {},
                ),
                _buildDivider(),
                _buildSettingsItem(
                  icon: Icons.privacy_tip,
                  title: 'Privacy Policy',
                  trailing: Icon(Icons.chevron_right, color: AppColors.gray400),
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 32),

              // Clear Data Button
              Center(
                child: TextButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.delete_outline, color: AppColors.red500),
                  label: Text(
                    'Clear App Data',
                    style: TextStyle(color: AppColors.red500, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.gray600,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.nature100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: AppColors.nature600),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray800,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.nature100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: AppColors.nature600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.gray800,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.nature600,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 68,
      color: AppColors.gray100,
    );
  }
}
