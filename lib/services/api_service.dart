import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // IP especial para que el emulador de Android vea tu Lenovo
  // LA URL DE ORO:
  static const String baseUrl = 'https://jaydi-delivery-serverv.onrender.com';

  // --- 1. FUNCIÓN PARA REGISTRAR ---
  static Future<bool> registrarUsuario(String nombre, String email, String password) async {
    final url = Uri.parse('$baseUrl/registrar');

    try {
      debugPrint("🚀 Intentando registrar en Postgres...");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'email': email,
          'password': password,
          'rol': 'cliente',
        }),
      );

      if (response.statusCode == 201) {
        debugPrint("✅ ÉXITO: Usuario guardado correctamente");
        return true;
      } else {
        debugPrint("❌ ERROR: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ ERROR DE CONEXIÓN: $e");
      return false;
    }
  }

  // --- 2. FUNCIÓN PARA LOGIN ---
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');

    try {
      debugPrint("🔐 Intentando iniciar sesión...");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ BIENVENIDO: Login exitoso");
        return jsonDecode(response.body);
      } else {
        debugPrint("❌ CREDENCIALES INCORRECTAS");
        return null;
      }
    } catch (e) {
      debugPrint("❌ ERROR DE CONEXIÓN: $e");
      return null;
    }
  }

  // --- 3. FUNCIÓN PARA OBTENER PRODUCTOS (NUEVA) ---
  static Future<List<dynamic>> obtenerProductos() async {
    final url = Uri.parse('$baseUrl/productos');

    try {
      debugPrint("📦 Trayendo productos desde Neon...");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        debugPrint("✅ Productos cargados: ${data.length}");
        return data;
      } else {
        debugPrint("❌ ERROR AL CARGAR PRODUCTOS: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("❌ ERROR DE CONEXIÓN AL TRAER PRODUCTOS: $e");
      return [];
    }
  }

  // --- 4. FUNCIÓN PARA FINALIZAR COMPRA (NUEVA ACTULIZACIÓN) ---
  static Future<bool> finalizarCompra({
    required int usuarioId,
    required String direccion,
    required double total,
    required List productos,
  }) async {
    final url = Uri.parse('$baseUrl/finalizar_pedido');

    try {
      debugPrint("🛒 Enviando pedido a Render...");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': usuarioId,
          'direccion_entrega': direccion,
          'total': total,
          'productos': productos, // Aquí mandamos la lista de lo que hay en el carrito
          'estado': 'pendiente',   // Por defecto entra como pendiente
        }),
      );

      if (response.statusCode == 201) {
        debugPrint("✅ PEDIDO REALIZADO: Ya aparece en Neon");
        return true;
      } else {
        debugPrint("❌ ERROR AL CREAR PEDIDO: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ ERROR DE CONEXIÓN AL FINALIZAR PEDIDO: $e");
      return false;
    }
  }
}