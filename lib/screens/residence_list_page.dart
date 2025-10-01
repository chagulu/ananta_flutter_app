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
        if (mounted) setState(() => _loading = false);
        return;
      }

      final qp = <String, dynamic>{
        'page': _page,
        'size': _size,
      };
      if (_nameController.text.trim().isNotEmpty) {
        qp['name'] = _nameController.text.trim();
      }
      if (_mobileController.text.trim().isNotEmpty) {
        qp['mobileNo'] = _mobileController.text.trim();
      }
      if (_selectedFlat != null) qp['flatNumber'] = _selectedFlat;
      if (_selectedBuilding != null) qp['buildingNumber'] = _selectedBuilding;

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
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      prefixIcon: const Icon(Icons.person),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _mobileController,
                    decoration: InputDecoration(
                      labelText: 'Mobile No',
                      prefixIcon: const Icon(Icons.phone),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
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
                  ),
                ),
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
                    onPressed: _loading ? null : _clearFilters,
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

  Widget _buildResidenceCard(Map<String, dynamic> res) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueAccent,
          child: Text(
            (res['name']?.toString().substring(0, 1) ?? '-').toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          res['name']?.toString() ?? '-',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.phone, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(res['mobileNo']?.toString() ?? '-'),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text(res['address']?.toString() ?? '-')),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.home_work, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text("Flat: ${res['flatNumber'] ?? '-'}, Bldg: ${res['buildingNumber'] ?? '-'}"),
            ]),
          ],
        ),
      ),
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
          if (_residences.isEmpty && !_loading)
            const Center(child: Text('No residences found.')),
          ..._residences.map(_buildResidenceCard).toList(),
          if (_more && !_loading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ElevatedButton(
                  onPressed: _loadMore,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Load More'),
                ),
              ),
            ),
          if (_loading && _residences.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
