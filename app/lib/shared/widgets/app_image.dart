import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/colors.dart';

ImageProvider? appImageProvider(String? source) {
  if (source == null || source.trim().isEmpty) return null;
  final value = source.trim();
  if (value.startsWith('data:image/')) {
    final commaIndex = value.indexOf(',');
    if (commaIndex < 0) return null;
    try {
      return MemoryImage(base64Decode(value.substring(commaIndex + 1)));
    } catch (_) {
      return null;
    }
  }
  final resolved = ApiConstants.resolveUrl(value);
  return resolved == null ? null : NetworkImage(resolved);
}

Widget appImage(
  String source, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  int? cacheWidth,
  int? cacheHeight,
}) {
  final value = source.trim();
  if (value.startsWith('data:image/')) {
    final commaIndex = value.indexOf(',');
    Uint8List? bytes;
    if (commaIndex >= 0) {
      try {
        bytes = base64Decode(value.substring(commaIndex + 1));
      } catch (_) {
        bytes = null;
      }
    }
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.low,
      );
    }
  }

  return Image.network(
    ApiConstants.resolveUrl(value) ?? value,
    fit: fit,
    width: width,
    height: height,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
    filterQuality: FilterQuality.low,
    errorBuilder: (context, error, stackTrace) => Container(
      width: width,
      height: height,
      color: BarColors.surfaceLight,
      child: const Icon(
        Icons.broken_image_outlined,
        color: BarColors.textSecondary,
      ),
    ),
  );
}

Future<void> showImagePreview(
  BuildContext context, {
  required String source,
  String? heroTag,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.92),
    builder: (context) => Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Center(
                  child: heroTag == null
                      ? appImage(source, fit: BoxFit.contain)
                      : Hero(
                          tag: heroTag,
                          child: appImage(source, fit: BoxFit.contain),
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: IconButton.filledTonal(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    ),
  );
}
