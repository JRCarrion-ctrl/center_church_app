// File: lib/transitions/slide.dart

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

// Helper to determine the exit position for the secondary (outgoing) animation
Offset _getReverseOffset(SlideDirection direction) {
  switch (direction) {
    case SlideDirection.left:
      return const Offset(1.0, 0.0); // If forward is left (-1), reverse is right (1)
    case SlideDirection.right:
      return const Offset(-1.0, 0.0); // If forward is right (1), reverse is left (-1)
    case SlideDirection.up:
      return const Offset(0.0, 1.0);
    case SlideDirection.down:
      return const Offset(0.0, -1.0);
  }
}

CustomTransitionPage<T> buildSlidePage<T>(
  Widget child, {
  SlideDirection direction = SlideDirection.right,
  Curve curve = Curves.easeInOut,
  LocalKey? key, // <--- Add this parameter
}) {
  final reverseOffset = _getReverseOffset(direction);

  final forwardAnimation = Tween<Offset>(
    begin: _getOffset(direction),
    end: Offset.zero,
  ).chain(CurveTween(curve: curve));

  final reverseTransition = Tween<Offset>(
    begin: Offset.zero,
    end: reverseOffset,
  ).chain(CurveTween(curve: curve));

  return CustomTransitionPage<T>(
    // USE THE PASSED KEY. Fallback to child.hashCode only if null.
    key: key ?? ValueKey(child.hashCode), 
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: animation.drive(forwardAnimation),
        child: SlideTransition(
          position: secondaryAnimation.drive(reverseTransition),
          child: child,
        ),
      );
    },
  );
}