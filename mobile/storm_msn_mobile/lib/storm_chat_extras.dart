import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'mobile_account.dart';

/// Optional voice notes on top of the original MSNP7 text channel.
///
/// Each note is uploaded to the Storm MSN HTTPS server; the text transport
/// carries its opaque media URL so that even an old desktop client can open it.
class StormVoiceRecorder extends StatefulWidget {
  const StormVoiceRecorder({
    super.key,
    required this.account,
    required this.sendText,
    required this.onError,
  });

  final StormMobileAccount? account;
  final Future<void> Function(String) sendText;
  final void Function(String) onError;

  @override
  State<StormVoiceRecorder> createState() => _StormVoiceRecorderState();
}

class _StormVoiceRecorderState extends State<StormVoiceRecorder> {
  final _recorder = AudioRecorder();
  final _api = const StormMobileApi();
  Timer? _tick;
  bool _recording = false;
  bool _busy = false;
  int _seconds = 0;

  @override
  void dispose() {
    _tick?.cancel();
    if (_recording) unawaited(_recorder.cancel());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    if (_recording) {
      await _finish();
      return;
    }
    final account = widget.account;
    if (account == null) {
      widget.onError('Entre com sua conta oficial para enviar áudio.');
      return;
    }
    try {
      if (!await _recorder.hasPermission()) {
        widget.onError('Autorize o microfone nas configurações do Android.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          dir.path +
          '/storm_voice_' +
          DateTime.now().microsecondsSinceEpoch.toString() +
          '.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 24000,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds += 1);
        if (_seconds >= 60) _finish();
      });
    } catch (error) {
      widget.onError(
        'Não foi possível iniciar a gravação: ' + error.toString(),
      );
    }
  }

  Future<void> _finish() async {
    if (!_recording || _busy) return;
    _tick?.cancel();
    setState(() => _busy = true);
    String? path;
    try {
      path = await _recorder.stop();
      setState(() => _recording = false);
      if (path == null || _seconds < 1) {
        widget.onError('Grave pelo menos um segundo de áudio.');
        return;
      }
      final bytes = await File(path).readAsBytes();
      final account = widget.account;
      if (account == null) throw StateError('Sua sessão expirou.');
      final url = await _api.uploadVoice(account.token, bytes);
      await widget.sendText('🎤 Mensagem de voz: ' + url);
    } catch (error) {
      widget.onError('Falha ao enviar voz: ' + error.toString());
    } finally {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      if (mounted)
        setState(() {
          _busy = false;
          _recording = false;
          _seconds = 0;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _busy
          ? 'Enviando áudio...'
          : _recording
          ? 'Toque para enviar áudio'
          : 'Gravar áudio de até 60 segundos',
      child: InkWell(
        onTap: _toggle,
        onLongPress: _recording
            ? () async {
                _tick?.cancel();
                await _recorder.cancel();
                if (mounted)
                  setState(() {
                    _recording = false;
                    _seconds = 0;
                  });
                widget.onError('Gravação cancelada.');
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: 41, minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _recording ? Icons.stop_circle_rounded : Icons.mic,
                      color: _recording ? Colors.red : const Color(0xff1688b5),
                      size: 25,
                    ),
                    if (_recording)
                      Text(
                        '0:' + _seconds.toString().padLeft(2, '0'),
                        style: const TextStyle(fontSize: 9, color: Colors.red),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class StormVoiceMessage extends StatefulWidget {
  const StormVoiceMessage({super.key, required this.url});
  final String url;
  @override
  State<StormVoiceMessage> createState() => _StormVoiceMessageState();
}

class _StormVoiceMessageState extends State<StormVoiceMessage> {
  final _player = AudioPlayer();
  StreamSubscription<ProcessingState>? _stateSubscription;
  bool _playing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed && mounted) {
        setState(() => _playing = false);
        _player.seek(Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;
    try {
      if (_playing) {
        await _player.pause();
        if (mounted) setState(() => _playing = false);
        return;
      }
      setState(() => _loading = true);
      if (_player.duration == null) await _player.setUrl(widget.url);
      if (mounted)
        setState(() {
          _loading = false;
          _playing = true;
        });
      await _player.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _playing = false;
        });
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Áudio indisponível ou expirado.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xffe6f7fc),
      border: Border.all(color: const Color(0xffadd9e9)),
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('play-voice'),
          tooltip: 'Reproduzir mensagem de voz',
          onPressed: _toggle,
          icon: _loading
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _playing ? Icons.pause_circle : Icons.play_circle_fill,
                  color: const Color(0xff1387b3),
                ),
        ),
        const Text(
          'Mensagem de voz',
          style: TextStyle(fontSize: 12, color: Color(0xff29617f)),
        ),
        const SizedBox(width: 7),
        const Icon(Icons.graphic_eq, size: 20, color: Color(0xff4696b6)),
      ],
    ),
  );
}

const stormClassicEmoticons = <String>[
  ':)',
  ':D',
  ';)',
  ':P',
  ':(',
  ':O',
  '(L)',
  '(Y)',
  '(N)',
  '(H)',
];

const stormModernEmoji = <String>[
  '😀',
  '😃',
  '😄',
  '😁',
  '😆',
  '😅',
  '😂',
  '🤣',
  '😊',
  '🙂',
  '😉',
  '😍',
  '🥰',
  '😘',
  '😎',
  '🤔',
  '😢',
  '😭',
  '😡',
  '😴',
  '🥳',
  '🤗',
  '😇',
  '😬',
  '❤️',
  '💙',
  '💚',
  '💜',
  '💛',
  '💔',
  '💕',
  '👍',
  '👎',
  '👏',
  '🙏',
  '👌',
  '🤝',
  '💪',
  '👋',
  '🙌',
  '🫶',
  '🎉',
  '🔥',
  '⭐',
  '✨',
  '💯',
  '🎮',
  '🎵',
  '🎧',
  '🍕',
  '☕',
  '🌹',
  '🐱',
  '🐶',
  '👀',
  '💬',
];

Future<String?> showStormEmoticonPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: 385,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                labelColor: Color(0xff1688b5),
                tabs: [
                  Tab(text: 'Emoticons MSN'),
                  Tab(text: 'Emojis modernos'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _EmoticonGrid(items: stormClassicEmoticons),
                    _EmoticonGrid(items: stormModernEmoji),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EmoticonGrid extends StatelessWidget {
  const _EmoticonGrid({required this.items});
  final List<String> items;
  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(12),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 6,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
    ),
    itemCount: items.length,
    itemBuilder: (ctx, i) => InkWell(
      onTap: () => Navigator.pop(ctx, items[i]),
      child: Center(
        child: Text(
          items[i],
          style: TextStyle(fontSize: items[i].length > 2 ? 16 : 26),
        ),
      ),
    ),
  );
}

/// Recognise only URLs served by our own Storm MSN voice-note endpoint.
String? stormVoiceUrl(String text) {
  const prefix = '🎤 Mensagem de voz: ';
  if (!text.startsWith(prefix)) return null;
  final url = text.substring(prefix.length).trim();
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'msn.hoststorm.com.br' ||
      !RegExp(r'^/api/mobile/voice/[0-9a-f]{48}$').hasMatch(uri.path)) {
    return null;
  }
  return url;
}
