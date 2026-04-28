import 'dart:developer'; // Necesario para log()
import '../models/notificacion_model.dart';

class NotificationService {
  // Lista simulada para el historial del centro de notificaciones
  final List<NotificacionModel> _historial = [];

  List<NotificacionModel> get historial => _historial;

  void agregarNotificacion(String titulo, String cuerpo, String tipo) {
    final nueva = NotificacionModel(
      titulo: titulo,
      cuerpo: cuerpo,
      fecha: DateTime.now(),
      tipo: tipo,
    );
    _historial.insert(0, nueva); 
    
    // Cambiado print por log
    log("Notificación recibida: $titulo");
  }

  void limpiarHistorial() {
    _historial.clear();
  }
}