class SauceOption {
  final String name;
  final int price;
  bool isSelected;

  SauceOption({
    required this.name,
    required this.price,
    this.isSelected = false,
  });

  // Copier avec modifications
  SauceOption copyWith({
    String? name,
    int? price,
    bool? isSelected,
  }) {
    return SauceOption(
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
  factory SauceOption.fromMap(Map<String, dynamic> map) {
    return SauceOption(
      name: map['name'] ?? '',
      price: map['price']?.toInt() ?? 0,
      isSelected: map['isSelected'] ?? false,
    );
  }

  // Pour debug
  @override
  String toString() =>
      'SauceOption(name: $name, price: $price, isSelected: $isSelected)';
}
