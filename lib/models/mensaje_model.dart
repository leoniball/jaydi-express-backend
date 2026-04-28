class MensajeModel {
  final String id;
  final String emisorId;
  final String receptorId;
  final String contenido;
  final DateTime fecha;
  final bool esLeido;

  MensajeModel({
    required this.id,
    required this.emisorId,
    required this.receptorId,
    required this.contenido,
    required this.fecha,
    this.esLeido = false,
  });

  // Para convertir los datos que vienen de tu Flask (JSON) a objetos de Dart
  factory MensajeModel.fromJson(Map<String, dynamic> json) {
    return MensajeModel(
      id: json['id'],
      emisorId: json['emisor_id'],
      receptorId: json['receptor_id'],
      contenido: json['contenido'],
      fecha: DateTime.parse(json['fecha']),
      esLeido: json['es_leido'] ?? false,
    );
  }
}