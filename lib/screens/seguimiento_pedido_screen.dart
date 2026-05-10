import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart'; // Nuevo motor
import 'package:latlong2/latlong.dart';
// ---> NUEVO: Importamos el ChatScreen <---
import 'package:prueba_jaydi/screens/chat_screen.dart'; 

class SeguimientoPedidoScreen extends StatefulWidget {
  final int pedidoId;
  final int repartidorId;

  const SeguimientoPedidoScreen({super.key, required this.pedidoId, required this.repartidorId});

  @override
  State<SeguimientoPedidoScreen> createState() => _SeguimientoPedidoScreenState();
}

class _SeguimientoPedidoScreenState extends State<SeguimientoPedidoScreen> {
  // CONTROLADORES
  final MapController _mapController = MapController();
  Timer? _timer;
  LatLng _ubicacionRepartidor = const LatLng(10.3445, -67.0432); // Los Teques por defecto
  String estadoDelPedido = 'en camino'; // NUEVO: Estado para el chat

  @override
  void initState() {
    super.initState();
    // Iniciamos el rastreo cada 10 segundos
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _obtenerUbicacionReal();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // IMPORTANTE: Apagar el radar al salir
    super.dispose();
  }

  Future<void> _obtenerUbicacionReal() async {
    try {
      // Consultamos el servidor en Render que conecta con Neon
      final response = await http.get(
        Uri.parse('https://jaydi-delivery-serverv.onrender.com/perfil/${widget.repartidorId}')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        double lat = data['latitud'] ?? 10.3445;
        double lng = data['longitud'] ?? -67.0432;

        if (mounted) {
          setState(() {
            _ubicacionRepartidor = LatLng(lat, lng);
            // Si el perfil devolviera estado, lo actualizaríamos aquí, 
            // pero asumimos 'en camino' mientras la pantalla esté activa.
          });

          // Movemos la cámara para seguir al repartidor
          _mapController.move(_ubicacionRepartidor, 15.0);
        }
      }
    } catch (e) {
      debugPrint("❌ Error rastreando Jaydi Delivery: $e");
    }
  }

  // ---> NUEVO: Función para abrir el chat <---
  void _abrirChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          pedidoId: widget.pedidoId,
          estadoPedido: estadoDelPedido, // Asumimos en camino
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sigue tu Pedido - Jaydi", style: TextStyle(fontFamily: 'Montserrat')),
        backgroundColor: Colors.orange.shade800,
      ),
      // ---> NUEVO: Botón Flotante para el Chat <---
      floatingActionButton: FloatingActionButton(
        heroTag: 'chat_button_seguimiento', // Hero tag único
        backgroundColor: Colors.orange.shade800,
        onPressed: _abrirChat,
        child: const Icon(Icons.chat_bubble, color: Colors.white),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _ubicacionRepartidor,
          initialZoom: 14.0,
        ),
        children: [
          // Capa base de OpenStreetMap
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.jaydi.express',
          ),
          
          // Capa de Marcadores
          MarkerLayer(
            markers: [
              Marker(
                point: _ubicacionRepartidor,
                width: 60,
                height: 60,
                child: const Icon(
                  Icons.directions_bike, // Ícono de moto
                  color: Colors.black,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}