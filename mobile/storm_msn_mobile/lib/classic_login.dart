import 'package:flutter/material.dart';

/// Login com a composição clássica do Windows Live Messenger 2009.
/// Arte desenhada em Flutter e controles adaptados para toque.
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
    required this.onRegister,
    required this.showPassword,
    required this.onShowPassword,
    required this.rememberEmail,
    required this.onRememberEmail,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool connecting;
  final String? error;
  final String status;
  final ValueChanged<String> onStatus;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final bool showPassword;
  final VoidCallback onShowPassword;
  final bool rememberEmail;
  final ValueChanged<bool> onRememberEmail;

  @override
  State<ClassicLogin> createState() => _ClassicLoginState();
}

class _ClassicLoginState extends State<ClassicLogin> {
  final _statuses = const <String, String>{
    'NLN': 'Disponível',
    'BSY': 'Ocupado',
    'AWY': 'Ausente',
    'HDN': 'Aparecer offline',
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 535;
        final frameWidth = c.maxWidth > 650 ? 600.0 : c.maxWidth - 22;
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xffc3ecf8), Color(0xffe8f6fc), Color(0xfff5fafc)],
              stops: [0.0, 0.38, 1.0],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: frameWidth),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xfffcfdfd),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xff81aabd),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x290a6083),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _titleBar(),
                        _header(compact),
                        _form(compact),
                        _footer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _titleBar() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffeefcff), Color(0xffcde9f2), Color(0xffa4cedf)],
        ),
        border: Border(bottom: BorderSide(color: Color(0xff95c4d7))),
      ),
      child: const Row(
        children: [
          _PeopleMark(size: 23),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Windows Live Messenger',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xff22516c),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            'Storm MSN',
            style: TextStyle(fontSize: 10, color: Color(0xff557f93)),
          ),
        ],
      ),
    );
  }

  Widget _header(bool compact) {
    return SizedBox(
      height: compact ? 96 : 126,
      width: double.infinity,
      child: CustomPaint(
        painter: _AeroBackdrop(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Entrar no',
                  style: TextStyle(
                    color: const Color(0xff55798b),
                    fontSize: compact ? 20 : 25,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(text: 'Windows Live '),
                      TextSpan(
                        text: 'Messenger',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xff3c5362),
                    fontSize: compact ? 20 : 27,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Preserva a composição horizontal original em telas comuns de celular.
  Widget _form(bool compact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 30,
        compact ? 4 : 0,
        compact ? 10 : 30,
        compact ? 4 : 20,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 276) {
            return Column(
              children: [
                const _ClassicAvatar(size: 82),
                const SizedBox(height: 13),
                _fields(),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _ClassicAvatar(size: compact ? 79 : 122),
              ),
              SizedBox(width: compact ? 10 : 24),
              Expanded(child: _fields()),
            ],
          );
        },
      ),
    );
  }

  Widget _fields() {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _classicField(
            controller: widget.email,
            hint: 'Endereço de e-mail',
            autofill: [AutofillHints.username, AutofillHints.email],
            keyboardType: TextInputType.emailAddress,
            action: TextInputAction.next,
            enabled: !widget.connecting,
          ),
          const SizedBox(height: 9),
          _classicField(
            controller: widget.password,
            hint: 'Senha',
            autofill: [AutofillHints.password],
            action: TextInputAction.done,
            obscure: !widget.showPassword,
            enabled: !widget.connecting,
            onSubmitted: (_) => widget.onLogin(),
            suffix: IconButton(
              onPressed: widget.onShowPassword,
              tooltip: widget.showPassword ? 'Ocultar senha' : 'Mostrar senha',
              icon: Icon(
                widget.showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xff6b94a8),
                size: 18,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _showPasswordHelp,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Esqueceu sua senha?',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xff1377a2),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          Row(
            children: [
              const Text(
                'Entrar como:',
                style: TextStyle(fontSize: 12, color: Color(0xff464e56)),
              ),
              const SizedBox(width: 7),
              _PresenceDot(status: widget.status),
              const SizedBox(width: 4),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    isExpanded: true,
                    value: _statuses.containsKey(widget.status)
                        ? widget.status
                        : 'NLN',
                    style: const TextStyle(
                      color: Color(0xff313f47),
                      fontSize: 12,
                    ),
                    items: _statuses.entries
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: widget.connecting
                        ? null
                        : (value) {
                            if (value != null) widget.onStatus(value);
                          },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          InkWell(
            onTap: widget.connecting
                ? null
                : () => widget.onRememberEmail(!widget.rememberEmail),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    height: 22,
                    width: 24,
                    child: Checkbox(
                      value: widget.rememberEmail,
                      onChanged: widget.connecting
                          ? null
                          : (v) => widget.onRememberEmail(v ?? false),
                      activeColor: const Color(0xff1d9ec3),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Lembrar meu ID',
                      style: TextStyle(fontSize: 12, color: Color(0xff526575)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.error != null && widget.error!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xfffff0ef),
                  border: Border.all(color: const Color(0xffe8adad)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 17,
                      color: Color(0xffb72f34),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        widget.error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xff9b252a),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: widget.connecting ? null : widget.onLogin,
                    style: ElevatedButton.styleFrom(
                      elevation: 1,
                      backgroundColor: const Color(0xffe8f6fc),
                      foregroundColor: const Color(0xff245a76),
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: Color(0xff48a2c1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    child: widget.connecting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Entrar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    onPressed: widget.connecting
                        ? null
                        : () {
                            widget.password.clear();
                            FocusScope.of(context).unfocus();
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff4d5357),
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: Color(0xffb6c6d0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 3,
            children: [
              const Text(
                'Não tem uma conta?',
                style: TextStyle(fontSize: 12, color: Color(0xff545d65)),
              ),
              TextButton(
                onPressed: widget.onRegister,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  minimumSize: const Size(44, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Cadastre-se',
                  style: TextStyle(
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    color: Color(0xff086fa1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPasswordHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: const Text(
          'A recuperação automática ainda não está disponível no Storm MSN. '
          'Use a senha da sua conta Storm MSN, não a senha de uma conta Microsoft. '
          'Não compartilhe sua senha com ninguém.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Widget _classicField({
    required TextEditingController controller,
    required String hint,
    required List<String> autofill,
    TextInputType? keyboardType,
    TextInputAction? action,
    bool obscure = false,
    bool enabled = true,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: action,
        obscureText: obscure,
        enableSuggestions: !obscure,
        autocorrect: false,
        enabled: enabled,
        onSubmitted: onSubmitted,
        autofillHints: autofill,
        style: const TextStyle(color: Color(0xff243c4d), fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xff8c99a2), fontSize: 13),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: suffix,
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
            borderSide: BorderSide(color: Color(0xffa8b9c3)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
            borderSide: BorderSide(color: Color(0xff159bc8), width: 1.4),
          ),
          disabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
            borderSide: BorderSide(color: Color(0xffc4d2da)),
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xfff4f8fa),
        border: Border(top: BorderSide(color: Color(0xffe0ebf0))),
      ),
      child: const Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            'Storm MSN Mobile · Versão de testes',
            style: TextStyle(fontSize: 10, color: Color(0xff7a95a4)),
          ),
          Text(
            'Conexão segura',
            style: TextStyle(fontSize: 10, color: Color(0xff46828f)),
          ),
        ],
      ),
    );
  }
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'BSY' => const Color(0xffdf463a),
      'AWY' => const Color(0xffdba325),
      'HDN' => const Color(0xff9ba3a8),
      _ => const Color(0xff39b730),
    };
    return Container(
      height: 10,
      width: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: const [BoxShadow(color: Color(0x55647888), blurRadius: 1)],
      ),
    );
  }
}

class _ClassicAvatar extends StatelessWidget {
  const _ClassicAvatar({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xfff7ffff), Color(0xff6cdd3b), Color(0xff17ad29)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xff219d41), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55004b72),
            blurRadius: 5,
            offset: Offset(1, 3),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xffffffff), Color(0xffd9edf4), Color(0xff89afc0)],
          ),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xffa3bac5), width: 1),
        ),
        child: Center(
          child: Icon(
            Icons.person,
            color: const Color(0xffe9f4f9),
            shadows: const [
              Shadow(
                color: Color(0xff31566d),
                blurRadius: 5,
                offset: Offset(1, 3),
              ),
            ],
            size: size * 0.67,
          ),
        ),
      ),
    );
  }
}

