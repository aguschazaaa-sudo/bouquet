import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/aviso.dart';
import '../acceso_providers.dart';
import '../domain/repositorio_de_sesion.dart';
import 'textos_de_acceso.dart';

/// Pedir el correo para crear la primera contrasena o cambiarla (HU-01.1).
///
/// El mensaje de exito es el mismo exista o no la cuenta: decir "ese mail no
/// tiene cuenta" le cuenta a un extrano quien tiene acceso al panel.
class FormularioDeContrasena extends ConsumerStatefulWidget {
  const FormularioDeContrasena({
    super.key,
    required this.mailInicial,
    required this.alVolver,
  });

  final String mailInicial;
  final ValueChanged<String> alVolver;

  @override
  ConsumerState<FormularioDeContrasena> createState() =>
      _FormularioDeContrasenaState();
}

class _FormularioDeContrasenaState
    extends ConsumerState<FormularioDeContrasena> {
  late final _mail = TextEditingController(text: widget.mailInicial);
  bool _ocupado = false;
  bool _enviado = false;
  String? _error;

  @override
  void dispose() {
    _mail.dispose();
    super.dispose();
  }

  Future<void> _pedir() async {
    if (_mail.text.trim().isEmpty) {
      setState(() => _error = textoFaltaMail);
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
      _enviado = false;
    });
    try {
      await ref
          .read(repositorioDeSesionProvider)
          .pedirMailDeContrasena(_mail.text);
      if (mounted) setState(() => _enviado = true);
    } on FalloDeEntrada catch (e) {
      if (mounted) setState(() => _error = textoDelError(e.error));
    } catch (e) {
      debugPrint('Pedir la contrasena fallo sin FalloDeEntrada: $e');
      if (mounted) {
        setState(() => _error = textoDelError(ErrorDeEntrada.desconocido));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Te mandamos un correo con un enlace para crear tu contraseña, o '
          'para cambiarla si te la olvidaste.',
          style: tema.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _mail,
          enabled: !_ocupado,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _pedir(),
          decoration: const InputDecoration(labelText: 'Mail'),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          Aviso(texto: error, tono: TonoDelAviso.error),
        ],
        if (_enviado) ...[
          const SizedBox(height: 16),
          const Aviso(texto: textoMailEnviado),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _ocupado ? null : _pedir,
          child: _ocupado
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Text(_enviado ? 'Mandarlo de nuevo' : 'Mandarme el correo'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _ocupado ? null : () => widget.alVolver(_mail.text),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver a entrar'),
          ),
        ),
      ],
    );
  }
}
