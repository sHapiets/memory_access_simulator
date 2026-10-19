import 'package:flutter/material.dart';

class TapToShowInDialog extends StatefulWidget {
  const TapToShowInDialog({
    super.key,
    required this.child,
    this.dialog,
    this.dialogWidth = 700,
    this.dialogHeight = 500,
    this.scaleToScreen = true,
  });

  final Widget child;
  final Widget? dialog;
  final double dialogWidth;
  final double dialogHeight;
  final bool scaleToScreen;

  @override
  State<TapToShowInDialog> createState() => _TapToShowInDialogState();
}

class _TapToShowInDialogState extends State<TapToShowInDialog> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (dialogContext) {
              final dialog = Dialog(
                child: (widget.dialog == null) ? widget.child : widget.dialog,
              );

              if (!widget.scaleToScreen) {
                return dialog;
              }

              final scale = (screenSize.height / 720).clamp(0.5, 1.0);

              return Transform.scale(scale: scale, child: dialog);
            },
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? theme.colorScheme.primary.withValues(alpha: 0.65)
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.30 : 0.12,
                      ),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: (isDark ? Colors.white : Colors.white).withValues(
                        alpha: isDark ? 0.05 : 0.7,
                      ),
                      blurRadius: 3,
                      offset: const Offset(-2, -2),
                    ),
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
