import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2342),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProfileCard(),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Business',
              items: [
                _SettingsItem(
                  icon: Icons.storefront_outlined,
                  title: 'Business Details',
                  subtitle: 'Name, type, contact info',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Security',
              items: [
                _SettingsItem(
                  icon: Icons.lock_outline,
                  title: 'Change PIN',
                  subtitle: 'Update app security PIN',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  subtitle: 'Log out of your account',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Data & Sync',
              items: [
                _SettingsItem(
                  icon: Icons.backup_outlined,
                  title: 'Backup Data',
                  subtitle: 'Create a secure backup',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.restore_outlined,
                  title: 'Restore Data',
                  subtitle: 'Recover saved data',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Notifications',
              items: [
                _SettingsItem(
                  icon: Icons.notifications_active_outlined,
                  title: 'Payment Reminders',
                  subtitle: 'Alerts for due payments',
                  trailing: Switch(
                    value: true,
                    activeColor: const Color(0xFF0A2342),
                    onChanged: (_) {},
                  ),
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.alarm_outlined,
                  title: 'Due Date Alerts',
                  subtitle: 'Daily and weekly reminders',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Preferences',
              items: [
                _SettingsItem(
                  icon: Icons.palette_outlined,
                  title: 'Theme',
                  subtitle: 'Light mode',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.language_outlined,
                  title: 'Language',
                  subtitle: 'English',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.calendar_month_outlined,
                  title: 'Date Format',
                  subtitle: 'DD/MM/YYYY',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.numbers_outlined,
                  title: 'Number Format',
                  subtitle: '2 decimal places',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Danger Zone',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsItem(
                    icon: Icons.delete_outline,
                    title: 'Delete Business',
                    subtitle: 'Permanently remove this business',
                    trailing: const Icon(Icons.chevron_right),
                    textColor: Colors.red,
                    iconColor: Colors.red,
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: Icons.restart_alt_outlined,
                    title: 'Reset App Data',
                    subtitle: 'Clear local data and cache',
                    trailing: const Icon(Icons.chevron_right),
                    textColor: Colors.red,
                    iconColor: Colors.red,
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.business,
              color: Color(0xFF0A2342),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yahya & Co',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A2342),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Trading Business',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF0A2342)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SectionCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A2342),
              ),
            ),
          ),
          ...items,
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final Color iconColor;
  final Color textColor;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.iconColor = const Color(0xFF0A2342),
    this.textColor = const Color(0xFF0A2342),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
