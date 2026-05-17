import 'package:flutter/material.dart';

class SmallDot extends StatelessWidget {
  const SmallDot({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      width: 4,
      decoration: BoxDecoration(
        color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black54).withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
    );
  }
}
