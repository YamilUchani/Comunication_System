import 'package:flutter/material.dart';

class UserSelectionDialog extends StatelessWidget {
  final Map<String, String> users;

  const UserSelectionDialog({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: const Text('Enviar a'),
            automaticallyImplyLeading: false,
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Todos los usuarios'),
            onTap: () => Navigator.pop(context, {'id': null, 'name': 'Todos'}),
          ),
          const Divider(),
          ...users.entries.map(
            (user) => ListTile(
              leading: CircleAvatar(child: Text(user.value[0].toUpperCase())),
              title: Text(user.value),
              onTap: () =>
                  Navigator.pop(context, {'id': user.key, 'name': user.value}),
            ),
          ),
        ],
      ),
    );
  }
}
