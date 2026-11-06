import 'package:flutter/material.dart';

class StormChatAttachment {
  const StormChatAttachment({
    required this.url,
    required this.name,
    required this.photo,
  });
  final String url;
  final String name;
  final bool photo;
}

StormChatAttachment? parseStormAttachment(String text) {
  const base = 'https://msn.hoststorm.com.br/api/mobile/attachment/';
  String url;
  String label;
  bool photo;
  if (text.startsWith('📷 Foto: ')) {
    url = text.substring('📷 Foto: '.length).trim();
    label = 'Foto';
    photo = true;
  } else if (text.startsWith('📎 Arquivo: ')) {
    final match = RegExp(r'^📎 Arquivo: (.+?) (https://\S+)$').firstMatch(text);
    if (match == null) return null;
    url = match.group(2)!;
    label = match.group(1)!;
    photo = false;
  } else {
    return null;
  }
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'msn.hoststorm.com.br' ||
      !url.startsWith(base) ||
      !RegExp(r'^/api/mobile/attachment/[0-9a-f]{48}$').hasMatch(uri.path) ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  return StormChatAttachment(url: url, name: label, photo: photo);
}

class StormAttachmentBubble extends StatelessWidget {
  const StormAttachmentBubble({
    super.key,
    required this.attachment,
    required this.onOpen,
  });

  final StormChatAttachment attachment;
  final Future<void> Function(String) onOpen;

  @override
  Widget build(BuildContext context) {
    if (attachment.photo) {
      return InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog(
            insetPadding: const EdgeInsets.all(10),
            backgroundColor: const Color(0xff101b25),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Fechar prévia',
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                      const Expanded(
                        child: Text(
                          'Foto do Storm MSN',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.open_in_new,
                          color: Colors.white,
                        ),
                        tooltip: 'Abrir foto no navegador',
                        onPressed: () => onOpen(attachment.url),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.sizeOf(dialogContext).height * 0.66,
                    width: double.infinity,
                    child: InteractiveViewer(
                      minScale: 0.7,
                      maxScale: 4,
                      child: Image.network(
                        attachment.url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text(
                            'Não foi possível carregar a imagem.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 285, maxHeight: 260),
            child: Image.network(
              attachment.url,
              fit: BoxFit.contain,
              frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
                  frame != null || wasSynchronouslyLoaded
                  ? child
                  : const SizedBox(
                      width: 180,
                      height: 120,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
              errorBuilder: (_, error, stack) => const SizedBox(
                width: 200,
                height: 90,
                child: Center(child: Text('Foto indisponível ou expirada')),
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      borderRadius: BorderRadius.circular(9),
      color: const Color(0xffe9f6fc),
      child: InkWell(
        onTap: () => onOpen(attachment.url),
        borderRadius: BorderRadius.circular(9),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 270),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.description_outlined,
                  color: Color(0xff1688b5),
                  size: 27,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    attachment.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.download_outlined,
                  color: Color(0xff1688b5),
                  size: 23,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
