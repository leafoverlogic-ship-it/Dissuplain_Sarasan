import 'package:flutter/material.dart';

class CommonFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BottomAppBar(
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text(
              '© 2025 Dissuplain',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.brightness_6_outlined,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              theme.brightness == Brightness.dark ? 'Dark mode active' : 'Light mode active',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}