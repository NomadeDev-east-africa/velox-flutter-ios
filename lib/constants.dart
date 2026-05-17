import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';

// ==================== COULEURS DJIBOUTIENNES 🇩🇯 ====================
// Couleurs principales de l'application
const Color primaryColor = Color(0xFF12AD2B); // Vert Djibouti (Restaurant)
const Color secondaryColor = Color(0xFF6AB2E7); // Bleu ciel Djibouti (Taxi)
const Color accentColor = Color(0xFFD7141A); // Rouge Djibouti (Étoile)

// Couleurs du drapeau 🇩🇯 (versions plus intenses)
const Color drapeauVert = Color(0xFF12AD2B);  // Vert vif
const Color drapeauBleu = Color(0xFF0D5EAF); // Bleu profond
const Color drapeauRouge = Color(0xFFDA121A); // Rouge vif

// ==================== COULEURS UI ====================
const Color titleColor = Color(0xFF212529);
const Color bodyTextColor = Color(0xFF6C757D);
const Color inputColor = Color(0xFFF8F9FA);
const Color blanc = Color(0xFFFFFFFF);
const Color grisFond = Color(0xFFF8F9FA);
const Color textePrincipal = Color(0xFF212121);
const Color texteSecondaire = Color(0xFF757575);

// ==================== COULEURS SUPPLÉMENTAIRES ====================
const Color vertPrincipal = Color(0xFF2E7D32); // Vert foncé (pour les cartes)
const Color vertClair = Color(0xFF6B8E23);
const Color bleuPrincipal = Color(0xFF1565C0); // Bleu foncé
const Color bleuCiel = Color(0xFF4FC3F7); // Bleu clair

// ==================== DIMENSIONS ====================
const double defaultPadding = 16;
const double defaultRadius = 12;
const double largeRadius = 24;
const double smallPadding = 8;

// ==================== DURÉES ====================
const Duration kDefaultDuration = Duration(milliseconds: 250);

// ==================== TEXT STYLES ====================
const TextStyle kButtonTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 14,
  fontWeight: FontWeight.bold,
);

const EdgeInsets kTextFieldPadding = EdgeInsets.symmetric(
  horizontal: defaultPadding,
  vertical: defaultPadding,
);

// ==================== INPUT DECORATIONS ====================
const OutlineInputBorder kDefaultOutlineInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(6)),
  borderSide: BorderSide(
    color: Color(0xFFF3F2F2),
  ),
);

const InputDecoration otpInputDecoration = InputDecoration(
  contentPadding: EdgeInsets.zero,
  counterText: "",
  errorStyle: TextStyle(height: 0),
);

const kErrorBorderSide = BorderSide(color: Colors.red, width: 1);

// ==================== VALIDATEURS ====================
final passwordValidator = MultiValidator([
  RequiredValidator(errorText: 'Password is required'),
  MinLengthValidator(8, errorText: 'Password must be at least 8 digits long'),
  PatternValidator(r'(?=.*?[#?!@$%^&*-/])',
      errorText: 'Passwords must have at least one special character')
]);

final emailValidator = MultiValidator([
  RequiredValidator(errorText: 'Email is required'),
  EmailValidator(errorText: 'Enter a valid email address')
]);

final requiredValidator =
RequiredValidator(errorText: 'This field is required');
final matchValidator = MatchValidator(errorText: 'passwords do not match');

final phoneNumberValidator = MinLengthValidator(10,
    errorText: 'Phone Number must be at least 10 digits long');

// ==================== TEXTE COMMUN ====================
class KOrText extends StatelessWidget {
  const KOrText({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "Or",
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}