import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

const stormMsnServer = 'msn.hoststorm.com.br';

class MsnBuddy {
  MsnBuddy(this.email, {String? title, this.presence = 'FLN'})
    : title = title == null || title.isEmpty ? email : title;
  final String email;
  String title;
  String presence;
  List<String> groupIds = const [];
  bool get online => !{'FLN', 'HDN'}.contains(presence);
}

class MsnMessage {
  MsnMessage(this.sender, this.text, {this.mine = false})
    : when = DateTime.now();
  final String sender;
  final String text;
  final bool mine;
  final DateTime when;
}

class MsnClient extends ChangeNotifier {
  MsnClient({String? notificationUrl, String? switchboardUrl})
    : notificationUrl = notificationUrl ?? 'wss://$stormMsnServer/ws/1863',
      switchboardUrl = switchboardUrl ?? 'wss://$stormMsnServer/ws/1864';

  final String notificationUrl;
  final String switchboardUrl;
  String email = '';
  String status = 'NLN';
  String? error;
  bool connecting = false;
  bool online = false;
  final buddies = <String, MsnBuddy>{};
  final groups = <String, String>{};
  final messages = <String, List<MsnMessage>>{};
  final unread = <String, int>{};
  String? recentIncoming;
  void markRead(String peer) {
    unread.remove(peer.toLowerCase());
    if (recentIncoming == peer.toLowerCase()) recentIncoming = null;
    notifyListeners();
  }

  List<MsnMessage> history(String who) =>
      messages[who.toLowerCase()] ?? <MsnMessage>[];
  final _switchboards = <String, MsnWire>{};
  final _pending = <String, List<String>>{};
  final _calls = Queue<String>();
  MsnWire? _notification;
  bool _quitting = false;
  int _tx = 10;

  Future<MsnWire> _open(int port, void Function(MsnFrame) onFrame) async {
    final ws = await WebSocket.connect(
      port == 1863 ? notificationUrl : switchboardUrl,
      compression: CompressionOptions.compressionOff,
    ).timeout(const Duration(seconds: 16));
    return MsnWire(
      ws,
      onFrame,
      onClose: () {
        if (port == 1863 && online && !_quitting) {
          online = false;
          error = 'Conexão com o servidor perdida. Entre novamente.';
          notifyListeners();
        }
      },
    );
  }

