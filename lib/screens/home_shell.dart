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
      const VisitorListPage(loginType: LoginType.guard), // 👈 add this
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
        label: 'Visitors', // 👈 new visitors tab
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
    // Residence role
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

  @override
  Widget build(BuildContext context) {
    if (_checkingToken) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ananta Residency'),
          actions: [
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
