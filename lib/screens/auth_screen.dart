import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../widgets/create_account_form.dart';
import '../widgets/login_form.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialTabIndex = 1});

  /// 0 for Login, 1 for Create Account
  final int initialTabIndex;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSuccess() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Premium Background Image with Overlay
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1596436889106-be35e843f974?q=80&w=800&auto=format&fit=crop',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF1E1B4B),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    const Color(0xFF080B1E).withValues(alpha: 0.6),
                    const Color(0xFF080B1E).withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Smart Travel Planner',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Hero Branding Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: const Icon(Icons.explore, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Malaysia Travel Portal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Access AI itineraries, weather alerts, and smart route optimization.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Card Container holding TabBar & Forms (FR100_1 & FR100_2)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        // Drag Handle
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tab Bar [Log In | Create Account]
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9), // Light slate gray background
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              indicatorPadding: EdgeInsets.zero,
                              labelPadding: EdgeInsets.zero,
                              overlayColor: WidgetStateProperty.all(Colors.transparent),
                              indicator: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              labelColor: Colors.white,
                              unselectedLabelColor: AppColors.muted,
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              unselectedLabelStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              tabs: const [
                                Tab(text: 'Log In'),
                                Tab(text: 'Create Account'),
                              ],
                            ),
                          ),
                        ),

                        // Tab View Content
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              LoginForm(onSuccess: _onSuccess),
                              CreateAccountForm(onSuccess: _onSuccess),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
