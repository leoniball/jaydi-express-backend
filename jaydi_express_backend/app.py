import os
import traceback
from flask import Flask, jsonify, request, render_template, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime
from sqlalchemy import text 

# --- IMPORTAR Y CARGAR VARIABLES DE ENTORNO OCULTAS ---
from dotenv import load_dotenv
load_dotenv()

app = Flask(__name__)
CORS(app)

# --- CONFIGURACIÓN DE LA BASE DE DATOS (NEON) ---
DATABASE_URL = os.environ.get('DATABASE_URL', '')

if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URL
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# LA VACUNA ANTI-DESCONEXIÓN PARA EXPRESS Y DELIVERY
app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
    "pool_pre_ping": True,  
    "pool_recycle": 300,    
}

db = SQLAlchemy(app)

# --- CONFIGURACIÓN DE SUBIDA DE ARCHIVOS (DELIVERY) ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads', 'documentos')
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024 # 16MB Límite

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

# --- MODELOS DE DATOS ---

class Usuario(db.Model):
    __tablename__ = 'usuario' 
    id = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(100), nullable=False)
    apellido = db.Column(db.String(100)) 
    telefono = db.Column(db.String(20))   
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False) 
    rol = db.Column(db.String(20), default='cliente') 
    verificado = db.Column(db.Boolean, default=False)
    saldo = db.Column(db.Float, default=0.0)
    foto_perfil = db.Column(db.Text, nullable=True) 
    vehiculo = db.Column(db.String(50), nullable=True) 
    placa = db.Column(db.String(20), nullable=True)
    viajes_completados = db.Column(db.Integer, default=0)
    latitud = db.Column(db.Float, nullable=True)
    longitud = db.Column(db.Float, nullable=True)
    ultima_conexion = db.Column(db.DateTime, default=datetime.utcnow) # Añadido para Delivery

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
    latitud_actual = db.Column(db.Float, nullable=True)
    longitud_actual = db.Column(db.Float, nullable=True)
    latitud_destino = db.Column(db.Float, nullable=True)
    longitud_destino = db.Column(db.Float, nullable=True)

class Mensaje(db.Model):
    __tablename__ = 'mensajes'
    id = db.Column(db.Integer, primary_key=True)
    pedido_id = db.Column(db.Integer, db.ForeignKey('pedidos.id'), nullable=False)
    remitente_tipo = db.Column(db.String(20), nullable=False) 
    texto = db.Column(db.Text, nullable=False)
    fecha = db.Column(db.DateTime, default=datetime.utcnow)

class DocumentoRepartidor(db.Model):
    __tablename__ = 'documentos_repartidor'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('usuario.id'), nullable=False)
    tipo_documento = db.Column(db.String(50), nullable=False)
    ruta_archivo_servidor = db.Column(db.String(255), nullable=False)

with app.app_context():
    db.create_all()
    print("¡Base de Datos de Neon Sincronizada y Lista (Unificada)!")

# --- RUTAS DE NAVEGACIÓN Y ARCHIVOS ---

@app.route('/')
def index():
    return jsonify({
        "status": "online",
        "mensaje": "Servidor Único Jaydi (Express + Delivery) funcionando 24/7"
    })

@app.route('/uploads/documentos/user_<int:user_id>/<filename>')
def ver_archivo(user_id, filename):
    directorio_usuario = os.path.join(UPLOAD_FOLDER, f"user_{user_id}")
    return send_from_directory(directorio_usuario, filename)

@app.route('/admin')
def admin_page():
    return render_template('admin_panel.html')

@app.route('/actualizar_bd_perfil')
def actualizar_bd_perfil():
    try:
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
        try: db.session.execute(text('ALTER TABLE usuario ADD COLUMN ultima_conexion TIMESTAMP;'))
        except: pass
        try: db.session.execute(text('ALTER TABLE pedidos ADD COLUMN latitud_actual FLOAT;'))
        except: pass
        try: db.session.execute(text('ALTER TABLE pedidos ADD COLUMN longitud_actual FLOAT;'))
        except: pass
        try: db.session.execute(text('ALTER TABLE pedidos ADD COLUMN latitud_destino FLOAT;'))
        except: pass
        try: db.session.execute(text('ALTER TABLE pedidos ADD COLUMN longitud_destino FLOAT;'))
        except: pass
        db.session.commit()
        return jsonify({"mensaje": "¡Éxito! Base de Datos Neon actualizada."}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"mensaje": "Aviso: " + str(e)}), 200

