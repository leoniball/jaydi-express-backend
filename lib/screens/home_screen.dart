import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/producto_carrito.dart';
import '../models/idiomas.dart'; // <--- Déjalo así solito
import '../widgets/product_card.dart';
import 'auth_screen.dart';
import 'carrito_screen.dart';
import 'edit_profile_screen.dart'; 
import 'mapa_seguimiento_screen.dart'; 
import 'chat_screen.dart'; 
import 'notificaciones_screen.dart'; 
import 'package:prueba_jaydi/services/api_service.dart';

// Notificadores globales
ValueNotifier<List<ProductoCarrito>> carritoNotifier = ValueNotifier([]);
ValueNotifier<int> notificacionesNotifier = ValueNotifier(0); 

Future<void> guardarCarritoEnDisco() async {
  final prefs = await SharedPreferences.getInstance();
  String? user = prefs.getString('ultimo_usuario_activo');
  if (user != null && user != "Invitado") {
    List<String> data = carritoNotifier.value.map((item) => 
      "${item.id}|${item.nombre}|${item.precio}|${item.cantidad}"
    ).toList();
    await prefs.setStringList('carrito_save_$user', data);
  }
}

class JaydiHomePage extends StatefulWidget {
  final String userName;
  const JaydiHomePage({super.key, required this.userName});
  @override
  State<JaydiHomePage> createState() => _JaydiHomePageState();
}

