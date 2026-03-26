import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'channel_input_screen.dart';
import '../Level/LevelSelectionScreen.dart';
import '../services/meeting_cleanup_service.dart';
import '../services/window_service.dart';
import '../utils/dialog_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? fullName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('full_name')
        .eq('user_id', user.id)
        .maybeSingle();

    setState(() {
      fullName = profile?['full_name'];
      _isLoading = false;
    });
  }

  Future<void> _signOut() async {
    // 🔐 Pedir confirmación antes de cerrar sesión
    final confirmed = await DialogUtils.showLogoutDialog(context);
    if (!confirmed) return;

    // 🧹 Limpieza al cerrar sesión
    await MeetingCleanupService.cleanupActiveMeeting();
    await WindowService().terminateSecondaryWindows();

    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _navigateToVideoCall() {
    if (fullName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa tu perfil primero')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChannelInputScreen(userName: fullName!),
      ),
    );
  }

  void _navigateToLevels() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LevelSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Inicio"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Cerrar sesión",
            onPressed: _signOut,
          )
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.red, Colors.green],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    fullName ?? "Usuario",
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
              ),
              _decorativeTile("Configuración", Colors.blue, Icons.settings),
              _decorativeTile("Videollamada", Colors.red, Icons.videocam, onTap: _navigateToVideoCall),
              _decorativeTile("Sección de niveles", Colors.green, Icons.school, onTap: _navigateToLevels),
              _decorativeTile("Contenido adicional", Colors.orange, Icons.menu_book),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Bienvenido, ${fullName ?? 'Usuario'} 👋",
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _decorativeCard("Configuración", Colors.blue, Icons.settings),
                      _decorativeCard("Videollamada", Colors.red, Icons.videocam, onTap: _navigateToVideoCall),
                      _decorativeCard("Sección de niveles", Colors.green, Icons.school, onTap: _navigateToLevels),
                      _decorativeCard("Contenido adicional", Colors.orange, Icons.menu_book),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _decorativeTile(String title, Color color, IconData icon, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      onTap: onTap ?? () {
        Navigator.of(context).pop();
      },
    );
  }

  Widget _decorativeCard(String title, Color color, IconData icon, {VoidCallback? onTap}) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 2,
      child: Card(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