class _PeopleMark extends StatelessWidget {
  const _PeopleMark({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _PeoplePainter());
  }
}

class _PeoplePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 26;
    final sy = size.height / 26;
    canvas.scale(sx, sy);
    canvas.drawCircle(
      const Offset(16, 8),
      5,
      Paint()..color = const Color(0xff56b94f),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(9, 13, 24, 24, const Radius.circular(6)),
      Paint()..color = const Color(0xff4cb14f),
    );
    canvas.drawCircle(
      const Offset(9, 10),
      5,
      Paint()..color = const Color(0xff39a1d5),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(2, 15, 17, 25, const Radius.circular(6)),
      Paint()..color = const Color(0xff248cbf),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AeroBackdrop extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffb1effb), Color(0xffdaf7fd), Color(0xfff7fcfd)],
          stops: [0, 0.55, 1],
        ).createShader(bounds),
    );
    final sweep = Path()
      ..moveTo(0, size.height * 0.30)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.04,
        size.width * 0.63,
        size.height * 0.68,
        size.width,
        size.height * 0.07,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(sweep, Paint()..color = const Color(0x5593e4f5));
    final gleam = Path()
      ..moveTo(0, size.height * 0.89)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.47,
        size.width * 0.66,
        size.height * 1.10,
        size.width,
        size.height * 0.56,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(gleam, Paint()..color = const Color(0x66ffffff));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
