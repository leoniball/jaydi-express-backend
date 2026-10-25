import os
import json
import ssl
import urllib.request
import traceback
import smtplib
import random
import uuid
import mimetypes
import boto3
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from flask import Flask, jsonify, request, render_template, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta
from sqlalchemy import text, or_
from werkzeug.utils import secure_filename

# --- IMPORTAR SOCKET.IO ---
from flask_socketio import SocketIO, emit, join_room, leave_room

# --- IMPORTAR Y CARGAR VARIABLES DE ENTORNO OCULTAS ---
from dotenv import load_dotenv
load_dotenv()

app = Flask(__name__)
CORS(app)

# --- INICIALIZAR SOCKET.IO ---
socketio = SocketIO(app, cors_allowed_origins="*")

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

# --- CONFIGURACIÓN DE SUBIDA DE ARCHIVOS (LOCAL/LEGACY) ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads', 'documentos')
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024 # 16MB Límite

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

# Configuración específica para imágenes de productos reales
UPLOAD_FOLDER_PRODUCTOS = os.path.join(BASE_DIR, 'uploads', 'productos')
if not os.path.exists(UPLOAD_FOLDER_PRODUCTOS):
    os.makedirs(UPLOAD_FOLDER_PRODUCTOS)

# --- CONFIGURACIÓN AWS S3 (NUEVO ECOSISTEMA CONDUCTORES) ---
BUCKET_NAME = 'jaydi-drivers-kyc'
s3_client = boto3.client(
    's3',
    aws_access_key_id=os.environ.get('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.environ.get('AWS_SECRET_ACCESS_KEY'),
    region_name='us-east-2'
)

def upload_document_to_s3(file_obj, filename):
    ext = filename.rsplit('.', 1)[1].lower() if '.' in filename else 'jpg'
    unique_filename = f"{uuid.uuid4().hex}.{ext}"
    content_type, _ = mimetypes.guess_type(filename)
    if not content_type:
        content_type = 'application/octet-stream'
    try:
        s3_client.upload_fileobj(
            file_obj,
            BUCKET_NAME,
            unique_filename,
            ExtraArgs={'ContentType': content_type}
        )
        return unique_filename
    except Exception as e:
        print(f"Error subiendo a S3: {e}", flush=True)
        return None

def get_presigned_url(object_key, expiration=3600):
    if not object_key: return None
    try:
        url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': BUCKET_NAME, 'Key': object_key},
            ExpiresIn=expiration
        )
        return url
    except Exception as e:
        print(f"Error generando Presigned URL: {e}", flush=True)
        return None

# --- MODELOS DE DATOS ---

class Usuario(db.Model):
    __tablename__ = 'usuario' 
    id = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(100), nullable=False)
    apellido = db.Column(db.String(100)) 
    telefono = db.Column(db.String(20))   
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False) 
    sexo = db.Column(db.String(50), default='Prefiero no decir')
    rol = db.Column(db.String(20), default='cliente') 
    verificado = db.Column(db.Boolean, default=False)
    saldo = db.Column(db.Float, default=0.0)
    foto_perfil = db.Column(db.Text, nullable=True) 
    vehiculo = db.Column(db.String(50), nullable=True) 
    placa = db.Column(db.String(20), nullable=True)
    viajes_completados = db.Column(db.Integer, default=0)
    latitud = db.Column(db.Float, nullable=True)
    longitud = db.Column(db.Float, nullable=True)
    ultima_conexion = db.Column(db.DateTime, default=datetime.utcnow)
    perfil_conductor = db.relationship('Conductor', backref='usuario_relacion', uselist=False, lazy=True)

class Conductor(db.Model):
    __tablename__ = 'conductores'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('usuario.id'), unique=True, nullable=False)
    nombres = db.Column(db.String(100), nullable=False)
    apellidos = db.Column(db.String(100), nullable=False)
    cedula_texto = db.Column(db.String(20), unique=True, nullable=False)
    telefono = db.Column(db.String(20), nullable=False)
    direccion = db.Column(db.Text, nullable=False)
    cert_medico_key = db.Column(db.String(255), nullable=False)
    licencia_key = db.Column(db.String(255), nullable=False)
    cedula_img_key = db.Column(db.String(255), nullable=False)
    seguro_key = db.Column(db.String(255), nullable=False)
    carnet_circulacion_key = db.Column(db.String(255), nullable=False)
    estado = db.Column(db.String(20), default='pending') 
    
    banco_pago = db.Column(db.String(100), nullable=True)
    cedula_pago = db.Column(db.String(50), nullable=True)
    telefono_pago = db.Column(db.String(50), nullable=True)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

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
    datos_pago = db.Column(db.JSON, nullable=True) 
    razon_cancelacion = db.Column(db.Text, nullable=True)
    # 👉 NUEVAS COLUMNAS PERMANENTES PARA VALORACIONES Y RESEÑAS
    calificacion_conductor = db.Column(db.Integer, nullable=True)
    resena_conductor = db.Column(db.Text, nullable=True)
    calificacion_cliente = db.Column(db.Integer, nullable=True)
    resena_cliente = db.Column(db.Text, nullable=True)
    notificado_conductor_fin = db.Column(db.Boolean, default=False)

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

class CodigoOTP(db.Model):
    __tablename__ = 'codigos_otp'
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), nullable=False)
    codigo = db.Column(db.String(6), nullable=False)
    proposito = db.Column(db.String(50), nullable=False) 
    fecha_expiracion = db.Column(db.DateTime, nullable=False)

def sincronizar_columnas_bd():
    comandos_sql = [
        "ALTER TABLE usuario ADD COLUMN IF NOT EXISTS sexo VARCHAR(50) DEFAULT 'Prefiero no decir';",
        "ALTER TABLE usuario ADD COLUMN IF NOT EXISTS foto_perfil TEXT;",
        "ALTER TABLE usuario ADD COLUMN IF NOT EXISTS vehiculo VARCHAR(50);",
        "ALTER TABLE usuario ADD COLUMN IF NOT EXISTS placa VARCHAR(20);",
        "ALTER TABLE usuario ADD COLUMN IF NOT EXISTS viajes_completados INTEGER DEFAULT 0;",
        "ALTER TABLE usuario ADD COLUMN IF NOT EXISTS latitud FLOAT;",
        "ALTER TABLE usuario ADD COLUMN IF NOT EXISTS longitud FLOAT;",
        "ALTER TABLE usuario ADD COLUMN IF NOT EXISTS ultima_conexion TIMESTAMP;",
        "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS latitud_actual FLOAT;",
        "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS longitud_actual FLOAT;",
        "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS latitud_destino FLOAT;",
        "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS longitud_destino FLOAT;",
        "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS datos_pago JSON;",
        "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS razon_cancelacion TEXT;",
        "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS calificacion_conductor INTEGER;",
        "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS resena_conductor TEXT;",
        "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS calificacion_cliente INTEGER;",
        "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS resena_cliente TEXT;",
        "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS notificado_conductor_fin BOOLEAN DEFAULT FALSE;",
        "ALTER TABLE conductores ADD COLUMN IF NOT EXISTS banco_pago VARCHAR(100);",
        "ALTER TABLE conductores ADD COLUMN IF NOT EXISTS cedula_pago VARCHAR(50);",
        "ALTER TABLE conductores ADD COLUMN IF NOT EXISTS telefono_pago VARCHAR(50);"
    ]
    for cmd in comandos_sql:
        try:
            db.session.execute(text(cmd))
            db.session.commit()
        except Exception:
            db.session.rollback()

with app.app_context():
    db.create_all()
    sincronizar_columnas_bd()
    print("¡Base de Datos de Neon Sincronizada y Lista (Unificada)!", flush=True)

