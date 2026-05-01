import os
from flask import Flask, jsonify, request, render_template
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime
from sqlalchemy import text # Importante para meter comandos SQL crudos a Neon

app = Flask(__name__)
CORS(app)

# --- CONFIGURACIÓN DE LA BASE DE DATOS (NEON) ---
DATABASE_URL = os.environ.get('DATABASE_URL', 'postgresql://neondb_owner:npg_hF4PjcEJq5RO@ep-jolly-waterfall-amgwvrji-pooler.c-5.us-east-1.aws.neon.tech/neondb?sslmode=require')

if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URL
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# --- MODELOS DE DATOS (Sincronizados con Neon) ---

class Usuario(db.Model):
    __tablename__ = 'usuario' # Única tabla de usuarios (Singular)
    id = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(100), nullable=False)
    apellido = db.Column(db.String(100)) 
    telefono = db.Column(db.String(20))   
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False) 
    rol = db.Column(db.String(20), default='cliente') # 'cliente' o 'repartidor'
    verificado = db.Column(db.Boolean, default=False)
    saldo = db.Column(db.Float, default=0.0)
    
    # --- CAMPOS DE PERFIL Y RASTREO ---
    foto_perfil = db.Column(db.Text, nullable=True) 
    vehiculo = db.Column(db.String(50), nullable=True) 
    placa = db.Column(db.String(20), nullable=True)
    viajes_completados = db.Column(db.Integer, default=0)
    
    # NUEVOS: Para el tiempo real en Los Teques
    latitud = db.Column(db.Float, nullable=True)
    longitud = db.Column(db.Float, nullable=True)

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
    comercio_id = db.Column(db.Integer, db.ForeignKey('comercio.id'), nullable=False)

class Pedido(db.Model):
    __tablename__ = 'pedidos'
    id = db.Column(db.Integer, primary_key=True)
    id_usuario = db.Column(db.Integer, db.ForeignKey('usuario.id'), nullable=False)
    direccion_entrega = db.Column(db.Text, nullable=False)
    total = db.Column(db.Float, nullable=False)
    estado = db.Column(db.String(50), default='pendiente')
    repartidor_id = db.Column(db.Integer, db.ForeignKey('usuario.id'), nullable=True)
    fecha_creacion = db.Column(db.DateTime, default=datetime.utcnow)
    
    # NUEVOS: Para rastrear el pedido específico en el mapa
    latitud_actual = db.Column(db.Float, nullable=True)
    longitud_actual = db.Column(db.Float, nullable=True)

# Sincronización automática de tablas al iniciar
with app.app_context():
    db.create_all()
    print("¡Base de Datos de Neon Sincronizada y Lista!")

# --- RUTAS DE NAVEGACIÓN ---

@app.route('/')
def index():
    return jsonify({"mensaje": "Servidor de Jaydi Express funcionando 24/7"})

@app.route('/admin')
def admin_page():
    return render_template('admin_panel.html')

# --- PARCHE MÁGICO 2.0: AHORA TAMBIÉN PARA GPS ---
@app.route('/actualizar_bd_perfil')
def actualizar_bd_perfil():
    try:
        # Inyectamos las columnas directo a Neon
        try: db.session.execute(text('ALTER TABLE usuario ADD COLUMN foto_perfil TEXT;'))
        except: pass
        try: db.session.execute(text('ALTER TABLE usuario ADD COLUMN vehiculo VARCHAR(50);'))
        except: pass
        try: db.session.execute(text('ALTER TABLE usuario ADD COLUMN placa VARCHAR(20);'))
        except: pass
        try: db.session.execute(text('ALTER TABLE usuario ADD COLUMN viajes_completados INTEGER DEFAULT 0;'))
        except: pass
        try: db.session.execute(text('ALTER TABLE usuario ADD COLUMN latitud FLOAT;'))
        except: pass
        try: db.session.execute(text('ALTER TABLE usuario ADD COLUMN longitud FLOAT;'))
        except: pass
        
        # Nuevos campos para la tabla de pedidos
        try: db.session.execute(text('ALTER TABLE pedidos ADD COLUMN latitud_actual FLOAT;'))
        except: pass
        try: db.session.execute(text('ALTER TABLE pedidos ADD COLUMN longitud_actual FLOAT;'))
        except: pass
        
        db.session.commit()
        return jsonify({"mensaje": "¡Éxito! Base de Datos Neon actualizada con campos de Perfil y GPS."}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"mensaje": "Aviso: " + str(e)}), 200

