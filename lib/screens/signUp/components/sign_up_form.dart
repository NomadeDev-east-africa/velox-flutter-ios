import 'package:flutter/material.dart';
import '../../auth-firebase/phoneLogin/phone_login_screen.dart';

import '../../../constants.dart';
import '../../../translations/app_translations.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();

  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Full Name Field
          TextFormField(
            validator: requiredValidator.call,
            onSaved: (value) {},
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: "Full Name"),
          ),
          const SizedBox(height: defaultPadding),

          // Email Field
          TextFormField(
            validator: emailValidator.call,
            onSaved: (value) {},
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: "Email Address"),
          ),
          const SizedBox(height: defaultPadding),

          // Password Field
          TextFormField(
            obscureText: _obscureText,
            validator: passwordValidator.call,
            textInputAction: TextInputAction.next,
            onChanged: (value) {},
            onSaved: (value) {},
            decoration: InputDecoration(
              hintText: tr('password'),
              suffixIcon: GestureDetector(
                onTap: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
                child: _obscureText
                    ? Icon(Icons.visibility_off, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))
                    : Icon(Icons.visibility, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
              ),
            ),
          ),
          const SizedBox(height: defaultPadding),

          // Confirm Password Field
          TextFormField(
            obscureText: _obscureText,
            decoration: InputDecoration(
              hintText: "Confirm Password",
              suffixIcon: GestureDetector(
                onTap: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
                child: _obscureText
                    ? Icon(Icons.visibility_off, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))
                    : Icon(Icons.visibility, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
              ),
            ),
          ),
          const SizedBox(height: defaultPadding),
          // Sign Up Button
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const PhoneLoginScreen(),
                ),
              );
            },
            child: Text(tr('signup')),
          ),
        ],
      ),
    );
  }
}
