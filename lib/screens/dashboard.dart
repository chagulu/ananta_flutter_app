// lib/screens/dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dashboard_widgets.dart';


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
  Map<String, dynamic> _data = {};
  String? _roleFromStorage;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: 'http://10.0.2.2:8080', // change if needed (emulator local)
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
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

      final res = await _dio.get('/api/dashboard',
          options: Options(headers: {'Authorization': 'Bearer $token'}));

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

  Future<void> _onRefresh() async {
    await _loadAndFetch();
  }

  Widget _buildStatCard(String label, String value, {IconData? icon, Color? color}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color ?? cs.primaryContainer,
              child: Icon(icon ?? Icons.info_outline, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResident(Map<String, dynamic> data) {
    // Expected fields: pendingRequests (list), totalRequestsTillDate, upcomingEvents (list)
    final pending = (data['pendingRequests'] as List<dynamic>?) ?? [];
    final total = (data['totalRequestsTillDate'] ?? 0).toString();
    final events = (data['upcomingEvents'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildStatCard('Total requests (till date)', total, icon: Icons.history, color: Colors.blueAccent),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pending requests', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (pending.isEmpty)
                    Text('No pending requests', style: Theme.of(context).textTheme.bodyMedium)
                  else
                    ...pending.map((p) {
                      final title = p['visitorName'] ?? p['guestName'] ?? 'Visitor';
                      final flat = p['flatNumber'] ?? p['flat'] ?? '-';
                      final time = p['requestTime'] ?? p['visitTime'] ?? '';
                      final status = p['status'] ?? 'PENDING';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(title),
                        subtitle: Text('$flat • ${time.toString()}'),
                        trailing: Text(status.toString(), style: TextStyle(color: Colors.orange)),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Upcoming events', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (events.isEmpty) Text('No upcoming events', style: Theme.of(context).textTheme.bodyMedium),
                ...events.map((e) {
                  final t = e['title'] ?? e['name'] ?? 'Event';
                  final d = e['date'] ?? e['when'] ?? '';
                  final desc = e['description'] ?? '';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t),
                    subtitle: Text('$d\n$desc', maxLines: 2, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuard(Map<String, dynamic> data) {
    // Expected fields: todayStats {totalVisitors, approved, rejected, pending}
    final today = data['todayStats'] as Map<String, dynamic>? ?? {};
    final totalVisitors = (today['totalVisitors'] ?? 0).toString();
    final approved = (today['approved'] ?? 0).toString();
    final rejected = (today['rejected'] ?? 0).toString();
    final pending = (today['pending'] ?? 0).toString();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        _buildStatCard('Today • Visitors', totalVisitors, icon: Icons.people, color: Colors.teal),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildStatCard('Approved', approved, icon: Icons.check_circle, color: Colors.green)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard('Rejected', rejected, icon: Icons.cancel, color: Colors.red)),
        ]),
        const SizedBox(height: 8),
        _buildStatCard('Pending', pending, icon: Icons.hourglass_empty, color: Colors.orange),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ElevatedButton.icon(onPressed: () => _navigateTo('/visitorList'), icon: const Icon(Icons.list), label: const Text('Visitor List')),
                ElevatedButton.icon(onPressed: () => _navigateTo('/manualEntry'), icon: const Icon(Icons.playlist_add), label: const Text('Manual Entry')),
                ElevatedButton.icon(onPressed: () => _navigateTo('/generateQr'), icon: const Icon(Icons.qr_code), label: const Text('Generate QR')),
              ])
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildAdmin(Map<String, dynamic> data) {
    // Expected fields: overallStats and events
    final overall = data['overallStats'] as Map<String, dynamic>? ?? {};
    final totalVisitors = (overall['totalVisitors'] ?? 0).toString();
    final approved = (overall['approved'] ?? 0).toString();
    final rejected = (overall['rejected'] ?? 0).toString();
    final pending = (overall['pending'] ?? 0).toString();

    final events = (data['events'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        _buildStatCard('Total visitors', totalVisitors, icon: Icons.timeline, color: Colors.purple),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildStatCard('Approved', approved, icon: Icons.check, color: Colors.green)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard('Rejected', rejected, icon: Icons.close, color: Colors.red)),
        ]),
        const SizedBox(height: 8),
        _buildStatCard('Pending', pending, icon: Icons.pending_actions, color: Colors.orange),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Events', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (events.isEmpty) Text('No events', style: Theme.of(context).textTheme.bodyMedium),
              ...events.map((e) {
                final t = e['title'] ?? e['name'] ?? 'Event';
                final d = e['date'] ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t),
                  subtitle: Text(d),
                );
              }).toList(),
            ]),
          ),
        ),
      ]),
    );
  }

  void _navigateTo(String route) {
    // Generic helper for quick actions
    if (!mounted) return;
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
            tooltip: 'Refresh',
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Failed to load dashboard', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(_errorMessage, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadAndFetch, child: const Text('Retry')),
                    ]),
                  ),
                )
              : Builder(builder: (_) {
                  final role = (_data['role'] ?? _roleFromStorage ?? 'ROLE_RESIDENT').toString().toUpperCase();
                  if (role.contains('RESIDENT')) return _buildResident(_data);
                  if (role.contains('GUARD')) return _buildGuard(_data);
                  if (role.contains('ADMIN')) return _buildAdmin(_data);
                  // fallback: show everything
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      _buildAdmin(_data),
                      const SizedBox(height: 12),
                      _buildGuard(_data),
                      const SizedBox(height: 12),
                      _buildResident(_data),
                    ]),
                  );
                }),
    );
  }
}
