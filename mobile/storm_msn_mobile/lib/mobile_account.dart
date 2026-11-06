import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'msn_protocol.dart';

class StormMobileAccount {
  const StormMobileAccount({
    required this.email,
    required this.username,
    required this.token,
  });
  final String email;
  final String username;
  final String token;
}

class StormMobileApi {
  static const base = 'https://$stormMsnServer';
  const StormMobileApi();

  Future<StormMobileAccount> signIn(
    String usernameOrEmail,
    String password,
  ) async {
    final result = await _send(
      'POST',
      '/api/mobile/session',
      json: <String, String>{
        'identifier': usernameOrEmail.trim(),
        'password': password,
      },
    );
    return StormMobileAccount(
      email: result['email'] as String,
      username: result['username'] as String,
      token: result['token'] as String,
    );
  }

  Future<void> uploadAvatar(String token, Uint8List image) async {
    if (image.isEmpty || image.length > 4 * 1024 * 1024) {
      throw StateError('Escolha uma imagem de até 4 MB.');
    }
    await _send('POST', '/api/mobile/avatar', token: token, image: image);
  }

  Future<String> uploadVoice(String token, Uint8List audio) async {
    if (audio.isEmpty || audio.length > 3 * 1024 * 1024) {
      throw StateError('Áudio acima de 3 MB.');
    }
    final data = await _send(
      'POST',
      '/api/mobile/voice',
      token: token,
      audio: audio,
    );
    final url = data['url'];
    if (url is! String ||
        !url.startsWith('https://msn.hoststorm.com.br/api/mobile/voice/')) {
      throw StateError('Link da mensagem de voz inválido.');
    }
    return url;
  }

  Future<void> removeAvatar(String token) async {
    await _send('DELETE', '/api/mobile/avatar', token: token);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? json,
    String? token,
    Uint8List? image,
    Uint8List? audio,
  }) async {
    final http = HttpClient();
    http.connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await http
          .openUrl(method, Uri.parse(base + path))
          .timeout(const Duration(seconds: 15));
      req.headers.set('Accept', 'application/json');
      if (token != null) {
        req.headers.set('Authorization', 'Bearer $token');
      }
      if (json != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(json));
      } else if (image != null) {
        req.headers.contentType = ContentType('image', 'jpeg');
        req.add(image);
      } else if (audio != null) {
        req.headers.contentType = ContentType('audio', 'mp4');
        req.add(audio);
      }
      final response = await req.close().timeout(const Duration(seconds: 20));
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        if (response.statusCode == 401) {
          throw StateError(
            token == null
                ? 'Usuário, e-mail ou senha inválidos.'
                : 'Sua sessão expirou. Saia e entre novamente para atualizar a foto.',
          );
        }
        if (response.statusCode == 403) {
          throw StateError('Operação não autorizada para esta conta.');
        }
        if (response.statusCode == 400 || response.statusCode == 415) {
          throw StateError('Imagem inválida. Use JPG, PNG ou WebP.');
        }
        if (response.statusCode == 413) {
          throw StateError('Arquivo acima do limite de 4 MB.');
        }
        if (response.statusCode == 429) {
          throw StateError('Muitas tentativas. Aguarde um pouco.');
        }
        throw StateError(
          'Servidor de perfil indisponível: ' + response.statusCode.toString(),
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('Resposta inesperada do Storm MSN.');
      }
      return decoded;
    } on SocketException {
      throw StateError('Falha de rede. Verifique sua internet.');
    } on HandshakeException {
      throw StateError('Erro de segurança na conexão HTTPS.');
    } finally {
      http.close(force: true);
    }
  }
}
