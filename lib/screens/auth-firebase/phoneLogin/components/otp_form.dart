import 'package:flutter/material.dart';
import 'package:nomade_client/services/notification_service.dart';
import 'package:nomade_client/services/auth_service.dart';
import 'package:nomade_client/screens/HomeScreen/home_screen_app.dart';
import 'package:form_field_validator/form_field_validator.dart';

import '../../../../constants.dart';
import '../../../../components/buttons/primary_button.dart';
import '../../../../translations/app_translations.dart';

class OtpForm extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpForm({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpForm> createState() => _OtpFormState();
}

class _OtpFormState extends State<OtpForm> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  // Controllers pour chaque digit
  final TextEditingController _pin1Controller = TextEditingController();
  final TextEditingController _pin2Controller = TextEditingController();
  final TextEditingController _pin3Controller = TextEditingController();
  final TextEditingController _pin4Controller = TextEditingController();
  final TextEditingController _pin5Controller = TextEditingController();
  final TextEditingController _pin6Controller = TextEditingController();

  late FocusNode _pin1Node;
  late FocusNode _pin2Node;
  late FocusNode _pin3Node;
  late FocusNode _pin4Node;
  late FocusNode _pin5Node;
  late FocusNode _pin6Node;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pin1Node = FocusNode();
    _pin2Node = FocusNode();
    _pin3Node = FocusNode();
    _pin4Node = FocusNode();
    _pin5Node = FocusNode();
    _pin6Node = FocusNode();
  }

  @override
  void dispose() {
    _pin1Controller.dispose();
    _pin2Controller.dispose();
    _pin3Controller.dispose();
    _pin4Controller.dispose();
    _pin5Controller.dispose();
    _pin6Controller.dispose();
    _pin1Node.dispose();
    _pin2Node.dispose();
    _pin3Node.dispose();
    _pin4Node.dispose();
    _pin5Node.dispose();
    _pin6Node.dispose();
    super.dispose();
  }

  String _getOTPCode() {
    return _pin1Controller.text +
        _pin2Controller.text +
        _pin3Controller.text +
        _pin4Controller.text +
        _pin5Controller.text +
        _pin6Controller.text;
  }

  Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _getOTPCode();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrez le code à 6 chiffres complet'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Vérifier le code OTP avec Firebase
      final user = await _authService.verifyOTP(
        verificationId: widget.verificationId,
        smsCode: code,
      );

      if (user != null && mounted) {
        // ✅ Rafraîchir le token FCM après connexion téléphone
        await NotificationService().refreshTokenForUser();
        if (!mounted) return;
        // SUCCÈS - Navigation vers home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreenApp(),
          ),
              (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Pin 1
              SizedBox(
                width: 48,
                height: 48,
                child: TextFormField(
                  controller: _pin1Controller,
                  onChanged: (value) {
                    if (value.length == 1) _pin2Node.requestFocus();
                  },
                  validator: RequiredValidator(errorText: '').call,
                  autofocus: true,
                  maxLength: 1,
                  focusNode: _pin1Node,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: otpInputDecoration,
                  enabled: !_isLoading,
                ),
              ),
              // Pin 2
              SizedBox(
                width: 48,
                height: 48,
                child: TextFormField(
                  controller: _pin2Controller,
                  onChanged: (value) {
                    if (value.length == 1) _pin3Node.requestFocus();
                  },
                  validator: RequiredValidator(errorText: '').call,
                  maxLength: 1,
                  focusNode: _pin2Node,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: otpInputDecoration,
                  enabled: !_isLoading,
                ),
              ),
              // Pin 3
              SizedBox(
                width: 48,
                height: 48,
                child: TextFormField(
                  controller: _pin3Controller,
                  onChanged: (value) {
                    if (value.length == 1) _pin4Node.requestFocus();
                  },
                  validator: RequiredValidator(errorText: '').call,
                  maxLength: 1,
                  focusNode: _pin3Node,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: otpInputDecoration,
                  enabled: !_isLoading,
                ),
              ),
              // Pin 4
              SizedBox(
                width: 48,
                height: 48,
                child: TextFormField(
                  controller: _pin4Controller,
                  onChanged: (value) {
                    if (value.length == 1) _pin5Node.requestFocus();
                  },
                  validator: RequiredValidator(errorText: '').call,
                  maxLength: 1,
                  focusNode: _pin4Node,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: otpInputDecoration,
                  enabled: !_isLoading,
                ),
              ),
              // Pin 5
              SizedBox(
                width: 48,
                height: 48,
                child: TextFormField(
                  controller: _pin5Controller,
                  onChanged: (value) {
                    if (value.length == 1) _pin6Node.requestFocus();
                  },
                  validator: RequiredValidator(errorText: '').call,
                  maxLength: 1,
                  focusNode: _pin5Node,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: otpInputDecoration,
                  enabled: !_isLoading,
                ),
              ),
              // Pin 6
              SizedBox(
                width: 48,
                height: 48,
                child: TextFormField(
                  controller: _pin6Controller,
                  onChanged: (value) {
                    if (value.length == 1) {
                      _pin6Node.unfocus();
                      // Auto-vérifier quand tous les digits sont entrés
                      _verifyOTP();
                    }
                  },
                  validator: RequiredValidator(errorText: '').call,
                  maxLength: 1,
                  focusNode: _pin6Node,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: otpInputDecoration,
                  enabled: !_isLoading,
                ),
              ),
            ],
          ),
          const SizedBox(height: defaultPadding * 2),

          // Info loading
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(defaultPadding),
              margin: const EdgeInsets.only(bottom: defaultPadding),
              decoration: BoxDecoration(
                color: secondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Vérification en cours...',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),

          // Continue Button
          PrimaryButton(
            text: _isLoading ? 'Vérification...' : tr('continue'),
            press: _isLoading ? () {} : _verifyOTP,
          )
        ],
      ),
    );
  }
}