# --- LÓGICA DE REGISTRO Y LOGIN (UNIFICADA PARA AMBAS APPS) ---

@app.route('/registrar', methods=['POST'])
@app.route('/registro', methods=['POST']) 
def registrar():
    try:
        datos = request.get_json()
        if not datos:
            return jsonify({"status": "error", "mensaje": "Datos JSON no recibidos", "error": "No JSON payload"}), 400
            
        email = datos.get('email', '').strip().lower()
        if Usuario.query.filter_by(email=email).first():
            return jsonify({"status": "error", "mensaje": "Este correo ya está registrado", "error": "El email ya existe"}), 400
        
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
        
        user_data = {
            "id": str(nuevo_usuario.id), 
            "nombre": nuevo_usuario.nombre, 
            "apellido": nuevo_usuario.apellido, 
            "email": nuevo_usuario.email,
            "status": "pendiente",
            "rol": nuevo_rol
        }
        return jsonify({"status": "success", "mensaje": "Usuario creado con éxito", "rol": nuevo_rol, "usuario": user_data, "userData": user_data}), 201
    except Exception as e:
        db.session.rollback()
        print("ERROR EN REGISTRO:\n", traceback.format_exc())
        return jsonify({"status": "error", "mensaje": f"Error en registro: {str(e)}", "error": str(e)}), 500

@app.route('/login', methods=['POST'])
def login():
    try:
        datos = request.get_json()
        if not datos:
            return jsonify({"status": "error", "mensaje": "Datos JSON vacíos"}), 400
            
        email = datos.get('email', '').strip().lower()
        usuario = Usuario.query.filter_by(email=email).first()
        
        if usuario and check_password_hash(usuario.password, datos.get('password')):
            usuario.ultima_conexion = datetime.utcnow()
            db.session.commit()
            
            user_data = {
                "id": str(usuario.id), 
                "nombre": usuario.nombre, 
                "apellido": usuario.apellido or "",
                "email": usuario.email, 
                "rol": usuario.rol,
                "status": "aprobado" if usuario.verificado else "pendiente",
                "es_verificado": usuario.verificado
            }
            return jsonify({
                "status": "success",
                "mensaje": "Bienvenido",
                "usuario": user_data,
                "userData": user_data
            }), 200
        return jsonify({"status": "error", "mensaje": "Correo o contraseña incorrectos", "error": "Credenciales inválidas"}), 401
    except Exception as e:
        print("ERROR EN LOGIN:\n", traceback.format_exc())
        return jsonify({"status": "error", "mensaje": "Error en el servidor", "error": str(e)}), 500

# --- PERFIL Y DOCUMENTOS ---

@app.route('/api/perfil/<int:user_id>', methods=['GET', 'PUT'])
@app.route('/perfil/<int:user_id>', methods=['GET', 'PUT'])
def gestionar_perfil(user_id):
    try:
        usuario = Usuario.query.get(user_id)
        if not usuario:
            return jsonify({"status": "error", "mensaje": "Usuario no encontrado", "error": "Usuario no encontrado"}), 404

        if request.method == 'GET':
            data = {
                "id": str(usuario.id),
                "nombre": usuario.nombre,
                "apellido": usuario.apellido or "",
                "email": usuario.email,
                "telefono": usuario.telefono or "",
                "foto_perfil": usuario.foto_perfil or "",
                "vehiculo": usuario.vehiculo or "",
                "placa": usuario.placa or "",
                "viajes_completados": usuario.viajes_completados or 0,
                "saldo": usuario.saldo or 0.0,
                "latitud": usuario.latitud or 10.3445, 
                "longitud": usuario.longitud or -67.0432,
                "status": "aprobado" if usuario.verificado else "pendiente",
                "es_verificado": usuario.verificado
            }
            return jsonify(data), 200

        if request.method == 'PUT':
            datos = request.get_json()
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
                    return jsonify({"status": "error", "mensaje": "La contraseña actual es incorrecta"}), 400

            db.session.commit()
            return jsonify({"status": "success", "mensaje": "Perfil actualizado con éxito"}), 200

    except Exception as e:
        db.session.rollback()
        print("ERROR EN PERFIL:\n", traceback.format_exc())
        return jsonify({"status": "error", "mensaje": str(e)}), 500

