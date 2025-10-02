import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:ananta_app/screens/verify_otp_page.dart';
import '../config.dart';
import '../models/login_type.dart';

class SendOtpPage extends StatefulWidget {
  const SendOtpPage({super.key});

  @override
  State<SendOtpPage> createState() => _SendOtpPageState();
}

class _SendOtpPageState extends State<SendOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: scheme.surface,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo added here
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Image.asset(
                    'assets/logo.png',
                    height: 100, // adjust as needed
                  ),
                ),

                // Toggle row
                SegmentedButton<LoginType>(
                  segments: const [
                    ButtonSegment(value: LoginType.guard, label: Text('Guard')),
                    ButtonSegment(value: LoginType.residence, label: Text('Residence')),
                  ],
                  selected: <LoginType>{_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 16),
                Text(
                  _type == LoginType.guard ? 'Send OTP to user' : 'Send OTP to residence',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),

                if (_banner != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 16),
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

                Card(
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
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
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
                  'User endpoint: $_sendPath',
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
