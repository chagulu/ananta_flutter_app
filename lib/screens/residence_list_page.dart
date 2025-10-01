import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../config.dart';
import 'home_shell.dart'; // api and baseUrl

class ResidenceListPage extends StatefulWidget {
  const ResidenceListPage({super.key});

  @override
  State<ResidenceListPage> createState() => _ResidenceListPageState();
}

class _ResidenceListPageState extends State<ResidenceListPage> {
  final List<Map<String, dynamic>> _residences = [];
  bool _loading = false;
  bool _more = true;
  int _page = 0;
  final int _size = 10;
  Timer? _pollingTimer;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  String? _selectedFlat;
  String? _selectedBuilding;

  // Static options
  static const List<String> kFlatOptions = <String>[
    'A1','A2','B1','B2','C1','C2','D1','D2','E1','E2',
  ];
  static const List<String> kBuildingOptions = <String>[
    'A1','A2','A3','A4','A5','A6','A7','A8',
  ];

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1500), (_) => _fetch(reset: true));
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      setState(() {
        _page = 0;
        _residences.clear();
        _more = true;
      });
    }

    setState(() => _loading = true);

    try {
      // Validate flat & building selection (must be both or none)
      final invalidPair = (_selectedFlat != null && _selectedBuilding == null) ||
          (_selectedFlat == null && _selectedBuilding != null);
      if (invalidPair) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Both Flat and Building must be selected together')),
          );
        }
        if (mounted) setState(() => _loading = false); // ensure loading is cleared
        return;
      }

      // Build query map without nulls/empties
      final qp = <String, dynamic>{
        'page': _page,
        'size': _size,
      };
      final name = _nameController.text.trim();
      final mobile = _mobileController.text.trim();
      if (name.isNotEmpty) qp['name'] = name;
      if (mobile.isNotEmpty) qp['mobileNo'] = mobile;
      if (_selectedFlat != null && _selectedFlat!.isNotEmpty) {
        qp['flatNumber'] = _selectedFlat!;
      }
      if (_selectedBuilding != null && _selectedBuilding!.isNotEmpty) {
        qp['buildingNumber'] = _selectedBuilding!;
      }

      final res = await api.get('/api/residences', queryParameters: qp);

      final content = res.data['content'] as List<dynamic>? ?? const [];

      setState(() {
        _residences.addAll(content.map((e) => Map<String, dynamic>.from(e)));
        final total = (res.data['totalElements'] ?? 0) as int;
        _more = (_page + 1) * _size < total;
      });
    } on DioException catch (e) {
      debugPrint('Failed to fetch residences: ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_more || _loading) return;
    setState(() => _page += 1);
    await _fetch();
  }

  void _clearFilters() {
    _nameController.clear();
    _mobileController.clear();
    setState(() {
      _selectedFlat = null;
      _selectedBuilding = null;
    });
    _fetch(reset: true);
  }

  Widget _buildFilter() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _mobileController,
                decoration: const InputDecoration(labelText: 'Mobile No'),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Flat Number'),
                value: _selectedFlat,
                items: kFlatOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedFlat = val),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Building Number'),
                value: _selectedBuilding,
                items: kBuildingOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedBuilding = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _loading ? null : () => _fetch(reset: true),
              icon: const Icon(Icons.search),
              label: const Text('Apply Filters'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _clearFilters,
              icon: const Icon(Icons.clear),
              label: const Text('Clear Filters'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _fetch(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildFilter(),
          const SizedBox(height: 12),
          if (_residences.isEmpty && !_loading)
            const Center(child: Text('No residences found.')),
          ..._residences.map((res) {
            return Card(
              child: ListTile(
                title: Text(res['name']?.toString() ?? '-'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mobile: ${res['mobileNo']?.toString() ?? '-'}'),
                    Text('Address: ${res['address']?.toString() ?? '-'}'),
                    Text('Flat: ${res['flatNumber']?.toString() ?? '-'}, Bldg: ${res['buildingNumber']?.toString() ?? '-'}'),
                  ],
                ),
              ),
            );
          }).toList(),
          if (_more)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ElevatedButton(
                  onPressed: _loadMore,
                  child: const Text('Load More'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
