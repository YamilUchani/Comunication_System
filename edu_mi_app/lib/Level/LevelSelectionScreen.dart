import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  int _totalLevels = 0;
  int _activeLevel = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('total_levels, active_level')
          .eq('user_id', user.id)
          .maybeSingle();

      setState(() {
        _totalLevels = profile?['total_levels'] ?? 20;
        _activeLevel = profile?['active_level'] ?? 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando niveles: $e')),
        );
      }
    }
  }

  void _selectLevel(int level) async {
    if (level > _activeLevel) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nivel $level seleccionado')),
    );

    // Ejemplo: actualizar active_level si el usuario completa un nivel
    // await Supabase.instance.client.from('profiles')
    //     .update({'active_level': level})
    //     .eq('user_id', Supabase.instance.client.auth.currentUser!.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar Nivel')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Nivel activo: $_activeLevel',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: _totalLevels,
                      itemBuilder: (context, index) {
                        final level = index + 1;
                        final isActive = level <= _activeLevel;

                        return GestureDetector(
                          onTap: () => _selectLevel(level),
                          child: Card(
                            color: isActive ? Colors.blueAccent : Colors.grey.shade300,
                            child: Center(
                              child: Text(
                                '$level',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.white : Colors.black45,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
