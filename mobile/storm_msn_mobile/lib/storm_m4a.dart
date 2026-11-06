import 'dart:convert';
import 'dart:typed_data';

/// Check that an MP4/AAC recording has all declared top-level bytes on disk.
/// The previous recorder could upload a 4 kB file with an mdat box declaring
/// 32 kB, leading to a message that existed but was impossible to play.
bool isCompleteStormM4a(Uint8List raw) {
  if (raw.length < 128 ||
      ascii.decode(raw.sublist(4, 8), allowInvalid: true) != 'ftyp') {
    return false;
  }
  final brands = raw.sublist(8, raw.length < 32 ? raw.length : 32);
  final brandText = latin1.decode(brands);
  if (!['M4A ', 'isom', 'mp42', 'M4B '].any(brandText.contains)) {
    return false;
  }

  final bytes = ByteData.sublistView(raw);
  var position = 0;
  var count = 0;
  var seenMoov = false;
  var seenMdat = false;
  while (position < raw.length && count < 256) {
    if (raw.length - position < 8) return false;
    final size32 = bytes.getUint32(position, Endian.big);
    final type = ascii.decode(
      raw.sublist(position + 4, position + 8),
      allowInvalid: true,
    );
    var headerSize = 8;
    int size;
    if (size32 == 1) {
      if (raw.length - position < 16) return false;
      size = bytes.getUint64(position + 8, Endian.big);
      headerSize = 16;
    } else if (size32 == 0) {
      size = raw.length - position;
    } else {
      size = size32;
    }
    if (size < headerSize || position + size > raw.length) return false;
    if (type == 'moov' && size > 100) seenMoov = true;
    if (type == 'mdat' && size - headerSize >= 128) seenMdat = true;
    position += size;
    count++;
  }
  return position == raw.length && seenMoov && seenMdat;
}
