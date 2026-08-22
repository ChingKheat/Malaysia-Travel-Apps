import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/demo_feedback.dart';
import '../services/auth_service.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  String? _errorMessage;
  Set<String> _highlightedEmptyFields = {};

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    demoHaptic();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _highlightedEmptyFields.clear();
    });

    final result = await _authService.loginUser(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (!result.success) {
        _errorMessage = result.message;
        _highlightedEmptyFields = result.emptyFields;
      }
    });

    if (result.success) {
      // Display M1 SnackBar
      showDemoSnackBar(
        context,
        AuthService.m1LoginSuccess,
        icon: Icons.check_circle_outline,
      );
      widget.onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sign in to manage your Malaysia travel plans.',
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 20),

          // Error Banner (M2 - M6)
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade200, width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Field 1: Email Address
          _buildLabel('Email Address', isMandatory: true),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hint: 'e.g. tourist@example.com',
              icon: Icons.email_outlined,
              isError: _highlightedEmptyFields.contains('email'),
            ),
          ),
          const SizedBox(height: 16),

          // Field 2: Password
          _buildLabel('Password', isMandatory: true),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleLogin(),
            decoration: _inputDecoration(
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              isError: _highlightedEmptyFields.contains('password'),
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Login Button
          _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _handleLogin,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text(
                      'Log In',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

          const SizedBox(height: 20),

          // Interactive UC200 Testing Bar for Reviewers
          Material(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: ExpansionTile(
                initiallyExpanded: false,
                title: Row(
                  children: const [
                    Icon(Icons.bug_report_outlined, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'UC200 Flow Testing Tools',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                  ],
                ),
                subtitle: const Text(
                  'Quickly test messages M1–M6 & alternative flows A1–A3',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.mark_email_read_outlined, size: 16),
                              label: const Text('Fill Valid Credentials', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                _emailController.text = 'chingkheat@example.com';
                                _passwordController.text = 'SafeP@ss123!';
                                setState(() => _errorMessage = null);
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.email_outlined, size: 16),
                              label: const Text('Test A1 (Empty Fields)', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                _emailController.text = '';
                                _passwordController.text = '';
                                setState(() => _errorMessage = null);
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.lock_open_outlined, size: 16),
                              label: const Text('Test A2 (Invalid Email)', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                _emailController.text = 'invalid-email-format';
                                _passwordController.text = 'SafeP@ss123!';
                                setState(() => _errorMessage = null);
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.compare_arrows_outlined, size: 16),
                              label: const Text('Test A3 (Wrong Password)', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                _emailController.text = 'chingkheat@example.com';
                                _passwordController.text = 'WrongPassword999!';
                                setState(() => _errorMessage = null);
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.person_search_outlined, size: 16),
                              label: const Text('Test A3 (No Account)', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                _emailController.text = 'unknown_tourist@example.com';
                                _passwordController.text = 'SafeP@ss123!';
                                setState(() => _errorMessage = null);
                              },
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildLabel(String text, {bool isMandatory = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        if (isMandatory)
          const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
    bool isError = false,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: isError ? Colors.red : AppColors.muted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: isError ? Colors.red.shade50 : Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isError ? Colors.red : AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isError ? Colors.red.shade400 : AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isError ? Colors.red : AppColors.primary, width: 2),
      ),
    );
  }
}
