import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../models/login_type.dart';
import 'home_shell.dart'; // api and baseUrl

class VisitorListPage extends StatefulWidget {
  final LoginType loginType;
  const VisitorListPage({super.key, this.loginType = LoginType.user});

  @override
  State<VisitorListPage> createState() => _VisitorListPageState();
}

class _VisitorListPageState extends State<VisitorListPage> {
  int _page = 0;
  final int _size = 10;
  bool _loading = false;
  bool _more = true;
  String? _error;
  final List<Map<String, dynamic>> _items = [];

  String get _endpoint {
    return widget.loginType == LoginType.user
        ? '/api/visitor/guard'
        : '/api/visitor';
  }

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      setState(() {
        _page = 0;
        _items.clear();
        _more = true;
        _error = null;
      });
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await api.get(
        _endpoint,
        queryParameters: {'page': _page, 'size': _size},
      );

      final body = res.data is Map ? (res.data as Map) : <String, dynamic>{};
      final visitorsAny = body['data']; // <-- changed from 'visitors' to 'data'
      final totalPages = body['pagination']?['totalPages'] ?? 1;

      final visitors = visitorsAny is List
          ? visitorsAny.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _items.addAll(visitors);
        _more = _page < totalPages - 1;
      });
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response?.data['message'] ?? 'Failed to load visitors').toString())
          : (e.message ?? 'Failed to load visitors');
      setState(() => _error = msg);
    } catch (_) {
      setState(() => _error = 'Failed to load visitors');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_more || _loading) return;
    setState(() => _page += 1);
    await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading && _items.isEmpty && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _fetch(reset: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _fetch(reset: true),
        child: ListView(
          children: const [
            SizedBox(height: 160),
            Center(child: Text('No visitors yet')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetch(reset: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length + (_more ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            _loadMore();
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final v = _items[index];
          final guestName = (v['guestName'] ?? '').toString();
          final mobile = (v['mobile'] ?? '').toString();
          final flat = (v['flatNumber'] ?? '-').toString();
          final bldg = (v['buildingNumber'] ?? '-').toString();
          final purpose = (v['visitPurpose'] ?? '-').toString();
          final status = (v['approveStatus'] ?? '-').toString();
          final time = (v['visitTime'] ?? '-').toString();
          final token = (v['token'] ?? '').toString();

          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('$guestName • $mobile'),
              subtitle: Text(
                'Flat $flat, Bldg $bldg\n'
                'Purpose: $purpose\n'
                'Status: $status\n'
                'Time: $time',
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy approval link',
                onPressed: token.isEmpty
                    ? null
                    : () async {
                        final link = '${AppConfig.baseUrl}/api/visitor/approve?token=$token';
                        await Clipboard.setData(ClipboardData(text: link));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Approval link copied')),
                        );
                      },
              ),
            ),
          );
        },
      ),
    );
  }
}
