import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// Import con el nombre de tu proyecto
import 'package:prueba_jaydi/services/map_service.dart'; 
import 'package:prueba_jaydi/services/states/venezuela_data.dart';

class MapaSeguimientoScreen extends StatefulWidget {
  const MapaSeguimientoScreen({super.key});

  @override
  State<MapaSeguimientoScreen> createState() => _MapaSeguimientoScreenState();
}

class _MapaSeguimientoScreenState extends State<MapaSeguimientoScreen> {
  // 1. CONTROLADORES Y VARIABLES DE ESTADO
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final String mapboxToken = 'pk.eyJ1IjoiamF5ZGkwMTA3IiwiYSI6ImNtbnc0enZrODA0a28ycG9qZDZjb2ZvbncifQ.apknCKbmIRshcUZZSWMOFg';
  
  String currentMapStyle = 'mapbox/streets-v12'; 
  bool isSatellite = false;

  // Variables para la lógica de la ruta y delivery
  List<LatLng> routePoints = []; 
  LatLng? ubicacionRepartidor;

  // 2. FUNCIONES DE LÓGICA
  void _toggleMapStyle() {
    setState(() {
      isSatellite = !isSatellite;
      currentMapStyle = isSatellite ? 'mapbox/satellite-streets-v12' : 'mapbox/streets-v12';
    });
  }

  void _centerMap() {
    _mapController.move(const LatLng(10.3444, -67.0433), 15.0);
  }

  Future<void> _trazarRuta() async {
    const LatLng puntoInicio = LatLng(10.3444, -67.0433); // Sucursal Los Teques
    const LatLng puntoDestino = LatLng(10.3500, -67.0400); // Destino cliente

    final puntos = await MapService.getRoute(puntoInicio, puntoDestino);

    setState(() {
      routePoints = puntos;
      if (puntos.isNotEmpty) {
        ubicacionRepartidor = puntos.first; // Inicia la moto en el origen
      }
    });

    if (puntos.isNotEmpty) {
      _mapController.move(puntoInicio, 14.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      // Solo abre con el botón de la silueta, no deslizando
      drawerEnableOpenDragGesture: false,
      drawer: _buildDrawer(), 
      body: Stack(
        children: [
          // --- EL MAPA ---
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(10.3444, -67.0433),
              initialZoom: 15.0,
              interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}',
                additionalOptions: {
                  'accessToken': mapboxToken,
                  'id': currentMapStyle,
                },
              ),
              
              // Capa de la línea de ruta (Polyline)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    color: Colors.orange.withValues(alpha: 0.8),
                    strokeWidth: 5.0,
                  ),
                ],
              ),

              // Capa de Marcadores Dinámicos
              MarkerLayer(
                markers: [
                  // Muestra todas las sedes registradas en VenezuelaData
                  ...VenezuelaData.sedesJaydi.map((sede) => Marker(
                    point: sede,
                    width: 60,
                    height: 60,
                    child: _buildSucursalMarker(),
                 )), // Marker

                  // Marcador del Delivery
                  if (ubicacionRepartidor != null)
                    Marker(
                      point: ubicacionRepartidor!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.directions_bike, color: Colors.black, size: 40),
                    ),
                ],
              ),
            ],
          ),

          // --- BOTONES SUPERIORES IZQUIERDA (VOLVER Y SILUETA VENEZUELA) ---
          Positioned(
            top: 50,
            left: 20,
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

          // --- BOTONES FLOTANTES DERECHA ---
          Positioned(
            top: 100,
            right: 20,
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
                const SizedBox(height: 15),
                _buildCompass(),
              ],
            ),
          ),

          // --- ELEMENTOS INFERIORES ---
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoLabel(),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: _trazarRuta,
                  child: _buildRastrearButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENTES DE INTERFAZ PERSONALIZADOS ---

  Widget _buildVenezuelaButton() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3), 
            blurRadius: 10, 
            spreadRadius: 2
          )
        ],
      ),
      child: Image.asset(
        'assets/images/venezuela_silueta.png',
        height: 32,
        width: 32,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade800, Colors.orange.shade400]
              )
            ),
            child: const Center(
              child: Text(
                "Sedes y Cobertura",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  fontSize: 20
                )
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.public, color: Colors.orange),
            title: const Text(
              "Ver Mapa de Venezuela",
              style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold)
            ),
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
                  leading: const Icon(Icons.location_city, color: Colors.orange, size: 20),
                  title: Text(
                    estado.nombre,
                    style: const TextStyle(fontFamily: 'Montserrat', fontSize: 14)
                  ),
                  onTap: () {
                    _mapController.move(estado.centro, 8.5);
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

  Widget _buildSucursalMarker() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange, width: 3),
        shape: BoxShape.circle,
        image: const DecorationImage(
          image: AssetImage('assets/images/jaydi_logo.jpg'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildRastrearButton() {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade800, Colors.orange.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 15)],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bike, color: Colors.white, size: 30),
          SizedBox(width: 15),
          Text(
            "Rastrear Delivery",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat'
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/gps.png', height: 35),
          const SizedBox(width: 12),
          const Text(
            "¡Cobertura Nacional Jaydi!",
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              color: Colors.orange,
              fontSize: 13
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActionCard({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.orange),
        onPressed: onPressed
      ),
    );
  }

  Widget _buildCompass() {
    return StreamBuilder<MapEvent>(
      stream: _mapController.mapEventStream,
      builder: (context, snapshot) {
        final rotation = _mapController.camera.rotation;
        return Transform.rotate(
          angle: -rotation * (3.14159 / 180),
          child: _buildCircularButton(
            icon: Icons.explore, 
            onPressed: () => _mapController.rotate(0), 
            heroTag: 'btn_compass'
          ),
        );
      },
    );
  }

  Widget _buildCircularButton({
    required IconData icon, 
    required VoidCallback onPressed, 
    required String heroTag
  }) {
    return FloatingActionButton(
      heroTag: heroTag,
      mini: true,
      backgroundColor: Colors.white,
      elevation: 4,
      onPressed: onPressed,
      child: Icon(icon, color: Colors.orange, size: 24),
    );
  }
}