import 'dart:typed_data';
import 'dart:ui' as ui;

/// Converts phone camera/gallery pictures to a canonical PNG regardless of
/// the original extension. The Android decoder may support HEIC/HEIF.
Future<Uint8List> prepareStormPhoto(
  Uint8List input, {
  int maxWidth = 320,
  int maxBytes = 4 * 1024 * 1024,
}) async {
  if (input.isEmpty) throw StateError('Foto vazia.');
  Object? lastError;
  for (final width in [maxWidth, maxWidth ~/ 2]) {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(
        input,
        targetWidth: width > 0 ? width : 160,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
      if (encoded == null) continue;
      final bytes = encoded.buffer.asUint8List();
      const pngMagic = [137, 80, 78, 71, 13, 10, 26, 10];
      if (bytes.length > maxBytes || bytes.length < pngMagic.length) {
        continue;
      }
      var valid = true;
      for (var i = 0; i < pngMagic.length; i++) {
        if (bytes[i] != pngMagic[i]) valid = false;
      }
      if (valid) return bytes;
    } catch (error) {
      lastError = error;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
  throw StateError(
    lastError == null
        ? 'A imagem é grande demais para o envio.'
        : 'Não foi possível converter essa foto. Experimente JPG ou PNG.',
  );
}

Future<Uint8List> prepareStormAvatar(Uint8List input) =>
    prepareStormPhoto(input, maxWidth: 320, maxBytes: 4 * 1024 * 1024);

Future<Uint8List> prepareStormChatPhoto(Uint8List input) =>
    prepareStormPhoto(input, maxWidth: 1024, maxBytes: 8 * 1024 * 1024);
