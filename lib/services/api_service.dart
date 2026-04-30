import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // URL ÚNICA DE PRODUCCIÓN (Basada en tus capturas de Render)
  // IMPORTANTE: Asegúrate de que no tenga espacios ni barras al final
  // URL ÚNICA DE PRODUCCIÓN 
static const String baseUrl = 'https://jaydi-delivery-serverv.onrender.com';
  // --- 1. FUNCIÓN PARA REGISTRAR ---
  static Future<bool> registrarUsuario(String nombre, String email, String password) async {
    final url = Uri.parse('$baseUrl/registrar');

    try {
      debugPrint("🚀 Intentando registrar usuario en la nube Jaydi...");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'email': email,
          'password': password,
          'rol': 'cliente', // Por defecto registramos como cliente
        }),
      );

      if (response.statusCode == 201) {
        debugPrint("✅ ÉXITO: Usuario guardado en Neon");
        return true;
      } else {
        // Muestra el error que devuelve Flask (ej: "Ese correo ya está registrado")
        final errorData = jsonDecode(response.body);
        debugPrint("❌ ERROR DEL SERVIDOR: ${errorData['mensaje']}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ ERROR CRÍTICO DE CONEXIÓN: $e");
      return false;
    }
  }

  // --- 2. FUNCIÓN PARA LOGIN ---
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');

    try {
      debugPrint("🔐 Iniciando sesión en Jaydi Cloud...");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ BIENVENIDO: Credenciales correctas");
        return jsonDecode(response.body);
      } else {
        debugPrint("❌ ERROR: Correo o contraseña incorrectos (Status: ${response.statusCode})");
        return null;
      }
    } catch (e) {
      debugPrint("❌ ERROR DE RED EN LOGIN: $e");
      return null;
    }
  }

  // --- 3. FUNCIÓN PARA OBTENER PRODUCTOS ---
  static Future<List<dynamic>> obtenerProductos() async {
    final url = Uri.parse('$baseUrl/productos');

    try {
      debugPrint("📦 Consultando inventario en Neon...");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        debugPrint("✅ Productos cargados: ${data.length}");
        return data;
      } else {
        debugPrint("❌ FALLO AL TRAER PRODUCTOS: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("❌ ERROR DE CONEXIÓN AL TRAER PRODUCTOS: $e");
      return [];
    }
  }

  // --- 4. FUNCIÓN PARA FINALIZAR COMPRA (Puente Express -> Delivery) ---
  static Future<bool> finalizarCompra({
    required int usuarioId,
    required String direccion,
    required double total,
    required List productos,
  }) async {
    final url = Uri.parse('$baseUrl/finalizar_pedido');

    try {
      debugPrint("🛒 Enviando pedido a la red de repartidores...");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': usuarioId,
          'direccion_entrega': direccion,
          'total': total,
          'productos': productos,
          'estado': 'pendiente', // Esto asegura que aparezca en la app de Delivery
        }),
      );

      if (response.statusCode == 201) {
        debugPrint("✅ PEDIDO REALIZADO: Ya es visible para el repartidor");
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

  // --- 5. FUNCIÓN PARA VER PEDIDOS DISPONIBLES (Delivery) ---
  static Future<List<dynamic>> obtenerPedidosDisponibles() async {
    final url = Uri.parse('$baseUrl/pedidos_disponibles');

    try {
      debugPrint("📋 Consultando pedidos pendientes en la nube...");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("❌ ERROR AL CARGAR PEDIDOS: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("❌ ERROR DE RED AL CARGAR PEDIDOS: $e");
      return [];
    }
  }

  // --- 6. FUNCIÓN PARA ACEPTAR PEDIDO (Delivery) ---
  static Future<bool> aceptarPedido(int pedidoId, int repartidorId) async {
    final url = Uri.parse('$baseUrl/aceptar_pedido');

    try {
      debugPrint("🤝 Aceptando pedido #$pedidoId...");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pedido_id': pedidoId,
          'repartidor_id': repartidorId,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ PEDIDO ACEPTADO: Ahora está en tu lista");
        return true;
      } else {
        debugPrint("❌ ERROR AL ACEPTAR: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ ERROR DE RED AL ACEPTAR PEDIDO: $e");
      return false;
    }
  }
}