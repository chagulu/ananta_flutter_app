import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/navigation_service.dart';
import 'models/login_type.dart';
import 'screens/send_otp_page.dart';
import 'screens/visitor_list.dart';
import 'screens/visitor_qr.dart';
import 'screens/visitor_manual_entry.dart';
import 'screens/home_shell.dart';

void main() {
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
        '/send-otp': (_) => const SendOtpPage(),
        '/visitorList': (_) => const VisitorListPage(loginType: LoginType.guard),
        '/generateQr': (_) => const GenerateQrPage(),
        '/manualEntry': (_) => const ManualEntryPage(),
        '/home': (_) => const HomeLoader(), // 🔄 dynamic role-based loader
      },
    );
  }
}

/// Loader widget to decide correct HomeShell role
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
  }

  Future<void> _loadUser() async {
    final role = await _secure.read(key: 'user_role');
    final loginTypeStr = await _secure.read(key: 'login_type');

    setState(() {
      _role = role ?? 'ROLE_GUARD'; // fallback
      _loginType = loginTypeStr == 'residence' ? LoginType.residence : LoginType.guard;
      _loading = false;
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
