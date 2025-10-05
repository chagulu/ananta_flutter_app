// File: lib/screens/dashboard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  late final Dio _dio;

  bool _loading = true;
  bool _error = false;
  String _errorMessage = '';
  Map<String, dynamic>? _response;
  String? _roleFromStorage;

  Timer? _autoTimer; // auto-refresh timer

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dio = Dio(BaseOptions(
      baseUrl: "http://10.0.2.2:8080",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
    _loadAndFetch();
    _startAutoRefresh(); // start periodic refresh
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoTimer?.cancel();
    super.dispose();
  }

  // Refresh when app returns to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAndFetch();
    }
  }

  void _startAutoRefresh() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (mounted) _loadAndFetch();
    });
  }

  Future<void> _loadAndFetch() async {
    setState(() {
      _loading = true;
      _error = false;
      _errorMessage = '';
    });

    try {
      final token = await _secure.read(key: 'access_token');
      final storedRole = await _secure.read(key: 'user_role');
      _roleFromStorage = storedRole;
      debugPrint('Dashboard roleFromStorage=$_roleFromStorage');

      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated');
      }

      final roleStr = (_roleFromStorage ?? '').toUpperCase();
      String endpoint = '/api/dashboard';
      if (roleStr.contains('RESIDENT') || roleStr.contains('RESIDENCE')) {
        endpoint = '/api/resident/dashboard';
      } else if (roleStr.contains('GUARD')) {
        endpoint = '/api/guard/dashboard';
      } else if (roleStr.contains('ADMIN')) {
        endpoint = '/api/admin/dashboard';
      }
      debugPrint('Dashboard calling endpoint=$endpoint');

      final res = await _dio.get(
        endpoint,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      debugPrint('Dashboard status=${res.statusCode}');
      debugPrint('Dashboard raw=${res.data}');

      if (res.statusCode == 200) {
        final d = res.data;
        // Normalize to a map and store
        final map = (d is Map<String, dynamic>) ? d : <String, dynamic>{};
        setState(() => _response = map);

        // Persist resident unit for downstream pages
        final roleStr = (_roleFromStorage ?? '').toUpperCase();
final isResident = roleStr.contains('RESIDENT') || roleStr.contains('RESIDENCE');
if (isResident) {
  final data = (map['data'] is Map) ? map['data'] as Map : <String, dynamic>{};
  final building = data['buildingNumber']?.toString();
  final flat = data['flatNumber']?.toString();
  if (building != null && building.isNotEmpty) {
    await _secure.write(key: 'resident_building_number', value: building);
    debugPrint('Dashboard: stored building=$building');
  }
  if (flat != null && flat.isNotEmpty) {
    await _secure.write(key: 'resident_flat_number', value: flat);
    debugPrint('Dashboard: stored flat=$flat');
  }
}
      } else {
        throw Exception('Failed to load dashboard (${res.statusCode})');
      }
    } on DioException catch (e) {
      setState(() {
        _error = true;
        _errorMessage = e.response?.data?.toString() ?? e.message ?? "Unknown error occurred";
      });
    } catch (e) {
      setState(() {
        _error = true;
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (_roleFromStorage ?? '').toUpperCase() == 'ROLE_GUARD'
        ? 'Guard Dashboard'
        : (_roleFromStorage ?? '').toUpperCase() == 'ROLE_ADMIN'
            ? 'Admin Dashboard'
            : 'Resident Dashboard';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? Center(
                  child: Text(
                    "Error: $_errorMessage",
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : _buildDashboard(context),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final payload = (_response?['data'] is Map<String, dynamic>)
        ? _response!['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final roleStr = (_roleFromStorage ?? '').toUpperCase();
    final isGuard = roleStr.contains('GUARD');
    final isResident = roleStr.contains('RESIDENT') || roleStr.contains('RESIDENCE');

    final todayVisitors = payload['todayVisitors'];
    final totalVisitors = payload['totalVisitors'];
    final approved = payload['approved'];
    final pending = payload['pending'];
    final rejected = payload['rejected'];
    final building = payload['buildingNumber']?.toString();
    final flat = payload['flatNumber']?.toString();

    final pendingVisitors = payload['pendingVisitors'];

    final events = (payload['events'] is List) ? (payload['events'] as List) : const [];

    return RefreshIndicator(
      onRefresh: _loadAndFetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Welcome, ${_roleFromStorage ?? "User"}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (isResident && building != null && building.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Chip(label: Text('Building: $building')),
                ),
              if (isResident && flat != null && flat.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Chip(label: Text('Flat: $flat')),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (isResident) ...[
            _statCard('Today visitors', (todayVisitors ?? 0).toString(), Icons.today, Colors.indigo),
            _statCard('Total visitors', (totalVisitors ?? 0).toString(), Icons.people, Colors.blue),
            _statCard('Approved', (approved ?? 0).toString(), Icons.check_circle, Colors.green),
            _statCard('Rejected', (rejected ?? 0).toString(), Icons.cancel, Colors.red),
            _statCard('Pending', (pending ?? 0).toString(), Icons.hourglass_top, Colors.orange),
          ],

          if (isGuard) ...[
            _statCard('Pending visitors', (pendingVisitors ?? 0).toString(), Icons.pending_actions, Colors.orange),
          ],

          const SizedBox(height: 24),
          Text('Upcoming events', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          if (events.isEmpty)
            const Text("No upcoming events"),
          for (var e in events)
            Card(
              child: ListTile(
                leading: const Icon(Icons.event),
                title: Text((e is Map && e['title'] != null) ? e['title'].toString() : ''),
                subtitle: Text((e is Map && (e['date'] ?? e['eventDate']) != null)
                    ? (e['date'] ?? e['eventDate']).toString()
                    : ''),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
