import os
from flask import Flask, jsonify, request, render_template
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime

app = Flask(__name__)
CORS(app)

# --- CONFIGURACIÓN DE LA BASE DE DATOS (NEON) ---
DATABASE_URL = os.environ.get('DATABASE_URL', 'postgresql://neondb_owner:npg_hF4PjcEJq5RO@ep-jolly-waterfall-amgwvrji-pooler.c-5.us-east-1.aws.neon.tech/neondb?sslmode=require')

if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URL
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# --- MODELOS DE DATOS ---

class Usuario(db.Model):
    __tablename__ = 'usuario'
    id = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False) 
    rol = db.Column(db.String(20), default='cliente')
    verificado = db.Column(db.Boolean, default=False) # Para el Panel Admin
    saldo = db.Column(db.Float, default=0.0)         # Para el Panel Admin

class Comercio(db.Model):
    __tablename__ = 'comercio'
    id = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(100), nullable=False)
    rif = db.Column(db.String(20), unique=True)
    direccion = db.Column(db.String(255))
    categoria = db.Column(db.String(50))
    productos = db.relationship('Producto', backref='comercio', lazy=True)

class Producto(db.Model):
    __tablename__ = 'producto'
    id = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(150), nullable=False)
    descripcion = db.Column(db.Text)
    precio = db.Column(db.Float, nullable=False)
    stock = db.Column(db.Integer, default=0)
    imagen_url = db.Column(db.String(500)) 
    codigo_barras = db.Column(db.String(50), unique=True)
    comercio_id = db.Column(db.Integer, db.ForeignKey('comercio.id'), nullable=False)

class Pedido(db.Model):
    __tablename__ = 'pedidos'
    id = db.Column(db.Integer, primary_key=True)
    id_usuario = db.Column(db.Integer, db.ForeignKey('usuario.id'), nullable=False)
    direccion_entrega = db.Column(db.Text, nullable=False)
    total = db.Column(db.Float, nullable=False)
    estado = db.Column(db.String(50), default='pendiente')
    repartidor_id = db.Column(db.Integer, nullable=True)
    fecha_creacion = db.Column(db.DateTime, default=datetime.utcnow)

with app.app_context():
    db.create_all()
    print("¡Base de Datos de Neon Sincronizada!")

# --- RUTAS DE NAVEGACIÓN ---

@app.route('/')
def index():
    return jsonify({"mensaje": "Servidor de Jaydi Express funcionando 24/7"})

@app.route('/admin')
def admin_page():
    """Sirve el archivo HTML del panel de administración"""
    return render_template('admin_panel.html')

# --- API DE ADMINISTRACIÓN ---

@app.route('/admin/api/repartidores', methods=['GET'])
def api_repartidores():
    """Devuelve la lista de usuarios para el Panel Admin"""
    try:
        usuarios = Usuario.query.all()
        resultado = []
        for u in usuarios:
            resultado.append({
                "id": u.id,
                "nombre": u.nombre,
                "correo": u.email,
                "saldo": u.saldo or 0.0,
                "es_verificado": u.verificado,
                "ultima_conexion": None # Opcional: datetime.utcnow().isoformat()
            })
        return jsonify(resultado), 200
    except Exception as e:
        return jsonify({"mensaje": str(e)}), 500

@app.route('/admin/aprobar/<int:user_id>', methods=['POST'])
def aprobar_repartidor(user_id):
    """Aprueba a un repartidor desde el Panel Admin"""
    try:
        u = Usuario.query.get(user_id)
        if u:
            u.verificado = True
            db.session.commit()
            return jsonify({"status": "success", "message": "Aprobado"}), 200
        return jsonify({"mensaje": "Usuario no encontrado"}), 404
    except Exception as e:
        db.session.rollback()
        return jsonify({"mensaje": str(e)}), 500

# --- RUTAS DE LA APP (LOGIN, REGISTRO, PRODUCTOS) ---

