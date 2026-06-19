// Modèle générique d'options de plat, piloté par les données Firestore.
//
// L'app Admin écrit sur chaque `menuItems/{id}` un champ `optionGroups`
// (Array<Map>) décrivant les vraies options du plat (Taille, Formule,
// Suppléments, Sauces…). Les noms de groupes sont LIBRES : le client doit
// rester 100% data-driven et ne jamais présumer du nom.
//
// Schéma d'un groupe :
// {
//   "name": "Taille",
//   "type": "single" | "multiple",
//   "required": true | false,
//   "choices": [ { "name": "L", "price": 600 } ]   // price = supplément FDJ
// }

enum OptionType { single, multiple }

/// Un choix dans un groupe. `price` = supplément (FDJ) ajouté au prix de base.
class OptionChoice {
  final String name;
  final int price;

  const OptionChoice({required this.name, this.price = 0});

  factory OptionChoice.fromMap(Map<String, dynamic> map) {
    return OptionChoice(
      name: (map['name'] ?? '').toString(),
      price: (map['price'] as num?)?.round() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
      };
}

/// Un groupe d'options (radios si `single`, checkboxes si `multiple`).
class OptionGroup {
  final String name;
  final OptionType type;
  final bool required;
  final List<OptionChoice> choices;

  const OptionGroup({
    required this.name,
    this.type = OptionType.multiple,
    this.required = false,
    this.choices = const [],
  });

  bool get isSingle => type == OptionType.single;

  factory OptionGroup.fromMap(Map<String, dynamic> map) {
    final rawType = (map['type'] ?? 'multiple').toString().toLowerCase();
    final rawChoices = map['choices'];
    return OptionGroup(
      name: (map['name'] ?? '').toString(),
      type: rawType == 'single' ? OptionType.single : OptionType.multiple,
      required: map['required'] == true,
      choices: rawChoices is List
          ? rawChoices
              .whereType<Map>()
              .map((c) => OptionChoice.fromMap(Map<String, dynamic>.from(c)))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': isSingle ? 'single' : 'multiple',
        'required': required,
        'choices': choices.map((c) => c.toMap()).toList(),
      };

  /// Parser tolérant : accepte `null`, une liste vide ou une liste de Maps.
  /// Retourne `[]` si le champ est absent (plats créés par l'ancienne app resto).
  static List<OptionGroup> listFromRaw(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((g) => OptionGroup.fromMap(Map<String, dynamic>.from(g)))
        .toList();
  }
}