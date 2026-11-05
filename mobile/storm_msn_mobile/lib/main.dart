import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'msn_protocol.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StormMsnApp());
}

const _blue = Color(0xff087cb3);
const _dark = Color(0xff21536b);
const _line = Color(0xffc7dfea);
const _statusGreen = Color(0xff51b90f);

const _statuses = <String, String>{
  'NLN': 'Disponível',
  'BSY': 'Ocupado',
  'AWY': 'Ausente',
  'HDN': 'Invisível',
};

class StormMsnApp extends StatefulWidget {
  const StormMsnApp({super.key});
  @override
  State<StormMsnApp> createState() => _StormMsnAppState();
}

class _StormMsnAppState extends State<StormMsnApp> {
  final client = MsnClient();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _search = TextEditingController();
  String? selected;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _search.dispose();
    client.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    final address = _email.text.trim();
    final pass = _password.text;
    _password.clear();
    await client.signIn(address, pass);
    if (mounted && client.online) {
      setState(() {
        selected = null;
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _openExternal(String url) async {
    try {
      await const MethodChannel(
        'cloud.hoststorm.storm_msn_mobile/navigation',
      ).invokeMethod<void>('openBrowser', <String, String>{'url': url});
    } catch (_) {
      _toast('Não foi possível abrir o navegador.');
    }
  }

  Future<void> _addContact() async {
    final input = TextEditingController();
    final who = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Adicionar contato'),
        content: TextField(
          controller: input,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'amigo@exemplo.com',
            labelText: 'Endereço do contato',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, input.text.trim()),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (who != null && who.contains('@')) {
      client.addContact(who);
      _toast('Solicitação enviada a ' + who);
    }
    // The dialog's input is not a persistent account credential.
    input.dispose();
  }

  Future<void> _logout() async {
    await client.signOut();
    if (mounted) setState(() => selected = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Storm MSN • Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xffeef8fc),
        primaryColor: _blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff0097cc),
          primary: _blue,
          surface: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xffb0cfdf)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _blue, width: 1.5),
          ),
        ),
      ),
      home: AnimatedBuilder(
        animation: client,
        builder: (context, _) => Scaffold(
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: client.online ? _mainView(context) : _loginView(context),
          ),
        ),
      ),
    );
  }

  Widget _loginView(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final narrow = constraints.maxWidth < 430;
        final max = constraints.maxWidth > 600 ? 455.0 : constraints.maxWidth;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xfffafdff), Color(0xffdff3fb), Color(0xffbce4f5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: narrow ? 16 : 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: max),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xffabcfe2)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22005388),
                        blurRadius: 25,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ClassicBrand(
                        title: 'Windows Live Messenger',
                        subtitle: 'Storm MSN • Edição mobile',
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 25, 22, 22),
                        child: Column(
                          children: [
                            const _MsnAvatar(
                              size: 92,
                              online: true,
                              login: false,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Bem-vindo de volta!',
                              style: TextStyle(
                                fontSize: 23,
                                color: Color(0xff2780af),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Entre com a sua conta do Storm MSN',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xff7290a1),
                              ),
                            ),
                            const SizedBox(height: 30),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.alternate_email,
                                  color: Color(0xff4897bd),
                                ),
                                hintText: 'Endereço de e-mail',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _password,
                              obscureText: !_showPassword,
                              enableSuggestions: false,
                              autocorrect: false,
                              onSubmitted: (_) => _enter(),
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                hintText: 'Senha',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xff4897bd),
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _showPassword = !_showPassword,
                                  ),
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                            ),
                            if (client.error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xffffedf0),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: const Color(0xfff0b4bc),
                                  ),
                                ),
                                child: Text(
                                  client.error!,
                                  style: const TextStyle(
                                    color: Color(0xffa4273a),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: client.connecting ? null : _enter,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff159cc9),
                                  foregroundColor: Colors.white,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                                child: client.connecting
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Entrar no Messenger',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextButton(
                              onPressed: () => _openExternal(
                                'https://msn.hoststorm.com.br/registrar',
                              ),
                              child: const Text(
                                'Não possui uma conta? Cadastre-se',
                              ),
                            ),
                            const Divider(height: 27),
                            const Text(
                              'Conexão protegida por WSS. Use uma senha exclusiva para o Storm MSN.\n'
                              'Aplicativo independente, não afiliado à Microsoft.',
                              style: TextStyle(
                                color: Color(0xff778d9d),
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mainView(BuildContext ctx) {
    return LayoutBuilder(
      builder: (ctx, c) {
        if (c.maxWidth >= 780) {
          return Container(
            color: const Color(0xffd8edf8),
            child: Row(
              children: [
                SizedBox(width: 360, child: _contactPage(wide: true)),
                Container(width: 1, color: const Color(0xff88bedb)),
                Expanded(
                  child: selected == null
                      ? _welcomePanel()
                      : _conversation(selected!, wide: true),
                ),
              ],
            ),
          );
        }
        if (selected == null) return _contactPage(wide: false);
        return _conversation(selected!, wide: false);
      },
    );
  }

  Widget _welcomePanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xffecf8fe), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, color: Color(0xff60b5df), size: 76),
            SizedBox(height: 16),
            Text(
              'Seu Messenger está de volta!',
              style: TextStyle(color: _dark, fontSize: 22),
            ),
            SizedBox(height: 8),
            Text(
              'Selecione um contato para começar uma conversa.',
              style: TextStyle(color: Color(0xff67889d), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactPage({required bool wide}) {
    final query = _search.text.toLowerCase().trim();
    final all =
        client.buddies.values
            .where(
              (b) =>
                  query.isEmpty ||
                  b.title.toLowerCase().contains(query) ||
                  b.email.toLowerCase().contains(query),
            )
            .toList()
          ..sort((a, b) {
            if (a.online != b.online) return a.online ? -1 : 1;
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });
    final active = all.where((b) => b.online).toList();
    final inactive = all.where((b) => !b.online).toList();
    return Container(
      color: const Color(0xfffdfefe),
      child: Column(
        children: [
          const _ClassicBrand(
            title: 'Windows Live Messenger',
            subtitle: 'Storm MSN Mobile',
          ),
          _personalBar(),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xfff3faff), Color(0xffd9f1fc)],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Pesquisar contatos...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: Color(0xff7aa6b9),
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _IconTool(
                      icon: Icons.person_add_alt_1_outlined,
                      label: 'Adicionar contato',
                      onTap: _addContact,
                    ),
                    _IconTool(
                      icon: Icons.videogame_asset_outlined,
                      label: 'Jogos SNES',
                      onTap: () => _openExternal(
                        'https://msn.hoststorm.com.br/AppDirectory/Directory.aspx',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.circle, size: 10, color: _statusGreen),
                    const SizedBox(width: 5),
                    Text(
                      active.length.toString() + ' online',
                      style: const TextStyle(color: _dark, fontSize: 12),
                    ),
                    const SizedBox(width: 11),
                    Text(
                      all.length.toString() + ' contatos',
                      style: const TextStyle(
                        color: Color(0xff7892a2),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'out') _logout();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'out',
                          child: Text('Sair do Messenger'),
                        ),
                      ],
                      icon: const Icon(Icons.more_horiz, color: _dark),
                      tooltip: 'Opções',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 15),
              children: [
                if (all.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 35,
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          color: Color(0xffa7cadc),
                          size: 58,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          client.buddies.isEmpty
                              ? 'Sua lista de contatos aparecerá aqui.'
                              : 'Nenhum contato corresponde à pesquisa.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xff7c9bae),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 15),
                        if (client.buddies.isEmpty)
                          OutlinedButton.icon(
                            onPressed: _addContact,
                            icon: const Icon(Icons.person_add_alt_outlined),
                            label: const Text('Adicionar amigo'),
                          ),
                      ],
                    ),
                  ),
                if (active.isNotEmpty) ...[
                  _group(
                    'Conectados',
                    active.length,
                    Icons.people_alt_outlined,
                  ),
                  ...active.map(_buddyTile),
                ],
                if (inactive.isNotEmpty) ...[
                  _group(
                    'Desconectados',
                    inactive.length,
                    Icons.people_outline,
                  ),
                  ...inactive.map(_buddyTile),
                ],
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '★ Favoritos podem ser organizados na versão desktop.',
                    style: TextStyle(color: Color(0xff91a8b6), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 45,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xffc5e8f8), Color(0xffe8f8ff)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(top: BorderSide(color: Color(0xffb7ddeb))),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.public, color: Color(0xff3087b4), size: 17),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Storm MSN • Conectado',
                    style: TextStyle(color: Color(0xff387ba5), fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => _openExternal(
                    'https://msn.hoststorm.com.br/AppDirectory/Directory.aspx',
                  ),
                  child: const Text('Jogos', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalBar() {
    return Container(
      height: 111,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff72c4ed), Color(0xffd8f4ff), Color(0xffedfaff)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _MsnWavePainter())),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 12, 12),
            child: Row(
              children: [
                const _MsnAvatar(size: 72, online: true, login: false),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        client.email.split('@').first,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _dark,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: client.status,
                          isDense: true,
                          onChanged: (v) {
                            if (v != null) client.setStatus(v);
                          },
                          icon: const Icon(Icons.arrow_drop_down, size: 16),
                          style: const TextStyle(color: _dark, fontSize: 12),
                          items: _statuses.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        color: e.key == 'NLN'
                                            ? _statusGreen
                                            : e.key == 'BSY'
                                            ? Colors.red
                                            : Colors.amber,
                                        size: 10,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(e.value),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const Text(
                        'Compartilhe uma mensagem rápida',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xff608ca5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(String name, int count, IconData icon) => Container(
    margin: const EdgeInsets.fromLTRB(8, 9, 8, 3),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xffeef8fe), Color(0xffdceffb)]),
      border: Border(bottom: BorderSide(color: Color(0xffc1e3f5))),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xff4388a5), size: 16),
        const SizedBox(width: 8),
        Text(
          name,
          style: const TextStyle(
            color: _dark,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '(' + count.toString() + ')',
          style: const TextStyle(color: Color(0xff7894a9), fontSize: 12),
        ),
      ],
    ),
  );

  Widget _buddyTile(MsnBuddy buddy) {
    final isSelected = selected == buddy.email;
    return InkWell(
      onTap: () => setState(() => selected = buddy.email),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xffdcf1ff) : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.blueGrey.withValues(alpha: .07)),
          ),
        ),
        child: Row(
          children: [
            _MsnAvatar(size: 42, online: buddy.online, login: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    buddy.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: buddy.online ? _dark : const Color(0xff84929d),
                      fontWeight: buddy.online
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    buddy.email,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xff89a1b0),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xffaac9da), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _conversation(String email, {required bool wide}) {
    final who = client.buddies[email] ?? MsnBuddy(email);
    return _ConversationPanel(
      key: ValueKey(email),
      client: client,
      who: who,
      showBack: !wide,
      onBack: () => setState(() => selected = null),
      onGames: () => _openExternal(
        'https://msn.hoststorm.com.br/AppDirectory/Directory.aspx',
      ),
      onUnavailable: (feature) =>
          _toast(feature + ' será implementado em uma atualização futura.'),
      onError: _toast,
    );
  }
}

