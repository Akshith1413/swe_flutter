import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/translation_service.dart';
import '../core/localization/language_provider.dart';

/// User Profile View - User profile and settings
/// Matches React's UserProfile component with localization
class UserProfileView extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onLogout;
  final VoidCallback? onLanguageChange;

  const UserProfileView({
    super.key,
    required this.onBack,
    this.onLogout,
    this.onLanguageChange,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLang = languageProvider.supportedLanguages.firstWhere(
      (l) => l['code'] == languageProvider.currentLanguage,
      orElse: () => {'name': 'English', 'nativeName': 'English'},
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
          color: AppColors.gray700,
        ),
        title: Text(
          context.t('userProfile.title'),
          style: const TextStyle(color: AppColors.gray800),
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
            children: [
              // Stats Cards
              _buildStatsRow(context),
              const SizedBox(height: 24),

              // Settings Section
              _buildSettingsSection(context, currentLang),
              const SizedBox(height: 24),

              // Logout Button
              if (onLogout != null)
                TextButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout, color: AppColors.red500),
                  label: Text(
                    context.t('userProfile.logout'),
                    style: const TextStyle(color: AppColors.red500, fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        _buildStatCard(context, '12', context.t('userProfile.scans'), Icons.camera_alt, AppColors.blue500),
        const SizedBox(width: 12),
        _buildStatCard(context, '8', context.t('userProfile.diseases'), Icons.bug_report, AppColors.amber600),
        const SizedBox(width: 12),
        _buildStatCard(context, '3', context.t('userProfile.crops'), Icons.eco, AppColors.nature600),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.gray800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, Map<String, dynamic> currentLang) {
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
      child: Column(
        children: [
          _buildSettingsItem(
            context: context,
            icon: Icons.eco,
            title: context.t('userProfile.myCrops'),
            subtitle: context.t('userProfile.cropsRegistered'),
            onTap: () {},
          ),
          _buildDivider(),
          _buildSettingsItem(
            context: context,
            icon: Icons.language,
            title: context.t('userProfile.language'),
            subtitle: currentLang['nativeName'] ?? 'English',
            onTap: onLanguageChange,
          ),
          _buildDivider(),
          _buildSettingsItem(
            context: context,
            icon: Icons.notifications,
            title: context.t('userProfile.notifications'),
            subtitle: context.t('userProfile.notificationsDesc'),
            onTap: () {},
          ),
          _buildDivider(),
          _buildSettingsItem(
            context: context,
            icon: Icons.help_outline,
            title: context.t('userProfile.helpSupport'),
            subtitle: context.t('userProfile.helpSupportDesc'),
            onTap: () {},
          ),
          _buildDivider(),
          _buildSettingsItem(
            context: context,
            icon: Icons.info_outline,
            title: context.t('userProfile.about'),
            subtitle: context.t('userProfile.version'),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.gray400),
            ],
          ),
        ),
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
