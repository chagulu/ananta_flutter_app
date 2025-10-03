// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/navigation_service.dart';
import 'models/login_type.dart';
import 'screens/send_otp_page.dart';
import 'screens/visitor_list.dart';
import 'screens/visitor_qr.dart';
import 'screens/visitor_manual_entry.dart';
import 'screens/home_shell.dart';
import 'firebase_options.dart';
import 'core/notifications_center.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Optionally log or persist; UI cannot be updated here.
  // Add to local list on next resume via getInitialMessage()/onMessageOpenedApp if desired.
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidInitSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const AnantaApp());
}

class AnantaApp extends StatelessWidget {
  const AnantaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ananta',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      initialRoute: '/send-otp',
      routes: {
        '/send-otp': (_) => SendOtpPage(),
        '/visitorList': (_) => const VisitorListPage(loginType: LoginType.guard),
        '/generateQr': (_) => const GenerateQrPage(),
        '/manualEntry': (_) => const ManualEntryPage(),
        '/home': (_) => const HomeLoader(),
      },
    );
  }
}

class HomeLoader extends StatefulWidget {
  const HomeLoader({super.key});

  @override
  State<HomeLoader> createState() => _HomeLoaderState();
}

class _HomeLoaderState extends State<HomeLoader> {
  final _secure = const FlutterSecureStorage();
  String? _role;
  LoginType? _loginType;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _setupFCM();
  }

  Future<void> _loadUser() async {
    final role = await _secure.read(key: 'user_role');
    final loginTypeStr = await _secure.read(key: 'login_type');
    setState(() {
      _role = role ?? 'ROLE_GUARD';
      _loginType = loginTypeStr == 'residence' ? LoginType.residence : LoginType.guard;
      _loading = false;
    });
  }

  Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await messaging.getToken();
    print('✅ FCM Token: $token');

    // Foreground messages -> add to dropdown center (keeps header in sync)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final t = message.notification?.title ?? 'Notification';
      final b = message.notification?.body ?? '';
      NotificationsCenter.add(AppNotification(title: t, body: b));
      // Optionally show local banner too using flutterLocalNotificationsPlugin.
    });

    // Notification taps when app in background -> handle routing and add to list if desired
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final t = message.notification?.title ?? 'Notification';
      final b = message.notification?.body ?? '';
      NotificationsCenter.add(AppNotification(title: t, body: b));
      // Example navigation:
      // NavigationService.navigatorKey.currentState?.pushNamed("/visitorList");
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return HomeShell(
      loginType: _loginType ?? LoginType.guard,
      role: _role ?? 'ROLE_GUARD',
    );
  }
}
