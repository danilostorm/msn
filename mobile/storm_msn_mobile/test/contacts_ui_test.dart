import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_msn_mobile/main.dart';
import 'package:storm_msn_mobile/msn_protocol.dart';

void main() {
  testWidgets('after login WLM contacts and conversation remain usable', (
    tester,
  ) async {
    late HttpServer server;
    late MsnClient client;
    WebSocket? peer;
    await tester.runAsync(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.transform(WebSocketTransformer()).listen((conn) {
        peer = conn;
        conn.listen((raw) {
          final line = utf8.decode(raw as List<int>).trim();
          void send(String response) =>
              conn.add(Uint8List.fromList(utf8.encode(response)));
          if (line.startsWith('VER ')) {
            send('VER 1 MSNP7\r\n');
          } else if (line.startsWith('INF ')) {
            send('INF 2 MD5\r\n');
          } else if (line.startsWith('USR 3 ')) {
            send('USR 3 MD5 S testSalt\r\n');
          } else if (line.startsWith('USR 4 ')) {
            final hash = md5
                .convert(utf8.encode('testSalttestSecret'))
                .toString();
            expect(line, 'USR 4 MD5 S $hash');
            send('USR 4 OK test@local.invalid NLN 1\r\n');
          } else if (line.startsWith('SYN ')) {
            send(
              'LST 5 FL 1 1 1 amiga@local.invalid Amiga%20do%20MSN 0\r\n'
              'SYN 5 1\r\n'
              'ILN 5 NLN amiga@local.invalid Amiga%20do%20MSN\r\n',
            );
          } else if (line.startsWith('CHG ')) {
            send('CHG 6 NLN\r\n');
          } else if (line.startsWith('ADD ')) {
            final parts = line.split(' ');
            send(
              'ADD ' +
                  parts[1] +
                  ' ' +
                  parts[2] +
                  ' 2 ' +
                  parts[3] +
                  ' ' +
                  parts[3] +
                  '\r\n',
            );
          }
        });
      });
      client = MsnClient(
        notificationUrl: 'ws://127.0.0.1:' + server.port.toString(),
      );
      await client.signIn('test@local.invalid', 'testSecret');
    });
    expect(client.online, true, reason: client.error);
    await tester.pumpWidget(StormMsnApp(session: client));
    await tester.pumpAndSettle();

    expect(find.text('Amiga do MSN'), findsOneWidget);
    expect(find.text('Disponível (1)'), findsOneWidget);
    expect(find.text('Contatos'), findsOneWidget);
    await tester.tap(find.byTooltip('Adicionar contato').first);
    await tester.pumpAndSettle();
    expect(find.text('Adicionar contato'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, 'novo@local.invalid');
    await tester.tap(find.text('Cancelar').last);
    await tester.pumpAndSettle();
    expect(find.text('Adicionar contato'), findsNothing);

    await tester.tap(find.text('Amiga do MSN'));
    await tester.pumpAndSettle();
    expect(find.text('Chamar'), findsOneWidget);
    expect(find.text('Jogos'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Digite sua mensagem...',
      ),
      findsOneWidget,
    );

    // 360 dp phone viewport: the composer must align attachment, emojis,
    // microphone and send without a RenderFlex overflow.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpAndSettle();
    expect(find.byTooltip('Anexar arquivo'), findsOneWidget);
    expect(find.byTooltip('Emoticons e emojis'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.text('Disponível (1)'),
      findsOneWidget,
      reason: 'Android Voltar must return to contacts instead of logout.',
    );
    expect(client.online, isTrue);
    // Pressing Back on contacts is allowed only to minimize, never to sign out.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(client.online, isTrue);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await client.signOut();
      client.dispose();
      await peer?.close();
      await server.close(force: true);
    });
  });
}
