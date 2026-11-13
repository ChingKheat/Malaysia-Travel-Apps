import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';

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

  void _clearEmailError() {
    if (_highlightedEmptyFields.contains('email') ||
        _errorMessage == AuthService.m3LoginInvalidEmail ||
        _errorMessage == AuthService.m2LoginMandatory) {
      setState(() {
        _highlightedEmptyFields.remove('email');
        if (_errorMessage == AuthService.m3LoginInvalidEmail ||
            (_highlightedEmptyFields.isEmpty &&
                _errorMessage == AuthService.m2LoginMandatory)) {
          _errorMessage = null;
        }
      });
    }
  }

  void _clearPasswordError() {
    if (_highlightedEmptyFields.contains('password') ||
        _errorMessage == AuthService.m2LoginMandatory) {
      setState(() {
        _highlightedEmptyFields.remove('password');
        if (_highlightedEmptyFields.isEmpty &&
            _errorMessage == AuthService.m2LoginMandatory) {
          _errorMessage = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_isLoading) return;
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
    final String? emailError = _highlightedEmptyFields.contains('email')
        ? context.l10n.pleaseEnterYourEmail
        : (_errorMessage == AuthService.m3LoginInvalidEmail
            ? context.l10n.pleaseEnterAValidEmail
            : null);

    final String? passwordError = _highlightedEmptyFields.contains('password')
        ? context.l10n.pleaseEnterYourPassword
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.welcomeBack,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.signInToManageYourMalaysiaTravelPlans,
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
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade700,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr(_errorMessage!),
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

          // Field 1: Email Address with Floating Label & Inline Validation
          TextField(
            controller: _emailController,
            onChanged: (_) => _clearEmailError(),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: _buildFieldLabel(context.l10n.emailAddress, isMandatory: true),
              hint: context.l10n.eGTouristExampleCom,
              helperText: context.l10n.eGTouristExampleCom,
              errorText: emailError,
              icon: Icons.email_outlined,
              isError: _highlightedEmptyFields.contains('email') || emailError != null,
            ),
          ),
          const SizedBox(height: 16),

          // Field 2: Password with Floating Label, Toggle & Inline Validation
          TextField(
            controller: _passwordController,
            onChanged: (_) => _clearPasswordError(),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleLogin(),
            decoration: _inputDecoration(
              label: _buildFieldLabel(context.l10n.password, isMandatory: true),
              hint: context.l10n.enterYourPassword,
              errorText: passwordError,
              icon: Icons.lock_outline,
              isError: _highlightedEmptyFields.contains('password') || passwordError != null,
              suffix: IconButton(
                tooltip: _obscurePassword
                    ? context.l10n.showPassword
                    : context.l10n.hidePassword,
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.muted,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: AppColors.primary,
                    ),
                    child: Text(
                      context.l10n.logIn,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text, {bool isMandatory = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            context.tr(text),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (isMandatory)
          const Text(
            ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required Widget label,
    required String hint,
    required IconData icon,
    Widget? suffix,
    String? helperText,
    String? errorText,
    bool isError = false,
  }) {
    final hasError = isError || errorText != null;
    return InputDecoration(
      label: label,
      hintText: hint,
      helperText: helperText,
      errorText: errorText,
      prefixIcon: Icon(
        icon,
        color: hasError ? Colors.red : AppColors.muted,
        size: 20,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: hasError ? Colors.red.shade50 : Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: hasError ? Colors.red : AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: hasError ? Colors.red.shade400 : AppColors.line,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: hasError ? Colors.red : AppColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}
