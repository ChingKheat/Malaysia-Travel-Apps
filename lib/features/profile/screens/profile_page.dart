import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/core/theme/app_decorations.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/admin/screens/admin_places_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthService();
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;

  Future<void> _editProfile() async {
    final user = _authService.currentUser;
    if (user == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _EditProfileDialog(initialName: user.name),
    );
    if (!mounted || name == null) return;
    if (name.trim().isEmpty) {
      showDemoSnackBar(context, AuthService.m2NameRequired);
      return;
    }
    final saved = await _authService.updateProfile(name: name);
    if (!mounted) return;
    setState(() {});
    showDemoSnackBar(
      context,
      saved ? AuthService.m1ProfileUpdated : AuthService.m3ProfileSaveError,
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out of your travel profile?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back from profile screen
              _authService.logout();
              showDemoSnackBar(
                context,
                'Successfully logged out.',
                icon: Icons.logout_outlined,
              );
            },
            child: const Text(
              'Log Out',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No active profile found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          children: [
            // User Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: cardDecoration(Colors.white),
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        backgroundImage: NetworkImage(user.avatarUrl),
                        onBackgroundImageError: (_, _) {},
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Email
                  Text(
                    user.email,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Nationality & Travel Style Badges
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBadge(
                        user.nationality,
                        Colors.blue.shade50,
                        Colors.blue.shade700,
                      ),

                      _buildBadge(
                        user.travelStyle,
                        Colors.purple.shade50,
                        Colors.purple.shade700,
                      ),
                      if (user.isAdmin)
                        _buildBadge(
                          '👑 Admin',
                          const Color(0xFFFEF3C7),
                          const Color(0xFFB45309),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats Grid
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    label: 'Trips Planned',
                    value: '${user.tripsPlanned}',
                    icon: Icons.event_note,
                    iconColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    label: 'Places Visited',
                    value: '${user.placesVisited}',
                    icon: Icons.explore,
                    iconColor: AppColors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Profile Settings
            Container(
              decoration: cardDecoration(Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      'Account Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  _buildListTile(
                    icon: Icons.edit_outlined,
                    title: 'Edit Profile',
                    subtitle: 'Change your full name',
                    onTap: _editProfile,
                  ),
                  const Divider(height: 1, color: AppColors.line, indent: 56),
                  _buildListTile(
                    icon: Icons.language,
                    title: 'App Language',
                    subtitle: 'English (United States)',
                    onTap: () => showDemoSheet(
                      context,
                      title: 'Language Support',
                      body:
                          'Our app supports English, Malay (Bahasa Melayu), and Chinese (简体中文). You can update your language preferences anytime.',
                      icon: Icons.translate,
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.line, indent: 56),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      value: _notificationsEnabled,
                      onChanged: (val) {
                        setState(() => _notificationsEnabled = val);
                        demoHaptic();
                      },
                      secondary: const Icon(
                        Icons.notifications_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Push Notifications',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.line, indent: 56),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      value: _darkModeEnabled,
                      onChanged: (val) {
                        setState(() => _darkModeEnabled = val);
                        demoHaptic();
                        showDemoSnackBar(
                          context,
                          'Dark mode is not supported in the demo version.',
                        );
                      },
                      secondary: const Icon(
                        Icons.dark_mode_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Dark Mode',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // General & Support
            Container(
              decoration: cardDecoration(Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      'Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  _buildListTile(
                    icon: Icons.info_outline,
                    title: 'About Smart Travel Planner',
                    subtitle: 'v1.0.0 (FYP Prototype Demo)',
                    onTap: () => showDemoSheet(
                      context,
                      title: 'About App',
                      body:
                          'This app is a prototype designed for a Final Year Project to showcase automated route scheduling and map visualization in Malaysia.',
                      icon: Icons.info,
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.line, indent: 56),
                  _buildListTile(
                    icon: Icons.description_outlined,
                    title: 'Privacy Policy & Terms',
                    subtitle: 'Read our terms of service',
                    onTap: () => showDemoSheet(
                      context,
                      title: 'Privacy & Terms',
                      body:
                          'By using this app, you agree to our terms of service. No real personal data is collected or sent to any server.',
                      icon: Icons.description,
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.line, indent: 56),
                  _buildListTile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Admin Database Hub',
                    subtitle: user.isAdmin
                        ? 'Secret portal to fetch & sync places'
                        : 'Admin access (Tap to log in as admin)',
                    onTap: () {
                      if (!user.isAdmin) {
                        _showAdminLoginDialog(context);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminPlacesScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Log Out Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: iconColor.withValues(alpha: 0.12),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.ink,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: AppColors.muted,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showAdminLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Admin Hub Access'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The Admin Database Hub requires administrator privileges to fetch, sync, and import places from Google.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 14),
            Text(
              'Default Admin Account:\nEmail: chingkheat@example.com\nPassword: SafeP@ss123!',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Login as Admin'),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await AuthService().login(
                'chingkheat@example.com',
                'SafeP@ss123!',
              );
              if (res && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logged in as Administrator (Ching Kheat)'),
                  ),
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPlacesScreen()),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit profile'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: 'Full name'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}