class _ConversationPanel extends StatefulWidget {
  const _ConversationPanel({
    super.key,
    required this.client,
    required this.who,
    required this.showBack,
    required this.onBack,
    required this.onGames,
    required this.onUnavailable,
    required this.onError,
  });
  final MsnClient client;
  final MsnBuddy who;
  final bool showBack;
  final VoidCallback onBack, onGames;
  final void Function(String) onUnavailable, onError;
  @override
  State<_ConversationPanel> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends State<_ConversationPanel> {
  final text = TextEditingController();
  final list = ScrollController();
  @override
  void dispose() {
    text.dispose();
    list.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final value = text.text.trim();
    if (value.isEmpty) return;
    try {
      await widget.client.sendMessage(widget.who.email, value);
      text.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (list.hasClients)
          list.animateTo(
            list.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
      });
    } catch (e) {
      widget.onError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.client.history(widget.who.email);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (list.hasClients) list.jumpTo(list.position.maxScrollExtent);
    });
    return Column(
      children: [
        const _ClassicBrand(
          title: 'Windows Live Messenger',
          subtitle: 'Conversa • Storm MSN',
        ),
        Container(
          height: 95,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xffb9e9fc), Color(0xffeafaff)],
            ),
            border: Border(bottom: BorderSide(color: Color(0xffb2d5e8))),
          ),
          child: Row(
            children: [
              if (widget.showBack)
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back, color: _dark),
                ),
              const SizedBox(width: 10),
              _MsnAvatar(size: 56, online: widget.who.online, login: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.who.title,
                      style: const TextStyle(
                        color: _dark,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.who.online ? 'Disponível' : 'Offline',
                      style: const TextStyle(
                        color: Color(0xff64869b),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.who.email,
                      style: const TextStyle(
                        color: Color(0xff7e9aac),
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        Container(
          height: 48,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xffe5f8fd), Color(0xffd4edf8)],
            ),
            border: Border(bottom: BorderSide(color: Color(0xffc5dfed))),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            children: [
              _IconTool(
                icon: Icons.videocam_outlined,
                label: 'Webcam (em breve)',
                onTap: () => widget.onUnavailable('Webcam'),
              ),
              _IconTool(
                icon: Icons.phone_outlined,
                label: 'Chamada (em breve)',
                onTap: () => widget.onUnavailable('Chamada de voz'),
              ),
              _IconTool(
                icon: Icons.videogame_asset_outlined,
                label: 'Jogos SNES no PlayStor',
                onTap: widget.onGames,
              ),
              _IconTool(
                icon: Icons.emoji_emotions_outlined,
                label: 'Emoticons',
                onTap: () {
                  text.text += ' 😊';
                  text.selection = TextSelection.collapsed(
                    offset: text.text.length,
                  );
                },
              ),
              _IconTool(
                icon: Icons.sentiment_very_satisfied_outlined,
                label: 'Enviar sorriso',
                onTap: () {
                  text.text += ' :)';
                  text.selection = TextSelection.collapsed(
                    offset: text.text.length,
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            child: conversation.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Color(0xffb2cfdf),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Comece uma conversa',
                          style: TextStyle(
                            color: Color(0xff6d92a8),
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Suas mensagens aparecem aqui.',
                          style: TextStyle(
                            color: Color(0xff9bb0bd),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: list,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 18,
                    ),
                    itemCount: conversation.length,
                    itemBuilder: (_, i) {
                      final m = conversation[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff356da0),
                                ),
                                children: [
                                  TextSpan(
                                    text: m.mine
                                        ? 'Você diz:'
                                        : widget.who.title + ' diz:',
                                  ),
                                  TextSpan(
                                    text:
                                        '  ' +
                                        TimeOfDay.fromDateTime(
                                          m.when,
                                        ).format(context),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xff9bb0bf),
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              m.text,
                              style: const TextStyle(
                                color: Color(0xff25384b),
                                fontSize: 14.5,
                                height: 1.36,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Color(0xffedf7fc),
            border: Border(top: BorderSide(color: _line)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: text,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Digite sua mensagem...',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: send,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(64, 46),
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Icon(Icons.send_rounded, size: 22),
              ),
            ],
          ),
        ),
        Container(
          height: 24,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: const Color(0xffcdebf7),
          child: const Text(
            'Storm MSN • Conexão segura WSS',
            style: TextStyle(color: Color(0xff4d7b98), fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _IconTool extends StatelessWidget {
  const _IconTool({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 43,
        height: 42,
        child: Icon(icon, size: 23, color: const Color(0xff3286aa)),
      ),
    ),
  );
}

class _ClassicBrand extends StatelessWidget {
  const _ClassicBrand({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    padding: const EdgeInsets.symmetric(horizontal: 13),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xff157bad), Color(0xff34b2e5), Color(0xff78d7ed)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x18035d8b),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        const Icon(
          Icons.people_alt_rounded,
          color: Color(0xfff7fffe),
          size: 28,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xffe4f8fe),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.minimize_rounded, color: Colors.white70, size: 18),
        const SizedBox(width: 7),
        const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
      ],
    ),
  );
}

class _MsnAvatar extends StatelessWidget {
  const _MsnAvatar({
    required this.size,
    required this.online,
    required this.login,
  });
  final double size;
  final bool online, login;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: online
            ? [const Color(0xff91dd3b), const Color(0xff2aa71c)]
            : [const Color(0xffd4dce2), const Color(0xff9baebb)],
      ),
      borderRadius: BorderRadius.circular(size / 6),
      border: Border.all(color: Colors.white, width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24005484),
          blurRadius: 4,
          offset: Offset(1, 2),
        ),
      ],
    ),
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffe4f6ff), Color(0xff81c6e9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(size / 8),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(
        Icons.person,
        size: size * .58,
        color: const Color(0xff3181ae),
      ),
    ),
  );
}

class _MsnWavePainter extends CustomPainter {
  const _MsnWavePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: .32);
    final wave = Path()
      ..moveTo(size.width * .47, 0)
      ..quadraticBezierTo(
        size.width * .68,
        size.height * .72,
        size.width,
        size.height * .26,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(wave, p);
    p.color = Colors.white.withValues(alpha: .24);
    final lower = Path()
      ..moveTo(0, size.height * .9)
      ..quadraticBezierTo(
        size.width * .55,
        size.height * .12,
        size.width,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(lower, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
