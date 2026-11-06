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

/// WAV is the primary Android voice-note format. The recorder writes plain
/// 16-bit mono PCM without the fragile MP4/MediaCodec finalization.
bool isCompleteStormWav(Uint8List raw) {
  if (raw.length < 48 ||
      ascii.decode(raw.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
      ascii.decode(raw.sublist(8, 12), allowInvalid: true) != 'WAVE') {
    return false;
  }
  final bytes = ByteData.sublistView(raw);
  if (bytes.getUint32(4, Endian.little) + 8 != raw.length) return false;
  var pos = 12;
  var format = false;
  var samples = false;
  while (pos + 8 <= raw.length) {
    final tag = ascii.decode(raw.sublist(pos, pos + 4), allowInvalid: true);
    final length = bytes.getUint32(pos + 4, Endian.little);
    if (pos + 8 + length > raw.length) return false;
    if (tag == 'fmt ') {
      if (length < 16) return false;
      final codec = bytes.getUint16(pos + 8, Endian.little);
      final channels = bytes.getUint16(pos + 10, Endian.little);
      final rate = bytes.getUint32(pos + 12, Endian.little);
      final byteRate = bytes.getUint32(pos + 16, Endian.little);
      final alignment = bytes.getUint16(pos + 20, Endian.little);
      final bits = bytes.getUint16(pos + 22, Endian.little);
      if (codec != 1 ||
          channels != 1 ||
          bits != 16 ||
          rate < 8000 ||
          rate > 48000 ||
          alignment != 2 ||
          byteRate != rate * 2)
        return false;
      format = true;
    }
    if (tag == 'data' && length >= 3200 && length.isEven) samples = true;
    pos += 8 + length + length % 2;
  }
  return format && samples && pos == raw.length;
}

String? stormVoiceFileType(Uint8List data) {
  if (isCompleteStormWav(data)) return 'wav';
  if (isCompleteStormM4a(data)) return 'm4a';
  return null;
}
