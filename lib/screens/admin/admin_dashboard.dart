// File: lib/screens/admin/dashboard.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _secure = const FlutterSecureStorage();
  late final Dio _dio;

  bool _loading = true;
  bool _error = false;
  String _errorMessage = '';
  Map<String, dynamic>? _response; // full response

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      // If using a global baseUrl via HomeShell/api, you can reuse that instead.
      // For standalone operation, set emulator host or env base:
      baseUrl: "http://10.0.2.2:8080",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = false;
      _errorMessage = '';
    });

    try {
      final token = await _secure.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated');
      }

      final res = await _dio.get(
        '/api/admin/dashboard',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (res.statusCode == 200) {
        final d = res.data;
        if (d is Map<String, dynamic>) {
          setState(() => _response = d);
        } else {
          setState(() => _response = {'data': {}});
        }
      } else {
        throw Exception('Failed (${res.statusCode})');
      }
    } on DioException catch (e) {
      setState(() {
        _error = true;
        _errorMessage = e.response?.data?.toString() ?? e.message ?? "Unknown error";
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
    final appBarTitle = 'Admin Dashboard';
    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? Center(
                  child: Text(
                    "Error: $_errorMessage",
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final payload = (_response?['data'] is Map<String, dynamic>)
        ? _response!['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final today = payload['todayVisitors'];
    final total = payload['totalVisitors'];
    final approved = payload['approved'];
    final rejected = payload['rejected'];
    final pending = payload['pending'];

    final events = (payload['events'] is List) ? (payload['events'] as List) : const [];

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Overview', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),

          _statCard('Today visitors', (today ?? 0).toString(), Icons.today, Colors.indigo),
          _statCard('Total visitors', (total ?? 0).toString(), Icons.people, Colors.blue),
          _statCard('Approved', (approved ?? 0).toString(), Icons.check_circle, Colors.green),
          _statCard('Rejected', (rejected ?? 0).toString(), Icons.cancel, Colors.red),
          _statCard('Pending', (pending ?? 0).toString(), Icons.hourglass_top, Colors.orange),

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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e is Map && e['description'] != null)
                      Text(e['description'].toString()),
                    if (e is Map && e['date'] != null)
                      Text(e['date'].toString()), // ISO string; format if needed
                  ],
                ),
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
