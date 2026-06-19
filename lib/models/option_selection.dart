import 'extra_option.dart';
import 'sauce_option.dart';
import 'option_group.dart';

/// Résultat du mapping des options sélectionnées vers le format panier
/// (`extras`/`sauces`) lisible par l'app restaurant Kotlin.
class OptionCartMapping {
  final List<ExtraOption> extras;
  final List<SauceOption> sauces;

  const OptionCartMapping({required this.extras, required this.sauces});
}

/// Outils PURS (sans UI ni état Flutter) pour le rendu data-driven des options.
///
/// Extraits de `add_to_order_screen.dart` pour être testables unitairement :
/// c'est le « chemin de l'argent » (prix facturé + options envoyées au ticket
/// cuisine), donc la logique doit être vérifiée hors widget.
///
/// Convention partagée avec l'écran : `selections[i]` est l'ensemble des index
/// de choix sélectionnés pour `groups[i]` (0 ou 1 pour un groupe `single`,
/// 0..N pour un `multiple`).
class OptionSelection {
  /// Minuscule + suppression des accents pour une comparaison robuste.
  static String normalize(String input) {
    const accents = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
    const plain   = 'aaaaaaceeeeiiiinooooouuuuyy';
    final lower = input.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      final idx = accents.indexOf(ch);
      buffer.write(idx >= 0 ? plain[idx] : ch);
    }
    return buffer.toString();
  }

  /// `true` si le nom du groupe contient « sauce » (insensible casse/accents)
  /// → ses choix sont reversés dans `sauces` plutôt que `extras`.
  static bool isSauceGroup(String groupName) =>
      normalize(groupName).contains('sauce');

  /// Somme des suppléments (FDJ) des choix sélectionnés. Ignore les index
  /// hors borne (robustesse face à des sélections incohérentes).
  static int surcharge(
      List<OptionGroup> groups, List<Set<int>> selections) {
    int sum = 0;
    for (var gi = 0; gi < groups.length && gi < selections.length; gi++) {
      final choices = groups[gi].choices;
      for (final ci in selections[gi]) {
        if (ci >= 0 && ci < choices.length) sum += choices[ci].price;
      }
    }
    return sum;
  }

  /// Convertit les choix sélectionnés en `extras`/`sauces`.
  /// Tout va dans `extras`, SAUF les groupes « sauce » → `sauces`.
  /// Index hors borne ignorés.
  static OptionCartMapping toCart(
      List<OptionGroup> groups, List<Set<int>> selections) {
    final extras = <ExtraOption>[];
    final sauces = <SauceOption>[];
    for (var gi = 0; gi < groups.length && gi < selections.length; gi++) {
      final group = groups[gi];
      final sauce = isSauceGroup(group.name);
      for (final ci in selections[gi]) {
        if (ci < 0 || ci >= group.choices.length) continue;
        final choice = group.choices[ci];
        if (sauce) {
          sauces.add(SauceOption(
              name: choice.name, price: choice.price, isSelected: true));
        } else {
          extras.add(ExtraOption(
              name: choice.name, price: choice.price, isSelected: true));
        }
      }
    }
    return OptionCartMapping(extras: extras, sauces: sauces);
  }
}
