import 'package:flutter/material.dart';
import '../models/producto_carrito.dart';

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> producto;
  final Function(ProductoCarrito) onAdd;

  const ProductCard({super.key, required this.producto, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    // Colores Oficiales Jaydi
    const Color azulJaydi = Color(0xFF0A4297);
    const Color naranjaJaydi = Color(0xFFE67E22);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8), // Un poco más redondeado para verse profesional
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), 
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          // Imagen del producto
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Icon(Icons.image_outlined, size: 24, color: Colors.grey)
              ),
            ),
          ),
          // Información y Botón
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              children: [
                Text(
                  "\$${producto['p']}",
                  style: const TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.bold, 
                    color: azulJaydi, // Usamos el azul oficial
                    fontFamily: 'Montserrat'
                  ),
                ),
                Text(
                  producto['n'],
                  style: const TextStyle(
                    fontSize: 11, 
                    color: Colors.grey,
                    fontFamily: 'Montserrat'
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                
                // MEJORADO: Botón con degradado bello
                GestureDetector(
                  onTap: () {
                    final nuevoItem = ProductoCarrito(
                      id: producto['id'],
                      nombre: producto['n'],
                      precio: producto['p'].toDouble(),
                    );
                    onAdd(nuevoItem);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 28, // Un poco más alto para mejor tacto
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [azulJaydi, naranjaJaydi],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}