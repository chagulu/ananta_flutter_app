import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ananta_app/screens/residence_list_page.dart';
import 'package:ananta_app/screens/visitor_list.dart';
import 'package:ananta_app/screens/visitor_qr.dart';
import 'package:ananta_app/screens/visitor_manual_entry.dart';
import 'package:ananta_app/screens/send_otp_page.dart';
import '../config.dart';
import '../models/login_type.dart';

const String baseUrl = AppConfig.baseUrl;
final _secure = FlutterSecureStorage();

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _secure.read(key: 'access_token');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await _secure.deleteAll();
    }
    handler.next(err);
  }
}

final Dio api = Dio(
  BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Content-Type': 'application/json'},
  ),
)..interceptors.add(AuthInterceptor());

class HomeShell extends StatefulWidget {
  final LoginType loginType;
  final String role;
  const HomeShell({super.key, required this.loginType, required this.role});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late List<Widget> _pages;
  late List<NavigationDestination> _destinations;
  bool _checkingToken = true;

  // Example notifications
  int _notifCount = 2;
  final List<Map<String, String>> _notifications = [
    {'title': 'Visitor approved', 'body': 'John Doe approved'},
    {'title': 'QR generated', 'body': 'Send to the visitor'},
  ];

  @override
  void initState() {
    super.initState();
    _setupMenu();
    _checkTokenStatus();
  }

  Future<void> _checkTokenStatus() async {
    try {
      final token = await _secure.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        _redirectToLogin();
        return;
      }

      final res = await api.get('/guard/auth/check-token');
      final data = res.data;
      if (data is Map && (data['expired'] == true || data['active'] == false)) {
        _redirectToLogin();
      }
    } catch (_) {
      _redirectToLogin();
    } finally {
      if (mounted) setState(() => _checkingToken = false);
    }
  }

  void _redirectToLogin() async {
    await _secure.deleteAll();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SendOtpPage()),
      (route) => false,
    );
  }

  void _setupMenu() {
    if (widget.role == 'ROLE_GUARD') {
      _pages = [
        const ResidenceListPage(),
        const VisitorListPage(loginType: LoginType.guard),
        const GenerateQrPage(),
        const ManualEntryPage(),
      ];
      _destinations = const [
        NavigationDestination(
          icon: Icon(Icons.apartment_outlined),
          selectedIcon: Icon(Icons.apartment),
          label: 'Residence list',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Visitors',
        ),
        NavigationDestination(
          icon: Icon(Icons.qr_code_2_outlined),
          selectedIcon: Icon(Icons.qr_code_2),
          label: 'Generate QR',
        ),
        NavigationDestination(
          icon: Icon(Icons.playlist_add_outlined),
          selectedIcon: Icon(Icons.playlist_add),
          label: 'Manual entry',
        ),
      ];
    } else {
      _pages = [
        const ResidenceListPage(),
        const VisitorListPage(loginType: LoginType.residence),
      ];
      _destinations = const [
        NavigationDestination(
          icon: Icon(Icons.apartment_outlined),
          selectedIcon: Icon(Icons.apartment),
          label: 'Residence list',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Visitors',
        ),
      ];
    }
  }

  void _onMenuSelected(String value) async {
    switch (value) {
      case 'profile':
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile coming soon')));
        break;
      case 'settings':
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Settings coming soon')));
        break;
      case 'logout':
        _redirectToLogin();
        break;
    }
  }

  void _openNotification(int index) {
    // Handle opening a notification (navigate, etc.)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_notifications[index]['title'] ?? 'Notification')),
    );
  }

  void _markAllRead() {
    setState(() => _notifCount = 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingToken) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cs = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Image.asset(
            'assets/logo.png', // ensure in pubspec.yaml
            height: 28,
            fit: BoxFit.contain,
          ),
          actions: [
            // Notifications dropdown with badge dot
            PopupMenuButton<String>(
              tooltip: 'Notifications',
              position: PopupMenuPosition.under,
              offset: const Offset(0, 8),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none),
                  if (_notifCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: cs.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              onOpened: _markAllRead, // clear badge when opening
              itemBuilder: (context) {
                final List<PopupMenuEntry<String>> menu = [];
                menu.add(PopupMenuItem<String>(
                  enabled: false,
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text('Notifications', style: Theme.of(context).textTheme.labelLarge),
                      const Spacer(),
                      if (_notifications.isNotEmpty)
                        Text(
                          '${_notifications.length}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.primary),
                        ),
                    ],
                  ),
                ));

                if (_notifications.isEmpty) {
                  menu.add(const PopupMenuItem<String>(
                    enabled: false,
                    child: Text('No new notifications'),
                  ));
                } else {
                  for (int i = 0; i < _notifications.length && i < 6; i++) {
                    final n = _notifications[i];
                    menu.add(PopupMenuItem<String>(
                      value: 'open_$i',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n['title'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            n['body'] ?? '-',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ));
                  }
                }

                menu.add(const PopupMenuDivider());
                menu.add(const PopupMenuItem<String>(value: 'mark_all', child: Text('Mark all as read')));
                menu.add(const PopupMenuItem<String>(value: 'settings', child: Text('Notification settings')));

                return menu;
              },
              onSelected: (value) {
                if (value.startsWith('open_')) {
                  final idx = int.tryParse(value.split('_').last) ?? -1;
                  if (idx >= 0 && idx < _notifications.length) _openNotification(idx);
                } else if (value == 'mark_all') {
                  _markAllRead();
                } else if (value == 'settings') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification settings')),
                  );
                }
              },
            ),
            PopupMenuButton<String>(
              onSelected: _onMenuSelected,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'profile', child: Text('Profile')),
                PopupMenuItem(value: 'settings', child: Text('Settings')),
                PopupMenuItem(value: 'logout', child: Text('Logout')),
              ],
            ),
          ],
        ),
        body: IndexedStack(
          index: _index.clamp(0, _pages.length - 1),
          children: _pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: _destinations,
        ),
      ),
    );
  }
}