# --- MOTOR DE ENVÍO DE CORREOS MULTICANAL ---
def enviar_correo_otp(destinatario, codigo, proposito):
    print(f"🔑 >>> [OTP JAYDI] Correo: {destinatario} | Código: {codigo} | Propósito: {proposito} <<<", flush=True)

    remitente = (os.environ.get('SMTP_USER') or os.environ.get('MAIL_USERNAME') or '').strip()
    password = (os.environ.get('SMTP_PASSWORD') or os.environ.get('MAIL_PASSWORD') or '').replace(' ', '').strip()
    url_script = os.environ.get('GOOGLE_SCRIPT_URL', '').strip()
    brevo_key = os.environ.get('BREVO_API_KEY', '').strip()

    if proposito == 'registro':
        asunto = "Tu código de verificación - Jaydi Express"
        cuerpo = f"Bienvenido a Jaydi Express.\n\nTu código de verificación es: {codigo}\n\nEste código expira en 10 minutos."
    else:
        asunto = "Recuperación de contraseña - Jaydi Express"
        cuerpo = f"Has solicitado recuperar tu contraseña.\n\nTu código de seguridad es: {codigo}\n\nSi no fuiste tú, ignora este mensaje."

    if brevo_key and remitente:
        try:
            payload = json.dumps({
                "sender": {"name": "Jaydi Express", "email": remitente},
                "to": [{"email": destinatario}],
                "subject": asunto,
                "textContent": cuerpo
            }).encode('utf-8')
            req = urllib.request.Request(
                "https://api.brevo.com/v3/smtp/email",
                data=payload,
                headers={'accept': 'application/json', 'api-key': brevo_key, 'content-type': 'application/json'},
                method='POST'
            )
            with urllib.request.urlopen(req, timeout=10) as resp:
                if resp.status in (200, 201, 202):
                    print(f"✅ Correo OTP enviado vía HTTPS (Brevo) a {destinatario}", flush=True)
                    return True
        except Exception as e_api:
            print(f"⚠️ Aviso API Brevo ({e_api}). Probando siguiente canal...", flush=True)

    if url_script:
        try:
            payload = json.dumps({"destinatario": destinatario, "asunto": asunto, "cuerpo": cuerpo}).encode('utf-8')
            req = urllib.request.Request(url_script, data=payload, headers={'Content-Type': 'application/json'}, method='POST')
            with urllib.request.urlopen(req, timeout=12) as resp:
                if resp.status in (200, 302):
                    print(f"✅ Correo OTP enviado vía HTTPS (Google Script) a {destinatario}", flush=True)
                    return True
        except Exception as e_gs:
            print(f"⚠️ Aviso Google Script ({e_gs}). Probando SMTP directo...", flush=True)

    if not remitente or not password:
        print("⚠️ AVISO: Credenciales SMTP no configuradas en Render. Usa el código impreso arriba en los Logs.", flush=True)
        return True

    msg = MIMEMultipart()
    msg['From'] = f"Jaydi Express <{remitente}>"
    msg['To'] = destinatario
    msg['Subject'] = asunto
    msg.attach(MIMEText(cuerpo, 'plain', 'utf-8'))

    contexto_ssl = ssl.create_default_context()

    try:
        with smtplib.SMTP_SSL('smtp.gmail.com', 465, timeout=10, context=contexto_ssl) as server:
            server.login(remitente, password)
            server.send_message(msg)
        print(f"✅ Correo OTP enviado por puerto 465 (SSL) a {destinatario}", flush=True)
        return True
    except Exception as e_ssl:
        print(f"⚠️ Falló puerto 465 ({e_ssl}). Probando puerto 587...", flush=True)

    try:
        with smtplib.SMTP('smtp.gmail.com', 587, timeout=10) as server:
            server.ehlo()
            server.starttls(context=contexto_ssl)
            server.ehlo()
            server.login(remitente, password)
            server.send_message(msg)
        print(f"✅ Correo OTP enviado por puerto 587 (TLS) a {destinatario}", flush=True)
        return True
    except Exception as e_tls:
        print(f"⚠️ Aviso SMTP ({e_tls}). Usa el código {codigo} mostrado en los Logs de Render.", flush=True)
        return True

# --- EVENTOS WEBSOCKET PARA EL CHAT EN VIVO Y RASTREO ---

@socketio.on('unirse_sala_pedido')
def handle_join_room(data):
    pedido_id = data.get('pedido_id')
    if pedido_id:
        room = f"pedido_{pedido_id}"
        join_room(room)
        print(f"Usuario se unió a la sala del chat: {room}", flush=True)

@socketio.on('salir_sala_pedido')
def handle_leave_room(data):
    pedido_id = data.get('pedido_id')
    if pedido_id:
        room = f"pedido_{pedido_id}"
        leave_room(room)
        print(f"Usuario abandonó la sala del chat: {room}", flush=True)

@socketio.on('enviar_mensaje_pedido')
def handle_send_message(data):
    pedido_id = data.get('pedido_id')
    remitente_tipo = data.get('remitente_tipo')
    texto = data.get('texto')

    if pedido_id and remitente_tipo and texto:
        try:
            nuevo_mensaje = Mensaje(pedido_id=pedido_id, remitente_tipo=remitente_tipo, texto=texto)
            db.session.add(nuevo_mensaje)
            db.session.commit()

            mensaje_formateado = {
                'id': nuevo_mensaje.id,
                'remitente_tipo': nuevo_mensaje.remitente_tipo,
                'texto': nuevo_mensaje.texto,
                'fecha': nuevo_mensaje.fecha.strftime('%Y-%m-%d %H:%M:%S')
            }

            room = f"pedido_{pedido_id}"
            emit('nuevo_mensaje_pedido', mensaje_formateado, room=room)
            print(f"Mensaje enviado a la sala {room}: {texto}", flush=True)
        except Exception as e:
            db.session.rollback()
            print(f"Error al guardar o emitir mensaje vía socket: {e}", flush=True)

# --- NUEVOS ENDPOINTS: REGISTRO Y VALIDACIÓN DE CONDUCTORES (S3) ---

@app.route('/api/drivers/register', methods=['POST'])
def registrar_conductor_s3():
    try:
        user_id_raw = request.form.get('user_id')
        
        if not user_id_raw:
            return jsonify({"status": "error", "mensaje": "Falta el ID de usuario"}), 400
            
        try:
            user_id = int(user_id_raw)
        except ValueError:
            return jsonify({"status": "error", "mensaje": "El formato del ID de usuario es inválido"}), 400
        
        usuario = Usuario.query.get(user_id)
        if not usuario:
            return jsonify({"status": "error", "mensaje": "Usuario principal no encontrado"}), 404
            
        if Conductor.query.filter_by(user_id=user_id).first():
            return jsonify({"status": "error", "mensaje": "Este usuario ya tiene una solicitud de conductor"}), 400

        archivos_requeridos = ['cert_medico', 'licencia', 'cedula_img', 'seguro', 'carnet_circulacion']
        for doc in archivos_requeridos:
            if doc not in request.files or request.files[doc].filename == '':
                return jsonify({"status": "error", "mensaje": f"Falta el documento: {doc}"}), 400

        keys = {}
        for doc in archivos_requeridos:
            file_obj = request.files[doc]
            s3_key = upload_document_to_s3(file_obj, file_obj.filename)
            if not s3_key:
                return jsonify({"status": "error", "mensaje": f"Error subiendo {doc} a la nube AWS S3"}), 500
            keys[doc] = s3_key

        nuevo_conductor = Conductor(
            user_id=user_id,
            nombres=request.form.get('nombres'),
            apellidos=request.form.get('apellidos'),
            cedula_texto=request.form.get('cedula_texto'),
            telefono=request.form.get('telefono'),
            direccion=request.form.get('direccion'),
            cert_medico_key=keys['cert_medico'],
            licencia_key=keys['licencia'],
            cedula_img_key=keys['cedula_img'],
            seguro_key=keys['seguro'],
            carnet_circulacion_key=keys['carnet_circulacion'],
            estado='pending'
        )
        db.session.add(nuevo_conductor)
        
        usuario.rol = 'repartidor_s3' 
        
        db.session.commit()
        return jsonify({"status": "success", "mensaje": "Solicitud de conductor enviada y documentos seguros en S3"}), 201

    except Exception as e:
        db.session.rollback()
        print("ERROR EN REGISTRO CONDUCTOR:\n", traceback.format_exc(), flush=True)
        return jsonify({"status": "error", "mensaje": str(e)}), 500

