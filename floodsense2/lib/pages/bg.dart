import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AnimatedBackgroundWrapper extends StatelessWidget {
  final Widget child;
  const AnimatedBackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Lottie.asset(
                'assets/animated_bg.json',
                fit: BoxFit.cover,
                repeat: true,
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}
