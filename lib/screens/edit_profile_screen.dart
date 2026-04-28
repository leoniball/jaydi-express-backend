import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/idiomas.dart';
import 'auth_screen.dart'; // Para acceder a idiomaGlobal

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Controladores para los datos reales
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatosDeBaseDeDatos();
  }

  // Carga los datos que el usuario guardó en el registro
  Future<void> _cargarDatosDeBaseDeDatos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nombreController.text = prefs.getString('registrado_nombre') ?? '';
      _apellidoController.text = prefs.getString('registrado_apellido') ?? '';
      _emailController.text = prefs.getString('registrado_correo') ?? '';
      _telefonoController.text = prefs.getString('registrado_telefono') ?? '';
    });
  }

  // Guarda los nuevos cambios en la "Base de Datos" (SharedPreferences)
  Future<void> _actualizarPerfil() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('registrado_nombre', _nombreController.text.trim());
    await prefs.setString('registrado_apellido', _apellidoController.text.trim());
    await prefs.setString('registrado_correo', _emailController.text.trim());
    await prefs.setString('registrado_telefono', _telefonoController.text.trim());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Traductor.obtener('perfil_editado', idiomaGlobal.value)),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context); // Regresa al Home con los datos actualizados
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: idiomaGlobal,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF0F2F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1565C0),
            title: Text(Traductor.obtener('editar', lang), style: const TextStyle(color: Colors.white)),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                const Icon(Icons.account_circle, size: 80, color: Color(0xFF1565C0)),
                const SizedBox(height: 20),
                
                // Campos de edición profesional
                _inputField(Traductor.obtener('nombre', lang), _nombreController, Icons.person),
                const SizedBox(height: 15),
                _inputField(Traductor.obtener('apellido', lang), _apellidoController, Icons.person_outline),
                const SizedBox(height: 15),
                _inputField(Traductor.obtener('correo', lang), _emailController, Icons.email),
                const SizedBox(height: 15),
                _inputField(Traductor.obtener('telefono', lang), _telefonoController, Icons.phone),
                
                const SizedBox(height: 40),
                
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _actualizarPerfil,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text(
                      Traductor.obtener('guardar', lang),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- AQUÍ ESTABA EL ERROR: AGREGAMOS 'Widget' AL PRINCIPIO ---
  Widget _inputField(String label, TextEditingController controller, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }
}