@app.route('/api/drivers/payment_info', methods=['POST'])
def guardar_datos_pago_conductor():
    try:
        datos = request.get_json()
        if not datos:
            return jsonify({"status": "error", "mensaje": "Sin datos JSON"}), 400
            
        user_id = datos.get('user_id')
        banco = datos.get('banco')
        cedula = datos.get('cedula')
        telefono = datos.get('telefono')
        
        if not all([user_id, banco, cedula, telefono]):
            return jsonify({"status": "error", "mensaje": "Faltan datos bancarios"}), 400
            
        conductor = Conductor.query.filter_by(user_id=user_id).first()
        if not conductor:
            return jsonify({"status": "error", "mensaje": "Conductor no encontrado"}), 404
            
        conductor.banco_pago = banco
        conductor.cedula_pago = cedula
        conductor.telefono_pago = telefono
        db.session.commit()
        
        return jsonify({"status": "success", "mensaje": "Datos de pago actualizados en Neon"}), 200
        
    except Exception as e:
        db.session.rollback()
        print("ERROR EN DATOS PAGO CONDUCTOR:\n", traceback.format_exc(), flush=True)
        return jsonify({"status": "error", "mensaje": str(e)}), 500

@app.route('/api/drivers/payment_info/<int:user_id>', methods=['GET'])
def obtener_datos_pago_conductor(user_id):
    try:
        conductor = Conductor.query.filter_by(user_id=user_id).first()
        if not conductor:
            return jsonify({"status": "error", "mensaje": "Conductor no encontrado"}), 404
        
        return jsonify({
            "status": "success",
            "banco": conductor.banco_pago or "",
            "cedula": conductor.cedula_pago or "",
            "telefono": conductor.telefono_pago or ""
        }), 200
    except Exception as e:
        print("ERROR GET DATOS PAGO:\n", traceback.format_exc(), flush=True)
        return jsonify({"status": "error", "mensaje": str(e)}), 500

# --- PANEL ADMIN MAESTRO ---

@app.route('/api/admin/conductores', methods=['GET'])
def obtener_todos_conductores():
    try:
        estado = request.args.get('estado') 
        if estado:
            conductores = Conductor.query.filter_by(estado=estado).all()
        else:
            conductores = Conductor.query.all()
        
        resultado = []
        for c in conductores:
            u = Usuario.query.get(c.user_id)
            resultado.append({
                "conductor_id": c.id,
                "user_id": c.user_id,
                "nombres": c.nombres,
                "apellidos": c.apellidos,
                "cedula_texto": c.cedula_texto,
                "telefono": c.telefono,
                "direccion": c.direccion,
                "estado": c.estado,
                "viajes_completados": u.viajes_completados if u else 0,
                "banco_pago": c.banco_pago or "No registrado",
                "cedula_pago": c.cedula_pago or "No registrado",
                "telefono_pago": c.telefono_pago or "No registrado",
                "documentos": {
                    "cert_medico": get_presigned_url(c.cert_medico_key),
                    "licencia": get_presigned_url(c.licencia_key),
                    "cedula_img": get_presigned_url(c.cedula_img_key),
                    "seguro": get_presigned_url(c.seguro_key),
                    "carnet_circulacion": get_presigned_url(c.carnet_circulacion_key)
                }
            })
        return jsonify(resultado), 200
    except Exception as e:
        return jsonify({"status": "error", "mensaje": str(e)}), 500