class _JaydiHomePageState extends State<JaydiHomePage> with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _pulse;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String tiendaSeleccionada = "Todos";
  String? nombreReal; 
  int _selectedIndex = 0;

  final Color azulJaydi = const Color(0xFF00337C);
  final Color naranjaJaydi = const Color(0xFFF07D00);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<String> tiendas = ["tienda_todos", "Farmatodo", "Traki", "Superlíder", "Forum", "Express"];
  final List<String> carrusel = ['assets/images/el real.jpg', 'assets/images/prueba compras.jpg', 'assets/images/pruebassss.jpg'];

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _heartController, curve: Curves.easeInOut));
    _cargarDatosUsuario(); 
    
    Timer.periodic(const Duration(milliseconds: 2000), (t) {
      if (_pageController.hasClients) {
        _currentPage = (_currentPage + 1) % carrusel.length;
        _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
      }
    });
  }

  Future<void> _cargarDatosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    String? userActivo = prefs.getString('ultimo_usuario_activo');
    setState(() {
      if (userActivo != null) {
        nombreReal = prefs.getString('nombre_$userActivo');
        _cargarCarritoDeUsuario(userActivo);
      }
    });
  }

  Future<void> _cargarCarritoDeUsuario(String user) async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? guardado = prefs.getStringList('carrito_save_$user');
    if (guardado != null) {
      carritoNotifier.value = guardado.map((s) {
        final p = s.split('|');
        return ProductoCarrito(id: int.parse(p[0]), nombre: p[1], precio: double.parse(p[2]), cantidad: int.parse(p[3]));
      }).toList();
    }
  }

  void _mostrarErrorSeguridad(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
        backgroundColor: naranjaJaydi,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      )
    );
  }

  void _mostrarMenuServicios(String lang) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lang == 'es' ? 'Servicios Jaydi' : 'Jaydi Services', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: azulJaydi)),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.map, color: naranjaJaydi),
              title: Text(lang == 'es' ? 'Rastrear mi Pedido' : 'Track my Order'),
              onTap: () {
                Navigator.pop(context);
                if (widget.userName == "Invitado") {
                   _mostrarErrorSeguridad("Regístrese para obtener estos servicios de Jaydi");
                } else {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const MapaSeguimientoScreen(idPedido: 1)));
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.support_agent, color: naranjaJaydi),
              title: Text(lang == 'es' ? 'Soporte Técnico (Chat Directo)' : 'Technical Support'),
              onTap: () {
                Navigator.pop(context);
                if (widget.userName == "Invitado") {
                   _mostrarErrorSeguridad("Regístrese para obtener estos servicios de Jaydi");
                } else {
                  Navigator.push(
  context, 
  MaterialPageRoute(
    builder: (context) => const ChatScreen(
      pedidoId: 0, // Un ID genérico porque no hay un pedido activo seleccionado aquí
      estadoPedido: 'pendiente', // Esto bloquea el chat hasta que haya un pedido real
    )
  )
);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delivery_dining, color: naranjaJaydi),
              title: Text(lang == 'es' ? 'Chat con Domiciliario' : 'Chat with Courier'),
              onTap: () {
                Navigator.pop(context);
                if (widget.userName == "Invitado") {
                   _mostrarErrorSeguridad("Regístrese para obtener estos servicios de Jaydi");
                } else {
                  Navigator.push(
  context, 
  MaterialPageRoute(
    builder: (context) => const ChatScreen(
      pedidoId: 0, // Un ID genérico porque no hay un pedido activo seleccionado aquí
      estadoPedido: 'pendiente', // Esto bloquea el chat hasta que haya un pedido real
    )
  )
);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications, color: naranjaJaydi),
              title: Text(lang == 'es' ? 'Centro de Notificaciones' : 'Notifications Center'),
              onTap: () {
                Navigator.pop(context);
                if (widget.userName == "Invitado") {
                   _mostrarErrorSeguridad("Regístrese para obtener estos servicios de Jaydi");
                } else {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacionesScreen()));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: idiomaGlobal,
      builder: (context, lang, _) {
        return Scaffold(
          key: _scaffoldKey, 
          backgroundColor: Colors.white,
          drawer: _buildAmazonDrawer(lang),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    // CAMBIO AQUÍ: Usamos withValues en vez de withOpacity
    azulJaydi.withValues(alpha: 0.08), 
    Colors.white,
    naranjaJaydi.withValues(alpha: 0.05),
  ],
),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildSuperiorHeader(lang),
                  _buildStoreFilter(lang),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 15),
                          _buildCarouselWithHeart(),
                          const SizedBox(height: 15),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: Align(
                              alignment: Alignment.centerLeft, 
                              child: Text(
                                "${Traductor.obtener('bienvenido', lang)} ${nombreReal ?? (widget.userName == 'Invitado' ? Traductor.obtener('invitado', lang) : widget.userName)}, ${Traductor.obtener('saludo', lang)}", 
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')
                              )
                            ),
                          ),
                          _buildGrid(lang),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _buildBottomNav(lang),
        );
      }
    );
  }

  Widget _buildBottomNav(String lang) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [azulJaydi, naranjaJaydi],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 2) {
            _mostrarMenuServicios(lang);
          }
          if (index == 3) _scaffoldKey.currentState?.openDrawer();
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withValues(alpha: 0.5),
        selectedFontSize: 10,
        unselectedFontSize: 10,
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.storefront_outlined), label: Traductor.obtener('tienda_todos', lang)),
          BottomNavigationBarItem(icon: const Icon(Icons.favorite_border), label: lang == 'es' ? 'Mis Artículos' : 'My Items'),
          BottomNavigationBarItem(icon: const Icon(Icons.grid_view_outlined), label: lang == 'es' ? 'Servicios' : 'Services'),
          BottomNavigationBarItem(
            icon: ValueListenableBuilder<int>(
              valueListenable: notificacionesNotifier,
              builder: (context, valor, _) => Badge(
                label: Text('$valor'),
                isLabelVisible: valor > 0, 
                child: const Icon(Icons.account_circle_outlined),
              ),
            ),
            label: lang == 'es' ? 'Cuenta' : 'Account',
          ),
        ],
      ),
    );
  }

  Widget _buildAmazonDrawer(String lang) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity, 
            padding: const EdgeInsets.only(top: 50, left: 20, bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [azulJaydi, naranjaJaydi],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.account_circle, size: 60, color: Colors.white),
              const SizedBox(height: 10),
              Text("${Traductor.obtener('bienvenido', lang)} ${nombreReal ?? widget.userName}", 
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
              Text(Traductor.obtener('config_cuenta', lang), 
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Montserrat')),
            ]),
          ),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              ListTile(
                leading: Icon(Icons.edit, color: azulJaydi), 
                title: Text(Traductor.obtener('editar', lang), style: const TextStyle(fontFamily: 'Montserrat')), 
                onTap: () {
                  Navigator.pop(context);
                  if (widget.userName == "Invitado") { 
                    _mostrarErrorSeguridad(Traductor.obtener('error_invitado_perfil', lang)); 
                  } else { 
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _cargarDatosUsuario()); 
                  }
                }
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.chat_outlined, color: azulJaydi),
                title: Text(lang == 'es' ? 'Mensajería' : 'Messaging', style: const TextStyle(fontFamily: 'Montserrat')),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.userName == "Invitado") {
                    _mostrarErrorSeguridad("Regístrese para obtener estos servicios de Jaydi");
                  } else {
                   Navigator.push(
  context, 
  MaterialPageRoute(
    builder: (context) => const ChatScreen(
      pedidoId: 0, // Un ID genérico porque no hay un pedido activo seleccionado aquí
      estadoPedido: 'pendiente', // Esto bloquea el chat hasta que haya un pedido real
    )
  )
);
                  }
                },
              ),
              const Divider(),
              ExpansionTile(
                leading: Icon(Icons.language, color: azulJaydi),
                title: Text(lang == 'es' ? 'Seleccionar Idioma' : 'Select Language', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
                children: [
                  _buildLanguageItem("Español", "es", "🇪🇸"),
                  _buildLanguageItem("Inglés", "en", "🇺🇸"),
                  _buildLanguageItem("Chino", "zh", "🇨🇳"),
                  _buildLanguageItem("Francés", "fr", "🇫🇷"),
                  _buildLanguageItem("Italiano", "it", "🇮🇹"),
                ],
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red), 
                title: Text(Traductor.obtener('salir', lang), 
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')), 
                onTap: _logout
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSuperiorHeader(String lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [azulJaydi, naranjaJaydi],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Column(children: [
        Row(children: [
          const SizedBox(width: 10), 
          Image.asset('assets/images/jaydi_logo.jpg', height: 35),
          const Expanded(child: SizedBox()), 

          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white, size: 24),
            onPressed: () async {
              debugPrint("🔥 Probando el NUEVO registro con contraseña...");
              bool exito = await ApiService.registrarUsuario(
                "Nick Real", 
                "nick_pro@jaydi.com", 
                "123456"
              );
              if (exito) {
                debugPrint("✅ ¡SÍ! Usuario con contraseña guardado en Neon");
              } else {
                debugPrint("❌ Falló: Quizás el correo ya existe o el servidor está caído");
              }
            },
          ),

          TextButton(
            onPressed: widget.userName == "Invitado" ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())) : _logout, 
            child: Text(
              widget.userName == "Invitado" ? Traductor.obtener('sesion_btn', lang) : Traductor.obtener('salir', lang), 
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')
            )
          ),

          const SizedBox(width: 5), 

          // Línea 393 en tu imagen
const Flexible(
  child: Text(
    "Compra con Jaydi",
    style: TextStyle(
      color: Colors.white,
      fontSize: 8,
      fontWeight: FontWeight.bold,
      fontFamily: 'Montserrat', // Manteniendo tu fuente Montserrat
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
),

          const Icon(Icons.arrow_forward, color: Colors.amber, size: 10),
          const SizedBox(width: 5), 

          GestureDetector(
            onTap: () {
              if (widget.userName == "Invitado") { 
                _mostrarErrorSeguridad(Traductor.obtener('error_invitado_compra', lang)); 
              } else { 
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CarritoScreen())); 
              }
            },
            child: Stack(
              clipBehavior: Clip.none, 
              children: [
                const Icon(Icons.shopping_cart, color: Colors.white, size: 30),
                ValueListenableBuilder<List<ProductoCarrito>>(
                  valueListenable: carritoNotifier, 
                  builder: (context, list, child) => list.isEmpty 
                    ? const SizedBox() 
                    : Positioned(
                        right: -5, top: -5, 
                        child: CircleAvatar(
                          radius: 10, backgroundColor: Colors.amber, 
                          child: Text("${list.length}", style: TextStyle(fontSize: 10, color: azulJaydi, fontWeight: FontWeight.bold))
                        )
                      )
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40, 
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), 
                child: TextField(
                  style: const TextStyle(fontFamily: 'Montserrat', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: Traductor.obtener('buscar', lang), 
                    hintStyle: const TextStyle(fontFamily: 'Montserrat'),
                    prefixIcon: Icon(Icons.search, size: 20, color: azulJaydi), 
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10)
                  )
                )
              ),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _buildGrid(String lang) {
    return FutureBuilder<List<dynamic>>(
      future: ApiService.obtenerProductos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              Traductor.obtener('error_cargar_productos', lang),
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        final productos = snapshot.data!;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: productos.length,
          itemBuilder: (context, i) {
            final p = productos[i];
            return ProductCard(
              producto: {
                'id': p['id'],
                'n': p['nombre'],
                'p': p['precio'],
                'img': p['imagen'],
                'comercio': p['comercio'],
              },
              onAdd: (item) {
                if (widget.userName == "Invitado") {
                  _mostrarErrorSeguridad(Traductor.obtener('error_invitado_compra', lang));
                } else {
                  final list = List<ProductoCarrito>.from(carritoNotifier.value);
                  list.add(item);
                  carritoNotifier.value = list;
                  guardarCarritoEnDisco();
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCarouselWithHeart() { 
    return SizedBox(
      height: 140, 
      width: MediaQuery.of(context).size.width * 0.95, 
      child: Stack(
        alignment: Alignment.center, 
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(15), child: PageView.builder(controller: _pageController, itemCount: carrusel.length, itemBuilder: (_, i) => Image.asset(carrusel[i], fit: BoxFit.cover))), 
          ScaleTransition(scale: _pulse, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: ClipOval(child: Image.asset('assets/images/jaydi_logo.jpg', height: 50, width: 50))))
        ]
      )
    ); 
  }

  Widget _buildStoreFilter(String lang) { 
    return Container(
      height: 45, 
      color: Colors.white, 
      child: ListView.builder(
        scrollDirection: Axis.horizontal, 
        itemCount: tiendas.length, 
        itemBuilder: (context, index) { 
          String n = tiendas[index].startsWith('tienda_') ? Traductor.obtener(tiendas[index], lang) : tiendas[index]; 
          bool isSelected = tiendaSeleccionada == tiendas[index];
          return GestureDetector(
            onTap: () => setState(() => tiendaSeleccionada = tiendas[index]), 
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16), 
              alignment: Alignment.center, 
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isSelected ? naranjaJaydi : Colors.transparent, width: 3))
              ), 
              child: Text(n, style: TextStyle(color: isSelected ? azulJaydi : Colors.grey, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontFamily: 'Montserrat'))
            )
          ); 
        }
      )
    ); 
  }
  
  Widget _buildLanguageItem(String n, String c, String b) { 
    return ListTile(
      leading: Text(b, style: const TextStyle(fontSize: 20)), 
      title: Text(n, style: const TextStyle(fontFamily: 'Montserrat')), 
      onTap: () { 
        idiomaGlobal.value = c; 
        Navigator.pop(context); 
      }
    ); 
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    carritoNotifier.value = []; 
    await prefs.remove('ultimo_usuario_activo'); 
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const JaydiHomePage(userName: "Invitado")));
  }

  @override
  void dispose() { 
    _heartController.dispose(); 
    _pageController.dispose(); 
    super.dispose(); 
  }
}