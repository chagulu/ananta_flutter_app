import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../models/login_type.dart';
import 'home_shell.dart'; // api and baseUrl

class VisitorListPage extends StatefulWidget {
  final LoginType loginType;
  const VisitorListPage({super.key, this.loginType = LoginType.guard});

  @override
  State<VisitorListPage> createState() => _VisitorListPageState();
}

class _VisitorListPageState extends State<VisitorListPage> with WidgetsBindingObserver {
  int _page = 0;
  final int _size = 10;
  bool _loading = false;
  bool _more = true;
  String? _error;
  final List<Map<String, dynamic>> _items = [];
  Timer? _pollingTimer;

  // Filter states
  String? _filterGuestName;
  String? _filterMobile;
  String? _filterFlat;
  String? _filterBuilding;
  String? _filterStatus;

  // Dropdown options for flats and buildings
  final List<String> _flatNumbers = ['C1','C2','C3','C4']; 
  final List<String> _buildingNumbers = ['B1','B2','B3','B4'];

  final TextEditingController _guestNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  String get _endpoint => widget.loginType == LoginType.guard
      ? '/api/visitor/guard'
      : '/api/visitor';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetch(reset: true);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _guestNameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollingTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 100), (_) => _fetch(reset: true));
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

    setState(() => _loading = true);

    try {
      final queryParams = {
        'page': _page,
        'size': _size,
        if (_filterGuestName?.isNotEmpty ?? false) 'guestName': _filterGuestName!,
        if (_filterMobile?.isNotEmpty ?? false) 'mobile': _filterMobile!,
        if (_filterFlat?.isNotEmpty ?? false) 'flatNumber': _filterFlat!,
        if (_filterBuilding?.isNotEmpty ?? false) 'buildingNumber': _filterBuilding!,
        if (_filterStatus?.isNotEmpty ?? false) 'approveStatus': _filterStatus!,
      };

      final res = await api.get(_endpoint, queryParameters: queryParams);

      final body = res.data is Map ? (res.data as Map) : <String, dynamic>{};
      final visitorsAny = body['data'];
      final totalPages = (body['pagination']?['totalPages'] ?? 1) as int;

      final visitors = visitorsAny is List
          ? visitorsAny.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList()
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

  Future<void> _visitorAction(int id, String action) async {
    try {
      await api.post('/api/visitor/$id/action', queryParameters: {'action': action});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${action[0].toUpperCase()}${action.substring(1)}d successfully')),
      );
      await _fetch(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${action[0].toUpperCase()}${action.substring(1)} failed')),
      );
    }
  }

  String formatToIST(String utcTime) {
    try {
      final dateTime = DateTime.parse(utcTime).toUtc();
      final istTime = dateTime.add(const Duration(hours: 5, minutes: 30));
      return DateFormat('dd MMM yyyy, hh:mm a').format(istTime);
    } catch (_) {
      return utcTime;
    }
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _guestNameController,
              decoration: const InputDecoration(
                labelText: 'Guest Name',
                prefixIcon: Icon(Icons.person),
              ),
              onChanged: (v) => _filterGuestName = v,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mobileController,
              decoration: const InputDecoration(
                labelText: 'Mobile',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              onChanged: (v) => _filterMobile = v,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _filterFlat,
              decoration: const InputDecoration(labelText: 'Flat Number'),
              items: _flatNumbers.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (v) => setState(() => _filterFlat = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _filterBuilding,
              decoration: const InputDecoration(labelText: 'Building Number'),
              items: _buildingNumbers.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (v) => setState(() => _filterBuilding = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _filterStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
              ],
              onChanged: (v) => setState(() => _filterStatus = v),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _guestNameController.clear();
                    _mobileController.clear();
                    setState(() {
                      _filterGuestName = null;
                      _filterMobile = null;
                      _filterFlat = null;
                      _filterBuilding = null;
                      _filterStatus = null;
                    });
                    _fetch(reset: true);
                  },
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _fetch(reset: true),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitorItem(BuildContext context, int index) {
    if (index >= _items.length) {
      _loadMore();
      return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16), child: CircularProgressIndicator()));
    }

    final v = _items[index];
    final id = v['id'] is int ? v['id'] as int : int.tryParse(v['id'].toString()) ?? 0;
    final guestName = (v['guestName'] ?? '').toString();
    final mobile = (v['mobile'] ?? '').toString();
    final flat = (v['flatNumber'] ?? '-').toString();
    final bldg = (v['buildingNumber'] ?? '-').toString();
    final purpose = (v['visitPurpose'] ?? '-').toString();
    final status = (v['approveStatus'] ?? '-').toString();
    final time = v['visitTime'] != null ? formatToIST(v['visitTime'].toString()) : '-';
    final color = _statusColor(status);
    final tint = _cardTint(status);
    final label = _statusLabel(status);
    final isPending = status.toUpperCase() == 'PENDING';

    return Card(
      color: tint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Chip(
                    label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    backgroundColor: color.withOpacity(0.15),
                    side: BorderSide(color: color, width: 1),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  ),
                  const SizedBox(width: 4),
                  if (isPending && widget.loginType == LoginType.residence) ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                      onPressed: id == 0 ? null : () => _visitorAction(id, 'approve'),
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: const Text('Approve', style: TextStyle(fontSize: 10)),
                    ),
                    const SizedBox(width: 2),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                      onPressed: id == 0 ? null : () => _visitorAction(id, 'reject'),
                      icon: const Icon(Icons.cancel_outlined, size: 14),
                      label: const Text('Reject', style: TextStyle(fontSize: 10)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copy approval link',
          onPressed: id == 0 ? null : () async {
            final link = '${AppConfig.baseUrl}/api/visitor/$id/action?action=approve';
            await Clipboard.setData(ClipboardData(text: link));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approval link copied')));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visitors')),
      body: RefreshIndicator(
        onRefresh: () => _fetch(reset: true),
        child: ListView(
          padding: const EdgeInsets.all(0),
          children: [
            _buildFilters(),
            if (_loading && _items.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_error != null && _items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(onPressed: () => _fetch(reset: true), icon: const Icon(Icons.refresh), label: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else if (_items.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 160), child: Center(child: Text('No visitors yet')))
            else
              ...List.generate(_items.length, (index) => _buildVisitorItem(context, index)),
            if (_more && _items.isNotEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}
