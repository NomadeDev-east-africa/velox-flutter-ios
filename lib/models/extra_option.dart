class ExtraOption {
  final String name;
  final int price;
  bool isSelected;

  ExtraOption({
    required this.name,
    required this.price,
    this.isSelected = false,
  });

  // Copier avec modifications
  ExtraOption copyWith({
    String? name,
    int? price,
    bool? isSelected,
  }) {
    return ExtraOption(
      name: name ?? this.name,
      price: price ?? this.price,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  // Convertir en Map pour Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'isSelected': isSelected,
    };
  }

  // Créer depuis Map
  factory ExtraOption.fromMap(Map<String, dynamic> map) {
    return ExtraOption(
      name: map['name'] ?? '',
      price: map['price']?.toInt() ?? 0,
      isSelected: map['isSelected'] ?? false,
    );
  }

  // Pour debug
  @override
  String toString() =>
      'ExtraOption(name: $name, price: $price, isSelected: $isSelected)';
}
