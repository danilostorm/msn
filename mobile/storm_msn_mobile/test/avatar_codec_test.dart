import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_msn_mobile/storm_avatar_codec.dart';

void main() {
  testWidgets(
    'Phone avatar converts a source gallery PNG to valid bounded PNG',
    (tester) async {
      await tester.runAsync(() async {
        final picture = ui.PictureRecorder();
        final canvas = Canvas(picture);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 600, 480),
          Paint()..color = const Color(0xff2255aa),
        );
        final img = await picture.endRecording().toImage(600, 480);
        final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
        img.dispose();
        expect(pngBytes, isNotNull);
        final original = pngBytes!.buffer.asUint8List();
        final uploaded = await prepareStormAvatar(original);
        expect(uploaded, isA<Uint8List>());
        expect(uploaded.length, lessThan(4 * 1024 * 1024));
        expect(
          uploaded.sublist(0, 8),
          equals([137, 80, 78, 71, 13, 10, 26, 10]),
        );
        final decoded = await ui.instantiateImageCodec(uploaded);
        final frame = await decoded.getNextFrame();
        expect(frame.image.width, lessThanOrEqualTo(320));
        frame.image.dispose();
        decoded.dispose();

        final chat = await prepareStormChatPhoto(original);
        expect(chat.sublist(0, 8), equals([137, 80, 78, 71, 13, 10, 26, 10]));
      });
    },
  );
}