@app.route('/subir_documento', methods=['POST'])
def subir_documento():
    if 'file' not in request.files:
        return jsonify({"error": "No hay archivo"}), 400
    
    file = request.files['file']
    user_id = request.form.get('user_id')
    tipo = request.form.get('tipo', 'documento')

    try:
        user_folder = os.path.join(UPLOAD_FOLDER, f"user_{user_id}")
        if not os.path.exists(user_folder):
            os.makedirs(user_folder)

        filename = f"{tipo}.jpg"
        path = os.path.join(user_folder, filename)
        file.save(path)
        ruta_publica = f"/uploads/documentos/user_{user_id}/{filename}"

        doc = DocumentoRepartidor.query.filter_by(user_id=user_id, tipo_documento=tipo).first()
        if doc:
            doc.ruta_archivo_servidor = ruta_publica
        else:
            nuevo_doc = DocumentoRepartidor(user_id=user_id, tipo_documento=tipo, ruta_archivo_servidor=ruta_publica)
            db.session.add(nuevo_doc)
            
        db.session.commit()
        return jsonify({"status": "success", "message": f"{tipo} guardado"}), 200
    except Exception as e:
        db.session.rollback()
        print("ERROR EN SUBIDA DOCUMENTO:\n", traceback.format_exc())
        return jsonify({"error": str(e)}), 500

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
        print("ERROR EN OBTENER PRODUCTOS:\n", traceback.format_exc())
        return jsonify({"mensaje": str(e)}), 500

@app.route('/finalizar_pedido', methods=['POST'])
def finalizar_pedido():
    try:
        datos = request.get_json()
        
        # 1. IMPRIMIR LO QUE MANDA EL TELÉFONO (Para depuración)
        print(">>> PAYLOAD RECIBIDO DE FLUTTER:", datos, flush=True)
        
        if not datos or isinstance(datos, list):
            return jsonify({"mensaje": "Error: Cuerpo de la solicitud inválido"}), 400

        # 2. BLINDAJE DEL ID DE USUARIO (Forzar a número entero)
        raw_uid = datos.get('usuario_id') or datos.get('id_usuario') or datos.get('id')
        if not raw_uid:
            return jsonify({"mensaje": "Error: ID de usuario no identificado"}), 400
            
        try:
            u_id = int(raw_uid)
        except ValueError:
            return jsonify({"mensaje": "Error: Formato de ID inválido"}), 400

        usuario_existe = Usuario.query.get(u_id)
        if not usuario_existe:
            return jsonify({"mensaje": "Error: Sesión caducada o usuario no existe."}), 404

        # 3. BLINDAJE DEL TOTAL (Forzar a decimal)
        try:
            total_float = float(datos.get('total', 0.0))
        except (ValueError, TypeError):
            total_float = 0.0

        # 4. BLINDAJE DE COORDENADAS (La cura para el Error 500)
        def sanear_coordenada(valor):
            try:
                # Si el valor no está vacío, lo convierte a Float. Si está vacío, devuelve None.
                return float(valor) if str(valor).strip() != "" else None
            except (ValueError, TypeError):
                return None

        lat_dest = sanear_coordenada(datos.get('latitud_destino'))
        lon_dest = sanear_coordenada(datos.get('longitud_destino'))

        # 5. CREACIÓN DEL PEDIDO
        nuevo_pedido = Pedido(
            id_usuario=u_id,
            direccion_entrega=str(datos.get('direccion_entrega', 'Los Teques, Centro')),
            total=total_float,
            estado='pendiente',
            latitud_destino=lat_dest,
            longitud_destino=lon_dest
        )
        db.session.add(nuevo_pedido)
        db.session.commit()
        
        print(f">>> PEDIDO EXITOSO GUARDADO. ID: {nuevo_pedido.id}", flush=True)
        return jsonify({"mensaje": "Pedido recibido", "id": nuevo_pedido.id}), 201
        
    except Exception as e:
        db.session.rollback()
        # IMPRIMIR ERROR REAL FORZADO EN CONSOLA
        print(">>> ERROR CRÍTICO EN FINALIZAR PEDIDO:", flush=True)
        print(traceback.format_exc(), flush=True)
        return jsonify({"mensaje": f"Error interno: {str(e)}"}), 500

