import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'age': int.parse(_ageController.text.trim()),
      }).eq('user_id', user.id);

      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Completa tu perfil")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration:
                    const InputDecoration(labelText: "Nombre completo"),
                validator: (val) =>
                    val == null || val.isEmpty ? "Ingresa tu nombre" : null,
              ),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Edad"),
                validator: (val) {
                  if (val == null || val.isEmpty) return "Ingresa tu edad";
                  final age = int.tryParse(val);
                  if (age == null || age < 3 || age > 120) {
                    return "Edad inválida";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isSaving
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text("Guardar"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
