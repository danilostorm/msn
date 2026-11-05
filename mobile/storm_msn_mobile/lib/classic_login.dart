import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Janela de entrada inspirada nas proporções do WLM 2009 exibido pelo usuário.
/// Reimplementação nativa; não contém DLLs nem imagens originais da Microsoft.
class ClassicLogin extends StatefulWidget {
  const ClassicLogin({
    super.key,
    required this.email,
    required this.password,
    required this.connecting,
    required this.error,
    required this.status,
    required this.onStatus,
    required this.onLogin,
    required this.onCancel,
    required this.onRegister,
    required this.showPassword,
    required this.onShowPassword,
    required this.rememberEmail,
    required this.onRememberEmail,
    this.rememberPassword = false,
    this.autoLogin = false,
    this.onRememberPassword,
    this.onAutoLogin,
    this.keepOnline = false,
    this.onKeepOnline,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool connecting;
  final String? error;
  final String status;
  final ValueChanged<String> onStatus;
  final VoidCallback onLogin, onCancel, onRegister, onShowPassword;
  final bool showPassword, rememberEmail;
  final ValueChanged<bool> onRememberEmail;
  final bool rememberPassword, autoLogin, keepOnline;
  final ValueChanged<bool>? onRememberPassword, onAutoLogin, onKeepOnline;

  @override
  State<ClassicLogin> createState() => _ClassicLoginState();
}

class _ClassicLoginState extends State<ClassicLogin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _buddySpin;
  bool _showOptions = false;

  static const _statuses = <String, String>{
    'NLN': 'Disponível',
    'BSY': 'Ocupado',
    'AWY': 'Ausente',
    'HDN': 'Aparecer offline',
  };

  @override
  void initState() {
    super.initState();
    _buddySpin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    if (widget.connecting) _buddySpin.repeat();
  }

  @override
  void didUpdateWidget(covariant ClassicLogin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connecting && !oldWidget.connecting) {
      _buddySpin.repeat();
    } else if (!widget.connecting && oldWidget.connecting) {
      _buddySpin.stop();
      _buddySpin.reset();
    }
  }

  @override
  void dispose() {
    _buddySpin.dispose();
    super.dispose();
  }

  void _info(String title, String text) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _menuAction(String action) {
    switch (action) {
      case 'login':
        widget.onLogin();
      case 'register':
        widget.onRegister();
      case 'options':
        setState(() => _showOptions = true);
      case 'privacy':
        _info(
          'Declaração de Privacidade',
          'O Storm MSN utiliza uma conexão WSS protegida entre o aplicativo '
              'e o servidor. O protocolo de mensagens é legado e não oferece '
              'criptografia ponta a ponta. Não reutilize senhas de outros serviços.',
        );
      case 'status':
        _info(
          'Status do servidor',
          'A conexão com o Storm MSN é verificada quando você entra. '
              'Se aparecer uma mensagem de erro, confira a rede e tente novamente. '
              'Este painel não faz monitoramento em tempo real.',
        );
      default:
        _info(
          'Windows Live Messenger — Storm MSN',
          'Cliente móvel independente inspirado no Messenger 2009. '
              'Utilize a conta criada no servidor Storm MSN.',
        );
    }
  }