# --- NUEVA RUTA: ACTUALIZAR UBICACIÓN GPS (REPARTIDOR) ---
@app.route('/actualizar_ubicacion', methods=['POST'])
def actualizar_ubicacion_post():
    try:
        datos = request.json
        id_pedido = datos.get('id_pedido')
        lat = datos.get('latitud')
        lng = datos.get('longitud')

        pedido = Pedido.query.get(id_pedido)
        if pedido:
            pedido.latitud_actual = lat
            pedido.longitud_actual = lng
            
            # También actualizamos la posición global del usuario repartidor
            usuario = Usuario.query.get(pedido.repartidor_id)
            if usuario:
                usuario.latitud = lat
                usuario.longitud = lng
                
            db.session.commit()
            return jsonify({"status": "ok", "mensaje": "Ubicación actualizada"}), 200
        return jsonify({"mensaje": "Pedido no encontrado"}), 404
    except Exception as e:
        db.session.rollback()
        return jsonify({"mensaje": str(e)}), 500

# --- NUEVA RUTA: ESTADO DEL PEDIDO (Para el Mapbox del Cliente) ---
@app.route('/estado_pedido/<int:id_pedido>', methods=['GET'])
def estado_pedido(id_pedido):
    try:
        pedido = Pedido.query.get(id_pedido)
        if pedido:
            return jsonify({
                "id": pedido.id,
                "estado": pedido.estado,
                "latitud_actual": pedido.latitud_actual or 10.3444,
                "longitud_actual": pedido.longitud_actual or -67.0433
            }), 200
        return jsonify({"mensaje": "Pedido no encontrado"}), 404
    except Exception as e:
        return jsonify({"mensaje": str(e)}), 500

# --- GESTIÓN DE PERFIL CON CAMBIO DE CLAVE ---
@app.route('/perfil/<int:user_id>', methods=['GET', 'PUT'])
def gestionar_perfil(user_id):
    try:
        usuario = Usuario.query.get(user_id)
        if not usuario:
            return jsonify({"mensaje": "Usuario no encontrado"}), 404

        if request.method == 'GET':
            return jsonify({
                "nombre": usuario.nombre,
                "apellido": usuario.apellido or "",
                "email": usuario.email,
                "telefono": usuario.telefono or "",
                "foto_perfil": usuario.foto_perfil or "",
                "vehiculo": usuario.vehiculo or "",
                "placa": usuario.placa or "",
                "viajes_completados": usuario.viajes_completados or 0,
                "saldo": usuario.saldo or 0.0,
                "latitud": usuario.latitud or 10.3445, # Por defecto Los Teques
                "longitud": usuario.longitud or -67.0432
            }), 200

        if request.method == 'PUT':
            datos = request.json
            if 'foto_perfil' in datos: usuario.foto_perfil = datos['foto_perfil']
            if 'vehiculo' in datos: usuario.vehiculo = datos['vehiculo']
            if 'placa' in datos: usuario.placa = datos['placa']
            if 'telefono' in datos: usuario.telefono = datos['telefono']
            if 'nombre' in datos: usuario.nombre = datos['nombre']
            if 'apellido' in datos: usuario.apellido = datos['apellido']

            if 'password_actual' in datos and 'password_nuevo' in datos:
                if check_password_hash(usuario.password, datos['password_actual']):
                    usuario.password = generate_password_hash(datos['password_nuevo'])
                else:
                    return jsonify({"mensaje": "La contraseña actual es incorrecta"}), 400

            db.session.commit()
            return jsonify({"mensaje": "Perfil actualizado con éxito"}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"mensaje": str(e)}), 500

# --- HISTORIAL DE VIAJES ---
@app.route('/historial_viajes/<int:repartidor_id>', methods=['GET'])
def historial_viajes(repartidor_id):
    try:
        pedidos = Pedido.query.filter_by(repartidor_id=repartidor_id, estado='entregado').order_by(Pedido.fecha_creacion.desc()).all()
        return jsonify([{
            "id": p.id,
            "direccion": p.direccion_entrega,
            "total": p.total,
            "fecha": p.fecha_creacion.strftime("%d/%m/%Y %H:%M")
        } for p in pedidos]), 200
    except Exception as e:
        return jsonify({"mensaje": str(e)}), 500

# --- API DE ADMINISTRACIÓN ---

@app.route('/admin/api/repartidores', methods=['GET'])
def api_repartidores():
    try:
        repartidores = Usuario.query.filter_by(rol='repartidor').all()
        resultado = []
        for r in repartidores:
            resultado.append({
                "id": r.id,
                "nombre": f"{r.nombre} {r.apellido or ''}",
                "correo": r.email,
                "telefono": r.telefono,
                "saldo": r.saldo,
                "es_verificado": r.verificado
            })
        return jsonify(resultado), 200
    except Exception as e:
        return jsonify({"mensaje": str(e)}), 500

