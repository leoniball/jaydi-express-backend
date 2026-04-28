import 'package:flutter/material.dart';
import '../models/mensaje_model.dart';
import 'dart:developer'; // Para usar log() en lugar de print()

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key}); // Se agrega la key necesaria

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<MensajeModel> _mensajesPrueba = [];

  void _enviarMensaje() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _mensajesPrueba.add(MensajeModel(
          id: DateTime.now().toString(),
          emisorId: "yo",
          receptorId: "repartidor",
          contenido: _controller.text,
          fecha: DateTime.now(),
        ));
      });
      log("Mensaje enviado: ${_controller.text}"); // Usamos log en lugar de print
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat con Soporte"), // Se agrega const
        backgroundColor: Colors.orange[800],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10), // Se agrega const
              itemCount: _mensajesPrueba.length,
              itemBuilder: (context, index) {
                final msg = _mensajesPrueba[index];
                final esMio = msg.emisorId == "yo";
                return Align(
                  alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5), // Se agrega const
                    padding: const EdgeInsets.all(12), // Se agrega const
                    decoration: BoxDecoration(
                      color: esMio ? Colors.orange[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(msg.contenido),
                  ),
                );
              },
            ),
          ),
          _buildInputChat(),
        ],
      ),
    );
  }

  Widget _buildInputChat() {
    return Container(
      padding: const EdgeInsets.all(8), // Se agrega const
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