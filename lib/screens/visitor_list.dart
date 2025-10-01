import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../models/login_type.dart';
import 'home_shell.dart'; // api and baseUrl

class VisitorListPage extends StatefulWidget {
  final LoginType loginType;
  const VisitorListPage({super.key, this.loginType = LoginType.guard});

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
    return widget.loginType == LoginType.guard
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
      final visitorsAny = body['data'];
      final totalPages = (body['pagination']?['totalPages'] ?? 1) as int;

      final visitors = visitorsAny is List
          ? visitorsAny
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map),
              )
              .toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _items.addAll(visitors);
        _more = _page < (totalPages - 1);
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

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'REJECTED':
      default:
        return Colors.red;
    }
  }

  Color? _cardTint(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green.withOpacity(0.06);
      case 'REJECTED':
        return Colors.red.withOpacity(0.06);
      case 'PENDING':
      default:
        return null;
    }
  }

  String _statusLabel(String status) {
    final s = status.toUpperCase();
    if (s == 'APPROVED' || s == 'PENDING' || s == 'REJECTED') return s;
    return status;
  }

  /// Manual approve API call (resident only)
  Future<void> _approve(int id, String mobileNo) async {
    try {
      await api.post(
        '/api/visitor/approve/$id',
        data: {"mobileNo": mobileNo}, // ✅ JSON body
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Approved successfully')));
      await _fetch(reset: true);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response?.data['message'] ?? 'Approve failed').toString())
          : (e.message ?? 'Approve failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Approve failed')));
    }
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
          final id = v['id'] is int ? v['id'] as int : int.tryParse(v['id'].toString()) ?? 0;
          final guestName = (v['guestName'] ?? '').toString();
          final mobile = (v['mobile'] ?? '').toString();
          final flat = (v['flatNumber'] ?? '-').toString();
          final bldg = (v['buildingNumber'] ?? '-').toString();
          final purpose = (v['visitPurpose'] ?? '-').toString();
          final status = (v['approveStatus'] ?? '-').toString();
          final time = (v['visitTime'] ?? '-').toString();

          final color = _statusColor(status);
          final tint = _cardTint(status);
          final label = _statusLabel(status);
          final isPending = status.toUpperCase() == 'PENDING';

          return Card(
            color: tint,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('$guestName • $mobile'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Flat $flat, Bldg $bldg'),
                  Text('Purpose: $purpose'),
                  Text('Time: $time'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Chip(
                        label: Text(label),
                        backgroundColor: color.withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(color: color),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      // ✅ Approve button only for resident
                      if (isPending && widget.loginType == LoginType.residence)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          ),
                          onPressed: id == 0 ? null : () => _approve(id, mobile),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Approve'),
                        ),
                    ],
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy approval link',
                onPressed: id == 0
                    ? null
                    : () async {
                        final link =
                            '${AppConfig.baseUrl}/api/visitor/approve/$id';
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
