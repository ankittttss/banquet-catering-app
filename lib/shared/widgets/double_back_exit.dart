import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a root screen so the Android hardware back button never closes the
/// app abruptly. When there is somewhere to go back to, back behaves normally.
/// When we're at the root (nothing to pop), the first back press shows a
/// "press back again to exit" hint and only a second quick press exits.
class DoubleBackToExit extends StatefulWidget {
  const DoubleBackToExit({super.key, required this.child});
  final Widget child;

  @override
  State<DoubleBackToExit> createState() => _DoubleBackToExitState();
}

class _DoubleBackToExitState extends State<DoubleBackToExit> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    // If this screen was pushed on top of something (e.g. the planning flow),
    // let back pop normally. Only guard when we're truly at the root.
    final canPop = Navigator.of(context).canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        final last = _lastBackPress;
        if (last == null || now.difference(last) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: widget.child,
    );
  }
}
