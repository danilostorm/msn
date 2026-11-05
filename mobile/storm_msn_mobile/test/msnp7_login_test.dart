import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_msn_mobile/msn_protocol.dart';

void main() {
  test('MSNP7 sign-in synchronizes contacts and accurate presence', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = Completer<WebSocket>();
    final sentCommands = <String>[];
    const identity = 'mobile-test@local.invalid';
    const password = 'test-only-password';
    const salt = 'testSalt2026';

    server.transform(WebSocketTransformer()).listen((peer) {
      accepted.complete(peer);
      peer.listen((dynamic data) {
        final line = utf8.decode(data as List<int>).trim();
        sentCommands.add(line);
        void reply(String text) =>
            peer.add(Uint8List.fromList(utf8.encode(text)));
        if (line.startsWith('VER ')) {
          reply('VER 1 MSNP7\r\n');
        } else if (line.startsWith('INF ')) {
          reply('INF 2 MD5\r\n');
        } else if (line.startsWith('USR 3 ')) {
          reply('USR 3 MD5 S $salt\r\n');
        } else if (line.startsWith('USR 4 ')) {
          final expected = md5.convert(utf8.encode(salt + password)).toString();
          expect(line, 'USR 4 MD5 S $expected');
          reply('USR 4 OK $identity NLN 1\r\n');
        } else if (line.startsWith('SYN ')) {
          reply(
            'LST 5 FL 7 1 1 amiga@local.invalid Amiga%20Do%20MSN 0\r\n'
            'LST 5 AL 7 1 1 allow@local.invalid Do%20Not%20Show 0\r\n'
            'SYN 5 7\r\n'
            'ILN 5 NLN amiga@local.invalid Amiga%20Do%20MSN 0\r\n',
          );
        } else if (line.startsWith('CHG ')) {
          reply('CHG 6 NLN\r\n');
        }
      });
    });

    final client = MsnClient(
      notificationUrl: 'ws://127.0.0.1:' + server.port.toString(),
    );
    try {
      await client.signIn(identity, password);
      expect(client.online, isTrue, reason: client.error);
      expect(client.error, isNull);
      expect(client.buddies, contains('amiga@local.invalid'));
      expect(client.buddies['amiga@local.invalid']!.title, 'Amiga Do MSN');
      expect(client.buddies['amiga@local.invalid']!.online, isTrue);
      expect(client.buddies, isNot(contains('allow@local.invalid')));
      expect(sentCommands, contains('SYN 5 0'));
      await client.signOut();
    } finally {
      client.dispose();
      if (accepted.isCompleted) await (await accepted.future).close();
      await server.close(force: true);
    }
  });
}
