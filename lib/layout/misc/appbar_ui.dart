import 'package:flutter/material.dart';
import 'package:memory_access_simulator/core/controller/runtime.dart';
import 'package:memory_access_simulator/layout/misc/access_sequence_modifier_dialog.dart';
import 'package:memory_access_simulator/layout/misc/configuration_dialog.dart';
import 'package:memory_access_simulator/layout/pages/page_mode.dart';
import 'package:memory_access_simulator/main.dart';

class AppbarUI extends StatelessWidget implements PreferredSizeWidget {
  const AppbarUI({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final screenSize = MediaQuery.sizeOf(context);

    void showConfiguration() {
      showDialog(
        context: context,
        builder: (_) => Transform.scale(
          scale: screenSize.height / 720,
          child: const ConfigurationDialog(),
        ),
      );
    }

    void showAccessSequence() {
      showDialog(
        context: context,
        builder: (_) => Transform.scale(
          scale: screenSize.height / 720,
          child: const AccessSequenceModifierDialog(),
        ),
      );
    }

    return AppBar(
      toolbarHeight: 68,
      automaticallyImplyLeading: false,
      scrolledUnderElevation: 0,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [colors.primary, colors.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.account_tree_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Memory Access Simulator',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  'Configurable Cache & Virtual Memory Parameters',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto-Mono',
                    fontSize: 9,
                    letterSpacing: 0.4,
                    color: colors.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _toolbarButton(
          context,
          icon: Icons.tune_rounded,
          label: 'CONFIGURE',
          tooltip: 'Change cache, page, TLB, and memory parameters.',
          onPressed: showConfiguration,
        ),
        /* 
        _toolbarButton(
          context,
          icon: Icons.format_list_numbered_rounded,
          label: 'Sequence',
          tooltip: 'Edit the ordered list of memory accesses to execute.',
          onPressed: showAccessSequence,
        ),
 */
        _toolbarDivider(context),

        _toolbarButton(
          context,
          icon: Icons.skip_next_rounded,
          label: 'STEP',
          tooltip: 'Advance the simulation by one micro-step.',
          onPressed: () => Runtime.singleton.microRun(),
        ),
        _toolbarButton(
          context,
          icon: Icons.fast_forward_rounded,
          label: 'ACCESS',
          tooltip: 'Execute the next complete memory access.',
          onPressed: () => Runtime.singleton.runAccess(),
        ),

        _toolbarDivider(context),

        _toolbarButton(
          context,
          icon: Icons.restart_alt_rounded,
          label: 'RESET',
          tooltip: 'Reset the simulation state and its statistics.',
          onPressed: () => Runtime.singleton.reset(),
        ),

        /* 
        _toolbarButton(
          context,
          icon: Icons.download_rounded,
          label: 'Export',
          tooltip:
              'Export simulation results. This feature is not implemented yet.',
          onPressed: () {
            // TODO: Add export / download functionality.
          },
        ), */
        _toolbarDivider(context),

        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (context, mode, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toolbarButton(
                  context,
                  icon: Icons.light_mode_rounded,
                  tooltip: 'Switch the application to its light theme.',
                  selected: mode == ThemeMode.light,
                  onPressed: () {
                    themeModeNotifier.value = ThemeMode.light;
                  },
                ),
                _toolbarButton(
                  context,
                  icon: Icons.dark_mode_rounded,
                  tooltip: 'Switch the application to its dark theme.',
                  selected: mode == ThemeMode.dark,
                  onPressed: () {
                    themeModeNotifier.value = ThemeMode.dark;
                  },
                ),
              ],
            );
          },
        ),

        const SizedBox(width: 8),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.65),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbarButton(
    BuildContext context, {
    required IconData icon,
    String label = '',
    required String tooltip,
    required VoidCallback onPressed,
    bool highlighted = false,
    bool selected = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final active = highlighted || selected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: active
              ? colors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: active
                      ? colors.primary.withValues(alpha: 0.45)
                      : colors.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: active ? colors.primary : colors.onSurfaceVariant,
                  ),

                  if (label != '') const SizedBox(width: 5),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: active ? colors.primary : colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbarDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 18),
      child: Container(
        width: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}
