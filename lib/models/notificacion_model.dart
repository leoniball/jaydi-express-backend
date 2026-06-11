class NotificacionModel {
  final String titulo;
  final String cuerpo;
  final DateTime fecha;
  final String tipo; // 'pedido', 'promo', 'sistema'

  NotificacionModel({
    required this.titulo,
    required this.cuerpo,
    required this.fecha,
    required this.tipo,
  });
}