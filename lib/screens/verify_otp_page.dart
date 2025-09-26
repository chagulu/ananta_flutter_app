import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ananta_app/screens/home_shell.dart'; // adjust path/package 
// import your config to reuse baseUrl if you centralized it
// import 'package:ananta_app/core/config/config.dart';

class VerifyOtpPage extends StatefulWidget {
  final String mobileNo;
  final String baseUrl;
  const VerifyOtpPage({super.key, required this.mobileNo, required this.baseUrl});

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
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() {
      _submitting = true;
      _banner = null;
      _isError = false;
    });

    try {
      final payload = {
        "mobileNo": widget.mobileNo,
        "otp": _otpCtrl.text.trim(),
      };

      final res = await _dio.post('/auth/verify-otp', data: payload);
      final data = res.data is Map ? res.data as Map : {};
      final success = data['success'] == true;
      final token = data['token']?.toString();

      if (success && token != null && token.isNotEmpty) {
        await _secure.write(key: 'access_token', value: token);
        // Navigate to the next screen after saving token
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()),
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
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Verify OTP'),
        backgroundColor: scheme.surface,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
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
                                  color: _isError ? scheme.onErrorContainer : scheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Card(
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
                              'Enter OTP sent to ${widget.mobileNo}',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _otpCtrl,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            maxLength: 6,
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
                              hintText: '6-digit OTP',
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
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: scheme.onPrimary,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.verified),
                              label: Text(_submitting ? 'Verifying...' : 'Verify OTP'),
                              onPressed: _submitting ? null : _verifyOtp,
                            ),
                          ),
                        ],
                      ),
                    ),
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

// Minimal placeholder for next screen
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Welcome', style: Theme.of(context).textTheme.headlineMedium)),
    );
  }
}
