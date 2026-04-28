import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/producto_carrito.dart';
import '../models/idiomas.dart';
import 'home_screen.dart'; 
import 'auth_screen.dart'; 

class CarritoScreen extends StatelessWidget {
  const CarritoScreen({super.key});

  // FINALIZAR COMPRA Y LIMPIAR DISCO
  Future<void> _finalizarCompraReal(BuildContext context, String lang, double totalFinal) async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('ultimo_usuario_activo');
    if (userId == null || userId == "Invitado") return;

    String historialKey = 'historial_jaydi_$userId';
    List<String> historialActual = prefs.getStringList(historialKey) ?? [];
    String fecha = DateTime.now().toString().substring(0, 16);
    historialActual.add("Fecha: $fecha | Total: \$${totalFinal.toStringAsFixed(2)}");
    
    await prefs.setStringList(historialKey, historialActual);
    
    // --- LIMPIEZA TOTAL ---
    carritoNotifier.value = [];
    await prefs.remove('carrito_save_$userId'); // Borramos el carrito pendiente porque ya se compró

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("¡Compra realizada con éxito!"), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: idiomaGlobal,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1565C0), iconTheme: const IconThemeData(color: Colors.white), centerTitle: true,
            title: Row(mainAxisSize: MainAxisSize.min, children: [ClipOval(child: Image.asset('assets/images/jaydi_logo.jpg', height: 28, width: 28, fit: BoxFit.cover)), const SizedBox(width: 10), Text(Traductor.obtener('carrito_titulo_jaydi', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white))]),
          ),
          body: ValueListenableBuilder<List<ProductoCarrito>>(
            valueListenable: carritoNotifier,
            builder: (context, lista, child) {
              if (lista.isEmpty) return Center(child: Text(Traductor.obtener('carrito_vacio_jaydi', lang)));

              double subtotal = lista.fold(0, (sum, item) => sum + (item.precio * item.cantidad));
              double iva = subtotal * 0.16; 
              double totalFinal = subtotal + iva;

              return Column(children: [
                Expanded(child: ListView.separated(
                  padding: const EdgeInsets.all(15), itemCount: lista.length, separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = lista[i];
                    return Container(
                      padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]),
                      child: Row(children: [
                        const Icon(Icons.shopping_bag_outlined, color: Color(0xFF1565C0), size: 30),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Row(children: [
                            _botonCant(Icons.remove, () {
                              if (item.cantidad > 1) {
                                var n = List<ProductoCarrito>.from(carritoNotifier.value);
                                n[i] = item.copyWith(cantidad: item.cantidad - 1);
                                carritoNotifier.value = n;
                                guardarCarritoEnDisco(); // <--- ACTUALIZAR DISCO
                              }
                            }),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: Text("${item.cantidad}", style: const TextStyle(fontWeight: FontWeight.bold))),
                            _botonCant(Icons.add, () {
                              var n = List<ProductoCarrito>.from(carritoNotifier.value);
                              n[i] = item.copyWith(cantidad: item.cantidad + 1);
                              carritoNotifier.value = n;
                              guardarCarritoEnDisco(); // <--- ACTUALIZAR DISCO
                            }),
                          ])
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22), onPressed: () {
                            var n = List<ProductoCarrito>.from(carritoNotifier.value);
                            n.removeAt(i);
                            carritoNotifier.value = n;
                            guardarCarritoEnDisco(); // <--- ACTUALIZAR DISCO
                          }),
                          Text("\$${(item.precio * item.cantidad).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1565C0))),
                        ])
                      ]),
                    );
                  },
                )),
                Container(
                  padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20)]),
                  child: Column(children: [
                    _filaCosto(Traductor.obtener('costo_productos', lang), subtotal),
                    _filaCosto(Traductor.obtener('iva', lang), iva),
                    const Divider(height: 30),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${Traductor.obtener('total', lang)}:", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text("\$${totalFinal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1565C0)))]),
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () => _finalizarCompraReal(context, lang, totalFinal), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: Text(Traductor.obtener('finalizar_jaydi', lang), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                  ]),
                )
              ]);
            },
          ),
        );
      },
    );
  }

  Widget _botonCant(IconData icon, VoidCallback action) { return GestureDetector(onTap: action, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: const Color(0xFF1565C0)))); }
  Widget _filaCosto(String t, double m) { return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t, style: const TextStyle(color: Colors.grey)), Text("\$${m.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold))]); }
}