import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../config.dart';
import 'home_shell.dart'; // contains api and baseUrl

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
  final TextEditingController _flatController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();

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
    _flatController.dispose();
    _buildingController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetch(reset: true));
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;

    // Validate Flat & Building
    if ((_flatController.text.isNotEmpty && _buildingController.text.isEmpty) ||
        (_flatController.text.isEmpty && _buildingController.text.isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Both Flat and Building must be selected together')),
      );
      return;
    }

    if (reset) {
      setState(() {
        _page = 0;
        _residences.clear();
        _more = true;
      });
    }

    setState(() => _loading = true);

    try {
      final res = await api.get('/api/residences', queryParameters: {
        'page': _page,
        'size': _size,
        'name': _nameController.text,
        'mobileNo': _mobileController.text,
        'flatNumber': _flatController.text,
        'buildingNumber': _buildingController.text,
      });

      final content = res.data['content'] as List<dynamic>? ?? [];

      setState(() {
        _residences.addAll(content.map((e) => Map<String, dynamic>.from(e)));
        _more = (_page + 1) * _size < (res.data['totalElements'] ?? 0);
      });
    } on DioException catch (e) {
      debugPrint('Failed to fetch residences: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch residences: ${e.message}')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_more || _loading) return;
    setState(() => _page += 1);
    await _fetch();
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
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _mobileController,
                decoration: const InputDecoration(labelText: 'Mobile No'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Building Number'),
                value: _buildingController.text.isEmpty ? null : _buildingController.text,
                items: kBuildingOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) {
                  setState(() => _buildingController.text = val ?? '');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Flat Number'),
                value: _flatController.text.isEmpty ? null : _flatController.text,
                items: kFlatOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) {
                  setState(() => _flatController.text = val ?? '');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _fetch(reset: true),
          icon: const Icon(Icons.search),
          label: const Text('Apply Filters'),
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
          if (_loading && _residences.isEmpty)
            const Center(child: CircularProgressIndicator()),
          ..._residences.map((res) {
            return Card(
              child: ListTile(
                title: Text(res['name'] ?? '-'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mobile: ${res['mobileNo'] ?? '-'}'),
                    Text('Address: ${res['address'] ?? '-'}'),
                    Text('Flat: ${res['flatNumber'] ?? '-'}, Bldg: ${res['buildingNumber'] ?? '-'}'),
                  ],
                ),
              ),
            );
          }).toList(),
          if (_more && !_loading)
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
