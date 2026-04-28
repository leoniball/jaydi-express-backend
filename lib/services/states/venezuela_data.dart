import 'package:latlong2/latlong.dart';

class EstadoVenezuela {
  final String nombre;
  final LatLng centro;

  EstadoVenezuela({required this.nombre, required this.centro});
}

class VenezuelaData {
  static List<EstadoVenezuela> estados = [
    EstadoVenezuela(nombre: "Amazonas", centro: const LatLng(3.1667, -65.8167)),
    EstadoVenezuela(nombre: "Anzoátegui", centro: const LatLng(9.0000, -64.5000)),
    EstadoVenezuela(nombre: "Apure", centro: const LatLng(7.0000, -68.5000)),
    EstadoVenezuela(nombre: "Aragua", centro: const LatLng(10.2333, -67.4333)),
    EstadoVenezuela(nombre: "Barinas", centro: const LatLng(8.2500, -69.5000)),
    EstadoVenezuela(nombre: "Bolívar", centro: const LatLng(6.0000, -63.0000)),
    EstadoVenezuela(nombre: "Carabobo", centro: const LatLng(10.1667, -68.0000)),
    EstadoVenezuela(nombre: "Cojedes", centro: const LatLng(9.3333, -68.3333)),
    EstadoVenezuela(nombre: "Delta Amacuro", centro: const LatLng(8.5000, -61.5000)),
    EstadoVenezuela(nombre: "Distrito Capital", centro: const LatLng(10.5000, -66.9167)),
    EstadoVenezuela(nombre: "Falcón", centro: const LatLng(11.0000, -70.0000)),
    EstadoVenezuela(nombre: "Guárico", centro: const LatLng(8.6667, -66.5000)),
    EstadoVenezuela(nombre: "Lara", centro: const LatLng(10.1667, -69.8333)),
    EstadoVenezuela(nombre: "Mérida", centro: const LatLng(8.5000, -71.1667)),
    EstadoVenezuela(nombre: "Miranda", centro: const LatLng(10.2500, -66.4167)),
    EstadoVenezuela(nombre: "Monagas", centro: const LatLng(9.3333, -63.0000)),
    EstadoVenezuela(nombre: "Nueva Esparta", centro: const LatLng(11.0000, -63.9167)),
    EstadoVenezuela(nombre: "Portuguesa", centro: const LatLng(9.0000, -69.2500)),
    EstadoVenezuela(nombre: "Sucre", centro: const LatLng(10.4167, -63.5000)),
    EstadoVenezuela(nombre: "Táchira", centro: const LatLng(7.8333, -72.1667)),
    EstadoVenezuela(nombre: "Trujillo", centro: const LatLng(9.4167, -70.4167)),
    EstadoVenezuela(nombre: "Vargas (La Guaira)", centro: const LatLng(10.6000, -66.9333)),
    EstadoVenezuela(nombre: "Yaracuy", centro: const LatLng(10.3333, -68.7500)),
    EstadoVenezuela(nombre: "Zulia", centro: const LatLng(10.0000, -72.0000)),
  ];

  // Aquí agregamos las sedes de Jaydi Express
  static List<LatLng> sedesJaydi = [
    const LatLng(10.3444, -67.0433), // Los Teques (Tu ubicación actual)
  ];
}