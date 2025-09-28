import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ananta_app/screens/home_shell.dart';
import '../models/login_type.dart';

class VerifyOtpPage extends StatefulWidget {
  final String mobileNo;
  final String baseUrl;
  final String verifyPath; // '/auth/verify-otp' or '/residence/auth/verify-otp'
  final LoginType loginType;
  const VerifyOtpPage({
    super.key,
    required this.mobileNo,
    required this.baseUrl,
    required this.verifyPath,
    this.loginType = LoginType.guard,
  });

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  bool _submitting = false;
  String? _banner;
  bool _isError = false;

  late final Dio _dio;
  final _secure = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: widget.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _banner = null;
      _isError = false;
    });

    try {
      final payload = {"mobileNo": widget.mobileNo, "otp": _otpCtrl.text.trim()};
      final res = await _dio.post(widget.verifyPath, data: payload);
      final data = res.data is Map ? res.data as Map : {};
      final success = data['success'] == true;
      final token = data['token']?.toString();
      final role = data['role']?.toString(); // 👈 extract role from response

      if (success && token != null && token.isNotEmpty) {
        await _secure.write(key: 'access_token', value: token);

        if (role != null && role.isNotEmpty) {
          await _secure.write(key: 'user_role', value: role); // 👈 store role
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeShell(
              loginType: widget.loginType,
              role: role ?? 'ROLE_RESIDENCE', // 👈 pass role to HomeShell
            ),
          ),
        );
      } else {
        setState(() {
          _banner = (data['message'] ?? 'Failed to verify OTP').toString();
          _isError = true;
        });
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response?.data['message'] ?? 'Failed to verify OTP').toString())
          : (e.message ?? 'Failed to verify OTP');
      setState(() {
        _banner = msg;
        _isError = true;
      });
    } catch (_) {
      setState(() {
        _banner = 'Failed to verify OTP';
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
      appBar: AppBar(title: const Text('Verify OTP'), backgroundColor: scheme.surface),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (_banner != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _isError ? scheme.errorContainer : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _banner!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _isError ? scheme.onErrorContainer : scheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text('Enter OTP sent to ${widget.mobileNo}'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _otpCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(hintText: '6-digit OTP', counterText: ''),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'OTP is required';
                          if (!RegExp(r'^\d{6}$').hasMatch(s)) return 'Enter a valid 6-digit OTP';
                          return null;
                        },
                        onFieldSubmitted: (_) => _verifyOtp(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          icon: _submitting
                              ? const SizedBox(
                                  height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.verified),
                          label: Text(_submitting ? 'Verifying...' : 'Verify OTP'),
                          onPressed: _submitting ? null : _verifyOtp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
