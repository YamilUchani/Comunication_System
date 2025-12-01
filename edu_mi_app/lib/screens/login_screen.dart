import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showResendButton = false;
  bool _isWaitingForOAuth = false;

  Future<void> _signIn() async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('is_verified')
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
          .single();
      if (profile['is_verified'] == false) {
        await Supabase.instance.client
            .from('profiles')
            .update({'is_verified': true})
            .eq('user_id', Supabase.instance.client.auth.currentUser!.id);
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on AuthException catch (e) {
      if (e.message.contains('Email not confirmed') && mounted) {
        setState(() => _showResendButton = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, verifica tu email primero.'),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
      }
    }
  }

  Future<void> _resendVerification() async {
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: _emailController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Correo de verificación reenviado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al reenviar: $e')));
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isWaitingForOAuth) return;
    setState(() => _isWaitingForOAuth = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'https://stemforall-f57ac.web.app',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Redirigiendo a Google para autenticación...'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isWaitingForOAuth = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signIn,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Iniciar sesión'),
              ),
              if (_showResendButton) ...[
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _resendVerification,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Reenviar correo de verificación'),
                ),
              ],
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Supabase.instance.client.auth
                    .resetPasswordForEmail(_emailController.text)
                    .then((_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enlace de recuperación enviado.'),
                          ),
                        );
                      }
                    })
                    .catchError((e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }),
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text('Registrarse'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Continuar con Google'),
                onPressed: _isWaitingForOAuth ? null : _signInWithGoogle,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              if (_isWaitingForOAuth) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
                const SizedBox(height: 10),
                const Text('Esperando respuesta de Google...'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
