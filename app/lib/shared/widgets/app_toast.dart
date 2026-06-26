import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

void showAppToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 1000),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || message.trim().isEmpty) return;

  late final OverlayEntry entry;
  Timer? timer;

  void close() {
    timer?.cancel();
    if (entry.mounted) {
      entry.remove();
    }
  }

  entry = OverlayEntry(
    builder: (context) => _AppToastOverlay(
      message: message.trim(),
      onClose: close,
    ),
  );

  overlay.insert(entry);
  timer = Timer(duration, close);
}

class _AppToastOverlay extends StatelessWidget {
  const _AppToastOverlay({
    required this.message,
    required this.onClose,
  });

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width - 48,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
                decoration: BoxDecoration(
                  color: BarColors.surface.withOpacity(0.86),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.34),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: BarColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onClose,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          color: BarColors.textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