@app.route('/registrar', methods=['POST'])
def registrar():
    try:
        datos = request.json
        usuario_existe = Usuario.query.filter_by(email=datos.get('email')).first()
        if usuario_existe:
            return jsonify({"mensaje": "Ese correo ya está registrado"}), 400

        password_encriptada = generate_password_hash(datos.get('password'))
        nuevo_usuario = Usuario(
            nombre=datos.get('nombre'),
            email=datos.get('email'),
            password=password_encriptada,
            rol=datos.get('rol', 'cliente')
        )
        db.session.add(nuevo_usuario)
        db.session.commit()
        return jsonify({"mensaje": "Usuario creado con éxito"}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"mensaje": str(e)}), 400

@app.route('/login', methods=['POST'])
def login():
    try:
        datos = request.json
        usuario = Usuario.query.filter_by(email=datos.get('email')).first()
        if usuario and check_password_hash(usuario.password, datos.get('password')):
            return jsonify({
                "mensaje": "Bienvenido",
                "usuario": {
                    "id": usuario.id, 
                    "nombre": usuario.nombre, 
                    "email": usuario.email, 
                    "rol": usuario.rol
                }
            }), 200
        else:
            return jsonify({"mensaje": "Correo o contraseña incorrectos"}), 401
    except Exception as e:
        return jsonify({"mensaje": "Error interno"}), 500

@app.route('/productos', methods=['GET'])
def obtener_productos():
    try:
        productos = Producto.query.all()
        resultado = []
        for p in productos:
            resultado.append({
                "id": p.id, "nombre": p.nombre, "descripcion": p.descripcion,
                "precio": p.precio, "stock": p.stock, "imagen": p.imagen_url,
                "comercio": p.comercio.nombre 
            })
        return jsonify(resultado), 200
    except Exception as e:
        return jsonify({"mensaje": str(e)}), 500

@app.route('/finalizar_pedido', methods=['POST'])
def finalizar_pedido():
    try:
        datos = request.json
        u_id = datos.get('usuario_id') or datos.get('id_usuario') or datos.get('id')
        if not u_id:
            return jsonify({"mensaje": "Falta ID"}), 400

        nuevo_pedido = Pedido(
            id_usuario=u_id,
            direccion_entrega=datos.get('direccion_entrega', 'Sin dirección'),
            total=datos.get('total', 0.0),
            estado='pendiente'
        )
        db.session.add(nuevo_pedido)
        db.session.commit()
        return jsonify({"mensaje": "Pedido guardado con éxito", "pedido_id": nuevo_pedido.id}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"mensaje": str(e)}), 500

@app.route('/pedidos_disponibles', methods=['GET'])
def pedidos_disponibles():
    try:
        pedidos = Pedido.query.filter_by(estado='pendiente').all()
        resultado = []
        for ped in pedidos:
            resultado.append({
                "id": ped.id, "direccion": ped.direccion_entrega,
                "total": ped.total, "estado": ped.estado,
                "fecha": ped.fecha_creacion.strftime("%Y-%m-%d %H:%M:%S")
            })
        return jsonify(resultado), 200
    except Exception as e:
        return jsonify({"mensaje": str(e)}), 500

@app.route('/seed', methods=['GET'])
def seed_data():
    try:
        if Comercio.query.filter_by(rif="J-12345678-0").first():
            return jsonify({"mensaje": "Los datos ya existen"}), 200
        nuevo_comercio = Comercio(nombre="Farmatodo", rif="J-12345678-0", direccion="Av. Principal", categoria="Farmacia")
        db.session.add(nuevo_comercio)
        db.session.flush()
        p1 = Producto(nombre="Acetaminofén", precio=2.50, stock=50, comercio_id=nuevo_comercio.id)
        db.session.add(p1)
        db.session.commit()
        return jsonify({"mensaje": "¡Datos creados!"}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"mensaje": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 10000))
    app.run(host='0.0.0.0', port=port)