  Future<void> signIn(String address, String password) async {
    if (connecting || online) return;
    email = address.trim().toLowerCase();
    error = null;
    connecting = true;
    _quitting = false;
    buddies.clear();
    groups.clear();
    unread.clear();
    recentIncoming = null;
    notifyListeners();
    try {
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ||
          password.isEmpty) {
        throw StateError(
          'Digite o e-mail completo da conta Storm MSN e a senha.',
        );
      }
      final ns = await _open(1863, _onNotification);
      _notification = ns;
      final ver = await ns.request('VER 1 MSNP7 CVR0', 'VER');
      if (ver.words.length < 3 || ver.words[2] != 'MSNP7') {
        throw StateError('Servidor não aceitou MSNP7.');
      }
      await ns.request('INF 2', 'INF');
      final challenge = await ns.request('USR 3 MD5 I ' + email, 'USR');
      if (challenge.words.length < 5) {
        throw StateError('Desafio de autenticação inválido.');
      }
      final salt = challenge.words[4];
      final proof = md5.convert(utf8.encode(salt + password)).toString();
      final auth = await ns.request('USR 4 MD5 S ' + proof, 'USR');
      if (auth.words.length < 3 || auth.words[2] != 'OK') {
        throw StateError('Usuário ou senha inválidos.');
      }
      await ns.request('SYN 5 0', 'SYN');
      await ns.request('CHG 6 ' + status, 'CHG');
      online = true;
      connecting = false;
      notifyListeners();
    } catch (e) {
      error = readableError(e);
      online = false;
      connecting = false;
      notifyListeners();
      await _notification?.close();
      _notification = null;
    }
  }

  Future<void> cancelSignIn() async {
    if (!connecting) return;
    _quitting = true;
    connecting = false;
    online = false;
    error = null;
    final notification = _notification;
    _notification = null;
    await notification?.close();
    notifyListeners();
  }

  String readableError(Object e) {
    final s = e.toString();
    if (s.contains('TimeoutException')) {
      return 'O MSN não respondeu. Verifique sua conexão.';
    }
    if (s.contains('WebSocketException') ||
        s.contains('SocketException') ||
        s.contains('HandshakeException')) {
      return 'Não foi possível conectar ao Storm MSN. Verifique a internet e tente novamente.';
    }
    if (s.contains('MsnProtocolException')) {
      return s.replaceFirst('MsnProtocolException: ', '');
    }
    return s.replaceFirst('Bad state: ', '');
  }

  void _onNotification(MsnFrame packet) {
    final w = packet.words;
    if (w.isEmpty) return;
    switch (packet.cmd) {
      // MSNP7 LSG trid serverVersion index count groupId groupName 0
      case 'LSG':
        if (w.length >= 7 && w[5] != '0') {
          groups[w[5]] = Uri.decodeComponent(w[6]);
          notifyListeners();
        }
        break;
      // MSNP7 LST: LST trid FL serverVersion index count email nickname groups
      // AL/BL/RL are permission lists, not additional contacts.
      case 'LST':
        if (w.length >= 8 && w[2] == 'FL' && w[6].contains('@')) {
          final addr = w[6].toLowerCase();
          final rawName = w[7];
          final title = rawName.contains('@') || rawName.isEmpty
              ? addr
              : Uri.decodeComponent(rawName);
          final buddy = buddies.putIfAbsent(
            addr,
            () => MsnBuddy(addr, title: title),
          );
          buddy.title = title;
          buddy.groupIds = w.length >= 9 ? w[8].split(',') : const [];
          notifyListeners();
        }
        break;
      case 'ADD':
        if (w.length > 4 && w[2] == 'FL' && w[4].contains('@')) {
          final addr = w[4].toLowerCase();
          buddies.putIfAbsent(addr, () => MsnBuddy(addr));
          notifyListeners();
        }
        break;
      // NLN status email displayName; ILN trid status email displayName.
      case 'NLN':
      case 'ILN':
        final addrIndex = packet.cmd == 'ILN' ? 3 : 2;
        final statusIndex = packet.cmd == 'ILN' ? 2 : 1;
        if (w.length > addrIndex && w[addrIndex].contains('@')) {
          final addr = w[addrIndex].toLowerCase();
          final b = buddies.putIfAbsent(addr, () => MsnBuddy(addr));
          b.presence = w[statusIndex];
          final displayIndex = addrIndex + 1;
          if (w.length > displayIndex &&
              w[displayIndex].isNotEmpty &&
              !w[displayIndex].contains('@')) {
            b.title = Uri.decodeComponent(w[displayIndex]);
          }
          notifyListeners();
        }
        break;
      case 'FLN':
        if (w.length > 1) {
          final b = buddies[w[1].toLowerCase()];
          if (b != null) {
            b.presence = 'FLN';
            notifyListeners();
          }
        }
        break;
      case 'XFR':
        if (w.length > 5 && w[2] == 'SB' && _calls.isNotEmpty) {
          _joinOutgoing(_calls.removeFirst(), w[5]);
        }
        break;
      case 'RNG':
        // RNG sessid host CKI token inviterEmail inviterName
        if (w.length >= 6 && w[3] == 'CKI' && w[5].contains('@')) {
          final inviter = w[5].toLowerCase();
          buddies.putIfAbsent(inviter, () => MsnBuddy(inviter));
          _joinIncoming(inviter, w[1], w[4]);
          notifyListeners();
        }
        break;
      default:
        break;
    }
  }

  Future<void> _joinOutgoing(String peer, String token) async {
    try {
      late MsnWire sb;
      sb = await _open(1864, (p) => _onSwitchboard(peer, sb, p));
      _switchboards[peer] = sb;
      await sb.request('USR 1 ' + email + ' ' + token, 'USR');
      await sb.request('CAL 2 ' + peer, 'CAL');
    } catch (e) {
      _pending.remove(peer);
      error = 'Conversa indisponível: ' + readableError(e);
      notifyListeners();
    }
  }

  Future<void> _joinIncoming(String peer, String id, String token) async {
    try {
      late MsnWire sb;
      sb = await _open(1864, (p) => _onSwitchboard(peer, sb, p));
      _switchboards[peer] = sb;
      await sb.request('ANS 1 ' + email + ' ' + token + ' ' + id, 'ANS');
      await _flush(peer);
    } catch (e) {
      error = 'Não foi possível receber conversa: ' + readableError(e);
      notifyListeners();
    }
  }

  void _onSwitchboard(String peer, MsnWire sb, MsnFrame p) {
    if (p.cmd == 'JOI') {
      _flush(peer);
    } else if (p.cmd == 'MSG') {
      final bytes = p.payload;
      var start = -1;
      for (var i = 0; i + 3 < bytes.length; i++) {
        if (bytes[i] == 13 &&
            bytes[i + 1] == 10 &&
            bytes[i + 2] == 13 &&
            bytes[i + 3] == 10) {
          start = i + 4;
          break;
        }
      }
      if (start < 0) return;
      final headers = utf8
          .decode(bytes.sublist(0, start), allowMalformed: true)
          .toLowerCase();
      if (!headers.contains('text/plain')) return;
      final text = utf8.decode(bytes.sublist(start), allowMalformed: true);
      final sender = p.words.length > 1 && p.words[1].contains('@')
          ? p.words[1].toLowerCase()
          : peer;
      if (text.isEmpty) return;
      buddies.putIfAbsent(sender, () => MsnBuddy(sender));
      (messages[sender] ??= []).add(MsnMessage(sender, text));
      unread[sender] = (unread[sender] ?? 0) + 1;
      recentIncoming = sender;
      notifyListeners();
    } else if (p.cmd == 'BYE') {
      _switchboards.remove(peer);
      sb.close();
    }
  }

  Future<void> _flush(String peer) async {
    final queued = _pending.remove(peer) ?? [];
    for (final line in queued) {
      await _sendToSwitch(peer, line);
    }
  }

  Future<void> _sendToSwitch(String peer, String text) async {
    final sb = _switchboards[peer];
    if (sb == null) return;
    final data = utf8.encode(
      'MIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n' +
          text,
    );
    if (data.length > 1664) throw StateError('Mensagem acima do limite MSNP7.');
    sb.send('MSG ' + (++_tx).toString() + ' A ' + data.length.toString(), data);
  }

  Future<void> sendMessage(String peer, String text) async {
    final to = peer.toLowerCase();
    final msg = text.trim();
    if (!online || _notification == null)
      throw StateError('Entre no MSN antes de enviar.');
    if (msg.isEmpty) return;
    final data = utf8.encode(
      'MIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n' +
          msg,
    );
    if (data.length > 1664)
      throw StateError('Mensagem muito longa para o MSN.');
    (messages[to] ??= []).add(MsnMessage(email, msg, mine: true));
    notifyListeners();
    if (_switchboards.containsKey(to)) {
      await _sendToSwitch(to, msg);
      return;
    }
    (_pending[to] ??= []).add(msg);
    if (!_calls.contains(to)) {
      _calls.add(to);
      _notification!.send('XFR ' + (++_tx).toString() + ' SB');
    }
  }

  void setStatus(String newStatus) {
    if (!{'NLN', 'BSY', 'AWY', 'HDN'}.contains(newStatus)) return;
    status = newStatus;
    if (_notification != null) {
      _notification!.send('CHG ' + (++_tx).toString() + ' ' + status);
    }
    notifyListeners();
  }

  Future<void> addContact(String address) async {
    if (!online || _notification == null) {
      throw StateError('Entre no Messenger antes de adicionar contatos.');
    }
    final addr = address.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(addr)) {
      throw StateError('Informe um endereço de e-mail válido.');
    }
    if (addr == email) {
      throw StateError('Não é possível adicionar você mesmo.');
    }
    if (buddies.containsKey(addr)) {
      throw StateError('Esse contato já está na sua lista.');
    }
    final ns = _notification!;
    final response = await ns.request(
      'ADD ' + (++_tx).toString() + ' FL ' + addr + ' ' + addr,
      'ADD',
    );
    if (response.words.length < 5 ||
        response.words[2] != 'FL' ||
        response.words[4].toLowerCase() != addr) {
      throw StateError('O servidor não confirmou a inclusão do contato.');
    }
    try {
      await ns.request(
        'ADD ' + (++_tx).toString() + ' AL ' + addr + ' ' + addr,
        'ADD',
      );
    } catch (_) {
      // O contato já foi incluído na lista principal FL.
    }
    buddies.putIfAbsent(addr, () => MsnBuddy(addr));
    notifyListeners();
  }

  /// Disconnect transport for an Android foreground-service handoff while
  /// preserving the visible chat history for when the app resumes.
  Future<void> handoffDisconnect() async {
    _quitting = true;
    _notification?.send('OUT');
    for (final sb in _switchboards.values) {
      await sb.close();
    }
    _switchboards.clear();
    await _notification?.close();
    _notification = null;
    online = false;
    connecting = false;
    _pending.clear();
    _calls.clear();
    notifyListeners();
  }

  /// Import messages received and encrypted by the Android service while
  /// the Flutter UI isolate was suspended. They were already notified there.
  void restoreBackgroundMessage(String sender, String body) {
    final address = sender.trim().toLowerCase();
    if (address.isEmpty || body.isEmpty) return;
    buddies.putIfAbsent(address, () => MsnBuddy(address));
    (messages[address] ??= []).add(MsnMessage(address, body));
    unread[address] = (unread[address] ?? 0) + 1;
    recentIncoming = address;
    notifyListeners();
  }

  Future<void> signOut() async {
    _quitting = true;
    _notification?.send('OUT');
    for (final w in _switchboards.values) {
      await w.close();
    }
    _switchboards.clear();
    await _notification?.close();
    _notification = null;
    online = false;
    connecting = false;
    buddies.clear();
    groups.clear();
    messages.clear();
    unread.clear();
    recentIncoming = null;
    _pending.clear();
    _calls.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _quitting = true;
    _notification?.close();
    for (final w in _switchboards.values) {
      w.close();
    }
    super.dispose();
  }
}