  Widget _menu(String title, List<(String, String)> items) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: title,
      onSelected: _menuAction,
      itemBuilder: (_) => [
        for (final (name, action) in items)
          PopupMenuItem<String>(value: action, child: Text(name)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          title,
          style: const TextStyle(fontSize: 11.5, color: Color(0xff1a2735)),
        ),
      ),
    );
  }

  Widget _top() {
    return Column(
      children: [
        Container(
          height: 27,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xfff9fbfe), Color(0xffe0edf7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(bottom: BorderSide(color: Color(0xff8abbd1))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _menu('Arquivo', const [
                  ('Entrar', 'login'),
                  ('Criar conta', 'register'),
                ]),
                _menu('Contatos', const [
                  ('Entre para ver seus contatos', 'help'),
                ]),
                _menu('Ações', const [
                  ('Entrar', 'login'),
                  ('Criar conta', 'register'),
                ]),
                _menu('Ferramentas', const [('Opções de login', 'options')]),
                _menu('Ajuda', const [
                  ('Sobre o Storm MSN', 'help'),
                  ('Status do servidor', 'status'),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _hero(double width) {
    return SizedBox(
      height: 158,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 79,
            child: CustomPaint(painter: _WlmHillsPainter()),
          ),
          Positioned(
            top: 26,
            left: 0,
            right: 0,
            child: Center(
              child: _ClassicLoginAvatar(size: width < 320 ? 101 : 111),
            ),
          ),
          const Positioned(right: 17, top: 16, child: _PeopleMark(size: 29)),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    bool password = false,
    Widget? suffix,
  }) {
    return SizedBox(
      height: 34,
      child: TextField(
        controller: controller,
        enabled: !widget.connecting,
        obscureText: password && !widget.showPassword,
        enableSuggestions: !password,
        autocorrect: false,
        keyboardType: password
            ? TextInputType.visiblePassword
            : TextInputType.text,
        textInputAction: password ? TextInputAction.done : TextInputAction.next,
        autofillHints: password
            ? const [AutofillHints.password]
            : const [AutofillHints.email, AutofillHints.username],
        onSubmitted: password ? (_) => widget.onLogin() : null,
        style: const TextStyle(fontSize: 12.5, color: Color(0xff2b4653)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xff9fb6c6)),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 7,
          ),
          suffixIcon: suffix,
          suffixIconConstraints: const BoxConstraints(
            minHeight: 30,
            minWidth: 27,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
            borderSide: BorderSide(color: Color(0xffafcbde)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
            borderSide: BorderSide(color: Color(0xff298dbb), width: 1.3),
          ),
        ),
      ),
    );
  }

  Widget _loginFields(double width) {
    return AutofillGroup(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: width < 350 ? 22 : 27),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(
              widget.email,
              'Usuário ou e-mail',
              suffix: PopupMenuButton<String>(
                tooltip: 'Selecionar ID lembrado',
                enabled: widget.email.text.isNotEmpty,
                padding: EdgeInsets.zero,
                iconSize: 16,
                onSelected: (email) => widget.email.text = email,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: widget.email.text,
                    child: Text(widget.email.text),
                  ),
                ],
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xff3c6176),
                ),
              ),
            ),
            const SizedBox(height: 7),
            _field(
              widget.password,
              'Senha',
              password: true,
              suffix: InkWell(
                onTap: widget.onShowPassword,
                child: Icon(
                  widget.showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 16,
                  color: const Color(0xff90adb8),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.only(
                left: 5,
                right: 2,
                top: 5,
                bottom: 3,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xffd1e5f0)),
                  right: BorderSide(color: Color(0xffd1e5f0)),
                  bottom: BorderSide(color: Color(0xffd1e5f0)),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Entrar como:',
                    style: TextStyle(fontSize: 11, color: Color(0xff4b5a63)),
                  ),
                  const SizedBox(width: 7),
                  _PresenceDot(status: widget.status),
                  const SizedBox(width: 3),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        isDense: true,
                        value: widget.status,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xff304854),
                        ),
                        iconSize: 16,
                        onChanged: widget.connecting
                            ? null
                            : (status) {
                                if (status != null) widget.onStatus(status);
                              },
                        items: [
                          for (final item in _statuses.entries)
                            DropdownMenuItem(
                              value: item.key,
                              child: Text(
                                item.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('more-login-options'),
                    onPressed: () =>
                        setState(() => _showOptions = !_showOptions),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 27,
                      minHeight: 27,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      _showOptions
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: const Color(0xff4595b5),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            if (_showOptions) ...[
              CheckboxListTile(
                title: const Text(
                  'Lembrar meu usuário ou e-mail',
                  style: TextStyle(fontSize: 11),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: widget.rememberEmail,
                onChanged: (v) => widget.onRememberEmail(v ?? false),
              ),
              CheckboxListTile(
                key: const Key('remember-password'),
                title: const Text(
                  'Salvar senha com proteção do aparelho',
                  style: TextStyle(fontSize: 11),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: widget.rememberPassword,
                onChanged: (value) =>
                    widget.onRememberPassword?.call(value ?? false),
              ),
              CheckboxListTile(
                key: const Key('auto-login'),
                title: const Text(
                  'Conectar automaticamente ao abrir',
                  style: TextStyle(fontSize: 11),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: widget.autoLogin,
                onChanged: (value) => widget.onAutoLogin?.call(value ?? false),
              ),
              CheckboxListTile(
                key: const Key('keep-online'),
                title: const Text(
                  'Continuar online em segundo plano (Android)',
                  style: TextStyle(fontSize: 11),
                ),
                subtitle: const Text(
                  'Serviço experimental com notificação permanente. O Android pode encerrá-lo.',
                  style: TextStyle(fontSize: 9.5),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: widget.keepOnline,
                onChanged: (value) => widget.onKeepOnline?.call(value ?? false),
              ),
            ],
            if (widget.error != null && widget.error!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Text(
                  widget.error!,
                  style: const TextStyle(
                    color: Color(0xffae3333),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 18),
            Align(
              child: SizedBox(
                width: 90,
                height: 31,
                child: OutlinedButton(
                  key: const Key('msn-login-button'),
                  onPressed: widget.connecting ? null : widget.onLogin,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color(0xfffbfeff),
                    foregroundColor: const Color(0xff213f51),
                    side: const BorderSide(
                      color: Color(0xff2096c1),
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  child: Text(
                    widget.connecting ? 'Entrando...' : 'Entrar',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottom() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xfff3fafc), Color(0xffc0f1fc)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _footerLink('Declaração de Privacidade', 'privacy'),
              const Text(
                ' | ',
                style: TextStyle(color: Color(0xff86c4d4), fontSize: 11),
              ),
              _footerLink('Status do servidor', 'status'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerLink(String label, String action) {
    return InkWell(
      onTap: () => _menuAction(action),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xff1366b0), fontSize: 11),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = math.min(430.0, c.maxWidth);
        return Container(
          width: double.infinity,
          color: const Color(0xffdbf2f9),
          alignment: Alignment.center,
          child: SizedBox(
            width: width,
            height: c.maxHeight,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  left: BorderSide(color: Color(0xffafd3e5)),
                  right: BorderSide(color: Color(0xffafd3e5)),
                ),
              ),
              child: Column(
                children: [
                  _top(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _hero(width),
                          if (widget.connecting) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Entrando...',
                              style: TextStyle(
                                color: Color(0xff72d3ee),
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 29),
                            RotationTransition(
                              turns: _buddySpin,
                              child: const _PeopleMark(size: 32),
                            ),
                            const SizedBox(height: 25),
                            OutlinedButton(
                              key: const Key('msn-cancel-login'),
                              onPressed: widget.onCancel,
                              child: const Text('Cancelar'),
                            ),
                          ] else ...[
                            Text(
                              'Bem-vindo novamente!',
                              style: TextStyle(
                                color: const Color(0xff73d5f2),
                                fontSize: width < 310 ? 17 : 19,
                              ),
                            ),
                            SizedBox(height: c.maxHeight > 690 ? 53 : 41),
                            _loginFields(width),
                            const SizedBox(height: 17),
                            TextButton(
                              onPressed: widget.onRegister,
                              child: const Text(
                                'Cadastrar usuário e e-mail',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xff277da9),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _bottom(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: switch (status) {
        'BSY' => const Color(0xffec4d38),
        'AWY' => const Color(0xffe5b431),
        'HDN' => const Color(0xffa5adb5),
        _ => const Color(0xff46c831),
      },
      border: Border.all(color: Colors.white),
      borderRadius: BorderRadius.circular(2),
      boxShadow: const [BoxShadow(color: Color(0x660a5779), blurRadius: 2)],
    ),
  );
}

class _ClassicLoginAvatar extends StatelessWidget {
  const _ClassicLoginAvatar({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xfff6feff), Color(0xff75bbd7), Color(0xff146a93)],
      ),
      border: Border.all(color: const Color(0xff477e98), width: 1.3),
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [
        BoxShadow(
          color: Color(0x5f164c66),
          blurRadius: 6,
          offset: Offset(2, 4),
        ),
      ],
    ),
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff0b2c43), Color(0xff246b87)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: Colors.white, width: 1.5),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(
        Icons.person,
        color: const Color(0xff94d8ec),
        size: size * 0.64,
      ),
    ),
  );
}

class _PeopleMark extends StatelessWidget {
  const _PeopleMark({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _PeoplePainter());
}

class _PeoplePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 26, size.height / 26);
    final back = Paint()..color = const Color(0xff70c14c);
    final front = Paint()..color = const Color(0xff289acb);
    canvas.drawCircle(const Offset(16, 7), 5, back);
    canvas.drawRRect(
      RRect.fromLTRBR(9, 13, 25, 25, const Radius.circular(5)),
      back,
    );
    canvas.drawCircle(const Offset(9, 10), 5, front);
    canvas.drawRRect(
      RRect.fromLTRBR(1, 15, 17, 26, const Radius.circular(5)),
      front,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WlmHillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xff74d1e9), Color(0xffaff4f9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
    );
    final landscape = Path()
      ..moveTo(0, size.height * .86)
      ..cubicTo(
        size.width * .22,
        size.height * .47,
        size.width * .58,
        size.height * .48,
        size.width,
        size.height * .82,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(landscape, Paint()..color = const Color(0xffa7dd28));
    final lower = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
        size.width * .3,
        size.height * .66,
        size.width,
        size.height * .95,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(lower, Paint()..color = const Color(0xff62bd19));
    for (var i = 0; i < 25; i++) {
      final x = (size.width * (i + .5) / 25);
      final y = (size.height * (.79 + .10 * math.sin(i * .7)));
      canvas.drawCircle(
        Offset(x, y),
        i.isEven ? 1.9 : 1.2,
        Paint()..color = const Color(0xfff5fbff),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
