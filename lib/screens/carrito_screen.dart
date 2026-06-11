import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/producto_carrito.dart';
import '../models/idiomas.dart'; // <--- ESTO QUITA EL ERROR ROJO DE IDIOMAGLOBAL
import '../services/api_service.dart'; 
import 'home_screen.dart'; // <--- ESTO QUITA EL ERROR DE CARRITONOTIFIER

class CarritoScreen extends StatelessWidget {
  const CarritoScreen({super.key});

  // FINALIZAR COMPRA Y ENVIAR A RENDER/NEON
  Future<void> _finalizarCompraReal(BuildContext context, String lang, double totalFinal) async {
    final prefs = await SharedPreferences.getInstance();
    
    int usuarioId = prefs.getInt('user_id_neon') ?? prefs.getInt('id') ?? 0; 
    String? userIdPref = prefs.getString('ultimo_usuario_activo');
    
    if (userIdPref == null || userIdPref == "Invitado" || usuarioId == 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes iniciar sesión para comprar"))
      );
      return;
    }

    // 👉 AQUI SE PREPARA LA LISTA DE PRODUCTOS (Esto ya funciona perfecto)
    List productosParaEnviar = carritoNotifier.value.map((item) => {
      'nombre': item.nombre,
      'cantidad': item.cantidad,
      'precio': item.precio,
    }).toList();

    // 👉 EXTRACCIÓN DE LA DIRECCIÓN REAL DEL CLIENTE
    String direccionReal = prefs.getString('direccion') ?? prefs.getString('direccion_usuario') ?? "Dirección no registrada, coordinar en el chat";

    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0))),
    );

    try {
      bool exitoServidor = await ApiService.finalizarCompra(
        usuarioId: usuarioId,
        direccion: direccionReal, // 👉 SIMULACIÓN ELIMINADA, AHORA USA LA VARIABLE REAL
        total: totalFinal,
        productos: productosParaEnviar,
      );

      if (!context.mounted) return;
      Navigator.pop(context);

      if (exitoServidor) {
        String historialKey = 'historial_jaydi_$userIdPref';
        List<String> historialActual = prefs.getStringList(historialKey) ?? [];
        String fecha = DateTime.now().toString().substring(0, 16);
        historialActual.add("Fecha: $fecha | Total: \$${totalFinal.toStringAsFixed(2)}");
        
        await prefs.setStringList(historialKey, historialActual);
        
        carritoNotifier.value = [];
        await prefs.remove('carrito_save_$userIdPref');

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("¡Pedido enviado con éxito!"), 
          backgroundColor: Colors.green
        ));
        
        Navigator.pop(context);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Error al procesar el pedido. Reintenta."), 
          backgroundColor: Colors.orange
        ));
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error crítico: $e"), 
        backgroundColor: Colors.red
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: idiomaGlobal, // Ya no saldrá rojo con el import de arriba
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1565C0), 
            iconTheme: const IconThemeData(color: Colors.white), 
            centerTitle: true,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min, 
              children: [
                ClipOval(child: Image.asset('assets/images/jaydi_logo.jpg', height: 28, width: 28, fit: BoxFit.cover)), 
                const SizedBox(width: 10), 
                Text(
                  Traductor.obtener('carrito_titulo_jaydi', lang), 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white, fontFamily: 'Montserrat')
                )
              ]
            ),
          ),
          body: ValueListenableBuilder<List<ProductoCarrito>>(
            valueListenable: carritoNotifier,
            builder: (context, lista, _) {
              if (lista.isEmpty) {
                return Center(
                  child: Text(
                    Traductor.obtener('carrito_vacio_jaydi', lang),
                    style: const TextStyle(fontFamily: 'Montserrat', color: Colors.grey),
                  )
                );
              }

              double subtotal = lista.fold(0, (sum, item) => sum + (item.precio * item.cantidad));
              double iva = subtotal * 0.16; 
              double totalFinal = subtotal + iva;

              return Column(children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(15), 
                    itemCount: lista.length, 
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = lista[i];
                      return Container(
                        padding: const EdgeInsets.all(12), 
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          borderRadius: BorderRadius.circular(15), 
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]
                        ),
                        child: Row(children: [
                          const Icon(Icons.shopping_bag_outlined, color: Color(0xFF1565C0), size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
                                const SizedBox(height: 8),
                                Row(children: [
                                  _botonCant(Icons.remove, () {
                                    if (item.cantidad > 1) {
                                      var n = List<ProductoCarrito>.from(carritoNotifier.value);
                                      n[i] = item.copyWith(cantidad: item.cantidad - 1);
                                      carritoNotifier.value = n;
                                      guardarCarritoEnDisco();
                                    }
                                  }),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 15), 
                                    child: Text("${item.cantidad}", style: const TextStyle(fontWeight: FontWeight.bold))
                                  ),
                                  _botonCant(Icons.add, () {
                                    var n = List<ProductoCarrito>.from(carritoNotifier.value);
                                    n[i] = item.copyWith(cantidad: item.cantidad + 1);
                                    carritoNotifier.value = n;
                                    guardarCarritoEnDisco();
                                  }),
                                ])
                              ]
                            )
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end, 
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22), 
                                onPressed: () {
                                  var n = List<ProductoCarrito>.from(carritoNotifier.value);
                                  n.removeAt(i);
                                  carritoNotifier.value = n;
                                  guardarCarritoEnDisco();
                                }
                              ),
                              Text(
                                "\$${(item.precio * item.cantidad).toStringAsFixed(2)}", 
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1565C0), fontFamily: 'Montserrat')
                              ),
                            ]
                          )
                        ]),
                      );
                    },
                  )
                ),
                Container(
                  padding: const EdgeInsets.all(25), 
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), 
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20)]
                  ),
                  child: Column(children: [
                    _filaCosto(Traductor.obtener('costo_productos', lang), subtotal),
                    const SizedBox(height: 8),
                    _filaCosto(Traductor.obtener('iva', lang), iva),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      children: [
                        Text("${Traductor.obtener('total', lang)}:", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')), 
                        Text("\$${totalFinal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1565C0), fontFamily: 'Montserrat'))
                      ]
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, 
                      height: 55, 
                      child: ElevatedButton(
                        onPressed: () => _finalizarCompraReal(context, lang, totalFinal), 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black, 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                        ), 
                        child: Text(
                          Traductor.obtener('finalizar_jaydi', lang).toUpperCase(), 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')
                        )
                      )
                    ),
                  ]),
                )
              ]);
            },
          ),
        );
      },
    );
  }

  Widget _botonCant(IconData icon, VoidCallback action) { 
    return GestureDetector(
      onTap: action, 
      child: Container(
        padding: const EdgeInsets.all(6), 
        decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(10)), 
        child: Icon(icon, size: 18, color: const Color(0xFF1565C0))
      )
    ); 
  }
  
  Widget _filaCosto(String t, double m) { 
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
      children: [
        Text(t, style: const TextStyle(color: Colors.grey, fontFamily: 'Montserrat')), 
        Text("\$${m.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat'))
      ]
    ); 
  }
}