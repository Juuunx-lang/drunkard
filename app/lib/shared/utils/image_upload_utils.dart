import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

const int maxUploadImageBytes = 8 * 1024 * 1024;

Future<XFile> compressUploadImage(
  XFile image, {
  int maxBytes = maxUploadImageBytes,
  int initialMaxSide = 1600,
}) async {
  final originalBytes = await image.readAsBytes();
  if (originalBytes.lengthInBytes <= maxBytes) {
    return image;
  }

  final sourceCodec = await ui.instantiateImageCodec(originalBytes);
  final sourceFrame = await sourceCodec.getNextFrame();
  final source = sourceFrame.image;
  final maxSourceSide =
      source.width > source.height ? source.width : source.height;
  var maxSide = initialMaxSide < maxSourceSide ? initialMaxSide : maxSourceSide;

  while (maxSide >= 480) {
    final scale = maxSide / maxSourceSide;
    final targetWidth = (source.width * scale).round().clamp(1, source.width);
    final targetHeight =
        (source.height * scale).round().clamp(1, source.height);
    final codec = await ui.instantiateImageCodec(
      originalBytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final frame = await codec.getNextFrame();
    final byteData =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes != null && bytes.lengthInBytes <= maxBytes) {
      return XFile.fromData(
        bytes,
        name: _compressedName(image.name),
        mimeType: 'image/png',
      );
    }
    maxSide = (maxSide * 0.78).round();
  }

  return image;
}

Future<List<XFile>> compressUploadImages(
  Iterable<XFile> images, {
  int maxBytes = maxUploadImageBytes,
  int initialMaxSide = 1600,
}) async {
  final result = <XFile>[];
  for (final image in images) {
    result.add(
      await compressUploadImage(
        image,
        maxBytes: maxBytes,
        initialMaxSide: initialMaxSide,
      ),
    );
  }
  return result;
}

String _compressedName(String originalName) {
  final dotIndex = originalName.lastIndexOf('.');
  final stem =
      dotIndex > 0 ? originalName.substring(0, dotIndex) : originalName;
  return '${stem}_compressed.png';
}
