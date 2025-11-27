import 'package:flutter/material.dart';

class ConfirmEmailScreen extends StatelessWidget {
  const ConfirmEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirma tu Email')),
      body: const Center(
        child: Text('Por favor, verifica tu email para completar el registro.'),
      ),
    );
  }
}