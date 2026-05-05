import 'package:flutter/material.dart';

class Traductor {
  static String obtener(String llave, String lang) {
    String idioma = lang.isEmpty ? 'es' : lang;

    Map<String, Map<String, String>> dics = {
      'es': {
        'eslogan': 'Tu Jaydicars está', 'bienvenido': 'Estimado', 'saludo': '¡eres bienvenido!',
        'buscar': 'Buscar en Jaydi...', 'compra_jaydi': 'HAZ TU COMPRA CON JAYDI',
        'sesion_btn': 'INICIAR SESIÓN', 'salir': 'SALIR', 'config_cuenta': 'Configuración de cuenta',
        'editar': 'Editar mi usuario', 'idioma': 'Cambiar Idioma', 'invitado': 'Invitado',
        'tienda_todos': 'Todos', 'carrito_titulo': 'Tu Carrito', 'carrito_vacio': 'Tu carrito está vacío',
        'total': 'Total a Pagar', 'finalizar': 'FINALIZAR COMPRA', 'version': 'Versión',
        'carrito_titulo_jaydi': 'Tu Carrito Jaydi', 'carrito_vacio_jaydi': 'Tu carrito Jaydi está vacío',
        'finalizar_jaydi': 'FINALIZAR TU COMPRA JAYDI',
        // --- AUTH & PERFIL REAL ---
        'inicio': 'Iniciar Sesión', 'registro': 'Registrarse', 'usuario': 'Usuario',
        'nombre': 'Nombre', 'apellido': 'Apellido', 'telefono': 'Teléfono',
        'correo': 'Correo electrónico', 'clave': 'Clave (6 dígitos)', 'crear': 'REGISTRARME',
        'entrar': 'INGRESAR', 'invitado_btn': 'Continuar como invitado Jaydi',
        'registro_exito': '¡Registro exitoso! Ya puedes iniciar sesión',
        'no_registrado': 'No hay ningún usuario registrado todavía',
        'error_auth': 'Usuario o clave incorrectos',
        'guardar': 'GUARDAR CAMBIOS', 'perfil_editado': '¡Perfil actualizado con éxito!',
        // --- AUTOPAGO JAYDI ---
        'costo_productos': 'Costo de productos', 'iva': 'IVA (16%)',
        // --- SEGURIDAD & VALIDACIÓN ---
        'error_invitado_compra': 'Debes registrarte para agregar productos al carrito',
        'error_invitado_perfil': 'Solo los usuarios registrados pueden editar su perfil',
        'error_duplicado': 'El nombre de usuario ya existe',
      },
      'en': {
        'eslogan': 'Your Jaydicars is', 'bienvenido': 'Dear', 'saludo': 'you are welcome!',
        'buscar': 'Search in Jaydi...', 'compra_jaydi': 'MAKE YOUR PURCHASE WITH JAYDI',
        'sesion_btn': 'LOG IN', 'salir': 'LOGOUT', 'config_cuenta': 'Account Settings',
        'editar': 'Edit User', 'idioma': 'Change Language', 'invitado': 'Guest',
        'tienda_todos': 'All', 'carrito_titulo': 'Your Cart', 'carrito_vacio': 'Your cart is empty',
        'total': 'Total to Pay', 'finalizar': 'CHECKOUT', 'version': 'Version',
        'carrito_titulo_jaydi': 'Your Jaydi Cart', 'carrito_vacio_jaydi': 'Your Jaydi cart is empty',
        'finalizar_jaydi': 'FINISH YOUR JAYDI PURCHASE',
        // --- AUTH & PERFIL REAL ---
        'inicio': 'Login', 'registro': 'Sign Up', 'usuario': 'Username',
        'nombre': 'First Name', 'apellido': 'Last Name', 'telefono': 'Phone Number',
        'correo': 'Email address', 'clave': 'Password (6 digits)', 'crear': 'SIGN UP',
        'entrar': 'LOG IN', 'invitado_btn': 'Continue as Jaydi guest',
        'registro_exito': 'Registration successful! You can now log in',
        'no_registrado': 'No user registered yet',
        'error_auth': 'Invalid username or password',
        'guardar': 'SAVE CHANGES', 'perfil_editado': 'Profile updated successfully!',
        // --- AUTOPAGO JAYDI ---
        'costo_productos': 'Product Cost', 'iva': 'VAT (16%)',
        // --- SEGURIDAD & VALIDACIÓN ---
        'error_invitado_compra': 'You must register to add products to the cart',
        'error_invitado_perfil': 'Only registered users can edit their profile',
        'error_duplicado': 'Username already exists',
      },
      'fr': {
        'eslogan': 'Votre Jaydicars est', 'bienvenido': 'Cher', 'saludo': 'bienvenue !',
        'buscar': 'Chercher sur Jaydi...', 'compra_jaydi': 'FAITES VOS ACHATS AVEC JAYDI',
        'sesion_btn': 'CONNEXION', 'salir': 'SORTIR', 'config_cuenta': 'Paramètres du compte',
        'editar': 'Modifier l\'utilisateur', 'idioma': 'Changer la langue', 'invitado': 'Invité',
        'tienda_todos': 'Tous', 'carrito_titulo': 'Votre Panier', 'carrito_vacio': 'Votre panier est vide',
        'total': 'Total à payer', 'finalizar': 'PASSER LA COMMANDE', 'version': 'Version',
        'carrito_titulo_jaydi': 'Votre Panier Jaydi', 'carrito_vacio_jaydi': 'Votre panier Jaydi est vide',
        'finalizar_jaydi': 'FINALISER VOTRE ACHAT JAYDI',
        // --- AUTH & PERFIL REAL ---
        'inicio': 'Connexion', 'registro': 'S\'inscrire', 'usuario': 'Utilisateur',
        'nombre': 'Prénom', 'apellido': 'Nom', 'telefono': 'Téléphone',
        'correo': 'E-mail', 'clave': 'Mot de passe (6 chiffres)', 'crear': 'S\'INSCRIRE',
        'entrar': 'SE CONNECTER', 'invitado_btn': 'Continuer en tant qu\'invité Jaydi',
        'registro_exito': 'Inscription réussie !', 'no_registrado': 'Aucun utilisateur enregistré',
        'error_auth': 'Utilisateur ou mot de passe incorrect',
        'guardar': 'ENREGISTRER', 'perfil_editado': 'Profil mis à jour avec succès!',
        // --- AUTOPAGO JAYDI ---
        'costo_productos': 'Coût des produits', 'iva': 'TVA (16%)',
        // --- SEGURIDAD & VALIDACIÓN ---
        'error_invitado_compra': 'Vous devez vous inscrire pour ajouter des produits',
        'error_invitado_perfil': 'Seuls les utilisateurs inscrits peuvent modifier leur profil',
        'error_duplicado': 'Ce nom d\'utilisateur existe déjà',
      },
      'it': {
        'eslogan': 'Il tuo Jaydicars è', 'bienvenido': 'Caro', 'saludo': 'benvenuto!',
        'buscar': 'Cerca su Jaydi...', 'compra_jaydi': 'FAI IL TUO ACQUISTO CON JAYDI',
        'sesion_btn': 'ACCEDI', 'salir': 'ESCI', 'config_cuenta': 'Impostazioni account',
        'editar': 'Modifica utente', 'idioma': 'Cambia lingua', 'invitado': 'Ospite',
        'tienda_todos': 'Tutti', 'carrito_titulo': 'Il tuo Carrello', 'carrito_vacio': 'Il tuo carrello è vuoto',
        'total': 'Totale da pagare', 'finalizar': 'CONCLUDI ORDINE', 'version': 'Versione',
        'carrito_titulo_jaydi': 'Il tuo Carrello Jaydi', 'carrito_vacio_jaydi': 'Il tuo carrello Jaydi è vuoto',
        'finalizar_jaydi': 'CONCLUDI IL TUO ACQUISTO JAYDI',
        // --- AUTH & PERFIL REAL ---
        'inicio': 'Accedi', 'registro': 'Registrati', 'usuario': 'Nome utente',
        'nombre': 'Nome', 'apellido': 'Cognome', 'telefono': 'Telefono',
        'correo': 'E-mail', 'clave': 'Password (6 cifre)', 'crear': 'REGISTRATI',
        'entrar': 'ENTRA', 'invitado_btn': 'Continua come ospite Jaydi',
        'registro_exito': 'Registrazione completata!', 'no_registrado': 'Nessun utente registrato',
        'error_auth': 'Utente o password errati',
        'guardar': 'SALVA MODIFICHE', 'perfil_editado': 'Profilo aggiornato con successo!',
        // --- AUTOPAGO JAYDI ---
        'costo_productos': 'Costo dei prodotti', 'iva': 'IVA (16%)',
        // --- SEGURIDAD & VALIDACIÓN ---
        'error_invitado_compra': 'Devi registrarti per aggiungere prodotti al carrello',
        'error_invitado_perfil': 'Solo gli utenti registrati possono modificare il profilo',
        'error_duplicado': 'Il nome utente esiste già',
      },
      'zh': {
        'eslogan': '您的 Jaydicars 是', 'bienvenido': '亲爱的', 'saludo': '欢迎你！',
        'buscar': '在 Jaydi 搜索...', 'compra_jaydi': '在 JAYDI 购买',
        'sesion_btn': '登录', 'salir': '登出', 'config_cuenta': '账户设置',
        'editar': '编辑用户', 'idioma': '更改语言', 'invitado': '访客',
        'tienda_todos': '全部', 'carrito_titulo': '您的购物车', 'carrito_vacio': '您的购物车是空的',
        'total': '待付总额', 'finalizar': '结账', 'version': '版本',
        'carrito_titulo_jaydi': '您的 Jaydi 购物车', 'carrito_vacio_jaydi': '您的 Jaydi 购物车是空的',
        'finalizar_jaydi': '完成您的 JAYDI 购买',
        // --- AUTH & PERFIL REAL ---
        'inicio': '登录', 'registro': '注册', 'usuario': '用户名',
        'nombre': '名字', 'apellido': '姓', 'telefono': '电话号码',
        'correo': '电子邮件', 'clave': '密码 (6位)', 'crear': '注册',
        'entrar': '登录', 'invitado_btn': '以 Jaydi 访客身份继续',
        'registro_exito': '注册成功！', 'no_registrado': '尚未注册用户',
        'error_auth': '用户名或密码无效',
        'guardar': '保存更改', 'perfil_editado': '个人资料更新成功！',
        // --- AUTOPAGO JAYDI ---
        '产品成本': 'Product Cost', 'iva': '增值税 (16%)',
        // --- SEGURIDAD & VALIDACIÓN ---
        'error_invitado_compra': '您必须注册才能将产品添加到购物车',
        'error_invitado_perfil': '只有注册用户才能编辑其个人资料',
        'error_duplicado': '用户名已存在',
      },
    };

    return dics[idioma]?[llave] ?? dics['es']![llave] ?? llave;
  }
}

// Variable global para notificar cambios de idioma en toda la app
ValueNotifier<String> idiomaGlobal = ValueNotifier<String>('es');