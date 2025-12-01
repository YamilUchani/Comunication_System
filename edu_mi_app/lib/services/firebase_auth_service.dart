import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio de autenticación con Firebase
/// Maneja Google Sign-In, email/password y sincronización con Supabase
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // Stream del estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Usuario actual
  User? get currentUser => _auth.currentUser;

  /// Login con Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Iniciar flujo de Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // Usuario canceló el login
        return null;
      }

      // Obtener credenciales de autenticación
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Crear credencial de Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Iniciar sesión en Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      // Sincronizar con Supabase (backup, el Cloud Function trigger ya lo hace)
      await _syncWithSupabase(userCredential.user!);

      return userCredential;
    } catch (e) {
      print('Error en Google Sign-In: $e');
      rethrow;
    }
  }

  /// Login con email y contraseña
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Registro con email y contraseña
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Actualizar nombre
    await userCredential.user?.updateDisplayName(fullName);

    // Sincronizar con Supabase
    await _syncWithSupabase(userCredential.user!);

    return userCredential;
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  /// Obtener token de Firebase (para las Cloud Functions)
  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  /// Recargar usuario (para obtener datos actualizados)
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  /// Enviar verificación de email
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Resetear contraseña
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Sincronizar usuario con Supabase
  /// Esto es un backup, el Cloud Function trigger ya lo hace automáticamente
  Future<void> _syncWithSupabase(User user) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.from('profiles').upsert({
        'user_id': user.uid,
        'email': user.email,
        'full_name': user.displayName ?? '',
        'avatar_url': user.photoURL ?? '',
        'can_create_meetings': true,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      print('Usuario sincronizado con Supabase: ${user.uid}');
    } catch (e) {
      print('Error sincronizando con Supabase: $e');
      // No lanzar error, el trigger de Firebase Cloud Function lo manejará
    }
  }
}
