// lib/screens/dashboard_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DashboardPage extends StatefulWidget {
  final String? role; // optional: if you want to pass role in constructor
  final String? baseUrl; // optional: custom baseUrl injection
  const DashboardPage({super.key, this.role, this.baseUrl});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
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
      baseUrl: widget.baseUrl ?? 'http://10.0.2.2:8080', // emulator local
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

      final res = await _dio.get(
        '/api/dashboard',
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

  Future<void> _onRefresh() async {
    await _loadAndFetch();
  }

  // ---------- UI building blocks ----------

  Widget _heroHeader(String role) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary.withOpacity(0.20), cs.tertiary.withOpacity(0.18)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(
                      role.contains('GUARD')
                          ? Icons.shield_outlined
                          : role.contains('ADMIN')
                              ? Icons.admin_panel_settings_outlined
                              : Icons.home_outlined,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dashboard',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          role.contains('GUARD')
                              ? 'Guard overview'
                              : role.contains('ADMIN')
                                  ? 'Admin overview'
                                  : 'Residence overview',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    int index = 0,
  }) {
    final cs = Theme.of(context).colorScheme;
    return _StaggerTile(
      index: index,
      child: GestureDetector(
        onTapDown: (_) => _StaggerTileScale.of(context)?.setScale(0.98),
        onTapUp: (_) => _StaggerTileScale.of(context)?.setScale(1.0),
        onTapCancel: () => _StaggerTileScale.of(context)?.setScale(1.0),
        onTap: onTap,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(value,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _eventsCard(List events, {String title = 'Upcoming events'}) {
    final cs = Theme.of(context).colorScheme;
    if (events.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No upcoming events'),
        ),
      );
    }
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...events.take(2).map((e) {
            final t = e['title'] ?? e['name'] ?? 'Event';
            final d = e['date'] ?? e['when'] ?? '';
            final desc = e['description'] ?? '';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle:
                  Text('$d\n$desc', maxLines: 2, overflow: TextOverflow.ellipsis),
            );
          }),
        ]),
      ),
    );
  }

  // ---------- Role sections ----------

  Widget _buildResident(Map<String, dynamic> data) {
    final pending = (data['pendingRequests'] as List<dynamic>?) ?? [];
    final total = (data['totalRequestsTillDate'] ?? 0).toString();
    final events = (data['upcomingEvents'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _heroHeader('ROLE_RESIDENCE'),
          const SizedBox(height: 12),
          _statTile(
            label: 'Total requests (till date)',
            value: total,
            icon: Icons.history,
            color: Colors.blueAccent,
            onTap: () {},
            index: 0,
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pending requests',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (pending.isEmpty)
                  Text('No pending requests',
                      style: Theme.of(context).textTheme.bodyMedium)
                else
                  ...pending.map((p) {
                    final title = p['visitorName'] ?? p['guestName'] ?? 'Visitor';
                    final flat = p['flatNumber'] ?? p['flat'] ?? '-';
                    final time = p['requestTime'] ?? p['visitTime'] ?? '';
                    final status = (p['status'] ?? 'PENDING').toString();
                    final color = status.toUpperCase() == 'APPROVED'
                        ? Colors.green
                        : status.toUpperCase() == 'REJECTED'
                            ? Colors.red
                            : Colors.orange;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(title),
                      subtitle: Text('$flat • ${time.toString()}'),
                      trailing: Chip(
                        label: Text(status,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                        backgroundColor: color.withOpacity(0.12),
                        side: BorderSide(color: color),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          _eventsCard(events),
        ],
      ),
    );
  }

  Widget _buildGuard(Map<String, dynamic> data) {
    final today = data['todayStats'] as Map<String, dynamic>? ?? {};
    final totalVisitors = (today['totalVisitors'] ?? 0).toString();
    final approved = (today['approved'] ?? 0).toString();
    final rejected = (today['rejected'] ?? 0).toString();
    final pending = (today['pending'] ?? 0).toString();

    final tiles = [
      _statTile(
        label: 'Today • Visitors',
        value: totalVisitors,
        icon: Icons.people,
        color: Colors.teal,
        onTap: () => _navigateTo('/visitorList'),
        index: 0,
      ),
      _statTile(
        label: 'Approved',
        value: approved,
        icon: Icons.verified_outlined,
        color: Colors.green,
        onTap: () => _navigateTo('/visitorList?status=APPROVED'),
        index: 1,
      ),
      _statTile(
        label: 'Rejected',
        value: rejected,
        icon: Icons.cancel_outlined,
        color: Colors.red,
        onTap: () => _navigateTo('/visitorList?status=REJECTED'),
        index: 2,
      ),
      _statTile(
        label: 'Pending',
        value: pending,
        icon: Icons.hourglass_empty,
        color: Colors.orange,
        onTap: () => _navigateTo('/visitorList?status=PENDING'),
        index: 3,
      ),
    ];

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _heroHeader('ROLE_GUARD'),
          const SizedBox(height: 12),
          ...tiles,
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Quick actions',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.tonalIcon(
                      onPressed: () => _navigateTo('/visitorList'),
                      icon: const Icon(Icons.list),
                      label: const Text('Visitor List')),
                  FilledButton.tonalIcon(
                      onPressed: () => _navigateTo('/manualEntry'),
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Manual Entry')),
                  FilledButton.tonalIcon(
                      onPressed: () => _navigateTo('/generateQr'),
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Generate QR')),
                ])
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdmin(Map<String, dynamic> data) {
    final overall = data['overallStats'] as Map<String, dynamic>? ?? {};
    final totalVisitors = (overall['totalVisitors'] ?? 0).toString();
    final approved = (overall['approved'] ?? 0).toString();
    final rejected = (overall['rejected'] ?? 0).toString();
    final pending = (overall['pending'] ?? 0).toString();
    final events = (data['events'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _heroHeader('ROLE_ADMIN'),
          const SizedBox(height: 12),
          _statTile(
            label: 'Total visitors',
            value: totalVisitors,
            icon: Icons.timeline,
            color: Colors.purple,
            onTap: () {},
            index: 0,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  label: 'Approved',
                  value: approved,
                  icon: Icons.check,
                  color: Colors.green,
                  onTap: () {},
                  index: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(
                  label: 'Rejected',
                  value: rejected,
                  icon: Icons.close,
                  color: Colors.red,
                  onTap: () {},
                  index: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _statTile(
            label: 'Pending',
            value: pending,
            icon: Icons.pending_actions,
            color: Colors.orange,
            onTap: () {},
            index: 3,
          ),
          const SizedBox(height: 12),
          _eventsCard(events, title: 'Events'),
        ],
      ),
    );
  }

  void _navigateTo(String route) {
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
          ),
        ],
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(12),
              children: List.generate(5, (i) => _shimmerTile(context)),
            )
          : _error
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Failed to load dashboard',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(_errorMessage, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: _loadAndFetch, child: const Text('Retry')),
                  ]),
                ))
              : Builder(builder: (_) {
                  final inferred = (_data['role'] ??
                          widget.role ??
                          _roleFromStorage ??
                          'ROLE_RESIDENCE')
                      .toString()
                      .toUpperCase();
                  if (inferred.contains('RESIDENT') ||
                      inferred.contains('RESIDENCE')) {
                    return _buildResident(_data);
                  }
                  if (inferred.contains('GUARD')) return _buildGuard(_data);
                  if (inferred.contains('ADMIN')) return _buildAdmin(_data);
                  // fallback: show guard basics
                  return _buildGuard(_data);
                }),
    );
  }

  // Simple shimmer placeholder (no package)
  Widget _shimmerTile(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Container(
        height: 78,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 12, width: 120, color: cs.surfaceContainerHighest),
                  const SizedBox(height: 12),
                  Container(height: 18, width: 80, color: cs.surfaceContainerHighest),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Internal stagger+scale helpers ----------

class _StaggerTile extends StatefulWidget {
  final Widget child;
  final int index;
  const _StaggerTile({required this.child, required this.index});

  @override
  State<_StaggerTile> createState() => _StaggerTileState();
}

class _StaggerTileState extends State<_StaggerTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  final _scaleController = _TileScaleController();

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _ac.forward();
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StaggerTileScale(
      controller: _scaleController,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: _scaleController.scale,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _TileScaleController {
  double scale = 1.0;
  void setScale(double v) => scale = v;
}

class _StaggerTileScale extends InheritedWidget {
  final _TileScaleController controller;
  const _StaggerTileScale({required this.controller, required Widget child, super.key})
      : super(child: child);

  static _TileScaleController? of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<_StaggerTileScale>();
    return w?.controller;
  }

  @override
  bool updateShouldNotify(covariant _StaggerTileScale oldWidget) => true;
}
