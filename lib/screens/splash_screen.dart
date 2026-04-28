import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart'; // Verifica que este nombre coincida con tu archivo

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Colores oficiales para el degradado realista
  final Color azulJaydi = const Color(0xFF00337C);
  final Color naranjaJaydi = const Color(0xFFF07D00);

  @override
  void initState() {
    super.initState();
    // Espera 3 segundos y luego decide a dónde ir
    Timer(const Duration(seconds: 3), _navegarAHome);
  }

  Future<void> _navegarAHome() async {
    final prefs = await SharedPreferences.getInstance();
    // Recuperamos el último usuario para que la Home sepa quién es
    String user = prefs.getString('ultimo_usuario_activo') ?? "Invitado";

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => JaydiHomePage(userName: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [azulJaydi, naranjaJaydi],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tu Logo
            Image.asset(
              'assets/images/jaydi_logo.jpg', // Ajusta a tu ruta real
              width: 180,
            ),
            const SizedBox(height: 30),
            // El texto que querías afuera
            const Text(
              'Jaydi Express',
              style: TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
                color: Color(0xFF002D62),
                letterSpacing: 1.5,
                shadows: [
                  Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}