@app.route('/api/admin/aprobar_conductor/<int:conductor_id>', methods=['POST'])
def aprobar_conductor_s3(conductor_id):
    try:
        conductor = Conductor.query.get(conductor_id)
        if not conductor: return jsonify({"error": "Conductor no encontrado"}), 404
        
        conductor.estado = 'approved'
        usuario = Usuario.query.get(conductor.user_id)
        if usuario:
            usuario.verificado = True
        
        db.session.commit()
        return jsonify({"status": "success", "mensaje": "Conductor aprobado para recibir carreras"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@app.route('/api/admin/suspender_conductor/<int:conductor_id>', methods=['POST'])
def suspender_conductor(conductor_id):
    try:
        conductor = Conductor.query.get(conductor_id)
        if not conductor: return jsonify({"error": "Conductor no encontrado"}), 404
        
        conductor.estado = 'suspended'
        usuario = Usuario.query.get(conductor.user_id)
        if usuario:
            usuario.verificado = False
        
        db.session.commit()
        return jsonify({"status": "success", "mensaje": "Conductor suspendido correctamente"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@app.route('/api/admin/conductor_chats/<int:user_id>', methods=['GET'])
def obtener_chats_conductor(user_id):
    try:
        pedidos = Pedido.query.filter_by(repartidor_id=user_id).order_by(Pedido.fecha_creacion.desc()).all()
        historial_completo = []
        
        for p in pedidos:
            mensajes = Mensaje.query.filter_by(pedido_id=p.id).order_by(Mensaje.fecha.asc()).all()
            
            historial_completo.append({
                "pedido_id": p.id,
                "fecha": p.fecha_creacion.strftime('%Y-%m-%d %H:%M') if p.fecha_creacion else "Desconocida",
                "cliente_id": p.id_usuario,
                "destino": p.direccion_entrega,
                "estado_carrera": p.estado,
                "total_usd": p.total,
                "hubo_chat": len(mensajes) > 0,
                "razon_cancelacion": p.razon_cancelacion or "",
                "calificacion_conductor": p.calificacion_conductor,
                "resena_conductor": p.resena_conductor or "",
                "calificacion_cliente": p.calificacion_cliente,
                "resena_cliente": p.resena_cliente or "",
                "mensajes": [{
                    "remitente": m.remitente_tipo,
                    "texto": m.texto,
                    "hora": m.fecha.strftime('%H:%M:%S')
                } for m in mensajes]
            })
            
        return jsonify(historial_completo), 200
    except Exception as e:
        return jsonify({"status": "error", "mensaje": str(e)}), 500

# --- RUTAS DE NAVEGACIÓN Y ARCHIVOS ---

@app.route('/')
def index():
    return jsonify({
        "status": "online",
        "mensaje": "Servidor Único Jaydi (Express + Delivery + Rides) funcionando 24/7"
    })

@app.route('/uploads/documentos/user_<int:user_id>/<filename>')
def ver_archivo(user_id, filename):
    directorio_usuario = os.path.join(UPLOAD_FOLDER, f"user_{user_id}")
    return send_from_directory(directorio_usuario, filename)

@app.route('/uploads/productos/<filename>')
def ver_imagen_producto(filename):
    return send_from_directory(UPLOAD_FOLDER_PRODUCTOS, filename)

@app.route('/admin')
def admin_page():
    return render_template('admin.html') 

@app.route('/actualizar_bd_perfil')
def actualizar_bd_perfil():
    try:
        sincronizar_columnas_bd()
        return jsonify({"mensaje": "¡Éxito! Base de Datos Neon actualizada y sincronizada."}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"mensaje": "Aviso: " + str(e)}), 200

# --- LÓGICA DE REGISTRO Y LOGIN ---

@app.route('/registrar', methods=['POST'])
@app.route('/registro', methods=['POST']) 
def registrar():
    try:
        datos = request.get_json()
        if not datos:
            return jsonify({"status": "error", "mensaje": "Datos JSON no recibidos", "error": "No JSON payload"}), 400
            
        email = datos.get('email', '').strip().lower()
        if not email:
            return jsonify({"status": "error", "mensaje": "El correo es obligatorio"}), 400

        if Usuario.query.filter_by(email=email).first():
            return jsonify({"status": "error", "mensaje": "Este correo ya está registrado", "error": "El email ya existe"}), 400
        
        nuevo_rol = datos.get('rol', 'cliente')
        sexo_ingresado = datos.get('sexo', 'Prefiero no decir') 

        nuevo_usuario = Usuario(
            nombre=datos.get('nombre'),
            apellido=datos.get('apellido'),
            telefono=datos.get('telefono'),
            email=email,
            password=generate_password_hash(datos.get('password')),
            sexo=sexo_ingresado,
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
            "sexo": nuevo_usuario.sexo,
            "status": "pendiente",
            "rol": nuevo_rol
        }
        print(f"✅ USUARIO REGISTRADO EN NEON: {email} (ID: {nuevo_usuario.id})", flush=True)
        return jsonify({"status": "success", "mensaje": "Usuario creado con éxito", "rol": nuevo_rol, "usuario": user_data, "userData": user_data}), 201
    except Exception as e:
        db.session.rollback()
        print("ERROR EN REGISTRO:\n", traceback.format_exc(), flush=True)
        return jsonify({"status": "error", "mensaje": f"Error en registro: {str(e)}", "error": str(e)}), 500

@app.route('/login', methods=['POST'])
def login():
    try:
        datos = request.get_json()
        if not datos:
            return jsonify({"status": "error", "mensaje": "Datos JSON vacíos"}), 400
            
        email = datos.get('email', '').strip().lower()
        usuario = Usuario.query.filter_by(email=email).first()
        
        if usuario and check_password_hash(usuario.password, datos.get('password', '')):
            usuario.ultima_conexion = datetime.utcnow()
            db.session.commit()
            
            user_data = {
                "id": str(usuario.id), 
                "nombre": usuario.nombre, 
                "apellido": usuario.apellido or "",
                "email": usuario.email, 
                "sexo": usuario.sexo or "Prefiero no decir", 
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
        print("ERROR EN LOGIN:\n", traceback.format_exc(), flush=True)
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
                "sexo": usuario.sexo or "Prefiero no decir", 
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
            if 'sexo' in datos: usuario.sexo = datos['sexo']

            if 'password_actual' in datos and 'password_nuevo' in datos:
                if check_password_hash(usuario.password, datos['password_actual']):
                    usuario.password = generate_password_hash(datos['password_nuevo'])
                else:
                    return jsonify({"status": "error", "mensaje": "La contraseña actual es incorrecta"}), 400

            db.session.commit()
            return jsonify({"status": "success", "mensaje": "Perfil actualizado con éxito"}), 200

    except Exception as e:
        db.session.rollback()
        print("ERROR EN PERFIL:\n", traceback.format_exc(), flush=True)
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
        print("ERROR EN SUBIDA DOCUMENTO:\n", traceback.format_exc(), flush=True)
        return jsonify({"error": str(e)}), 500

# --- PRODUCTOS Y PEDIDOS ---

@app.route('/productos', methods=['GET'])
def obtener_productos():
    try:
        productos = Producto.query.all()
        return jsonify([{
            "id": p.id, "nombre": p.nombre, "precio": p.precio, 
            "imagen": p.imagen_url, "comercio": p.comercio.nombre if p.comercio else "Jaydi"
        } for p in productos]), 200
    except Exception as e:
        print("ERROR EN OBTENER PRODUCTOS:\n", traceback.format_exc(), flush=True)
        return jsonify({"mensaje": str(e)}), 500

@app.route('/api/admin/productos', methods=['POST'])
def admin_subir_producto():
    try:
        if 'imagen' not in request.files:
            return jsonify({"status": "error", "mensaje": "No se incluyó el archivo de imagen"}), 400
        
        file = request.files['imagen']
        if file.filename == '':
            return jsonify({"status": "error", "mensaje": "Nombre de archivo de imagen vacío"}), 400

        nombre = request.form.get('nombre')
        descripcion = request.form.get('descripcion', '')
        precio_raw = request.form.get('precio')
        stock_raw = request.form.get('stock', '10')
        comercio_id_raw = request.form.get('comercio_id')

        if not nombre or not precio_raw:
            return jsonify({"status": "error", "mensaje": "El nombre y el precio son obligatorios"}), 400

        try:
            precio = float(precio_raw)
            stock = int(stock_raw)
        except ValueError:
            return jsonify({"status": "error", "mensaje": "Formato de precio o stock inválido numéricamente"}), 400

        if comercio_id_raw:
            comercio_id = int(comercio_id_raw)
            comercio_existe = Comercio.query.get(comercio_id)
            if not comercio_existe:
                return jsonify({"status": "error", "mensaje": f"El comercio_id {comercio_id} asignado no existe"}), 404
        else:
            primer_comercio = Comercio.query.first()
            if not primer_comercio:
                nuevo_comercio = Comercio(
                    nombre="Tienda Principal Jaydi", 
                    rif="J-00000000-0", 
                    direccion="Sede Central Los Teques", 
                    categoria="General"
                )
                db.session.add(nuevo_comercio)
                db.session.commit()
                comercio_id = nuevo_comercio.id
            else:
                comercio_id = primer_comercio.id

        extension = file.filename.rsplit('.', 1)[1].lower() if '.' in file.filename else 'jpg'
        timestamp_unico = int(datetime.utcnow().timestamp())
        nombre_seguro_archivo = secure_filename(f"prod_{timestamp_unico}_{random.randint(100, 999)}.{extension}")
        
        ruta_guardado_fisico = os.path.join(UPLOAD_FOLDER_PRODUCTOS, nombre_seguro_archivo)
        file.save(ruta_guardado_fisico)

        url_recurso_estatico = f"/uploads/productos/{nombre_seguro_archivo}"

        nuevo_producto = Producto(
            nombre=nombre,
            descripcion=descripcion,
            precio=precio,
            stock=stock,
            imagen_url=url_recurso_estatico,
            comercio_id=comercio_id
        )
        db.session.add(nuevo_producto)
        db.session.commit()

        return jsonify({
            "status": "success",
            "mensaje": "Artículo cargado y publicado en el ecosistema con éxito",
            "producto": {
                "id": nuevo_producto.id,
                "nombre": nuevo_producto.nombre,
                "precio": nuevo_producto.precio,
                "imagen_url": nuevo_producto.imagen_url,
                "comercio_id": nuevo_producto.comercio_id
            }
        }), 201

    except Exception as e:
        db.session.rollback()
        print("ERROR CRÍTICO EN OPERACIÓN ADMINISTRATIVA:\n", traceback.format_exc(), flush=True)
        return jsonify({"status": "error", "mensaje": f"Fallo interno del servidor: {str(e)}"}), 500

@app.route('/finalizar_pedido', methods=['POST'])
def finalizar_pedido():
    try:
        datos = request.get_json()
        
        if not datos or isinstance(datos, list):
            return jsonify({"mensaje": "Error: Cuerpo de la solicitud inválido"}), 400

        raw_uid = datos.get('usuario_id') or datos.get('id_usuario') or datos.get('id')
        usuario_existe = None
        if raw_uid:
            try:
                usuario_existe = Usuario.query.get(int(raw_uid))
            except (ValueError, TypeError):
                usuario_existe = None

        if not usuario_existe:
            usuario_existe = Usuario.query.first()
            if not usuario_existe:
                usuario_existe = Usuario(
                    nombre="Cliente Jaydi",
                    email="cliente@jaydi.com",
                    password=generate_password_hash("jaydi123456"),
                    sexo="Prefiero no decir",
                    rol="cliente",
                    verificado=True
                )
                db.session.add(usuario_existe)
                db.session.commit()

        try:
            total_float = float(datos.get('total', 0.0))
        except (ValueError, TypeError):
            total_float = 0.0

        datos_pago = datos.get('pago')

        def sanear_coordenada(valor):
            try:
                return float(valor) if valor is not None and str(valor).strip() != "" else None
            except (ValueError, TypeError):
                return None

        lat_orig = sanear_coordenada(datos.get('latitud_origen')) or 10.3444
        lon_orig = sanear_coordenada(datos.get('longitud_origen')) or -67.0433
        lat_dest = sanear_coordenada(datos.get('latitud_destino'))
        lon_dest = sanear_coordenada(datos.get('longitud_destino'))

        nuevo_pedido = Pedido(
            id_usuario=usuario_existe.id,
            direccion_entrega=str(datos.get('direccion_entrega', 'Los Teques, Centro')),
            total=total_float,
            estado='verificando_pago', 
            latitud_actual=lat_orig,
            longitud_actual=lon_orig,
            latitud_destino=lat_dest,
            longitud_destino=lon_dest,
            datos_pago=datos_pago 
        )
        db.session.add(nuevo_pedido)
        db.session.commit()
        
        return jsonify({"mensaje": "Pedido recibido", "id": nuevo_pedido.id}), 201
        
    except Exception as e:
        db.session.rollback()
        print(">>> ERROR CRÍTICO EN FINALIZAR PEDIDO:", flush=True)
        print(traceback.format_exc(), flush=True)
        return jsonify({"mensaje": f"Error interno: {str(e)}"}), 500

# --- NUEVAS RUTAS REALES PARA JAYDI RIDES (VIAJES, ENVÍOS E HISTORIAL EN NEON) ---

@app.route('/api/rides/solicitar', methods=['POST'])
def solicitar_viaje_o_envio():
    try:
        datos = request.get_json() or {}

        raw_uid = datos.get('usuario_id')
        usuario = None
        if raw_uid:
            try:
                usuario = Usuario.query.get(int(raw_uid))
            except (ValueError, TypeError):
                usuario = None

        if not usuario:
            usuario = Usuario.query.first()
            if not usuario:
                usuario = Usuario(
                    nombre="Cliente Jaydi",
                    email="invitado@jaydi.com",
                    password=generate_password_hash("jaydi123456"),
                    sexo="Prefiero no decir",
                    rol="cliente",
                    verificado=True
                )
                db.session.add(usuario)
                db.session.commit()

        tipo_servicio = datos.get('tipo_servicio', 'Viajes')
        origen_texto = datos.get('origen', 'Los Teques')
        destino_texto = datos.get('direccion_entrega', 'Los Teques, Centro')
        total_usd = float(datos.get('total', 3.50))

        lat_origen = float(datos.get('latitud_origen', 10.3444))
        lon_origen = float(datos.get('longitud_origen', -67.0433))
        lat_destino = float(datos.get('latitud_destino', 10.3495))
        lon_destino = float(datos.get('longitud_destino', -67.0401))

        fecha_programada = datos.get('fecha_programada')
        hora_programada = datos.get('hora_programada')

        info_extra = {
            "tipo_servicio": tipo_servicio,
            "origen": origen_texto,
            "destino": destino_texto,
            "metodo": datos.get('metodo_pago', 'Pago Móvil'),
            "tasa_bcv": float(datos.get('tasa_bcv', 0.0)),
            "monto_ves": float(datos.get('monto_ves', 0.0)),
            "distancia_km": str(datos.get('distancia_km', '0.0')),
            "duracion_min": int(datos.get('duracion_min', 5)),
            "pasajero": datos.get('pasajero', 'Para mí'),
            "fecha_programada": fecha_programada,
            "hora_programada": hora_programada
        }

        estado_inicial = 'agendado' if (fecha_programada and hora_programada) else 'pendiente'

        nuevo_viaje = Pedido(
            id_usuario=usuario.id,
            direccion_entrega=f"[{tipo_servicio.upper()}] {origen_texto} -> {destino_texto}",
            total=total_usd,
            estado=estado_inicial,
            latitud_actual=lat_origen,
            longitud_actual=lon_origen,
            latitud_destino=lat_destino,
            longitud_destino=lon_destino,
            datos_pago=info_extra
        )
        db.session.add(nuevo_viaje)
        db.session.commit()

        if estado_inicial == 'pendiente':
            socketio.emit('nuevo_viaje_disponible', {
                'id': nuevo_viaje.id,
                'tipo_servicio': tipo_servicio,
                'origen': origen_texto,
                'destino': destino_texto,
                'total_usd': total_usd,
                'cliente_nombre': usuario.nombre,
                'latitud_origen': lat_origen,
                'longitud_origen': lon_origen,
                'latitud_destino': lat_destino,
                'longitud_destino': lon_destino
            })

        print(f"🚗 NUEVO {tipo_servicio.upper()} CREADO EN NEON -> ID #{nuevo_viaje.id} | Estado: {estado_inicial}", flush=True)
        return jsonify({
            "status": "success",
            "mensaje": f"{tipo_servicio} registrado correctamente",
            "id": nuevo_viaje.id,
            "usuario_id": usuario.id
        }), 201

    except Exception as e:
        db.session.rollback()
        print("ERROR EN SOLICITAR VIAJE:\n", traceback.format_exc(), flush=True)
        return jsonify({"status": "error", "mensaje": str(e)}), 500

# 👉 RUTA MEJORADA: DEVUELVE TANTO LOS VIAJES COMO CLIENTE Y COMO CONDUCTOR + RESEÑAS PERMANENTES
@app.route('/api/rides/mis_viajes/<int:usuario_id>', methods=['GET'])
def obtener_mis_viajes_cliente(usuario_id):
    try:
        if usuario_id > 0:
            viajes = Pedido.query.filter(
                or_(Pedido.id_usuario == usuario_id, Pedido.repartidor_id == usuario_id)
            ).order_by(Pedido.fecha_creacion.desc()).all()
        else:
            viajes = Pedido.query.order_by(Pedido.fecha_creacion.desc()).limit(15).all()

        resultado = []
        for v in viajes:
            meta = v.datos_pago if isinstance(v.datos_pago, dict) else {}
            
            cliente = Usuario.query.get(v.id_usuario)
            repartidor = Usuario.query.get(v.repartidor_id) if v.repartidor_id else None
            
            resultado.append({
                "id": v.id,
                "cliente_id": v.id_usuario,
                "repartidor_id": v.repartidor_id,
                "direccion_entrega": v.direccion_entrega,
                "origen": meta.get("origen", "Los Teques"),
                "destino": meta.get("destino", v.direccion_entrega),
                "tipo_servicio": meta.get("tipo_servicio", "Viajes"),
                "metodo_pago": meta.get("metodo", "Pago Móvil"),
                "distancia_km": meta.get("distancia_km", "--"),
                "duracion_min": meta.get("duracion_min", 5),
                "total": float(v.total),
                "monto_ves": float(meta.get("monto_ves", 0.0)),
                "estado": v.estado,
                "fecha": v.fecha_creacion.strftime("%d/%m/%Y %H:%M") if v.fecha_creacion else "",
                "fecha_programada": meta.get("fecha_programada", ""),
                "hora_programada": meta.get("hora_programada", ""),
                "razon_cancelacion": v.razon_cancelacion or "",
                "latitud_origen": v.latitud_actual or 10.3444,
                "longitud_origen": v.longitud_actual or -67.0433,
                "latitud_destino": v.latitud_destino or 10.3495,
                "longitud_destino": v.longitud_destino or -67.0401,
                "cliente_nombre": cliente.nombre if cliente else "Cliente",
                "usuario_nombre": cliente.nombre if cliente else "Cliente",
                "repartidor_nombre": repartidor.nombre if repartidor else "Conductor",
                "calificacion_conductor": v.calificacion_conductor,
                "resena_conductor": v.resena_conductor or "",
                "calificacion_cliente": v.calificacion_cliente,
                "resena_cliente": v.resena_cliente or "",
                "notificado_conductor_fin": bool(v.notificado_conductor_fin)
            })
        return jsonify(resultado), 200
    except Exception as e:
        print("ERROR EN OBTENER MIS VIAJES:\n", traceback.format_exc(), flush=True)
        return jsonify({"status": "error", "mensaje": str(e)}), 500

@app.route('/api/rides/cancelar', methods=['POST'])
def cancelar_viaje():
    try:
        datos = request.get_json()
        pedido_id = datos.get('pedido_id')
        rol = datos.get('rol') 
        razon = datos.get('razon', 'Sin especificar')

        pedido = Pedido.query.get(pedido_id)
        if not pedido:
            return jsonify({"status": "error", "mensaje": "Viaje no encontrado"}), 404

        if rol == 'cliente':
            pedido.estado = 'cancelado'
            pedido.razon_cancelacion = f"Cliente: {razon}"
        elif rol == 'conductor':
            pedido.estado = 'pendiente'
            pedido.repartidor_id = None
            pedido.razon_cancelacion = f"Conductor canceló: {razon}"
            
        db.session.commit()
        return jsonify({"status": "success", "mensaje": "Viaje actualizado correctamente"}), 200
    except Exception as e:
        db.session.rollback()
        print("ERROR CANCELANDO VIAJE:\n", traceback.format_exc(), flush=True)
        return jsonify({"status": "error", "mensaje": str(e)}), 500

# 👉 NUEVA RUTA PARA CULMINAR VIAJE, GUARDAR VALORACIÓN/RESEÑA DEL CONDUCTOR Y NOTIFICARLE AL INSTANTE
@app.route('/api/rides/culminar', methods=['POST'])
@app.route('/api/rides/completar_viaje', methods=['POST'])
def completar_viaje_driver():
    try:
        datos = request.get_json() or {}
        pedido_id = datos.get('pedido_id')
        repartidor_id = datos.get('repartidor_id')
        calificacion_conductor = datos.get('calificacion_conductor')
        resena_conductor = datos.get('resena_conductor')

        pedido = Pedido.query.get(pedido_id)
        if not pedido:
            return jsonify({"status": "error", "mensaje": "Viaje no encontrado"}), 404

        ya_estaba_entregado = (pedido.estado == 'entregado')
        pedido.estado = 'entregado'

        if calificacion_conductor is not None:
            try:
                pedido.calificacion_conductor = int(calificacion_conductor)
            except (ValueError, TypeError):
                pedido.calificacion_conductor = 5

        if resena_conductor is not None and str(resena_conductor).strip() != "":
            pedido.resena_conductor = str(resena_conductor).strip()

        # Marca que el conductor debe recibir la notificación de viaje culminado y modal de reseña al cliente
        pedido.notificado_conductor_fin = False

        id_cond = repartidor_id or pedido.repartidor_id
        if id_cond and not ya_estaba_entregado:
            conductor = Usuario.query.get(id_cond)
            if conductor:
                conductor.viajes_completados = (conductor.viajes_completados or 0) + 1
                conductor.saldo = (conductor.saldo or 0.0) + float(pedido.total or 0.0)

        db.session.commit()

        meta = pedido.datos_pago if isinstance(pedido.datos_pago, dict) else {}
        destino_limpio = meta.get("destino", pedido.direccion_entrega)
        cliente = Usuario.query.get(pedido.id_usuario)
        nombre_cliente = cliente.nombre if cliente else "Cliente"

        socketio.emit('viaje_culminado', {
            'pedido_id': pedido.id,
            'repartidor_id': pedido.repartidor_id,
            'cliente_id': pedido.id_usuario,
            'cliente_nombre': nombre_cliente,
            'destino': destino_limpio,
            'calificacion_conductor': pedido.calificacion_conductor or 5,
            'resena_conductor': pedido.resena_conductor or ""
        })

        return jsonify({
            "status": "success",
            "mensaje": "Viaje culminado y reseña guardada para siempre en el historial",
            "destino": destino_limpio,
            "cliente_nombre": nombre_cliente
        }), 200
    except Exception as e:
        db.session.rollback()
        print("ERROR EN COMPLETAR VIAJE:\n", traceback.format_exc(), flush=True)
        return jsonify({"status": "error", "mensaje": str(e)}), 500

# 👉 NUEVA RUTA PARA QUE EL CONDUCTOR ACEPTE EL FIN DEL VIAJE Y DEJE SU RESEÑA OPCIONAL AL CLIENTE
@app.route('/api/rides/resena_cliente', methods=['POST'])
def guardar_resena_al_cliente():
    try:
        datos = request.get_json() or {}
        pedido_id = datos.get('pedido_id')
        calificacion_cliente = datos.get('calificacion_cliente')
        resena_cliente = datos.get('resena_cliente')

        pedido = Pedido.query.get(pedido_id)
        if not pedido:
            return jsonify({"status": "error", "mensaje": "Viaje no encontrado"}), 404

        pedido.notificado_conductor_fin = True

        if calificacion_cliente is not None:
            try:
                pedido.calificacion_cliente = int(calificacion_cliente)
            except (ValueError, TypeError):
                pass

        if resena_cliente is not None and str(resena_cliente).strip() != "":
            pedido.resena_cliente = str(resena_cliente).strip()

        db.session.commit()
        return jsonify({
            "status": "success",
            "mensaje": "Confirmación y reseña del cliente guardadas en el historial"
        }), 200
    except Exception as e:
        db.session.rollback()
        print("ERROR GUARDANDO RESEÑA CLIENTE:\n", traceback.format_exc(), flush=True)
        return jsonify({"status": "error", "mensaje": str(e)}), 500

# 👉 NUEVA RUTA: OBTIENE PROMEDIO DE ESTRELLAS, HISTORIAL DE RESEÑAS E INFORMA VIAJES RECIÉN CULMINADOS AL CONDUCTOR
@app.route('/api/rides/resenas_usuario/<int:usuario_id>', methods=['GET'])
def obtener_resenas_y_alertas_usuario(usuario_id):
    try:
        # 1. Reseñas recibidas como conductor
        viajes_como_conductor = Pedido.query.filter_by(repartidor_id=usuario_id, estado='entregado').order_by(Pedido.fecha_creacion.desc()).all()
        resenas_conductor = []
        suma_estrellas_cond = 0
        conteo_estrellas_cond = 0

        pendientes_aceptar_fin = []

        for p in viajes_como_conductor:
            meta = p.datos_pago if isinstance(p.datos_pago, dict) else {}
            destino_limpio = meta.get("destino", p.direccion_entrega)
            cli = Usuario.query.get(p.id_usuario)
            nombre_cli = cli.nombre if cli else "Cliente"

            if p.calificacion_conductor is not None:
                suma_estrellas_cond += int(p.calificacion_conductor)
                conteo_estrellas_cond += 1

            if p.calificacion_conductor is not None or (p.resena_conductor and p.resena_conductor.strip()):
                resenas_conductor.append({
                    "pedido_id": p.id,
                    "cliente_nombre": nombre_cli,
                    "destino": destino_limpio,
                    "estrellas": p.calificacion_conductor or 5,
                    "resena": p.resena_conductor or "",
                    "fecha": p.fecha_creacion.strftime("%d/%m/%Y %H:%M") if p.fecha_creacion else ""
                })

            if not p.notificado_conductor_fin:
                pendientes_aceptar_fin.append({
                    "pedido_id": p.id,
                    "cliente_id": p.id_usuario,
                    "cliente_nombre": nombre_cli,
                    "destino": destino_limpio,
                    "total": float(p.total or 0.0),
                    "calificacion_recibida": p.calificacion_conductor or 5,
                    "resena_recibida": p.resena_conductor or ""
                })

        promedio_conductor = round(suma_estrellas_cond / conteo_estrellas_cond, 2) if conteo_estrellas_cond > 0 else 5.0

        # 2. Reseñas recibidas como cliente
        viajes_como_cliente = Pedido.query.filter_by(id_usuario=usuario_id, estado='entregado').order_by(Pedido.fecha_creacion.desc()).all()
        resenas_cliente = []
        suma_estrellas_cli = 0
        conteo_estrellas_cli = 0

        for p in viajes_como_cliente:
            meta = p.datos_pago if isinstance(p.datos_pago, dict) else {}
            destino_limpio = meta.get("destino", p.direccion_entrega)
            cond = Usuario.query.get(p.repartidor_id) if p.repartidor_id else None
            nombre_cond = cond.nombre if cond else "Conductor"

            if p.calificacion_cliente is not None:
                suma_estrellas_cli += int(p.calificacion_cliente)
                conteo_estrellas_cli += 1

            if p.calificacion_cliente is not None or (p.resena_cliente and p.resena_cliente.strip()):
                resenas_cliente.append({
                    "pedido_id": p.id,
                    "conductor_nombre": nombre_cond,
                    "destino": destino_limpio,
                    "estrellas": p.calificacion_cliente or 5,
                    "resena": p.resena_cliente or "",
                    "fecha": p.fecha_creacion.strftime("%d/%m/%Y %H:%M") if p.fecha_creacion else ""
                })

        promedio_cliente = round(suma_estrellas_cli / conteo_estrellas_cli, 2) if conteo_estrellas_cli > 0 else 5.0

        return jsonify({
            "status": "success",
            "promedio_conductor": promedio_conductor,
            "total_calificaciones_conductor": conteo_estrellas_cond,
            "resenas_recibidas_conductor": resenas_conductor,
            "promedio_cliente": promedio_cliente,
            "total_calificaciones_cliente": conteo_estrellas_cli,
            "resenas_recibidas_cliente": resenas_cliente,
            "viajes_culminados_por_aceptar": pendientes_aceptar_fin
        }), 200
    except Exception as e:
        print("ERROR EN OBTENER RESEÑAS USUARIO:\n", traceback.format_exc(), flush=True)
        return jsonify({"status": "error", "mensaje": str(e)}), 500

# 👉 RUTA CORREGIDA: AHORA ENVÍA EL NOMBRE DEL CLIENTE Y DEL REPARTIDOR PARA EL CHAT + RESEÑAS
@app.route('/obtener_pedido/<int:pedido_id>', methods=['GET'])
def obtener_pedido(pedido_id):
    try:
        pedido = Pedido.query.get(pedido_id)
        if pedido:
            cliente = Usuario.query.get(pedido.id_usuario)
            repartidor = Usuario.query.get(pedido.repartidor_id) if pedido.repartidor_id else None
            meta = pedido.datos_pago if isinstance(pedido.datos_pago, dict) else {}
            
            return jsonify({
                "id": pedido.id,
                "cliente_id": pedido.id_usuario,
                "repartidor_id": pedido.repartidor_id,
                "direccion": pedido.direccion_entrega,
                "destino": meta.get("destino", pedido.direccion_entrega),
                "estado": pedido.estado,
                "total": pedido.total,
                "latitud_actual": pedido.latitud_actual or 10.3444,
                "longitud_actual": pedido.longitud_actual or -67.0433,
                "latitud_destino": pedido.latitud_destino or 10.3495,
                "longitud_destino": pedido.longitud_destino or -67.0401,
                "datos_pago": pedido.datos_pago,
                "usuario_nombre": cliente.nombre if cliente else "Cliente",
                "cliente_nombre": cliente.nombre if cliente else "Cliente",
                "repartidor_nombre": repartidor.nombre if repartidor else "Conductor",
                "calificacion_conductor": pedido.calificacion_conductor,
                "resena_conductor": pedido.resena_conductor or "",
                "calificacion_cliente": pedido.calificacion_cliente,
                "resena_cliente": pedido.resena_cliente or "",
                "notificado_conductor_fin": bool(pedido.notificado_conductor_fin)
            }), 200
        return jsonify({"error": "Pedido no encontrado"}), 404
    except Exception as e:
        print("ERROR EN OBTENER PEDIDO:\n", traceback.format_exc(), flush=True)
        return jsonify({"error": str(e)}), 500

# 👉 RUTA CORREGIDA: AHORA ENVÍA EL NOMBRE DEL CLIENTE PARA EL RADAR DEL CONDUCTOR
@app.route('/pedidos_disponibles', methods=['GET'])
@app.route('/api/delivery/pedidos_disponibles', methods=['GET'])
def pedidos_disponibles():
    try:
        pedidos = Pedido.query.filter(Pedido.estado.in_(['pendiente', 'listo_para_entrega', 'agendado'])).order_by(Pedido.fecha_creacion.desc()).all()
        resultado = []
        
        for p in pedidos:
            cliente = Usuario.query.get(p.id_usuario)
            resultado.append({
                "id": p.id, 
                "cliente": p.id_usuario, 
                "direccion": p.direccion_entrega, 
                "total": p.total,
                "estado": p.estado,
                "latitud_origen": p.latitud_actual or 10.3444,
                "longitud_origen": p.longitud_actual or -67.0433,
                "latitud_destino": p.latitud_destino or 10.3495,
                "longitud_destino": p.longitud_destino or -67.0401,
                "datos_pago": p.datos_pago,
                "usuario_nombre": cliente.nombre if cliente else "Cliente",
                "cliente_nombre": cliente.nombre if cliente else "Cliente"
            })
        return jsonify(resultado), 200
    except Exception as e:
        print("ERROR EN PEDIDOS DISPONIBLES:\n", traceback.format_exc(), flush=True)
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
        if pedido and pedido.estado in ['pendiente', 'listo_para_entrega', 'agendado']:
            pedido.repartidor_id = repartidor_id
            pedido.estado = 'en camino'
            db.session.commit()
            return jsonify({"status": "success", "mensaje": "Pedido aceptado con éxito", "message": "¡Pedido aceptado!"}), 200
        return jsonify({"status": "error", "mensaje": "Pedido no encontrado o ya no disponible", "error": "Pedido ya no disponible"}), 404
    except Exception as e:
        db.session.rollback()
        print("ERROR EN ACEPTAR PEDIDO:\n", traceback.format_exc(), flush=True)
        return jsonify({"status": "error", "mensaje": str(e)}), 500

# 👉 RUTA CORREGIDA: AHORA ENVÍA EL NOMBRE DEL CONDUCTOR Y ESTADO AL MAPA DE SEGUIMIENTO
@app.route('/estado_pedido/<int:id_pedido>', methods=['GET'])
def estado_pedido(id_pedido):
    try:
        pedido = Pedido.query.get(id_pedido)
        if pedido:
            cliente = Usuario.query.get(pedido.id_usuario)
            repartidor = Usuario.query.get(pedido.repartidor_id) if pedido.repartidor_id else None
            meta = pedido.datos_pago if isinstance(pedido.datos_pago, dict) else {}
            
            return jsonify({
                "id": pedido.id,
                "estado": pedido.estado,
                "destino": meta.get("destino", pedido.direccion_entrega),
                "repartidor_id": pedido.repartidor_id,
                "cliente_id": pedido.id_usuario,
                "latitud_actual": pedido.latitud_actual or 10.3444,
                "longitud_actual": pedido.longitud_actual or -67.0433,
                "latitud_destino": pedido.latitud_destino or 10.3495,
                "longitud_destino": pedido.longitud_destino or -67.0401,
                "usuario_nombre": cliente.nombre if cliente else "Cliente",
                "cliente_nombre": cliente.nombre if cliente else "Cliente",
                "repartidor_nombre": repartidor.nombre if repartidor else "Conductor",
                "calificacion_conductor": pedido.calificacion_conductor,
                "resena_conductor": pedido.resena_conductor or "",
                "calificacion_cliente": pedido.calificacion_cliente,
                "resena_cliente": pedido.resena_cliente or "",
                "notificado_conductor_fin": bool(pedido.notificado_conductor_fin)
            }), 200
        return jsonify({"mensaje": "Pedido no encontrado"}), 404
    except Exception as e:
        print("ERROR EN ESTADO PEDIDO:\n", traceback.format_exc(), flush=True)
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

            socketio.emit('ubicacion_tiempo_real', {
                'id_pedido': pedido.id,
                'latitud': pedido.latitud_actual,
                'longitud': pedido.longitud_actual,
                'estado': pedido.estado
            })
            return jsonify({"status": "ok", "mensaje": "Ubicación actualizada"}), 200
        return jsonify({"mensaje": "Pedido no encontrado"}), 404
    except Exception as e:
        db.session.rollback()
        print("ERROR EN ACTUALIZAR UBICACION:\n", traceback.format_exc(), flush=True)
        return jsonify({"mensaje": str(e)}), 500

# --- HISTORIAL Y ADMINISTRACIÓN ---

@app.route('/admin/api/pagos_pendientes', methods=['GET'])
def get_pagos_pendientes():
    try:
        pedidos = Pedido.query.filter_by(estado='verificando_pago').all()
        lista = []
        for p in pedidos:
            pago_seguro = p.datos_pago if p.datos_pago else {"metodo": "No reportado", "referencia": "N/A", "tasa_bcv": 0}
            
            lista.append({
                "id": p.id,
                "total": float(p.total),
                "datos_pago": pago_seguro
            })
        return jsonify(lista), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/admin/aprobar_pago/<int:pedido_id>', methods=['GET'])
def admin_aprobar_pago(pedido_id):
    try:
        pedido = Pedido.query.get(pedido_id)
        if not pedido:
            return jsonify({"error": "Pedido no encontrado"}), 404
            
        if pedido.estado == 'verificando_pago':
            pedido.estado = 'pendiente' 
            db.session.commit()
            return jsonify({
                "status": "success", 
                "mensaje": f"Pago del pedido {pedido_id} verificado. Orden enviada a los domiciliarios."
            }), 200
        else:
            return jsonify({"aviso": f"El pedido ya ha sido procesado (estado actual: {pedido.estado})"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@app.route('/historial_viajes/<int:repartidor_id>', methods=['GET'])
def historial_viajes(repartidor_id):
    try:
        pedidos = Pedido.query.filter_by(repartidor_id=repartidor_id, estado='entregado').order_by(Pedido.fecha_creacion.desc()).all()
        resultado = []
        for p in pedidos:
            cli = Usuario.query.get(p.id_usuario)
            meta = p.datos_pago if isinstance(p.datos_pago, dict) else {}
            resultado.append({
                "id": p.id,
                "direccion": p.direccion_entrega,
                "destino": meta.get("destino", p.direccion_entrega),
                "total": p.total,
                "fecha": p.fecha_creacion.strftime("%d/%m/%Y %H:%M") if p.fecha_creacion else "",
                "cliente_nombre": cli.nombre if cli else "Cliente",
                "calificacion_conductor": p.calificacion_conductor,
                "resena_conductor": p.resena_conductor or "",
                "calificacion_cliente": p.calificacion_cliente,
                "resena_cliente": p.resena_cliente or ""
            })
        return jsonify(resultado), 200
    except Exception as e:
        print("ERROR EN HISTORIAL:\n", traceback.format_exc(), flush=True)
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
        print("ERROR EN ADMIN REPARTIDORES:\n", traceback.format_exc(), flush=True)
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
        print("ERROR EN APROBAR REPARTIDOR:\n", traceback.format_exc(), flush=True)
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
        print("ERROR EN VERIFICAR ESTATUS:\n", traceback.format_exc(), flush=True)
        return jsonify({"status": "error", "mensaje": str(e)}), 500

# --- CHAT REST API (Sincronizado con Socket.IO) ---

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
        print("ERROR EN OBTENER MENSAJES:\n", traceback.format_exc(), flush=True)
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

        mensaje_formateado = {
            'id': nuevo_mensaje.id,
            'remitente_tipo': nuevo_mensaje.remitente_tipo,
            'texto': nuevo_mensaje.texto,
            'fecha': nuevo_mensaje.fecha.strftime('%Y-%m-%d %H:%M:%S')
        }
        socketio.emit('nuevo_mensaje_pedido', mensaje_formateado, room=f"pedido_{pedido_id}")

        return jsonify({'status': 'success', 'mensaje': 'Enviado correctamente'}), 200
    except Exception as e:
        db.session.rollback()
        print("ERROR EN ENVIAR MENSAJE:\n", traceback.format_exc(), flush=True)
        return jsonify({"mensaje": str(e)}), 500

# --- RUTAS DE SEGURIDAD OTP Y RECUPERACIÓN ---

@app.route('/api/solicitar_otp', methods=['POST'])
def solicitar_otp():
    try:
        data = request.get_json() or {}
        email = data.get('email', '').strip().lower()
        proposito = data.get('proposito', '').strip()

        if not email or not proposito:
            return jsonify({'error': 'Faltan datos'}), 400

        if proposito == 'recuperacion':
            user = Usuario.query.filter_by(email=email).first()
            if not user:
                return jsonify({'error': 'Este correo no está registrado en Jaydi'}), 404
        
        if proposito == 'registro':
            user = Usuario.query.filter_by(email=email).first()
            if user:
                return jsonify({'error': 'Este correo ya tiene una cuenta activa'}), 400

        codigo = str(random.randint(100000, 999999))
        expiracion = datetime.utcnow() + timedelta(minutes=10)

        CodigoOTP.query.filter_by(email=email, proposito=proposito).delete()

        nuevo_otp = CodigoOTP(email=email, codigo=codigo, proposito=proposito, fecha_expiracion=expiracion)
        db.session.add(nuevo_otp)
        db.session.commit()

        enviar_correo_otp(email, codigo, proposito)
        return jsonify({'mensaje': 'Código enviado con éxito'}), 200
    except Exception as e:
        db.session.rollback()
        print("ERROR EN SOLICITAR OTP:\n", traceback.format_exc(), flush=True)
        return jsonify({'error': f'Error interno en OTP: {str(e)}'}), 500

@app.route('/api/verificar_otp', methods=['POST'])
def verificar_otp():
    try:
        data = request.get_json() or {}
        email = data.get('email', '').strip().lower()
        codigo = data.get('codigo', '').strip()
        proposito = data.get('proposito', '').strip()

        registro_otp = CodigoOTP.query.filter_by(email=email, codigo=codigo, proposito=proposito).first()

        if not registro_otp:
            return jsonify({'error': 'Código incorrecto'}), 400

        if datetime.utcnow() > registro_otp.fecha_expiracion:
            return jsonify({'error': 'Este código ya expiró. Solicita uno nuevo.'}), 400

        db.session.delete(registro_otp)
        db.session.commit()

        return jsonify({'mensaje': 'Identidad verificada exitosamente'}), 200
    except Exception as e:
        db.session.rollback()
        print("ERROR EN VERIFICAR OTP:\n", traceback.format_exc(), flush=True)
        return jsonify({'error': f'Error verificando OTP: {str(e)}'}), 500

@app.route('/api/reset_password', methods=['POST'])
def reset_password():
    try:
        data = request.get_json() or {}
        email = data.get('email', '').strip().lower()
        nueva_clave = data.get('nueva_clave', '')

        user = Usuario.query.filter_by(email=email).first()
        if not user:
            return jsonify({'error': 'Usuario no encontrado'}), 404

        user.password = generate_password_hash(nueva_clave)
        db.session.commit()

        return jsonify({'mensaje': 'Contraseña actualizada. Ya puedes iniciar sesión.'}), 200
    except Exception as e:
        db.session.rollback()
        print("ERROR EN RESET PASSWORD:\n", traceback.format_exc(), flush=True)
        return jsonify({'error': str(e)}), 500


# --- WEBHOOK BANCARIO ---

@app.route('/api/pagos/webhook', methods=['POST'])
def webhook_pagos_banco():
    try:
        datos_banco = request.get_json()
        if not datos_banco:
            return jsonify({"status": "error", "mensaje": "Payload vacío"}), 400

        print(f">>> WEBHOOK BANCARIO RECIBIDO: {datos_banco}", flush=True)
        return jsonify({"status": "success", "mensaje": "Notificación recibida procesada"}), 200
        
    except Exception as e:
        print("ERROR EN WEBHOOK BANCARIO:\n", traceback.format_exc(), flush=True)
        return jsonify({"status": "error", "mensaje": str(e)}), 500


if __name__ == '__main__':
    port = int(os.environ.get("PORT", 10000))
    socketio.run(app, host='0.0.0.0', port=port, allow_unsafe_werkzeug=True)