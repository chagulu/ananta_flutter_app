// File: lib/screens/visitor_list.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  // Storage for residence unit
  final _secure = const FlutterSecureStorage();
  String? _residentBuildingFromStorage;
  String? _residentFlatFromStorage;

  // Filter states
  final TextEditingController _guestNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  String? _selectedFlat;
  String? _selectedBuilding;
  String? _selectedStatus;

  // Options
  static const List<String> kFlatOptions = <String>[
    'A1','A2','B1','B2','C1','C2','D1','D2','E1','E2',
  ];
  static const List<String> kBuildingOptions = <String>[
    'A1','A2','A3','A4','A5','A6','A7','A8',
  ];
  static const List<DropdownMenuItem<String>> kStatusOptions = [
    DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
    DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
    DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
  ];

  // Endpoint: guard has dedicated path; residence/admin use generic
  String get _endpoint => widget.loginType == LoginType.guard
      ? '/api/visitor/guard'
      : '/api/visitor';

  bool get _isResidence => widget.loginType == LoginType.residence;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadResidenceUnitFromStorage().then((_) {
      _fetch(reset: true);
      _startPolling();
    });
  }

  Future<void> _loadResidenceUnitFromStorage() async {
    if (_isResidence) {
      _residentBuildingFromStorage =
          await _secure.read(key: 'resident_building_number');
      _residentFlatFromStorage =
          await _secure.read(key: 'resident_flat_number');
      debugPrint('VisitorList residence storage: bldg=$_residentBuildingFromStorage flat=$_residentFlatFromStorage'); // [info]
    }
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
      // Paired validation: if one is selected, require the other (only for non-residents)
      if (!_isResidence) {
        final invalidPair = (_selectedFlat != null && _selectedBuilding == null) ||
                            (_selectedFlat == null && _selectedBuilding != null);
        if (invalidPair) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Both Flat and Building must be selected together')),
            );
          }
          if (mounted) setState(() => _loading = false);
          return;
        }
      }

      // Query parameters
      final qp = <String, dynamic>{
        'page': _page,
        'size': _size,
      };
      final name = _guestNameController.text.trim();
      final mobile = _mobileController.text.trim();
      if (name.isNotEmpty) qp['guestName'] = name;
      if (mobile.isNotEmpty) qp['mobile'] = mobile;

      // Inject residence unit from storage; fall back to UI for guard/admin
      if (_isResidence) {
        if ((_residentFlatFromStorage ?? '').isNotEmpty) {
          qp['flatNumber'] = _residentFlatFromStorage!;
        }
        if ((_residentBuildingFromStorage ?? '').isNotEmpty) {
          qp['buildingNumber'] = _residentBuildingFromStorage!;
        }
      } else {
        if (_selectedFlat != null && _selectedFlat!.isNotEmpty) {
          qp['flatNumber'] = _selectedFlat!;
        }
        if (_selectedBuilding != null && _selectedBuilding!.isNotEmpty) {
          qp['buildingNumber'] = _selectedBuilding!;
        }
      }

      if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
        qp['approveStatus'] = _selectedStatus!;
      }

      final res = await api.get(_endpoint, queryParameters: qp);

      final body = res.data is Map ? (res.data as Map) : <String, dynamic>{};
      final visitorsAny = body['data'];
      final totalPages = (body['pagination']?['totalPages'] ?? 1) as int;

      final visitors = visitorsAny is List
          ? visitorsAny
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
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
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_more || _loading) return;
    setState(() => _page += 1);
    await _fetch();
  }

  // Status presentation
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
    } catch (_) {
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

  // Filters
  Widget _buildFilter() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _guestNameController,
                    decoration: InputDecoration(
                      labelText: 'Guest Name',
                      prefixIcon: const Icon(Icons.person),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _mobileController,
                    decoration: InputDecoration(
                      labelText: 'Mobile',
                      prefixIcon: const Icon(Icons.phone),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Flat Number',
                      prefixIcon: const Icon(Icons.home),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    value: _selectedFlat,
                    items: kFlatOptions
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedFlat = val),
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Building Number',
                      prefixIcon: const Icon(Icons.apartment),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    value: _selectedBuilding,
                    items: kBuildingOptions
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedBuilding = val),
                    isExpanded: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Status',
                      prefixIcon: const Icon(Icons.verified_outlined),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    value: _selectedStatus,
                    items: kStatusOptions,
                    onChanged: (val) => setState(() => _selectedStatus = val),
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Container()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : () => _fetch(reset: true),
                    icon: const Icon(Icons.search),
                    label: const Text('Apply Filters'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            _guestNameController.clear();
                            _mobileController.clear();
                            setState(() {
                              _selectedFlat = null;
                              _selectedBuilding = null;
                              _selectedStatus = null;
                            });
                            _fetch(reset: true);
                          },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Filters'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
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
                    label: Text(
                      label,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: color.withOpacity(0.15),
                    side: BorderSide(color: color, width: 1),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  ),
                  const SizedBox(width: 4),
                  if (isPending && _isResidence) ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      ),
                      onPressed: id == 0 ? null : () => _visitorAction(id, 'approve'),
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: const Text('Approve', style: TextStyle(fontSize: 10)),
                    ),
                    const SizedBox(width: 2),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
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
          onPressed: id == 0
              ? null
              : () async {
                  final link = '${AppConfig.baseUrl}/api/visitor/$id/action?action=approve';
                  await Clipboard.setData(ClipboardData(text: link));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Approval link copied')),
                  );
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _fetch(reset: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilter(),
              if (_loading && _items.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null && _items.isEmpty)
                Center(
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
                )
              else if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 160),
                  child: Center(child: Text('No visitors yet')),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length + (_more ? 1 : 0),
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
                    return _buildVisitorItem(context, index);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
