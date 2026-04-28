import 'dart:developer'; // Necesario para log()
import '../models/mensaje_model.dart';

class ChatService {
  // Aquí almacenaremos los mensajes de la sesión actual
  final List<MensajeModel> _mensajes = [];

  List<MensajeModel> get mensajes => _mensajes;

  // Simulación de envío de mensaje
  void enviarMensaje(String contenido, String emisorId, String receptorId) {
    final nuevoMensaje = MensajeModel(
      id: DateTime.now().toString(),
      emisorId: emisorId,
      receptorId: receptorId,
      contenido: contenido,
      fecha: DateTime.now(),
    );
    _mensajes.add(nuevoMensaje);
    
    // Cambiado print por log
    log("Mensaje enviado: $contenido");
  }

  // Aquí es donde más adelante conectaremos el SocketIO
  void conectarServidor() {
    // Cambiado print por log
    log("Conectando al servidor de mensajería de Jaydi...");
  }
}