class MsnProtocolException implements Exception {
  const MsnProtocolException(this.message);
  final String message;

  @override
  String toString() => 'MsnProtocolException: ' + message;
}

String msnServerError(String code) {
  return switch (code) {
    '911' =>
      'E-mail ou senha incorretos, ou autenticação antiga indisponível para esta conta.',
    '205' => 'Este e-mail não está cadastrado no Storm MSN.',
    '215' => 'O contato já existe.',
    '217' => 'O contato não está disponível.',
    '500' ||
    '600' ||
    '601' ||
    '602' ||
    '603' => 'O Storm MSN está temporariamente indisponível. Tente novamente.',
    _ => 'O servidor recusou a solicitação (código ' + code + ').',
  };
}

class MsnFrame {
  MsnFrame(this.words, this.payload);
  final List<String> words;
  final Uint8List payload;
  String get cmd => words.isEmpty ? '' : words[0];
}

class MsnWire {
  MsnWire(this.ws, this.onFrame, {this.onClose}) {
    ws.listen(
      _read,
      onError: (Object e) {
        _failPending(
          MsnProtocolException('A conexão foi interrompida: ' + e.toString()),
        );
        onClose?.call();
      },
      onDone: () {
        _failPending(
          const MsnProtocolException('A conexão com o servidor foi encerrada.'),
        );
        onClose?.call();
      },
    );
  }
  final WebSocket ws;
  final void Function(MsnFrame) onFrame;
  final VoidCallback? onClose;
  final List<int> _buffer = [];
  final Map<String, Queue<Completer<MsnFrame>>> _wait = {};

