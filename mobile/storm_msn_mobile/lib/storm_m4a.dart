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

/// The Android recorder sometimes writes a RIFF header with a stale data size.
/// This is only for local files returned by AudioRecorder.stop(). Rebuild a
/// canonical PCM WAV from the audio bytes already present, never invent audio.
Uint8List? repairStormRecorderWav(Uint8List raw) {
  if (raw.length < 44 ||
      ascii.decode(raw.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
      ascii.decode(raw.sublist(8, 12), allowInvalid: true) != 'WAVE') {
    return null;
  }
  final bytes = ByteData.sublistView(raw);
  int? sampleRate;
  int? start;
  var at = 12;
  for (var step = 0; step < 12 && at + 8 <= raw.length; step++) {
    final marker = ascii.decode(raw.sublist(at, at + 4), allowInvalid: true);
    final size = bytes.getUint32(at + 4, Endian.little);
    final payload = at + 8;
    if (marker == 'fmt ') {
      if (size < 16 || payload + 16 > raw.length) return null;
      final codec = bytes.getUint16(payload, Endian.little);
      final channels = bytes.getUint16(payload + 2, Endian.little);
      final rate = bytes.getUint32(payload + 4, Endian.little);
      final byteRate = bytes.getUint32(payload + 8, Endian.little);
      final frame = bytes.getUint16(payload + 12, Endian.little);
      final bits = bytes.getUint16(payload + 14, Endian.little);
      if (codec != 1 ||
          channels != 1 ||
          bits != 16 ||
          frame != 2 ||
          rate < 8000 ||
          rate > 48000 ||
          byteRate != rate * 2)
        return null;
      sampleRate = rate;
    } else if (marker == 'data') {
      start = payload;
      break; // The recorded bytes, not the stale header length, are trusted.
    }
    if (size > raw.length - payload) return null;
    at = payload + size + (size & 1);
  }
  if (sampleRate == null || start == null) return null;
  var pcmLength = raw.length - start;
  if (pcmLength.isOdd) pcmLength--;
  // Enough for ~250ms at 16k; rejects empty/failed microphone capture.
  if (pcmLength < sampleRate ~/ 2 || pcmLength > 8 * 1024 * 1024 - 44) {
    return null;
  }
  final output = Uint8List(pcmLength + 44);
  final header = ByteData.sublistView(output);
  output.setRange(0, 4, ascii.encode('RIFF'));
  header.setUint32(4, output.length - 8, Endian.little);
  output.setRange(8, 12, ascii.encode('WAVE'));
  output.setRange(12, 16, ascii.encode('fmt '));
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  output.setRange(36, 40, ascii.encode('data'));
  header.setUint32(40, pcmLength, Endian.little);
  output.setRange(44, output.length, raw, start);
  return output;
}
