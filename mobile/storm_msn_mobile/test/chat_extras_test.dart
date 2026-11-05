import 'package:flutter_test/flutter_test.dart';
import 'package:storm_msn_mobile/storm_chat_extras.dart';

void main() {
  test('voice URL parser accepts only Storm MSN capability URLs', () {
    const voice =
        '🎤 Mensagem de voz: '
        'https://msn.hoststorm.com.br/api/mobile/voice/'
        '0123456789abcdef0123456789abcdef0123456789abcdef';
    expect(
      stormVoiceUrl(voice),
      voice.substring('🎤 Mensagem de voz: '.length),
    );
    expect(stormVoiceUrl('Mensagem normal :)'), isNull);
    expect(stormVoiceUrl('🎤 Mensagem de voz: https://evil.com/hi'), isNull);
    expect(
      stormVoiceUrl(
        '🎤 Mensagem de voz: http://msn.hoststorm.com.br/api/mobile/voice/123',
      ),
      isNull,
    );
    expect(stormClassicEmoticons, contains('(L)'));
    expect(stormModernEmoji, contains('❤️'));
  });
}
