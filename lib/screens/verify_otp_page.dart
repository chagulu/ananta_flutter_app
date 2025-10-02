import 'dart:async';
import 'dart:ui';
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

  // Resend UX
  Timer? _timer;
  int _secondsLeft = 45;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: widget.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
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
      final data = res.data is Map ? res.data as Map : <String, dynamic>{};
      final success = data['success'] == true;
      final token = data['token']?.toString();
      final role = data['role']?.toString();

      if (success && token != null && token.isNotEmpty) {
        await _secure.write(key: 'access_token', value: token);
        if (role != null && role.isNotEmpty) {
          await _secure.write(key: 'user_role', value: role);
        }
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeShell(
              loginType: widget.loginType,
              role: role ?? 'ROLE_RESIDENCE',
            ),
          ),
          (route) => false,
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

  Future<void> _resend() async {
    setState(() {
      _banner = 'A new OTP has been sent';
      _isError = false;
    });
    _startTimer();
  }

  // Visual 6 boxes reflecting controller value
  Widget _otpBoxes(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget box(int i) {
      final ch = i < _otpCtrl.text.length ? _otpCtrl.text[i] : '';
      final focused = _otpCtrl.text.length == i;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 48,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: focused ? cs.primary : cs.outlineVariant,
            width: focused ? 1.6 : 1,
          ),
        ),
        child: Text(
          ch,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) => box(i)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.surface,
          centerTitle: true,
          title: Image.asset('assets/logo.png', height: 28, fit: BoxFit.contain),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                children: [
                  // Header
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                        decoration: BoxDecoration(
                          color: cs.surface.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'Verify One-Time Password',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Enter the 6-digit code sent to ${widget.mobileNo}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_banner != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: _isError ? cs.errorContainer : cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _isError ? cs.error : cs.primary),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _isError ? Icons.error_outline : Icons.check_circle_outline,
                            color: _isError ? cs.onErrorContainer : cs.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _banner!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: _isError ? cs.onErrorContainer : cs.onPrimaryContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Single input approach: Stack the boxes over a minimal TextFormField
                  Form(
                    key: _formKey,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // The real input (visible to OS/keyboard, but visually minimal)
                        TextFormField(
                          controller: _otpCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          autofocus: true,
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            // keep minimal to avoid a second visible box
                            contentPadding: EdgeInsets.symmetric(vertical: 22),
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            // keep text transparent so only boxes show characters
                            color: Colors.transparent,
                            height: 0.01, // very small so caret doesn’t shift layout
                          ),
                          cursorColor: Colors.transparent,
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return 'OTP is required';
                            if (!RegExp(r'^\d{6}$').hasMatch(s)) return 'Enter a valid 6-digit OTP';
                            return null;
                          },
                          onFieldSubmitted: (_) => _verifyOtp(),
                        ),

                        // The pretty boxes on top (only visual)
                        IgnorePointer(
                          child: _otpBoxes(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_secondsLeft > 0)
                        Text(
                          'Resend in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        )
                      else
                        TextButton.icon(
                          onPressed: _submitting ? null : _resend,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Resend code'),
                        ),
                    ],
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
          ),
        ),
      ),
    );
  }
}
