import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';

class CreateAccountForm extends StatefulWidget {
  const CreateAccountForm({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  State<CreateAccountForm> createState() => _CreateAccountFormState();
}

class _CreateAccountFormState extends State<CreateAccountForm> {
  final _authService = AuthService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  String? _errorMessage;
  Set<String> _highlightedEmptyFields = {};

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    setState(() {});
  }

  void _clearValidationError(String field) {
    if (_errorMessage == null && !_highlightedEmptyFields.contains(field)) {
      return;
    }
    setState(() {
      _errorMessage = null;
      _highlightedEmptyFields.remove(field);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.removeListener(_onPasswordChanged);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (_isLoading) return;
    demoHaptic();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _highlightedEmptyFields = {};
    });

    final result = await _authService.registerUser(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (!result.success) {
        _errorMessage = result.message;
        _highlightedEmptyFields = Set.of(result.emptyFields);
      }
    });

    if (result.success) {
      if (result.requiresEmailConfirmation) {
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.l10n.checkYourEmail),
            content: Text(
              context
                  .l10n
                  .ifThisEmailCanBeRegisteredAConfirmationEmailWillBeSentOpenTheLinkInThatEmailThenReturnHere,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.l10n.ok),
              ),
            ],
          ),
        );
        return;
      }
      // Display M1 SnackBar
      showDemoSnackBar(
        context,
        result.message,
        icon: Icons.check_circle_outline,
      );
      widget.onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pwd = _passwordController.text;

    final String? nameError = _highlightedEmptyFields.contains('name')
        ? context.tr(AuthService.m2NameRequired)
        : null;

    final String? emailError = _highlightedEmptyFields.contains('email')
        ? context.l10n.pleaseEnterYourEmail
        : null;

    final String? passwordError = _highlightedEmptyFields.contains('password')
        ? context.l10n.pleaseEnterYourPassword
        : null;

    final String? confirmPasswordError =
        _highlightedEmptyFields.contains('confirmPassword')
            ? context.l10n.pleaseEnterYourPassword
            : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header description
          Text(
            context.l10n.createAccount,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context
                .l10n
                .registerAsANewTouristToPlanYourPersonalizedTripsInMalaysia,
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 20),

          // Error Banner (M2 - M8)
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

          // Field 1: Full Name with Floating Label & Inline Validation
          TextField(
            controller: _nameController,
            onChanged: (_) => _clearValidationError('name'),
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: _buildFieldLabel(context.l10n.fullName, isMandatory: true),
              hint: context.l10n.eGAliBinAhmad,
              helperText: context.l10n.eGAliBinAhmad,
              errorText: nameError,
              icon: Icons.person_outline,
              isError: _highlightedEmptyFields.contains('name') || nameError != null,
            ),
          ),
          const SizedBox(height: 16),

          // Field 2: Email Address with Floating Label & Inline Validation
          TextField(
            controller: _emailController,
            onChanged: (_) => _clearValidationError('email'),
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

          // Field 3: Password with Floating Label, Toggle & Strength Checklist
          TextField(
            controller: _passwordController,
            onChanged: (_) => _clearValidationError('password'),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: _buildFieldLabel(context.l10n.password, isMandatory: true),
              hint: context.l10n.enterStrongPassword,
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
          const SizedBox(height: 10),

          // Password Strength Policy Checklist (C3)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.passwordStrengthPolicyC3,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRuleItem(
                  'At least 8 characters',
                  AuthService.hasMinLength(pwd),
                ),
                _buildRuleItem(
                  'One uppercase letter (A-Z)',
                  AuthService.hasUppercase(pwd),
                ),
                _buildRuleItem(
                  'One lowercase letter (a-z)',
                  AuthService.hasLowercase(pwd),
                ),
                _buildRuleItem('One number (0-9)', AuthService.hasDigit(pwd)),
                _buildRuleItem(
                  'One special character (!@#\$%^&*)',
                  AuthService.hasSpecialChar(pwd),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Field 4: Confirm Password with Floating Label & Inline Validation
          TextField(
            controller: _confirmPasswordController,
            onChanged: (_) => _clearValidationError('confirmPassword'),
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleRegister(),
            decoration: _inputDecoration(
              label: _buildFieldLabel(context.l10n.confirmPassword, isMandatory: true),
              hint: context.l10n.reEnterPassword,
              errorText: confirmPasswordError,
              icon: Icons.lock_clock_outlined,
              isError: _highlightedEmptyFields.contains('confirmPassword') || confirmPasswordError != null,
              suffix: IconButton(
                tooltip: _obscureConfirmPassword
                    ? context.l10n.showPassword
                    : context.l10n.hidePassword,
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Register Button
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
                    onPressed: _handleRegister,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: AppColors.primary,
                    ),
                    child: Text(
                      context.l10n.registerAccount,
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

  Widget _buildRuleItem(String label, bool isSatisfied) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isSatisfied ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 15,
            color: isSatisfied ? Colors.green.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              context.tr(label),
              style: TextStyle(
                fontSize: 11.5,
                color: isSatisfied
                    ? Colors.green.shade800
                    : Colors.grey.shade700,
                fontWeight: isSatisfied ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