  void _failPending(MsnProtocolException error) {
    for (final queue in _wait.values) {
      while (queue.isNotEmpty) {
        final pending = queue.removeFirst();
        if (!pending.isCompleted) pending.completeError(error);
      }
    }
  }

  Future<MsnFrame> request(String command, String op) async {
    final c = Completer<MsnFrame>();
    (_wait[op] ??= Queue()).add(c);
    try {
      send(command);
      return await c.future.timeout(const Duration(seconds: 14));
    } finally {
      _wait[op]?.remove(c);
    }
  }

  void send(String command, [List<int>? bytes]) {
    ws.add(
      Uint8List.fromList(<int>[...utf8.encode(command + '\r\n'), ...?bytes]),
    );
  }

  void _read(dynamic chunk) {
    if (chunk is! List<int>) return;
    _buffer.addAll(chunk);
    if (_buffer.length > 65536) {
      ws.close();
      return;
    }
    while (true) {
      final end = _buffer.indexOf(10);
      if (end < 0) return;
      final w = utf8
          .decode(_buffer.sublist(0, end), allowMalformed: true)
          .trim()
          .split(' ');
      final withPayload = {'MSG', 'NOT', 'UBX', 'GCF', 'ADL'}.contains(w[0]);
      final length = withPayload ? int.tryParse(w.last) : null;
      if (length != null && (length < 0 || length > 32768)) {
        ws.close();
        return;
      }
      if (length != null && _buffer.length < end + 1 + length) return;
      final data = length == null
          ? Uint8List(0)
          : Uint8List.fromList(_buffer.sublist(end + 1, end + 1 + length));
      _buffer.removeRange(0, end + 1 + (length ?? 0));
      final p = MsnFrame(w, data);
      if (RegExp(r'^\d{3}$').hasMatch(p.cmd)) {
        _failPending(MsnProtocolException(msnServerError(p.cmd)));
        onFrame(p);
        continue;
      }
      final q = _wait[p.cmd];
      if (q != null && q.isNotEmpty) {
        final c = q.removeFirst();
        if (!c.isCompleted) c.complete(p);
      }
      onFrame(p);
    }
  }

  Future<void> close() async {
    await ws.close();
  }
}
