import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:storm_msn_mobile/msn_protocol.dart';

void main() {
  test('MSNP wire parses split payload and handshake frames', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final connection = Completer<WebSocket>();
    server.transform(WebSocketTransformer()).listen((ws) {
      if (!connection.isCompleted) connection.complete(ws);
    });

    final clientSocket = await WebSocket.connect(
      'ws://127.0.0.1:' + server.port.toString(),
    );
    final peer = await connection.future.timeout(const Duration(seconds: 5));
    final frames = <MsnFrame>[];
    final wire = MsnWire(clientSocket, frames.add);
    final handshake = wire.request('VER 1 MSNP7 CVR0', 'VER');
    peer.add(Uint8List.fromList(utf8.encode('VER 1 MSNP7\r\n')));
    final response = await handshake;
    expect(response.words, ['VER', '1', 'MSNP7']);
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(frames, isNotEmpty);

    const body =
        'MIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\nOlá!';
    final bytes = utf8.encode(body);
    final packet = utf8.encode(
      'MSG sender@test.invalid 123 ' + bytes.length.toString() + '\r\n',
    );
    peer.add(Uint8List.fromList(<int>[...packet, ...bytes.sublist(0, 12)]));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(frames.where((x) => x.cmd == 'MSG'), isEmpty);
    peer.add(Uint8List.fromList(bytes.sublist(12)));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final msg = frames.last;
    expect(msg.cmd, 'MSG');
    expect(utf8.decode(msg.payload), body);

    await wire.close();
    await peer.close();
    await server.close(force: true);
  });
}
