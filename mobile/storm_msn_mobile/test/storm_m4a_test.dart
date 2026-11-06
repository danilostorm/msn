import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_msn_mobile/storm_m4a.dart';
import 'package:storm_msn_mobile/mobile_account.dart';

Uint8List box(String type, List<int> data, {bool extended = false}) {
  final header = extended ? 16 : 8;
  final result = Uint8List(header + data.length);
  final bytes = ByteData.sublistView(result);
  if (extended) {
    bytes.setUint32(0, 1, Endian.big);
    bytes.setUint64(8, result.length, Endian.big);
  } else {
    bytes.setUint32(0, result.length, Endian.big);
  }
  result.setRange(4, 8, ascii.encode(type));
  result.setRange(header, result.length, data);
  return result;
}

void main() {
  test('M4A validator rejects incomplete extended mdat uploads', () {
    final ftyp = box('ftyp', [
      ...ascii.encode('M4A '),
      0,
      0,
      0,
      0,
      ...ascii.encode('isom'),
      ...ascii.encode('mp42'),
    ]);
    final moov = box('moov', List<int>.filled(120, 0));
    final mdat = box('mdat', List<int>.filled(512, 1), extended: true);
    final complete = Uint8List.fromList([...ftyp, ...moov, ...mdat]);
    expect(isCompleteStormM4a(complete), isTrue);
    expect(
      isCompleteStormM4a(
        Uint8List.fromList(complete.sublist(0, complete.length - 1)),
      ),
      isFalse,
    );

    final malformed = Uint8List.fromList(complete);
    final mediaPosition = ftyp.length + moov.length;
    ByteData.sublistView(
      malformed,
    ).setUint64(mediaPosition + 8, 32000, Endian.big);
    expect(isCompleteStormM4a(malformed), isFalse);
    expect(isCompleteStormM4a(Uint8List(20)), isFalse);
  });

  test('session expiry is explicitly distinguishable from wrong passwords', () {
    expect(const StormSessionExpired().toString(), contains('Sessão'));
  });
}
