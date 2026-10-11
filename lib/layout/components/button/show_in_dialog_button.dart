import 'package:flutter/material.dart';

class ShowInDialogButton extends StatelessWidget {
  const ShowInDialogButton({
    super.key,
    required this.child,
    this.dialogWidth = 700,
    this.dialogHeight = 500,
    this.icon = Icons.remove_red_eye_outlined,
  });

  final Widget child;
  final double dialogWidth;
  final double dialogHeight;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return IconButton(
      icon: Icon(icon, size: 25),
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return Transform.scale(
              scale: (screenSize.height / 720),
              child: Dialog(child: child),
            );
          },
        );
      },
    );
  }
}
