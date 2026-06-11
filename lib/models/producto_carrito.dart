// lib/models/producto_carrito.dart

class ProductoCarrito {
  final int id;
  final String nombre;
  final double precio;
  final int cantidad;

  ProductoCarrito({
    required this.id,
    required this.nombre,
    required this.precio,
    this.cantidad = 1,
  });

  // ESTA ES LA FUNCIÓN QUE TE FALTA Y QUE ARREGLA EL ERROR
  // Permite crear una copia del producto pero cambiando solo lo que necesitemos (como la cantidad)
  ProductoCarrito copyWith({
    int? id,
    String? nombre,
    double? precio,
    int? cantidad,
  }) {
    return ProductoCarrito(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      precio: precio ?? this.precio,
      cantidad: cantidad ?? this.cantidad,
    );
  }
}