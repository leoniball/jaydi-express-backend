import 'dart:async'; // NUEVO: Para actualizar los mensajes en tiempo real
import 'package:flutter/material.dart';
import 'dart:developer'; // Para usar log() en lugar de print()
import '../services/api_service.dart'; // NUEVO: Importar tu API

class ChatScreen extends StatefulWidget {
  final int pedidoId; // NUEVO: Necesitamos saber de qué pedido es el chat
  final String estadoPedido; // NUEVO: Para saber si bloquear o abrir el chat

  const ChatScreen({
    super.key, 
    required this.pedidoId, 
    required this.estadoPedido
  }); 

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _mensajesReales = []; // NUEVO: Ahora viene de la API, no de prueba
  Timer? _timer; // NUEVO: El motor del "tiempo real"

  @override
  void initState() {
    super.initState();
    // Solo iniciamos la consulta constante si el pedido ya lo tiene un domiciliario
    if (widget.estadoPedido != 'pendiente') {
      _cargarMensajes();
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) => _cargarMensajes());
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // IMPORTANTE: Apagar el timer al salir de la pantalla
    _controller.dispose();
    super.dispose();
  }

  // --- NUEVA FUNCIÓN QUE CONECTA CON LA API ---
  Future<void> _cargarMensajes() async {
    final mensajes = await ApiService.obtenerMensajes(widget.pedidoId);
    if (mounted) {
      setState(() {
        _mensajesReales = mensajes;
      });
    }
  }

  // --- FUNCIÓN MODIFICADA PARA ENVIAR A LA BASE DE DATOS ---
  Future<void> _enviarMensaje() async {
    if (_controller.text.trim().isNotEmpty) {
      String textoEnviado = _controller.text.trim();
      log("Enviando a Render: $textoEnviado");
      
      _controller.clear(); // Limpiamos rápido para buena experiencia

      bool exito = await ApiService.enviarMensaje(
        widget.pedidoId, 
        'cliente', // Jaydi Express es el cliente
        textoEnviado
      );

      if (exito) {
        _cargarMensajes(); // Refrescamos la lista de inmediato
      } else {
        log("Error al enviar el mensaje al servidor");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // REGLA: Si nadie ha agarrado el pedido, mostrar pantalla de bloqueo
    if (widget.estadoPedido == 'pendiente') {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Chat con Repartidor"),
          backgroundColor: Colors.orange[800],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "El chat se activará en cuanto un domiciliario acepte tu pedido.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    bool chatCerrado = widget.estadoPedido == 'entregado';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat con Repartidor"), // Cambié el título a Repartidor
        backgroundColor: Colors.orange[800],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _mensajesReales.length,
              itemBuilder: (context, index) {
                final msg = _mensajesReales[index];
                final esMio = msg['remitente_tipo'] == 'cliente'; // Adaptado a la BD real
                
                return Align(
                  alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: esMio ? Colors.orange[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(msg['texto'] ?? ''),
                  ),
                );
              },
            ),
          ),
          // REGLA: Si ya se entregó, bloquear el input
          if (chatCerrado)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.red[100],
              child: const Text(
                "Pedido entregado. Historial guardado.",
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            )
          else
            _buildInputChat(), // Tu input original
        ],
      ),
    );
  }

  // TU ESTRUCTURA ORIGINAL INTACTA
  Widget _buildInputChat() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Escribe un mensaje...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: Colors.orange[800]),
            onPressed: _enviarMensaje,
          ),
        ],
      ),
    );
  }
}