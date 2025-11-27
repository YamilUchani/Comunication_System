import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  _VerifyEmailScreenState createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 5), () {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  Future<void> _resendVerification() async {
    setState(() => _isResending = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo de verificación reenviado.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reenviar: $e')),
      );
    } finally {
      setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifica tu Email')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Se ha enviado un email de verificación a ${widget.email}.'),
            const Text('Por favor, haz clic en el enlace para confirmar.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isResending ? null : _resendVerification,
              child: _isResending
                  ? const CircularProgressIndicator()
                  : const Text('Reenviar correo'),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const Text('Redirigiendo a login en 5 segundos...'),
          ],
        ),
      ),
    );
  }
}
