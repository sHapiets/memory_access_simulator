import 'package:flutter/material.dart';

enum AppSnackbarType { success, error, info }

class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    AppSnackbarType type = AppSnackbarType.info,
  }) {
    final colors = Theme.of(context).colorScheme;

    final (icon, color) = switch (type) {
      AppSnackbarType.success => (Icons.check_circle_rounded, colors.primary),
      AppSnackbarType.error => (Icons.error_rounded, colors.error),
      AppSnackbarType.info => (Icons.info_rounded, colors.secondary),
    };

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: colors.surfaceContainer,
          elevation: 4,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.6)),
          ),
          content: Row(
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
