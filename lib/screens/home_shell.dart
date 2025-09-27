import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ananta_app/screens/visitor_list.dart';
import 'package:ananta_app/screens/visitor_qr.dart';
import 'package:ananta_app/screens/visitor_manual_entry.dart';
import '../config.dart';
import '../models/login_type.dart';



const String baseUrl = AppConfig.baseUrl;
final _secure = const FlutterSecureStorage();

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _secure.read(key: 'access_token');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
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
  const HomeShell({super.key, required this.loginType});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      VisitorListPage(loginType: widget.loginType),
      const GenerateQrPage(),
      const ManualEntryPage(),
    ];
  }

  void _onMenuSelected(String value) async {
    switch (value) {
      case 'profile':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile coming soon')));
        break;
      case 'settings':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
        break;
      case 'logout':
        await _secure.delete(key: 'access_token');
        if (!mounted) return;
        Navigator.of(context).popUntil((r) => r.isFirst);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ananta'),
        backgroundColor: scheme.surface,
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenuSelected,
            itemBuilder: (context) => const [
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment),
            label: 'Residence list',
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
        ],
      ),
    );
  }
}
