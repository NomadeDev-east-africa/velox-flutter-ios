import 'package:flutter_test/flutter_test.dart';

import 'package:nomade_client/models/extra_option.dart';
import 'package:nomade_client/models/sauce_option.dart';
import 'package:nomade_client/models/order_item.dart';
import 'package:nomade_client/models/option_group.dart';
import 'package:nomade_client/models/option_selection.dart';

/// Tests ciblés du « chemin de l'argent » :
///   - calcul du prix panier (OrderItem)
///   - parsing tolérant des options Firestore (OptionGroup)
///   - mapping options sélectionnées → extras/sauces du ticket cuisine
///
/// Aucune dépendance Flutter/Firebase : logique pure, rapide et stable.
void main() {
  // ════════════════════════════════════════════════════════════════
  // OrderItem — calculs de prix
  // ════════════════════════════════════════════════════════════════
  group('OrderItem pricing', () {
    OrderItem buildItem({
      int basePrice = 1000,
      int quantity = 1,
      List<ExtraOption>? extras,
      List<SauceOption>? sauces,
    }) {
      return OrderItem(
        menuId: 'm1',
        name: 'Tacos',
        description: '',
        imageUrl: '',
        category: 'Tacos',
        basePrice: basePrice,
        quantity: quantity,
        extras: extras,
        sauces: sauces,
      );
    }

    test('ne compte QUE les extras/sauces sélectionnés', () {
      final item = buildItem(
        extras: [
          ExtraOption(name: 'Frites', price: 500, isSelected: true),
          ExtraOption(name: 'Salade', price: 500, isSelected: false),
        ],
        sauces: [
          SauceOption(name: 'Ketchup', price: 50, isSelected: true),
          SauceOption(name: 'Mayo', price: 50, isSelected: false),
        ],
      );
      expect(item.extrasTotal, 500);
      expect(item.saucesTotal, 50);
    });

    test('unitPrice = base + extras + sauces sélectionnés', () {
      final item = buildItem(
        basePrice: 1000,
        extras: [ExtraOption(name: 'Frites', price: 500, isSelected: true)],
        sauces: [SauceOption(name: 'Ketchup', price: 50, isSelected: true)],
      );
      expect(item.unitPrice, 1550);
    });

    test('totalPrice = unitPrice × quantité', () {
      final item = buildItem(
        basePrice: 1000,
        quantity: 3,
        extras: [ExtraOption(name: 'Frites', price: 500, isSelected: true)],
      );
      expect(item.unitPrice, 1500);
      expect(item.totalPrice, 4500);
    });

    test('sans option : unitPrice == basePrice', () {
      final item = buildItem(basePrice: 800);
      expect(item.unitPrice, 800);
      expect(item.totalPrice, 800);
    });

    test('selectedExtras / selectedSauces filtrent bien', () {
      final item = buildItem(
        extras: [
          ExtraOption(name: 'A', price: 100, isSelected: true),
          ExtraOption(name: 'B', price: 100, isSelected: false),
        ],
      );
      expect(item.selectedExtras.map((e) => e.name), ['A']);
      expect(item.selectedSauces, isEmpty);
    });

    test('toMap expose les totaux calculés pour le ticket resto', () {
      final item = buildItem(
        basePrice: 1000,
        quantity: 2,
        extras: [ExtraOption(name: 'Frites', price: 500, isSelected: true)],
        sauces: [SauceOption(name: 'Ketchup', price: 50, isSelected: true)],
      );
      final map = item.toMap();
      expect(map['basePrice'], 1000);
      expect(map['quantity'], 2);
      expect(map['extrasTotal'], 500);
      expect(map['saucesTotal'], 50);
      expect(map['unitPrice'], 1550);
      expect(map['totalPrice'], 3100);
      expect((map['extras'] as List).length, 1);
      expect((map['sauces'] as List).length, 1);
    });

    test('roundtrip toMap → fromMap conserve les calculs', () {
      final original = buildItem(
        basePrice: 1200,
        quantity: 2,
        extras: [ExtraOption(name: 'Frites', price: 500, isSelected: true)],
        sauces: [SauceOption(name: 'Harissa', price: 50, isSelected: true)],
      );
      final restored = OrderItem.fromMap(original.toMap());
      expect(restored.basePrice, original.basePrice);
      expect(restored.quantity, original.quantity);
      expect(restored.unitPrice, original.unitPrice);
      expect(restored.totalPrice, original.totalPrice);
      expect(restored.selectedExtras.length, 1);
      expect(restored.selectedSauces.length, 1);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // OptionGroup — parsing tolérant des données Firestore
  // ════════════════════════════════════════════════════════════════
  group('OptionGroup.listFromRaw tolérance', () {
    test('null → liste vide (plat sans options / ancien plat resto)', () {
      expect(OptionGroup.listFromRaw(null), isEmpty);
    });

    test('String corrompue ("[[object Object]]") → liste vide, pas de crash', () {
      // Reflète le risque réel : si l'admin sérialise mal optionGroups en
      // String, le client doit tomber proprement en fallback, pas planter.
      expect(OptionGroup.listFromRaw('[[object Object]]'), isEmpty);
    });

    test('liste vide → liste vide', () {
      expect(OptionGroup.listFromRaw(<dynamic>[]), isEmpty);
    });

    test('parse un groupe single requis avec choix', () {
      final groups = OptionGroup.listFromRaw([
        {
          'name': 'Taille',
          'type': 'single',
          'required': true,
          'choices': [
            {'name': 'M', 'price': 0},
            {'name': 'L', 'price': 600},
            {'name': 'XL', 'price': 1200},
          ],
        },
      ]);
      expect(groups, hasLength(1));
      final g = groups.first;
      expect(g.name, 'Taille');
      expect(g.type, OptionType.single);
      expect(g.isSingle, isTrue);
      expect(g.required, isTrue);
      expect(g.choices, hasLength(3));
      expect(g.choices[1].name, 'L');
      expect(g.choices[1].price, 600);
    });

    test('type absent → multiple par défaut', () {
      final groups = OptionGroup.listFromRaw([
        {
          'name': 'Suppléments',
          'choices': [
            {'name': 'Emmental', 'price': 100},
          ],
        },
      ]);
      expect(groups.first.type, OptionType.multiple);
      expect(groups.first.required, isFalse); // required absent → false
    });

    test('price double → arrondi en int', () {
      final groups = OptionGroup.listFromRaw([
        {
          'name': 'X',
          'choices': [
            {'name': 'a', 'price': 99.6},
          ],
        },
      ]);
      expect(groups.first.choices.first.price, 100);
    });

    test('choix sans price → 0', () {
      final groups = OptionGroup.listFromRaw([
        {
          'name': 'X',
          'choices': [
            {'name': 'inclus'},
          ],
        },
      ]);
      expect(groups.first.choices.first.price, 0);
    });

    test('choices absent → groupe sans choix (pas de crash)', () {
      final groups = OptionGroup.listFromRaw([
        {'name': 'Vide', 'type': 'single'},
      ]);
      expect(groups, hasLength(1));
      expect(groups.first.choices, isEmpty);
    });

    test('entrées non-Map ignorées', () {
      final groups = OptionGroup.listFromRaw([
        'garbage',
        42,
        {
          'name': 'OK',
          'choices': [
            {'name': 'a', 'price': 10},
          ],
        },
      ]);
      expect(groups, hasLength(1));
      expect(groups.first.name, 'OK');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // OptionSelection — surcharge + mapping vers extras/sauces
  // ════════════════════════════════════════════════════════════════
  group('OptionSelection', () {
    final groups = [
      const OptionGroup(
        name: 'Taille',
        type: OptionType.single,
        required: true,
        choices: [
          OptionChoice(name: 'M', price: 0),
          OptionChoice(name: 'L', price: 600),
        ],
      ),
      const OptionGroup(
        name: 'Suppléments',
        type: OptionType.multiple,
        choices: [
          OptionChoice(name: 'Emmental', price: 100),
          OptionChoice(name: 'Cheddar', price: 100),
        ],
      ),
      const OptionGroup(
        name: 'Choix des Sauces',
        type: OptionType.multiple,
        choices: [
          OptionChoice(name: 'Samouraï', price: 50),
          OptionChoice(name: 'Ketchup', price: 50),
        ],
      ),
    ];

    test('isSauceGroup insensible à la casse et aux accents', () {
      expect(OptionSelection.isSauceGroup('Sauces'), isTrue);
      expect(OptionSelection.isSauceGroup('CHOIX DES SAUCES'), isTrue);
      expect(OptionSelection.isSauceGroup('Sauce maison'), isTrue);
      expect(OptionSelection.isSauceGroup('Taille'), isFalse);
      expect(OptionSelection.isSauceGroup('Suppléments'), isFalse);
    });

    test('normalize retire les accents', () {
      expect(OptionSelection.normalize('Samouraï'), 'samourai');
      expect(OptionSelection.normalize('Suppléments'), 'supplements');
    });

    test('surcharge somme les choix sélectionnés', () {
      // Taille=L (600) + Emmental (100) + Ketchup (50) = 750
      final selections = [
        {1}, // L
        {0}, // Emmental
        {1}, // Ketchup
      ];
      expect(OptionSelection.surcharge(groups, selections), 750);
    });

    test('surcharge ignore les index hors borne', () {
      final selections = [
        {5}, // hors borne
        <int>{},
        <int>{},
      ];
      expect(OptionSelection.surcharge(groups, selections), 0);
    });

    test('toCart range les sauces dans sauces et le reste dans extras', () {
      final selections = [
        {1}, // Taille L → extras
        {0}, // Emmental → extras
        {0, 1}, // Samouraï + Ketchup → sauces
      ];
      final mapping = OptionSelection.toCart(groups, selections);

      expect(mapping.extras.map((e) => e.name), containsAll(['L', 'Emmental']));
      expect(mapping.extras, hasLength(2));
      expect(mapping.sauces.map((s) => s.name), containsAll(['Samouraï', 'Ketchup']));
      expect(mapping.sauces, hasLength(2));
    });

    test('toCart conserve les prix et marque isSelected', () {
      final selections = [
        {1}, // L (600)
        <int>{},
        {0}, // Samouraï (50)
      ];
      final mapping = OptionSelection.toCart(groups, selections);

      final l = mapping.extras.singleWhere((e) => e.name == 'L');
      expect(l.price, 600);
      expect(l.isSelected, isTrue);

      final sauce = mapping.sauces.single;
      expect(sauce.name, 'Samouraï');
      expect(sauce.price, 50);
      expect(sauce.isSelected, isTrue);
    });

    test('toCart cohérent avec surcharge → unitPrice OrderItem', () {
      // Vérifie que le total affiché (surcharge) == total recalculé par
      // OrderItem une fois les options reversées en extras/sauces.
      const base = 1000;
      final selections = [
        {1}, // L (600)
        {0, 1}, // Emmental + Cheddar (200)
        {0}, // Samouraï (50)
      ];
      final surcharge = OptionSelection.surcharge(groups, selections);
      final mapping = OptionSelection.toCart(groups, selections);

      final item = OrderItem(
        menuId: 'm',
        name: 'x',
        description: '',
        imageUrl: '',
        category: 'c',
        basePrice: base,
        quantity: 1,
        extras: mapping.extras,
        sauces: mapping.sauces,
      );
      expect(surcharge, 850);
      expect(item.unitPrice, base + surcharge);
    });

    test('toCart ignore les index hors borne', () {
      final selections = [
        {9}, // hors borne
        <int>{},
        <int>{},
      ];
      final mapping = OptionSelection.toCart(groups, selections);
      expect(mapping.extras, isEmpty);
      expect(mapping.sauces, isEmpty);
    });
  });
}
