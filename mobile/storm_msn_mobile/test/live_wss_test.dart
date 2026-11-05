import 'package:flutter_test/flutter_test.dart';
import 'package:storm_msn_mobile/msn_protocol.dart';

/// Opt-in end-to-end exercise of the public WSS bridge.
/// Uses a deliberately nonexistent account, never a real user's password.
const runLive = bool.fromEnvironment('STORM_MSN_LIVE_TEST');

void main() {
  test(
    'public Storm MSN WSS returns a clear authentication error',
    () async {
      final client = MsnClient();
      try {
        await client.signIn(
          'storm-mobile-nonexistent-qa@example.invalid',
          'ThisIsNotARealPassword',
        );
        expect(client.online, isFalse);
        expect(client.error, contains('senha'));
      } finally {
        client.dispose();
      }
    },
    skip: !runLive,
    timeout: const Timeout(Duration(seconds: 35)),
  );
}
