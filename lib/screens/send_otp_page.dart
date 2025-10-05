// File: lib/screens/send_otp_page.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:ananta_app/screens/verify_otp_page.dart';
import 'package:ananta_app/screens/home_shell.dart';
import '../config.dart';
import '../models/login_type.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final FlutterSecureStorage _secure = const FlutterSecureStorage();

class SendOtpPage extends StatefulWidget {
  const SendOtpPage({super.key});

  @override
  State<SendOtpPage> createState() => _SendOtpPageState();
}

class _SendOtpPageState extends State<SendOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _submitting = false;
  String? _banner;
  bool _isError = false;
  LoginType _type = LoginType.guard;

  static const String baseUrl = AppConfig.baseUrl;
  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String get _sendPath =>
      _type == LoginType.guard ? '/guard/auth/send-otp' : '/residence/auth/send-otp';
  String get _verifyPath =>
      _type == LoginType.guard ? '/guard/auth/verify-otp' : '/residence/auth/verify-otp';

  Future<void> _sendOtp() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() {
      _submitting = true;
      _banner = null;
      _isError = false;
    });

    try {
      final payload = {"mobileNo": _mobileCtrl.text.trim()};
      final res = await _dio.post(_sendPath, data: payload);
      final data = res.data is Map ? res.data as Map : {};
      final success = data['success'] == true;
      final message = (data['message'] ?? 'OTP sent').toString();

      setState(() {
        _banner = message;
        _isError = !success;
      });

      if (success && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerifyOtpPage(
              mobileNo: _mobileCtrl.text.trim(),
              baseUrl: baseUrl,
              verifyPath: _verifyPath,
              loginType: _type,
            ),
          ),
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response?.data['message'] ?? 'Failed to send OTP').toString())
          : (e.message ?? 'Failed to send OTP');
      setState(() {
        _banner = msg;
        _isError = true;
      });
    } catch (_) {
      setState(() {
        _banner = 'Failed to send OTP';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _adminLogin() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _banner = "Username and password are required";
        _isError = true;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _banner = null;
      _isError = false;
    });

    try {
      final payload = {"username": username, "password": password};
      final res = await _dio.post('/api/admin/login', data: payload);
      final data = res.data as Map;
      if (data['success'] == true) {
        final token = data['data']['token'] ?? '';
        await _secure.write(key: 'access_token', value: token);
        await _secure.write(key: 'user_role', value: 'ROLE_ADMIN');
        await _secure.write(key: 'login_type', value: 'admin');

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const HomeShell(
                loginType: LoginType.admin,
                role: "ROLE_ADMIN",
              ),
            ),
          );
        }
      } else {
        setState(() {
          _banner = data['message'] ?? 'Login failed';
          _isError = true;
        });
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Login failed';
      setState(() {
        _banner = msg;
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppBar(
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary.withOpacity(0.90), scheme.tertiary.withOpacity(0.90)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ananta Residency',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'Login',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimary.withOpacity(0.95),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header above logo
                Text(
                  'Welcome to Ananta Residency',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 16),
                // Logo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Image.asset(
                    'assets/logo.png',
                    height: 84,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),

                SegmentedButton<LoginType>(
                  segments: const [
                    ButtonSegment(value: LoginType.guard, label: Text('Guard')),
                    ButtonSegment(value: LoginType.residence, label: Text('Residence')),
                    ButtonSegment(value: LoginType.admin, label: Text('Admin')),
                  ],
                  selected: <LoginType>{_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 12),
                Text(
                  _type == LoginType.guard
                      ? 'Send OTP to user'
                      : _type == LoginType.residence
                          ? 'Send OTP to residence'
                          : 'Admin login',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                if (_banner != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _isError ? scheme.errorContainer : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isError ? scheme.error : scheme.primary,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isError ? Icons.error_outline : Icons.check_circle_outline,
                          color: _isError ? scheme.onErrorContainer : scheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _banner!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: _isError
                                      ? scheme.onErrorContainer
                                      : scheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Conditional Form Card
                _type == LoginType.admin
                    ? Card(
                        color: scheme.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _usernameCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: Icon(Icons.person_outline, color: scheme.onSurfaceVariant),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton.icon(
                                  icon: _submitting
                                      ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: scheme.onPrimary,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.login),
                                  label: Text(_submitting ? 'Logging in...' : 'Login'),
                                  onPressed: _submitting ? null : _adminLogin,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Card(
                        color: scheme.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Mobile number',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _mobileCtrl,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.done,
                                  maxLength: 10,
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.phone_outlined, color: scheme.onSurfaceVariant),
                                    hintText: 'Enter 10-digit mobile number',
                                    counterText: '',
                                    filled: true,
                                    fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: scheme.outlineVariant),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: scheme.primary, width: 1.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: scheme.error),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) return 'Mobile number is required';
                                    final is10Digits = RegExp(r'^\d{10}$').hasMatch(s);
                                    if (!is10Digits) return 'Enter a valid 10-digit number';
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _sendOtp(),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: FilledButton.icon(
                                    icon: _submitting
                                        ? SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: scheme.onPrimary,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.send),
                                    label: Text(_submitting ? 'Sending...' : 'Send OTP'),
                                    onPressed: _submitting ? null : _sendOtp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                const SizedBox(height: 16),
                Text(
                  _type == LoginType.admin ? 'Admin endpoint: /api/admin/login' : 'User endpoint: $_sendPath',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
