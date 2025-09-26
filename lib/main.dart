import 'package:flutter/material.dart';
import 'screens/send_otp_page.dart'; // adjust path if you used a different folder

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const SendOtpPage(), // starts here
      // Alternatively, use routes:
      // initialRoute: '/send-otp',
      // routes: {
      //   '/send-otp': (_) => const SendOtpPage(),
      // },
    );
  }
}
