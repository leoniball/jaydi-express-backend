import 'package:flutter/material.dart';
import '../models/notificacion_model.dart';
import 'dart:developer'; // Importación necesaria para usar log()

class NotificacionesScreen extends StatelessWidget {
  // Se agrega el constructor con la key para cumplir con las buenas prácticas de Flutter
  const NotificacionesScreen({super.key});

  // Lista de prueba para el diseño
  final List<NotificacionModel> notifications = const []; // Nota: En producción esto vendrá de tu Service

  @override
  Widget build(BuildContext context) {
    // Lista de ejemplo interna para que veas el diseño de inmediato
    final List<NotificacionModel> listaEjemplo = [
      NotificacionModel(
        titulo: "¡Oferta Relámpago!",
        cuerpo: "Los audífonos que buscabas tienen 20% de descuento solo por hoy.",
        fecha: DateTime.now(),
        tipo: "promo",
      ),
      NotificacionModel(
        titulo: "Pedido en camino",
        cuerpo: "Tu repartidor de Jaydi Express ha recolectado tu paquete.",
        fecha: DateTime.now(),
        tipo: "pedido",
      ),
      NotificacionModel(
        titulo: "Actualización de Seguridad",
        cuerpo: "Se ha iniciado sesión desde un nuevo dispositivo Lenovo.",
        fecha: DateTime.now(),
        tipo: "sistema",
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Centro de Servicios"),
        backgroundColor: Colors.orange[800],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: listaEjemplo.length,
        itemBuilder: (context, index) {
          final item = listaEjemplo[index];
          
          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: _buildIcon(item.tipo),
              title: Text(
                item.titulo,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900]),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Text(item.cuerpo),
                  const SizedBox(height: 5),
                  Text(
                    "${item.fecha.hour}:${item.fecha.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              isThreeLine: true,
              onTap: () {
                // Reemplazamos print por log para evitar el warning de 'avoid_print'
                log("Tocaste la notificación: ${item.titulo}");
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildIcon(String tipo) {
    IconData iconData;
    Color color;

    switch (tipo) {
      case 'promo':
        iconData = Icons.local_offer;
        color = Colors.redAccent;
        break;
      case 'pedido':
        iconData = Icons.delivery_dining;
        color = Colors.green;
        break;
      default:
        iconData = Icons.info;
        color = Colors.blue;
    }

    return CircleAvatar(
      // Usamos withAlpha para evitar el warning de 'deprecated_member_use' de withOpacity
      backgroundColor: color.withAlpha(50), 
      child: Icon(iconData, color: color),
    );
  }
}