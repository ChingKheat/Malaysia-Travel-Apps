import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';

enum RecoveryResult {
  success,
  invalidEmail,
  invalidCode,
  expired,
  weakPassword,
  samePassword,
  unavailable,
}

/// Owns the short-lived recovery credentials for a single reset dialog.
/// Keeping this outside the app's auth client avoids persisting a sign-in or
/// broadcasting the recovery session to an open browser tab.
class PasswordRecovery {
  PasswordRecovery({
    http.Client? client,
    String projectUrl = SupabaseConfig.supabaseUrl,
    String publicKey = SupabaseConfig.supabaseAnonKey,
  }) : _client = client ?? http.Client(),
       _projectUrl = Uri.tryParse(projectUrl),
       _headers = {'apikey': publicKey};

  final http.Client _client;
  final Uri? _projectUrl;
  final Map<String, String> _headers;
  String? _email;
  String? _accessToken;

  Future<RecoveryResult> sendCode(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!AuthService.isValidEmail(normalized)) {
      return RecoveryResult.invalidEmail;
    }

    _accessToken = null;
    _email = null;
    final response = await _request(
      'POST',
      'recover',
      data: {'email': normalized},
    );
    final code = _errorCode(response);
    if (!_isSuccessful(response) &&
        code != 'user_not_found' &&
        code != 'over_email_send_rate_limit') {
      return RecoveryResult.unavailable;
    }
    _email = normalized;
    return RecoveryResult.success;
  }

  Future<RecoveryResult> verifyCode(String code) async {
    final email = _email;
    final token = code.trim();
    if (email == null || !RegExp(r'^\d{6,10}$').hasMatch(token)) {
      return RecoveryResult.invalidCode;
    }

    _accessToken = null;
    final response = await _request(
      'POST',
      'verify',
      data: {'email': email, 'token': token, 'type': 'recovery'},
    );
    final body = _responseBody(response);
    if (_isSuccessful(response)) {
      final accessToken = body['access_token'];
      if (accessToken is String && accessToken.isNotEmpty) {
        _accessToken = accessToken;
        return RecoveryResult.success;
      }
    }
    final errorCode = _errorCode(response);
    if (errorCode == 'otp_expired' || errorCode == 'user_not_found') {
      return RecoveryResult.invalidCode;
    }
    return RecoveryResult.unavailable;
  }

  Future<RecoveryResult> setPassword(String password) async {
    final token = _accessToken;
    if (token == null) return RecoveryResult.expired;
    if (!AuthService.isStrongPassword(password)) {
      return RecoveryResult.weakPassword;
    }

    final response = await _request(
      'PUT',
      'user',
      data: {'password': password},
      token: token,
    );
    if (_isSuccessful(response)) {
      _accessToken = null;
      await _request(
        'POST',
        'logout',
        token: token,
        query: {'scope': 'local'},
        timeout: const Duration(seconds: 3),
      );
      return RecoveryResult.success;
    }
    if (response?.statusCode == 401 || response?.statusCode == 403) {
      _accessToken = null;
      return RecoveryResult.expired;
    }
    return switch (_errorCode(response)) {
      'same_password' => RecoveryResult.samePassword,
      'weak_password' => RecoveryResult.weakPassword,
      _ => RecoveryResult.unavailable,
    };
  }

  Future<http.Response?> _request(
    String method,
    String endpoint, {
    Map<String, String>? data,
    Map<String, String>? query,
    String? token,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final project = _projectUrl;
    if (project == null ||
        project.host.isEmpty ||
        _headers['apikey']!.isEmpty) {
      return null;
    }
    final isLoopback = ['localhost', '127.0.0.1', '::1'].contains(project.host);
    if (project.scheme != 'https' &&
        !(project.scheme == 'http' && isLoopback)) {
      return null;
    }
    final prefix = project.path.replaceFirst(RegExp(r'/+$'), '');
    final url = project.replace(
      path: '$prefix/auth/v1/$endpoint',
      queryParameters: query ?? const {},
    );
    final request = http.Request(method, url)..followRedirects = false;
    request.headers.addAll(_headers);
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (data != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(data);
    }

    try {
      return await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on http.ClientException {
      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _isSuccessful(http.Response? response) =>
      response != null &&
      response.statusCode >= 200 &&
      response.statusCode < 300;

  static String? _errorCode(http.Response? response) {
    final body = _responseBody(response);
    final errorCode = body['error_code'];
    if (errorCode is String && errorCode.isNotEmpty) return errorCode;
    final code = body['code'];
    if (code is String && code.isNotEmpty) return code;
    return null;
  }

  static Map<String, dynamic> _responseBody(http.Response? response) {
    if (response == null) return const {};
    try {
      final body = jsonDecode(response.body);
      return body is Map<String, dynamic> ? body : const {};
    } on FormatException {
      return const {};
    }
  }

  void dispose() {
    _email = null;
    _accessToken = null;
    _client.close();
  }
}