@app.route('/obtener_pedido/<int:pedido_id>', methods=['GET'])
def obtener_pedido(pedido_id):
    try:
        pedido = Pedido.query.get(pedido_id)
        if pedido:
            return jsonify({
                "id": pedido.id,
                "direccion": pedido.direccion_entrega,
                "latitud_destino": pedido.latitud_destino,
                "longitud_destino": pedido.longitud_destino
            }), 200
        return jsonify({"error": "Pedido no encontrado"}), 404
    except Exception as e:
        print("ERROR EN OBTENER PEDIDO:\n", traceback.format_exc())
        return jsonify({"error": str(e)}), 500

@app.route('/pedidos_disponibles', methods=['GET'])
@app.route('/api/delivery/pedidos_disponibles', methods=['GET'])
def pedidos_disponibles():
    try:
        pedidos = Pedido.query.filter(Pedido.estado.in_(['pendiente', 'listo_para_entrega'])).all()
        return jsonify([{
            "id": p.id, 
            "cliente": p.id_usuario, 
            "direccion": p.direccion_entrega, 
            "total": p.total
        } for p in pedidos]), 200
    except Exception as e:
        print("ERROR EN PEDIDOS DISPONIBLES:\n", traceback.format_exc())
        return jsonify({"mensaje": str(e)}), 500

@app.route('/aceptar_pedido/<int:pedido_id>', methods=['POST']) 
@app.route('/aceptar_pedido', methods=['POST']) 
def aceptar_pedido(pedido_id=None):
    try:
        datos = request.get_json()
        if not datos: return jsonify({"status": "error", "mensaje": "Datos vacíos"}), 400

        id_ped = pedido_id if pedido_id else datos.get('pedido_id')
        repartidor_id = datos.get('repartidor_id')
        
        repartidor = Usuario.query.get(repartidor_id)
        if not repartidor or not repartidor.verificado:
            return jsonify({"status": "error", "error": "Cuenta de repartidor no verificada o inexistente"}), 403

        pedido = Pedido.query.get(id_ped)
        if pedido and pedido.estado in ['pendiente', 'listo_para_entrega']:
            pedido.repartidor_id = repartidor_id
            pedido.estado = 'en camino'
            db.session.commit()
            return jsonify({"status": "success", "mensaje": "Pedido aceptado con éxito", "message": "¡Pedido aceptado!"}), 200
        return jsonify({"status": "error", "mensaje": "Pedido no encontrado o ya no disponible", "error": "Pedido ya no disponible"}), 404
    except Exception as e:
        db.session.rollback()
        print("ERROR EN ACEPTAR PEDIDO:\n", traceback.format_exc())
        return jsonify({"status": "error", "mensaje": str(e)}), 500

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
        print("ERROR EN ESTADO PEDIDO:\n", traceback.format_exc())
        return jsonify({"mensaje": str(e)}), 500

@app.route('/actualizar_ubicacion', methods=['POST'])
def actualizar_ubicacion_post():
    try:
        datos = request.get_json()
        if not datos: return jsonify({"mensaje": "Sin datos"}), 400

        pedido = Pedido.query.get(datos.get('id_pedido'))
        if pedido:
            pedido.latitud_actual = datos.get('latitud')
            pedido.longitud_actual = datos.get('longitud')
            usuario = Usuario.query.get(pedido.repartidor_id)
            if usuario:
                usuario.latitud = datos.get('latitud')
                usuario.longitud = datos.get('longitud')
            db.session.commit()
            return jsonify({"status": "ok", "mensaje": "Ubicación actualizada"}), 200
        return jsonify({"mensaje": "Pedido no encontrado"}), 404
    except Exception as e:
        db.session.rollback()
        print("ERROR EN ACTUALIZAR UBICACION:\n", traceback.format_exc())
        return jsonify({"mensaje": str(e)}), 500

# --- HISTORIAL Y ADMINISTRACIÓN ---

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
        print("ERROR EN HISTORIAL:\n", traceback.format_exc())
        return jsonify({"mensaje": str(e)}), 500

