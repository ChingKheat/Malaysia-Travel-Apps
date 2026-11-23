import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/auth/services/password_recovery.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';

enum _RecoveryStep { email, code, password }

class PasswordRecoveryDialog extends StatefulWidget {
  const PasswordRecoveryDialog({super.key, required this.initialEmail});

  final String initialEmail;

  @override
  State<PasswordRecoveryDialog> createState() => _PasswordRecoveryDialogState();
}

class _PasswordRecoveryDialogState extends State<PasswordRecoveryDialog> {
  final _request = PasswordRecovery();
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  late final _email = TextEditingController(text: widget.initialEmail);

  _RecoveryStep _step = _RecoveryStep.email;
  RecoveryResult? _error;
  bool _busy = false;
  bool _obscurePassword = true;

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await switch (_step) {
      _RecoveryStep.email => _request.sendCode(_email.text),
      _RecoveryStep.code => _request.verifyCode(_code.text),
      _RecoveryStep.password => _request.setPassword(_password.text),
    };
    if (!mounted) return;
    if (_step == _RecoveryStep.password && result == RecoveryResult.success) {
      Navigator.of(context).pop(_email.text.trim());
      return;
    }
    setState(() {
      _busy = false;
      if (result == RecoveryResult.success) {
        switch (_step) {
          case _RecoveryStep.email:
            _step = _RecoveryStep.code;
          case _RecoveryStep.code:
            _code.clear();
            _step = _RecoveryStep.password;
          case _RecoveryStep.password:
            break;
        }
      } else {
        _error = result;
        if (result == RecoveryResult.expired) {
          _password.clear();
          _step = _RecoveryStep.email;
        }
      }
    });
  }

  @override
  void dispose() {
    _request.dispose();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final errorText = switch (_error) {
      RecoveryResult.invalidEmail => l10n.pleaseEnterAValidEmailAddress,
      RecoveryResult.invalidCode => l10n.passwordRecoveryInvalidCode,
      RecoveryResult.expired => l10n.passwordRecoveryExpired,
      RecoveryResult.weakPassword =>
        l10n.passwordMustContainAtLeast8CharactersIncluding1Uppercase1Lowercase1NumberAnd1SpecialCharac,
      RecoveryResult.samePassword => l10n.passwordRecoverySamePassword,
      RecoveryResult.unavailable => l10n.passwordRecoveryUnavailable,
      RecoveryResult.success || null => null,
    };
    final actionLabel = switch (_step) {
      _RecoveryStep.email => l10n.passwordRecoverySendCode,
      _RecoveryStep.code => l10n.passwordRecoveryVerifyCode,
      _RecoveryStep.password => l10n.passwordRecoverySave,
    };

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.passwordRecoveryTitle),
        content: Form(
          key: _form,
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == _RecoveryStep.email) ...[
                  Text(l10n.passwordRecoveryEmailHelp),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('recovery-email'),
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: l10n.emailAddress),
                    validator: (email) => AuthService.isValidEmail(email ?? '')
                        ? null
                        : l10n.pleaseEnterAValidEmailAddress,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
                if (_step == _RecoveryStep.code) ...[
                  Text(l10n.passwordRecoveryCodeHelp),
                  const SizedBox(height: 8),
                  Text(_email.text.trim()),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('recovery-code'),
                    controller: _code,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.passwordRecoveryCode,
                    ),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
                if (_step == _RecoveryStep.password) ...[
                  TextFormField(
                    key: const ValueKey('recovery-password'),
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _obscurePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.passwordRecoveryNewPassword,
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? l10n.showPassword
                            : l10n.hidePassword,
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (password) =>
                        AuthService.isStrongPassword(password ?? '')
                        ? null
                        : l10n.passwordMustContainAtLeast8CharactersIncluding1Uppercase1Lowercase1NumberAnd1SpecialCharac,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('recovery-confirm-password'),
                    enabled: !_busy,
                    obscureText: _obscurePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: l10n.confirmPassword,
                    ),
                    validator: (confirmation) => confirmation == _password.text
                        ? null
                        : l10n.passwordAndConfirmPasswordDoNotMatchPleaseReEnter,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
                if (errorText != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      errorText,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          if (_step == _RecoveryStep.code)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _code.clear();
                      _error = null;
                      _step = _RecoveryStep.email;
                    }),
              child: Text(l10n.back),
            ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
