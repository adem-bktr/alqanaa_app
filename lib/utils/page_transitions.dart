import 'package:flutter/material.dart';

// ══════════════════════════════════
//    Slide Directions
// ══════════════════════════════════
enum SlideDirection {
  fromRight,
  fromLeft,
  fromBottom,
  fromTop,
}

// ══════════════════════════════════
//    ✅ SlidePageRoute مع Generic Type
// ══════════════════════════════════
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SlideDirection direction;

  SlidePageRoute({
    required this.page,
    this.direction = SlideDirection.fromRight,
  }) : super(
    pageBuilder: (_, __, ___) => page,
    transitionDuration:
    const Duration(milliseconds: 400),
    reverseTransitionDuration:
    const Duration(milliseconds: 300),
    transitionsBuilder: (_, animation, __, child) {
      Offset begin;
      switch (direction) {
        case SlideDirection.fromRight:
          begin = const Offset(1.0, 0.0);
          break;
        case SlideDirection.fromLeft:
          begin = const Offset(-1.0, 0.0);
          break;
        case SlideDirection.fromBottom:
          begin = const Offset(0.0, 1.0);
          break;
        case SlideDirection.fromTop:
          begin = const Offset(0.0, -1.0);
          break;
      }
      return SlideTransition(
        position: Tween(
          begin: begin,
          end: Offset.zero,
        )
            .chain(
          CurveTween(curve: Curves.easeOutCubic),
        )
            .animate(animation),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}

// ══════════════════════════════════
//    ✅ FadeScaleRoute مع Generic Type
// ══════════════════════════════════
class FadeScaleRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeScaleRoute({required this.page})
      : super(
    pageBuilder: (_, __, ___) => page,
    transitionDuration:
    const Duration(milliseconds: 400),
    reverseTransitionDuration:
    const Duration(milliseconds: 300),
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.92,
            end: 1.0,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
          ),
          child: child,
        ),
      );
    },
  );
}
