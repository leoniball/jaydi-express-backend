import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart';
import 'package:prueba_jaydi/screens/chat_screen.dart'; 

class SeguimientoPedidoScreen extends StatefulWidget {
  final int pedidoId;
  final int repartidorId;

  const SeguimientoPedidoScreen({super.key, required this.pedidoId, required this.repartidorId});

  @override
  State<SeguimientoPedidoScreen> createState() => _SeguimientoPedidoScreenState();
}

class _SeguimientoPedidoScreenState extends State<SeguimientoPedidoScreen> {
  final MapController _mapController = MapController();
  Timer? _timer;
  
  LatLng _ubicacionRepartidor = const LatLng(10.3445, -67.0432); 
  LatLng? _ubicacionCliente; // 👉 NUEVO: Para marcar la casa del cliente
  String estadoDelPedido = 'en camino'; 
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _prepararMapa();
  }

  // 👉 NUEVO: Trae el destino y la primera ubicación antes de arrancar el radar
  Future<void> _prepararMapa() async {
    await _obtenerDestinoCliente();
    await _obtenerUbicacionReal();
    
    setState(() => _cargando = false);

    // Arrancamos el radar cada 10 segundos
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _obtenerUbicacionReal();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); 
    super.dispose();
  }

  // Busca las coordenadas de destino que guardamos en Neon
  Future<void> _obtenerDestinoCliente() async {
    try {
      final response = await http.get(
        Uri.parse('https://jaydi-delivery-serverv.onrender.com/obtener_pedido/${widget.pedidoId}')
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['latitud_destino'] != null && data['longitud_destino'] != null) {
          setState(() {
            _ubicacionCliente = LatLng(data['latitud_destino'], data['longitud_destino']);
          });
        }
      }
    } catch (e) {
      debugPrint("Error al obtener destino: $e");
    }
  }

  // 👉 CORRECCIÓN: Ahora lee el estado del pedido, no solo el perfil del repartidor
  Future<void> _obtenerUbicacionReal() async {
    try {
      final response = await http.get(
        Uri.parse('https://jaydi-delivery-serverv.onrender.com/estado_pedido/${widget.pedidoId}')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Verificamos si el motorizado ya marcó como entregado
        if (data['estado'] == 'entregado') {
          _timer?.cancel();
          _mostrarAlertaEntregado();
          return;
        }

        double lat = data['latitud_actual'] ?? _ubicacionRepartidor.latitude;
        double lng = data['longitud_actual'] ?? _ubicacionRepartidor.longitude;

        if (mounted) {
          setState(() {
            _ubicacionRepartidor = LatLng(lat, lng);
            estadoDelPedido = data['estado'] ?? 'en camino';
          });

          // Movemos la cámara suavemente siguiendo a la moto
          _mapController.move(_ubicacionRepartidor, 15.0);
        }
      }
    } catch (e) {
      debugPrint("❌ Error rastreando Jaydi Delivery: $e");
    }
  }

  // Notifica al cliente y lo saca de la pantalla de rastreo
  void _mostrarAlertaEntregado() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("¡Pedido Entregado! 🎉", style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold)),
        content: const Text("Tu pedido ha llegado a su destino. ¡Disfrútalo!", style: TextStyle(fontFamily: 'Montserrat')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () {
              Navigator.of(context).pop(); // Cierra el modal
              Navigator.of(context).pop(); // Saca de la pantalla de seguimiento
            },
            child: const Text("Aceptar", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _abrirChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          pedidoId: widget.pedidoId,
          estadoPedido: estadoDelPedido, 
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sigue tu Pedido", style: TextStyle(fontFamily: 'Montserrat', color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'chat_button_seguimiento', 
        backgroundColor: Colors.orange.shade800,
        onPressed: _abrirChat,
        child: const Icon(Icons.chat_bubble, color: Colors.white),
      ),
      body: _cargando 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _ubicacionRepartidor,
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.jaydi.express',
          ),
          
          MarkerLayer(
            markers: [
              // 🏠 Marcador del Cliente (Destino)
              if (_ubicacionCliente != null)
                Marker(
                  point: _ubicacionCliente!,
                  width: 50,
                  height: 50,
                  child: const Icon(
                    Icons.home_work, 
                    color: Colors.redAccent,
                    size: 40,
                  ),
                ),

              // 🏍️ Marcador del Repartidor (Moto en movimiento)
              Marker(
                point: _ubicacionRepartidor,
                width: 60,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.orange.shade800, width: 2)
                  ),
                  child: Icon(
                    Icons.directions_bike, 
                    color: Colors.orange.shade900,
                    size: 35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}