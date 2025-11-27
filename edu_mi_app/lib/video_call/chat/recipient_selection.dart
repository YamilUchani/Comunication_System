class RecipientSelection {
  final String? id;
  final String name;

  RecipientSelection({this.id, required this.name});

  factory RecipientSelection.fromMap(Map<String, dynamic> map) {
    return RecipientSelection(
      id: map['id']?.toString(),
      name: map['name']?.toString() ?? 'Usuario',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }
}