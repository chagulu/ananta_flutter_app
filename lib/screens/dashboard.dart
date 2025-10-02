import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A unified dashboard for Resident & Guard users.
/// - Calls /api/resident/dashboard for residents
/// - Calls /api/guard/dashboard for guards
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  late final Dio _dio;

  bool _loading = true;
  bool _error = false;
  String _errorMessage = '';
  Map<String, dynamic>? _data;
  String? _roleFromStorage;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: "http://10.0.2.2:8080", // ✅ change for your backend host
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
    _loadAndFetch();
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

      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated');
      }

      // ✅ Decide endpoint based on role
      String endpoint = '/api/dashboard';
      if ((_roleFromStorage ?? '').toUpperCase().contains('RESIDENT') ||
          (_roleFromStorage ?? '').toUpperCase().contains('RESIDENCE')) {
        endpoint = '/api/resident/dashboard';
      } else if ((_roleFromStorage ?? '').toUpperCase().contains('GUARD')) {
        endpoint = '/api/guard/dashboard';
      }

      final res = await _dio.get(
        endpoint,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (res.statusCode == 200) {
        final d = res.data;
        if (d is Map<String, dynamic>) {
          setState(() => _data = d);
        } else {
          setState(() => _data = {'role': _roleFromStorage ?? 'UNKNOWN'});
        }
      } else {
        throw Exception('Failed to load dashboard (${res.statusCode})');
      }
    } on DioException catch (e) {
      setState(() {
        _error = true;
        _errorMessage =
            e.response?.data?.toString() ?? e.message ?? "Unknown error occurred";
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _roleFromStorage?.toUpperCase() == 'ROLE_GUARD'
              ? 'Guard Dashboard'
              : 'Resident Dashboard',
        ),
      ),
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
    if (_data == null) {
      return const Center(child: Text("No data available"));
    }

    final data = _data?['data'] ?? {};
    final events = (data['events'] ?? []) as List;

    return RefreshIndicator(
      onRefresh: _loadAndFetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Welcome, ${_roleFromStorage ?? "User"}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          // ✅ Dashboard cards
          if (data['totalVisitors'] != null)
            _statCard('Total Visitors', data['totalVisitors'].toString(),
                Icons.people, Colors.blue),
          if (data['approved'] != null)
            _statCard('Approved Visitors', data['approved'].toString(),
                Icons.check_circle, Colors.green),
          if (data['pending'] != null)
            _statCard('Pending Requests', data['pending'].toString(),
                Icons.hourglass_top, Colors.orange),
          if (data['rejected'] != null)
            _statCard('Rejected Visitors', data['rejected'].toString(),
                Icons.cancel, Colors.red),

          const SizedBox(height: 24),
          Text('Upcoming Events',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          if (events.isEmpty)
            const Text("No upcoming events"),
          for (var e in events)
            Card(
              child: ListTile(
                leading: const Icon(Icons.event),
                title: Text(e['title'] ?? ''),
                subtitle: Text(e['date'] ?? ''),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCard(
      String title, String value, IconData icon, Color color) {
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