@app.route('/admin/aprobar/<int:user_id>', methods=['POST'])
def aprobar_repartidor(user_id):
    try:
        u = Usuario.query.get(user_id)
        if u and u.rol == 'repartidor':
            u.verificado = True
            db.session.commit()
            return jsonify({"status": "success", "message": "Repartidor aprobado"}), 200
        return jsonify({"mensaje": "Usuario no encontrado o no es repartidor"}), 404
    except Exception as e:
        db.session.rollback()
        return jsonify({"mensaje": str(e)}), 500

@app.route('/verificar_estatus/<int:user_id>', methods=['GET'])
def verificar_estatus(user_id):
    try:
        usuario = Usuario.query.get(user_id)
        if usuario:
            return jsonify({"verificado": usuario.verificado}), 200
        return jsonify({"mensaje": "Usuario no encontrado"}), 404
    except Exception as e:
        return jsonify({"mensaje": str(e)}), 500

# --- LÓGICA DE REGISTRO Y LOGIN ---

@app.route('/registrar', methods=['POST'])
def registrar():
    try:
        datos = request.json
        email = datos.get('email')
        if Usuario.query.filter_by(email=email).first():
            return jsonify({"mensaje": "Este correo ya está registrado"}), 400
        nuevo_rol = datos.get('rol', 'cliente')
        nuevo_usuario = Usuario(
            nombre=datos.get('nombre'),
            apellido=datos.get('apellido'),
            telefono=datos.get('telefono'),
            email=email,
            password=generate_password_hash(datos.get('password')),
            rol=nuevo_rol,
            verificado=False
        )
        db.session.add(nuevo_usuario)
        db.session.commit()
        return jsonify({"mensaje": "Usuario creado con éxito", "rol": nuevo_rol}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"mensaje": f"Error en registro: {str(e)}"}), 400

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
                    "rol": usuario.rol,
                    "verificado": usuario.verificado
                }
            }), 200
        return jsonify({"mensaje": "Correo o contraseña incorrectos"}), 401
    except Exception as e:
        return jsonify({"mensaje": "Error en el servidor"}), 500

# --- PRODUCTOS Y PEDIDOS ---

@app.route('/productos', methods=['GET'])
def obtener_productos():
    try:
        productos = Producto.query.all()
        return jsonify([{
            "id": p.id, "nombre": p.nombre, "precio": p.precio, 
            "imagen": p.imagen_url, "comercio": p.comercio.nombre
        } for p in productos]), 200
    except Exception as e:
        return jsonify({"mensaje": str(e)}), 500

@app.route('/finalizar_pedido', methods=['POST'])
def finalizar_pedido():
    try:
        datos = request.json
        u_id = datos.get('usuario_id') or datos.get('id')
        if not u_id:
            return jsonify({"mensaje": "Error: ID de usuario no identificado"}), 400
        nuevo_pedido = Pedido(
            id_usuario=u_id,
            direccion_entrega=datos.get('direccion_entrega', 'Los Teques, Centro'),
            total=datos.get('total', 0.0),
            estado='pendiente'
        )
        db.session.add(nuevo_pedido)
        db.session.commit()
        return jsonify({"mensaje": "Pedido recibido", "id": nuevo_pedido.id}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"mensaje": str(e)}), 500

@app.route('/pedidos_disponibles', methods=['GET'])
def pedidos_disponibles():
    try:
        pedidos = Pedido.query.filter_by(estado='pendiente').all()
        return jsonify([{
            "id": p.id, "direccion": p.direccion_entrega, "total": p.total
        } for p in pedidos]), 200
    except Exception as e:
        return jsonify({"mensaje": str(e)}), 500

# --- RUTA PARA ACEPTAR PEDIDO ---
@app.route('/aceptar_pedido/<int:pedido_id>', methods=['POST'])
def aceptar_pedido(pedido_id):
    try:
        datos = request.json
        pedido = Pedido.query.get(pedido_id)
        if pedido:
            pedido.repartidor_id = datos.get('repartidor_id')
            pedido.estado = 'en camino'
            db.session.commit()
            return jsonify({"mensaje": "Pedido aceptado con éxito"}), 200
        return jsonify({"mensaje": "Pedido no encontrado"}), 404
    except Exception as e:
        db.session.rollback()
        return jsonify({"mensaje": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 10000))
    app.run(host='0.0.0.0', port=port)