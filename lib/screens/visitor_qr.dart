// lib/screens/generate_qr_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'home_shell.dart' show api; // ensures the shared Dio with interceptor is available


class GenerateQrPage extends StatefulWidget {
  const GenerateQrPage({super.key});

  @override
  State<GenerateQrPage> createState() => _GenerateQrPageState();
}

class _GenerateQrPageState extends State<GenerateQrPage> {
  String? _token;
  int? _ttl;
  Timer? _timer;
  bool _loading = false;
  DateTime? _lastFetch;

  Future<void> _fetch() async {
    // Debounce manual refreshes
    final now = DateTime.now();
    if (_lastFetch != null && now.difference(_lastFetch!).inSeconds < 2) return;
    _lastFetch = now;

    if (_loading) return;
    setState(() => _loading = true);
    try {
      final res = await api.get('/api/visitor/qr-token');
      final data = res.data is Map ? res.data as Map : {};
      if (data['success'] == true) {
        setState(() {
          _token = data['qrToken']?.toString();
          _ttl = data['expiresInSeconds'] is int ? data['expiresInSeconds'] as int : null;
        });
      } else {
        if (!mounted) return;
        final msg = (data['message'] ?? 'Failed to fetch QR token').toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? ((e.response?.data['message'] ?? 'Failed to fetch QR token').toString())
          : (e.message ?? 'Failed to fetch QR token');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to fetch QR token')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
    // Refresh to match ~45s TTL from backend
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading && _token == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Scan to start guest entry', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Container(
                    width: 240,
                    height: 240,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    // Replace with a QR widget in production (e.g., qr_flutter's QrImageView)
                    child: _token == null
                        ? const Text('No token')
                        : SelectableText(_token!, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 8),
                  Text(_ttl == null ? '' : 'Expires in ~$_ttl s'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _fetch,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
      ),
    );
  }
}
