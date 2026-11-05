import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local alerts for messages received while an active MSN socket is alive.
/// For reliable delivery after Android terminates the process, FCM is needed.
class StormMessageNotifications {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  void Function(String?)? _onTap;

  Future<void> initialize({required void Function(String?) onTap}) async {
    _onTap = onTap;
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (notification) {
          _onTap?.call(notification.payload);
        },
      );
      _ready = true;
    } catch (_) {
      // Permission/plugin may be unavailable in an emulator or widget test.
    }
  }

  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  Future<void> showConversation({
    required String sender,
    required String title,
    required String text,
  }) async {
    if (!_ready) return;
    try {
      const details = AndroidNotificationDetails(
        'storm_msn_messages',
        'Mensagens do Storm MSN',
        channelDescription:
            'Mensagens recebidas enquanto o aplicativo está ativo',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        styleInformation: BigTextStyleInformation(''),
      );
      await _plugin.show(
        sender.hashCode & 0x7fffffff,
        title,
        text.length > 250 ? text.substring(0, 250) : text,
        const NotificationDetails(android: details),
        payload: sender,
      );
    } catch (_) {}
  }
}
