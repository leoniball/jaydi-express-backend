import 'package:flutter/material.dart';
import 'screens/splash_screen.dart'; 


void main() => runApp(const JaydiApp());

class JaydiApp extends StatelessWidget {
  const JaydiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Colores Oficiales Jaydi
    const Color azulJaydi = Color(0xFF00337C);
    const Color naranjaJaydi = Color(0xFFF07D00);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jaydi Express',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Montserrat',
        
        colorScheme: ColorScheme.fromSeed(
          seedColor: azulJaydi,
          primary: azulJaydi,
          secondary: naranjaJaydi,
          surface: Colors.white,
        ),

        // Estilo de la AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: azulJaydi, // Cambiado de transparente a Azul para que se vea el título
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),

        // Botones con estilo Jaydi
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: azulJaydi,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Navegación inferior
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: naranjaJaydi.withValues(alpha: 0.2),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontFamily: 'Montserrat', fontSize: 12),
          ),
        ),
      ),
      
      /* OPCIÓN A: Si quieres probar el MAPA directamente:
      home: const MapaSeguimientoScreen(), 
      
      OPCIÓN B: Si quieres ver el flujo real (Splash -> Home):
      */
      home: const SplashScreen(), 
    );
  }
}