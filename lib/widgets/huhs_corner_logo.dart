import 'package:flutter/material.dart';

class HuhsCornerLogo extends StatelessWidget {
  const HuhsCornerLogo({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/logos/huhs_corner_logo.png',
      width: 34,
      height: 48,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    ),
  );
}
