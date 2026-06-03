import 'package:flutter/material.dart';

import 'components/body.dart';

class FeaturedScreen extends StatelessWidget {
  const FeaturedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("By Categories"),
      ),
      body: const Body(),
    );
  }
}
