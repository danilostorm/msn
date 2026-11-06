import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:storm_msn_mobile/storm_m4a.dart';
import 'package:storm_msn_mobile/storm_attachments.dart';

Uint8List testWav({int samples = 16000}) {
  final payloadSize = samples * 2;
  final raw = Uint8List(44 + payloadSize);
  final view = ByteData.sublistView(raw);
  raw.setRange(0, 4, ascii.encode('RIFF'));
  view.setUint32(4, raw.length - 8, Endian.little);
  raw.setRange(8, 12, ascii.encode('WAVE'));
  raw.setRange(12, 16, ascii.encode('fmt '));
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, 16000, Endian.little);
  view.setUint32(28, 32000, Endian.little);
  view.setUint16(32, 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  raw.setRange(36, 40, ascii.encode('data'));
  view.setUint32(40, payloadSize, Endian.little);
  return raw;
}

void main() {
  test('WAV PCM 16-kHz mono from Android recorder is complete', () {
    final wav = testWav();
    expect(isCompleteStormWav(wav), isTrue);
    expect(stormVoiceFileType(wav), 'wav');
    expect(
      isCompleteStormWav(Uint8List.fromList(wav.sublist(0, wav.length - 5))),
      isFalse,
    );
    final bad = Uint8List.fromList(wav);
    ByteData.sublistView(bad).setUint32(40, 9900000, Endian.little);
    expect(isCompleteStormWav(bad), isFalse);
    final stale = Uint8List.fromList(wav);
    final view = ByteData.sublistView(stale);
    view.setUint32(4, 0, Endian.little);
    view.setUint32(40, 999999, Endian.little);
    expect(isCompleteStormWav(stale), isFalse);
    final repaired = repairStormRecorderWav(stale);
    expect(repaired, isNotNull);
    expect(isCompleteStormWav(repaired!), isTrue);
    expect(repaired.length, wav.length);
  });

  test('attachment links reject domains and unknown path shapes', () {
    const key = '0123456789abcdef0123456789abcdef0123456789abcdef';
    final photo = parseStormAttachment(
      '📷 Foto: https://msn.hoststorm.com.br/api/mobile/attachment/$key',
    );
    expect(photo?.photo, isTrue);
    expect(photo?.name, 'Foto');
    final file = parseStormAttachment(
      '📎 Arquivo: manual.pdf https://msn.hoststorm.com.br/api/mobile/attachment/$key',
    );
    expect(file?.name, 'manual.pdf');
    expect(file?.photo, isFalse);
    expect(
      parseStormAttachment(
        '📷 Foto: https://evil.example/api/mobile/attachment/$key',
      ),
      isNull,
    );
  });
}
