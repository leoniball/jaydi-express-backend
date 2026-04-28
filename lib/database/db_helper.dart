import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Future<Database> database() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'jaydi_app.db'),
      onCreate: (db, version) {
        // Añadimos la columna 'correo' aquí
        return db.execute(
          'CREATE TABLE usuarios(id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT, password TEXT, correo TEXT)',
        );
      },
      version: 1,
    );
  }

  static Future<void> insertarUsuario(String email, String password, String correo) async {
    final db = await DBHelper.database();
    await db.insert(
      'usuarios',
      {
        'email': email, 
        'password': password,
        'correo': correo // Ahora sí guardamos el correo
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> loginUsuario(String email, String password) async {
    final db = await DBHelper.database();
    return db.query(
      'usuarios',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
  }
}