@app.route('/admin/api/repartidores', methods=['GET'])
def api_repartidores():
    try:
        repartidores = Usuario.query.filter_by(rol='repartidor').all()
        resultado = []
        for r in repartidores:
            docs = DocumentoRepartidor.query.filter_by(user_id=r.id).all()
            resultado.append({
                "id": r.id,
                "nombre": r.nombre,
                "apellido": r.apellido or "",
                "correo": r.email,
                "email": r.email, 
                "telefono": r.telefono,
                "saldo": r.saldo,
                "es_verificado": r.verificado,
                "documentos": [{"tipo": d.tipo_documento, "ruta": d.ruta_archivo_servidor} for d in docs]
            })
        return jsonify(resultado), 200
    except Exception as e:
        print("ERROR EN ADMIN REPARTIDORES:\n", traceback.format_exc())
        return jsonify({"mensaje": str(e)}), 500

@app.route('/admin/aprobar/<int:user_id>', methods=['POST', 'GET'])
def aprobar_repartidor(user_id):
    try:
        u = Usuario.query.get(user_id)
        if u and u.rol == 'repartidor':
            u.verificado = True
            db.session.commit()
            return jsonify({"status": "success", "message": "Repartidor aprobado", "mensaje": "Repartidor aprobado"}), 200
        return jsonify({"status": "error", "mensaje": "Usuario no encontrado o no es repartidor"}), 404
    except Exception as e:
        db.session.rollback()
        print("ERROR EN APROBAR REPARTIDOR:\n", traceback.format_exc())
        return jsonify({"status": "error", "mensaje": str(e)}), 500

@app.route('/verificar_estatus/<int:user_id>', methods=['GET'])
def verificar_estatus(user_id):
    try:
        usuario = Usuario.query.get(user_id)
        if usuario:
            return jsonify({
                "status": "success",
                "verificado": usuario.verificado,
                "es_verificado": usuario.verificado,
                "user_status": "aprobado" if usuario.verificado else "pendiente"
            }), 200
        return jsonify({"status": "error", "mensaje": "Usuario no encontrado"}), 404
    except Exception as e:
        print("ERROR EN VERIFICAR ESTATUS:\n", traceback.format_exc())
        return jsonify({"status": "error", "mensaje": str(e)}), 500

# --- CHAT ---

@app.route('/api/chat/<int:pedido_id>', methods=['GET'])
def obtener_mensajes(pedido_id):
    try:
        mensajes = Mensaje.query.filter_by(pedido_id=pedido_id).order_by(Mensaje.fecha.asc()).all()
        return jsonify([{
            'id': m.id,
            'remitente_tipo': m.remitente_tipo,
            'texto': m.texto,
            'fecha': m.fecha.strftime('%Y-%m-%d %H:%M:%S')
        } for m in mensajes]), 200
    except Exception as e:
        print("ERROR EN OBTENER MENSAJES:\n", traceback.format_exc())
        return jsonify({"mensaje": str(e)}), 500

@app.route('/api/chat/enviar', methods=['POST'])
def enviar_mensaje():
    try:
        datos = request.get_json()
        if not datos: return jsonify({"error": "Sin datos"}), 400

        pedido_id = datos.get('pedido_id')
        pedido = Pedido.query.get(pedido_id)
        if not pedido: return jsonify({'error': 'Pedido no encontrado'}), 404
        if pedido.estado == 'pendiente': return jsonify({'error': 'El chat se activará cuando un domiciliario acepte el pedido.'}), 403
        if pedido.estado == 'entregado': return jsonify({'error': 'El pedido ya fue entregado. Chat cerrado.'}), 403

        nuevo_mensaje = Mensaje(pedido_id=pedido_id, remitente_tipo=datos.get('remitente_tipo'), texto=datos.get('texto'))
        db.session.add(nuevo_mensaje)
        db.session.commit()
        return jsonify({'status': 'success', 'mensaje': 'Enviado correctamente'}), 200
    except Exception as e:
        db.session.rollback()
        print("ERROR EN ENVIAR MENSAJE:\n", traceback.format_exc())
        return jsonify({"mensaje": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 10000))
    app.run(host='0.0.0.0', port=port)