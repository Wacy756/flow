import 'package:flutter/material.dart';

/// Drop-in replacement for showModalBottomSheet that shows a centered dialog
/// on desktop (width >= 700) and a bottom sheet on mobile.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool enableDrag = true,
  Color? backgroundColor,
  bool useRootNavigator = false,
  ShapeBorder? shape,
}) {
  final isDesktop = MediaQuery.of(context).size.width >= 700;

  if (!isDesktop) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor ?? Colors.transparent,
      useRootNavigator: useRootNavigator,
      shape: shape,
      builder: builder,
    );
  }

  // Desktop: centered dialog — no extra X button, each sheet owns its header
  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) {
      final size = MediaQuery.of(ctx).size;
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 680,
            maxHeight: size.height * 0.92,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: Colors.transparent,
              child: builder(ctx),
            ),
          ),
        ),
      );
    },
  );
}
