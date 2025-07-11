import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum SlideDirection {
  left,
  right,
  up,
  down,
}

Offset _getOffset(SlideDirection direction) {
  switch (direction) {
    case SlideDirection.left:
      return const Offset(-1.0, 0.0);
    case SlideDirection.right:
      return const Offset(1.0, 0.0);
    case SlideDirection.up:
      return const Offset(0.0, -1.0);
    case SlideDirection.down:
      return const Offset(0.0, 1.0);
  }
}

CustomTransitionPage<T> buildSlidePage<T>(
  Widget child, {
  SlideDirection direction = SlideDirection.right,
  Curve curve = Curves.easeInOut,
}) {
  final offsetAnimation = Tween<Offset>(
    begin: _getOffset(direction),
    end: Offset.zero,
  ).chain(CurveTween(curve: curve));

  return CustomTransitionPage<T>(
    key: ValueKey(child.runtimeType), // helpful for route diffing
    child: child,
    transitionsBuilder: (context, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: animation.drive(offsetAnimation),
          child: child,
        ),
      );
    },
  );
}

