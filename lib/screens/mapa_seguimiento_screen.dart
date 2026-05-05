import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart'; // Nuevo motor
import 'package:latlong2/latlong.dart';
import 'package:prueba_jaydi/services/states/venezuela_data.dart';
import 'package:prueba_jaydi/services/map_service.dart';

class MapaSeguimientoScreen extends StatefulWidget {
  final int idPedido;

  const MapaSeguimientoScreen({super.key, required this.idPedido});

  @override
  State<MapaSeguimientoScreen> createState() => _MapaSeguimientoScreenState();
}

class _MapaSeguimientoScreenState extends State<MapaSeguimientoScreen> {
  // 1. CONTROLADORES Y VARIABLES
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  bool isSatellite = false;
  bool isRastreando = false;
  Timer? _timer;

  final LatLng _centroInicial = const LatLng(10.3444, -67.0433);
  LatLng? ubicacionRepartidor;
  List<LatLng> puntosRuta = [];
  
  // Coordenada de destino (Fija en Los Teques)
  final LatLng ubicacionDestino = const LatLng(10.3500, -67.0400); 

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 2. LÓGICA DE MAPA Y RASTREO
  void _toggleMapStyle() {
    setState(() {
      isSatellite = !isSatellite;
    });
  }

  void _centerMap() {
    if (ubicacionRepartidor != null) {
      _mapController.move(ubicacionRepartidor!, 15.0);
    } else {
      _mapController.move(_centroInicial, 15.0);
    }
  }

  void _iniciarRastreoRealTime() {
    if (isRastreando) return;

    setState(() => isRastreando = true);
    _obtenerUbicacionServidor(); 
    
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _obtenerUbicacionServidor();
    });
  }

  Future<void> _obtenerUbicacionServidor() async {
    try {
      final response = await http.get(
        Uri.parse('https://jaydi-delivery-serverv.onrender.com/estado_pedido/${widget.idPedido}')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        double lat = double.parse(data['latitud_actual'].toString());
        double lng = double.parse(data['longitud_actual'].toString());

        if (mounted) {
          LatLng nuevaUbi = LatLng(lat, lng);
          
          // Actualizamos la ruta cada vez que se mueve el repartidor
          List<LatLng> nuevaRuta = await MapService.getRoute(nuevaUbi, ubicacionDestino);

          setState(() {
            ubicacionRepartidor = nuevaUbi;
            puntosRuta = nuevaRuta;
          });

          _mapController.move(nuevaUbi, 15.5);
        }
      }
    } catch (e) {
      debugPrint("❌ Error Jaydi Tracker: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawerEnableOpenDragGesture: false,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // REEMPLAZO DEL MOTOR DE MAPA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centroInicial,
              initialZoom: 15.0,
            ),
            children: [
              // Capa de Mapa (Calles o Satélite)
              TileLayer(
                urlTemplate: isSatellite 
                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.jaydi.express',
              ),
              
              // Capa de la Ruta Azul
              if (puntosRuta.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: puntosRuta,
                      color: Colors.blue.shade600,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),

              // Capa de Marcadores (Sedes, Destino y Repartidor)
              MarkerLayer(
                markers: [
                  // Sedes Jaydi
                  ...VenezuelaData.sedesJaydi.map((sede) => Marker(
                    point: LatLng(sede.latitude, sede.longitude),
                    width: 80, height: 80,
                    child: Column(
                      children: [
                        const Icon(Icons.location_on, color: Colors.deepOrange, size: 30),
                        Text("Sede", style: TextStyle(color: Colors.deepOrange.shade900, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),

                  // Marcador de Destino (Cliente)
                  Marker(
                    point: ubicacionDestino,
                    width: 40, height: 40,
                    child: const Icon(Icons.home, color: Colors.red, size: 35),
                  ),

                  // Marcador del Repartidor (Motorizado)
                  if (ubicacionRepartidor != null)
                    Marker(
                      point: ubicacionRepartidor!,
                      width: 60, height: 60,
                      child: const Icon(Icons.directions_bike, color: Colors.black, size: 40),
                    ),
                ],
              ),
            ],
          ),

          // Interfaz UI (Se mantiene tu diseño original)
          Positioned(
            top: 50, left: 20,
            child: Row(
              children: [
                _buildTopActionCard(
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: _buildVenezuelaButton(),
                ),
              ],
            ),
          ),

          Positioned(
            top: 100, right: 20,
            child: Column(
              children: [
                _buildCircularButton(
                  icon: isSatellite ? Icons.map_outlined : Icons.layers,
                  onPressed: _toggleMapStyle,
                  heroTag: 'btn_style'
                ),
                const SizedBox(height: 15),
                _buildCircularButton(
                  icon: Icons.my_location,
                  onPressed: _centerMap,
                  heroTag: 'btn_center'
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoLabel(),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: _iniciarRastreoRealTime,
                  child: _buildRastrearButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS DE UI (SIN CAMBIOS EN TU DISEÑO) ---

  Widget _buildRastrearButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity, height: 65,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isRastreando 
            ? [Colors.green.shade700, Colors.green.shade400] 
            : [Colors.orange.shade800, Colors.orange.shade400]
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isRastreando ? Icons.gps_fixed : Icons.directions_bike, color: Colors.white, size: 30),
          const SizedBox(width: 15),
          Text(
            isRastreando ? "Rastreando en Vivo..." : "Iniciar Seguimiento",
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.orange.shade800, Colors.orange.shade400])),
            child: const Center(child: Text("Sedes Jaydi 🇻🇪", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22))),
          ),
          ListTile(
            leading: const Icon(Icons.map, color: Colors.orange),
            title: const Text("Vista Nacional"),
            onTap: () {
              _mapController.move(const LatLng(7.1291, -66.1818), 6.0);
              Navigator.pop(context);
            },
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: VenezuelaData.estados.length,
              itemBuilder: (context, index) {
                final estado = VenezuelaData.estados[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_city, color: Colors.orange, size: 18),
                  title: Text(estado.nombre, style: const TextStyle(fontSize: 14)),
                  onTap: () {
                    _mapController.move(LatLng(estado.centro.latitude, estado.centro.longitude), 9.0);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVenezuelaButton() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Image.asset('assets/images/venezuela_silueta.png', height: 35, width: 35),
    );
  }

  Widget _buildInfoLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.orange.shade100)),
      child: const Text("Tu pedido Jaydi está en camino", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)),
    );
  }

  Widget _buildTopActionCard({required IconData icon, required VoidCallback onPressed}) {
    return CircleAvatar(
      backgroundColor: Colors.white,
      child: IconButton(icon: Icon(icon, color: Colors.orange), onPressed: onPressed),
    );
  }

  Widget _buildCircularButton({required IconData icon, required VoidCallback onPressed, required String heroTag}) {
    return FloatingActionButton(
      heroTag: heroTag, mini: true, backgroundColor: Colors.white,
      onPressed: onPressed,
      child: Icon(icon, color: Colors.orange),
    );
  }
}