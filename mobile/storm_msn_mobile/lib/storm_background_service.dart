import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'mobile_account.dart';
import 'msn_protocol.dart';
import 'storm_notifications.dart';

/// Opt-in Android foreground-service handoff. A visible persistent notification
/// is required. OEM battery management can still stop the service.
/// Firebase Cloud Messaging remains the recommended terminated-app solution.
class StormBackgroundService {
  static Future<void> configure() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final notifications = FlutterLocalNotificationsPlugin();
    try {
      await notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'storm_msn_presence',
              'Storm MSN em segundo plano',
              description: 'Conexão ativa com o Messenger e aviso permanente',
              importance: Importance.low,
            ),
          );
      await FlutterBackgroundService().configure(
        androidConfiguration: AndroidConfiguration(
          onStart: stormMsnBackgroundOnStart,
          autoStart: false,
          autoStartOnBoot: false,
          isForegroundMode: true,
          foregroundServiceTypes: const [AndroidForegroundType.remoteMessaging],
          notificationChannelId: 'storm_msn_presence',
          initialNotificationTitle: 'Storm MSN',
          initialNotificationContent: 'Aguardando segundo plano',
          foregroundServiceNotificationId: 8844,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: stormMsnBackgroundOnStart,
        ),
      );
    } catch (_) {
      // Foreground service is optional: the standard app must still work.
    }
  }

  static Future<bool> startIdle() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }
      return await service.isRunning();
    } catch (_) {
      return false;
    }
  }

  static Future<void> activate() async {
    if (kIsWeb || !Platform.isAndroid) return;
    FlutterBackgroundService().invoke('activate');
  }

  static Future<void> deactivate() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) return;
    final finished = service
        .on('sessionStopped')
        .first
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => <String, dynamic>{},
        );
    service.invoke('deactivate');
    try {
      await finished;
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final service = FlutterBackgroundService();
    if (await service.isRunning()) service.invoke('stopService');
  }
}

@pragma('vm:entry-point')
Future<void> stormMsnBackgroundOnStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final storage = FlutterSecureStorage();
  final notifier = StormMessageNotifications();
  await notifier.initialize(onTap: (_) {});
  MsnClient? session;
  bool active = false;
  bool connecting = false;
  String? previousMessage;
  Future<void> writes = Future.value();

  Future<void> notification(String sender, String name, String body) async {
    await notifier.showConversation(sender: sender, title: name, text: body);
    writes = writes.then((_) async {
      try {
        final raw = await storage.read(key: 'storm_background_inbox');
        final items = raw == null
            ? <dynamic>[]
            : (jsonDecode(raw) as List<dynamic>);
        items.add(<String, String>{
          'sender': sender,
          'text': body,
          'timestamp': DateTime.now().toIso8601String(),
        });
        await storage.write(
          key: 'storm_background_inbox',
          value: jsonEncode(
            items.length > 40 ? items.sublist(items.length - 40) : items,
          ),
        );
      } catch (_) {}
    });
    await writes;
  }

  Future<void> disconnect() async {
    active = false;
    final old = session;
    session = null;
    if (old != null) {
      try {
        await old.signOut();
      } catch (_) {}
      old.dispose();
    }
    await writes;
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Storm MSN',
        content: 'Aguardando segundo plano',
      );
    }
    service.invoke('sessionStopped');
  }

  Future<void> connect() async {
    if (!active || connecting || session?.online == true) return;
    connecting = true;
    try {
      final keep = await storage.read(key: 'storm_keep_online');
      final identifier = await storage.read(key: 'storm_login_id');
      final password = await storage.read(key: 'storm_login_password');
      if (keep != 'true' ||
          identifier == null ||
          password == null ||
          identifier.isEmpty ||
          password.isEmpty) {
        await disconnect();
        return;
      }
      final account = await const StormMobileApi().signIn(identifier, password);
      if (!active) return;
      final client = MsnClient();
      session = client;
      client.addListener(() {
        if (!active || session != client) return;
        final sender = client.recentIncoming;
        if (sender == null) return;
        final history = client.history(sender);
        if (history.isEmpty || history.last.mine) return;
        final key =
            sender + ':' + history.last.when.microsecondsSinceEpoch.toString();
        if (previousMessage == key) return;
        previousMessage = key;
        unawaited(
          notification(
            sender,
            client.buddies[sender]?.title ?? sender,
            history.last.text,
          ),
        );
      });
      await client.signIn(account.email, password);
      if (!active) {
        await client.signOut();
        return;
      }
      if (client.online && service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Storm MSN online',
          content: 'Recebendo mensagens em segundo plano',
        );
      } else if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Storm MSN sem conexão',
          content: 'Tentando reconectar...',
        );
      }
    } catch (_) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Storm MSN sem conexão',
          content: 'Tentando reconectar...',
        );
      }
    } finally {
      connecting = false;
    }
  }

  service.on('activate').listen((_) {
    active = true;
    unawaited(connect());
  });
  service.on('deactivate').listen((_) {
    unawaited(disconnect());
  });
  service.on('stopService').listen((_) async {
    await disconnect();
    service.stopSelf();
  });

  final retry = Timer.periodic(const Duration(seconds: 60), (_) {
    if (active && !connecting && session?.online != true) unawaited(connect());
  });
  service.on('stopService').listen((_) => retry.cancel());
}
