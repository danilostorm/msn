import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_msn_mobile/msn_protocol.dart';

void main() {
  test('desktop RNG -> ANS -> split MSG -> unread + respond', () async {
    final notification = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final switchboard = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    const self = 'mobile@qa.invalid';
    const friend = 'desktop@qa.invalid';
    const password = 'qa-password';
    const salt = 'qa-salt';
    final sbCommands = <String>[];
    WebSocket? nsSocket;
    WebSocket? sbSocket;
    final receivedAnswer = Completer<void>();

    notification.transform(WebSocketTransformer()).listen((ws) {
      nsSocket = ws;
      ws.listen((dynamic data) {
        final cmd = utf8.decode(data as List<int>).trim();
        void send(String line) => ws.add(Uint8List.fromList(utf8.encode(line)));
        if (cmd.startsWith('VER ')) {
          send('VER 1 MSNP7\r\n');
        } else if (cmd.startsWith('INF ')) {
          send('INF 2 MD5\r\n');
        } else if (cmd.startsWith('USR 3 ')) {
          send('USR 3 MD5 S $salt\r\n');
        } else if (cmd.startsWith('USR 4 ')) {
          final expected = md5.convert(utf8.encode(salt + password));
          expect(cmd, 'USR 4 MD5 S $expected');
          send('USR 4 OK $self NLN 1\r\n');
        } else if (cmd.startsWith('SYN ')) {
          send(
            'LSG 5 9 1 2 0 Other%20Contacts 0\r\n'
            'LSG 5 9 2 2 21 Amigos 0\r\n'
            'LST 5 FL 9 1 1 $friend Desktop%20QA 21\r\n'
            'SYN 5 9\r\n'
            'ILN 5 NLN $friend Desktop%20QA 0\r\n',
          );
        } else if (cmd.startsWith('CHG ')) {
          send('CHG 6 NLN\r\n');
          Future<void>.delayed(const Duration(milliseconds: 50), () {
            send(
              'RNG 42 server:1864 CKI invitation-token $friend Desktop%20QA\r\n',
            );
          });
        } else if (cmd.startsWith('ADD ')) {
          final parts = cmd.split(' ');
          final id = parts[1];
          final list = parts[2];
          final contact = parts[3];
          if (contact == 'absent@qa.invalid') {
            send('205 $id\r\n');
          } else {
            send('ADD $id $list 10 $contact $contact\r\n');
          }
        }
      });
    });

    switchboard.transform(WebSocketTransformer()).listen((ws) {
      sbSocket = ws;
      ws.listen((dynamic data) {
        final raw = data as List<int>;
        final cmd = utf8.decode(raw).trim();
        sbCommands.add(cmd);
        if (cmd.startsWith('ANS ')) {
          expect(cmd, 'ANS 1 $self invitation-token 42');
          ws.add(Uint8List.fromList(utf8.encode('ANS 1 OK\r\n')));
          if (!receivedAnswer.isCompleted) receivedAnswer.complete();
          Future<void>.delayed(const Duration(milliseconds: 55), () {
            const body =
                'MIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\nMensagem do desktop!';
            final bytes = utf8.encode(body);
            final head = utf8.encode(
              'MSG $friend Desktop%20QA ' + bytes.length.toString() + '\r\n',
            );
            ws.add(Uint8List.fromList([...head, ...bytes.sublist(0, 11)]));
            ws.add(Uint8List.fromList(bytes.sublist(11)));
          });
        }
      });
    });

    final client = MsnClient(
      notificationUrl: 'ws://127.0.0.1:' + notification.port.toString(),
      switchboardUrl: 'ws://127.0.0.1:' + switchboard.port.toString(),
    );
    try {
      await client.signIn(self, password);
      expect(client.online, isTrue, reason: client.error);
      expect(client.groups['21'], 'Amigos');
      expect(client.buddies[friend]!.groupIds, ['21']);
      await receivedAnswer.future.timeout(const Duration(seconds: 5));
      for (var i = 0; i < 50 && client.history(friend).isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(client.history(friend), hasLength(1), reason: client.error);
      expect(client.history(friend).single.text, 'Mensagem do desktop!');
      expect(client.unread[friend], 1);
      expect(client.recentIncoming, friend);
      client.markRead(friend);
      expect(client.unread.containsKey(friend), isFalse);
      expect(client.recentIncoming, isNull);
      await client.sendMessage(friend, 'Resposta mobile');
      for (
        var i = 0;
        i < 50 && !sbCommands.any((e) => e.startsWith('MSG '));
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(sbCommands.any((e) => e.startsWith('MSG ')), isTrue);

      await client.addContact('new@qa.invalid');
      expect(client.buddies.containsKey('new@qa.invalid'), isTrue);
      await expectLater(
        client.addContact('absent@qa.invalid'),
        throwsA(isA<MsnProtocolException>()),
      );
      expect(client.buddies.containsKey('absent@qa.invalid'), isFalse);
    } finally {
      await client.signOut();
      client.dispose();
      await nsSocket?.close();
      await sbSocket?.close();
      await notification.close(force: true);
      await switchboard.close(force: true);
    }
  });
}
