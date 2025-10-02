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
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

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

/// -------------------- DASHBOARD PAGE --------------------
class DashboardPage extends StatelessWidget {
  final String role;
  const DashboardPage({super.key, required this.role});

  Widget _statCard(BuildContext ctx, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: Theme.of(ctx).textTheme.bodyLarge),
            ),
            Text(value,
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ⚡ For now values are static demo data; replace with API calls
    if (role == "ROLE_RESIDENCE") {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statCard(context, "Pending requests", "2", Icons.pending_actions, cs.primary),
          _statCard(context, "Total requests", "12", Icons.history, cs.tertiary),
          _statCard(context, "Upcoming events", "2", Icons.event, cs.secondary),
        ],
      );
    } else if (role == "ROLE_GUARD") {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statCard(context, "Today's visitors", "15", Icons.today, cs.primary),
          _statCard(context, "Approved", "10", Icons.check_circle, Colors.green),
          _statCard(context, "Rejected", "3", Icons.cancel, Colors.red),
          _statCard(context, "Pending", "2", Icons.pending, cs.tertiary),
        ],
      );
    } else {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statCard(context, "Total residences", "120", Icons.apartment, cs.primary),
          _statCard(context, "Total guards", "8", Icons.security, cs.secondary),
          _statCard(context, "Total visitors", "560", Icons.people, cs.tertiary),
          _statCard(context, "Events posted", "6", Icons.event, Colors.orange),
        ],
      );
    }
  }
}

/// -------------------- MAIN SHELL --------------------
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

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  int _notifCount = 0;
  final List<Map<String, String>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _setupMenu();
    _checkTokenStatus();
    _setupFCM();
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
        DashboardPage(role: widget.role),
        const ResidenceListPage(),
        const VisitorListPage(loginType: LoginType.guard),
        const GenerateQrPage(),
        const ManualEntryPage(),
      ];
      _destinations = const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.apartment_outlined), selectedIcon: Icon(Icons.apartment), label: 'Residences'),
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Visitors'),
        NavigationDestination(icon: Icon(Icons.qr_code_2_outlined), selectedIcon: Icon(Icons.qr_code_2), label: 'QR'),
        NavigationDestination(icon: Icon(Icons.playlist_add_outlined), selectedIcon: Icon(Icons.playlist_add), label: 'Manual'),
      ];
    } else if (widget.role == 'ROLE_RESIDENCE') {
      _pages = [
        DashboardPage(role: widget.role),
        const VisitorListPage(loginType: LoginType.residence),
      ];
      _destinations = const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Visitors'),
      ];
    } else {
      _pages = [
        DashboardPage(role: widget.role),
        const ResidenceListPage(),
        const VisitorListPage(loginType: LoginType.guard),
      ];
      _destinations = const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.apartment_outlined), selectedIcon: Icon(Icons.apartment), label: 'Residences'),
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Visitors'),
      ];
    }
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
        _redirectToLogin();
        break;
    }
  }

  /// ---------------- FCM SETUP ----------------
  Future<void> _setupFCM() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);

    await _localNotificationsPlugin.initialize(initSettings);

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    print("FCM Token: $token");

    FirebaseMessaging.onMessage.listen((m) {
      _addNotification(m);
      _showLocalNotification(m);
    });
  }

  void _addNotification(RemoteMessage message) {
    setState(() {
      _notifications.insert(0, {
        'title': message.notification?.title ?? 'Notification',
        'body': message.notification?.body ?? '',
      });
      _notifCount = _notifications.length;
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default',
      importance: Importance.max,
      priority: Priority.high,
    );
    await _localNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? "Notification",
      message.notification?.body ?? "",
      const NotificationDetails(android: androidDetails),
    );
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
          centerTitle: true,
          title: Image.asset('assets/logo.png', height: 28, fit: BoxFit.contain),
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
          index: _index,
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
