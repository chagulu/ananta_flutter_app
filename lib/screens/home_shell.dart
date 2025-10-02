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

  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Example notifications list
  int _notifCount = 0;
  final List<Map<String, String>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _setupMenu();
    _checkTokenStatus();
    _setupFCM(); // initialize Firebase messaging
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_notifications[index]['title'] ?? 'Notification')),
    );
  }

  void _markAllRead() {
    setState(() => _notifCount = 0);
  }

  /// ---------------- FCM SETUP ----------------
  Future<void> _setupFCM() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Android notification channel
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: (payload) {
      // handle notification tap
    });

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission (iOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission for notifications');
    }

    // Get FCM token
    final token = await messaging.getToken();
    print('FCM Token: $token');

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message: ${message.notification?.title}');
      _addNotification(message);
      _showLocalNotification(message);
    });

    // Background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // When app opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _addNotification(message);
      print('Notification opened: ${message.notification?.title}');
    });
  }

  /// Background message handler
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    print('Background message received: ${message.messageId}');
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      channelDescription: 'General notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'Test Notification',
      message.notification?.body ?? 'This is a test notification',
      platformDetails,
      payload: 'payload',
    );
  }

  /// Add message to local notifications list
  void _addNotification(RemoteMessage message) {
    setState(() {
      _notifications.insert(0, {
        'title': message.notification?.title ?? 'Notification',
        'body': message.notification?.body ?? '',
      });
      _notifCount = _notifications.length;
    });
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
            'assets/logo.png',
            height: 28,
            fit: BoxFit.contain,
          ),
          actions: [
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
              onOpened: _markAllRead,
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
