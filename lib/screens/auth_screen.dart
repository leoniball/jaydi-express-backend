import 'package:prueba_jaydi/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/idiomas.dart'; 
import 'home_screen.dart';
import '../database/db_helper.dart'; 

ValueNotifier<String> idiomaGlobal = ValueNotifier("es");

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isRegister = false;
  
  final _userController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Colores Oficiales Jaydi basados en el logo
  final Color azulJaydi = const Color(0xFF0A4297);
  final Color naranjaJaydi = const Color(0xFFE67E22);




  @override
  void dispose() {
    _userController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _procesarAcceso() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      final String usuarioInput = _userController.text.trim();
      final String claveInput = _passController.text.trim();
      final String correoInput = _emailController.text.trim();
      final String lang = idiomaGlobal.value;

      if (isRegister) {
        try {
          // 1. INTENTAR SUBIR A LA NUBE (NEON/PYTHON)
          debugPrint("🚀 Subiendo a la nube de Jaydi...");
          bool exitoNube = await ApiService.registrarUsuario(usuarioInput, correoInput, claveInput);

          if (exitoNube) {
            // 2. SI SUBE A LA NUBE, TAMBIÉN GUARDAMOS LOCAL (SQLITE)
            await DBHelper.insertarUsuario(usuarioInput, claveInput, correoInput);
            await prefs.setString('ultimo_usuario_activo', usuarioInput);

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(Traductor.obtener('registro_exito', lang)), 
                backgroundColor: Colors.green
              )
            );

            setState(() {
              isRegister = false;
              _passController.clear();
            });
          } else {
            _mostrarError("El correo ya existe en la nube o el servidor está caído");
          }
        } catch (e) {
          _mostrarError("Error de conexión con el servidor");
        }
      } else {
        // --- LÓGICA DE LOGIN ---
        debugPrint("🔐 Verificando credenciales...");
        
        // Aquí usamos usuarioInput que es donde escriben el correo para entrar
        var resultadoNube = await ApiService.login(usuarioInput, claveInput);

        if (resultadoNube != null) {
          debugPrint("✅ Login exitoso. Entrando...");
          
          // Extraemos el nombre real
          String nombreReal = resultadoNube['usuario']['nombre'];

          // Guardamos y mandamos el nombre, no el correo
          await prefs.setString('ultimo_usuario_activo', nombreReal);
          _irAlHome(nombreReal); 
        } else {
          _mostrarError(Traductor.obtener('no_registrado', lang));
        }
      }
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _irAlHome(String name) {
    Navigator.pushAndRemoveUntil(
      context, 
      MaterialPageRoute(builder: (_) => JaydiHomePage(userName: name)), 
      (route) => false
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: idiomaGlobal,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF0F2F5),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Image.asset('assets/images/jaydi_logo.jpg', height: 100), // Aumenté un poco el tamaño
                      const SizedBox(height: 15),
                      Text(
                        Traductor.obtener('eslogan', lang), 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          _tab(Traductor.obtener('inicio', lang), !isRegister, () => setState(() => isRegister = false), true),
                          _tab(Traductor.obtener('registro', lang), isRegister, () => setState(() => isRegister = true), false),
                        ],
                      ),
                      const SizedBox(height: 30),
                      _input(Traductor.obtener('usuario', lang), _userController, Icons.person_rounded),
                      if (isRegister) ...[
                        const SizedBox(height: 15),
                        _input(Traductor.obtener('correo', lang), _emailController, Icons.email_rounded),
                      ],
                      const SizedBox(height: 15),
                      _input(Traductor.obtener('clave', lang), _passController, Icons.lock_rounded, isPass: true, len: 6),
                      const SizedBox(height: 35),
                      
                      // --- BOTÓN PRINCIPAL CON DEGRADADO BELLO ---
                      GestureDetector(
                        onTap: _procesarAcceso,
                        child: Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [azulJaydi, naranjaJaydi],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: azulJaydi.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              isRegister ? Traductor.obtener('crear', lang) : Traductor.obtener('entrar', lang), 
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 16, 
                                fontWeight: FontWeight.bold, 
                                fontFamily: 'Montserrat'
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 25),
                      TextButton(
                        onPressed: () => _irAlHome("Invitado"), 
                        child: Text(
                          Traductor.obtener('invitado_btn', lang), 
                          style: TextStyle(
                            color: azulJaydi.withValues(alpha: 0.7), 
                            fontWeight: FontWeight.w600, 
                            fontFamily: 'Montserrat'
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _tab(String t, bool s, VoidCallback o, bool l) => Expanded(
    child: GestureDetector(
      onTap: o,
      child: Container(
        height: 50, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: s ? azulJaydi : Colors.white, 
          border: Border.all(color: azulJaydi),
          borderRadius: l ? const BorderRadius.horizontal(left: Radius.circular(12)) : const BorderRadius.horizontal(right: Radius.circular(12)),
        ),
        child: Text(
          t, 
          style: TextStyle(
            color: s ? Colors.white : azulJaydi, 
            fontWeight: FontWeight.bold, 
            fontFamily: 'Montserrat'
          )
        ),
      ),
    ),
  );

  Widget _input(String l, TextEditingController c, IconData i, {bool isPass = false, int? len}) => TextFormField(
    controller: c, obscureText: isPass, maxLength: len,
    keyboardType: len != null ? TextInputType.number : TextInputType.text,
    style: const TextStyle(fontFamily: 'Montserrat'),
    decoration: InputDecoration(
      labelText: l, 
      labelStyle: const TextStyle(fontFamily: 'Montserrat', fontSize: 14),
      prefixIcon: Icon(i, color: azulJaydi), 
      filled: true, 
      fillColor: Colors.white, 
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      counterText: "", 
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
    ),
    validator: (v) => v!.isEmpty ? "..." : null,
  );
}