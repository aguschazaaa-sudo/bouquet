import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/aviso.dart';
import '../acceso_providers.dart';
import '../domain/repositorio_de_sesion.dart';
import 'boton_de_google.dart';
import 'separador_con_texto.dart';
import 'textos_de_acceso.dart';

/// Entrar con Google o con mail y contrasena (HU-01.1). No hay "crear
/// cuenta": las cuentas las crea el script de acceso.
///
/// Si entra bien no hace nada mas: el enrutador escucha la sesion y lleva a
/// la pantalla que corresponde.
class FormularioDeEntrada extends ConsumerStatefulWidget {
  const FormularioDeEntrada({
    super.key,
    required this.mailInicial,
    required this.alPedirContrasena,
  });

  final String mailInicial;

  /// Recibe el mail escrito, para no hacerlo tipear dos veces.
  final ValueChanged<String> alPedirContrasena;

  @override
  ConsumerState<FormularioDeEntrada> createState() =>
      _FormularioDeEntradaState();
}

class _FormularioDeEntradaState extends ConsumerState<FormularioDeEntrada> {
  late final _mail = TextEditingController(text: widget.mailInicial);
  final _contrasena = TextEditingController();
  bool _ocupado = false;
  bool _mostrarContrasena = false;
  String? _error;

  @override
  void dispose() {
    _mail.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _intentar(Future<void> Function() operacion) async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await operacion();
    } on FalloDeEntrada catch (e) {
      if (mounted) setState(() => _error = textoDelError(e.error));
    } catch (e) {
      // Nada se traga: un error que no es de Auth tambien llega a la pantalla.
      debugPrint('Entrar fallo sin FalloDeEntrada: $e');
      if (mounted) {
        setState(() => _error = textoDelError(ErrorDeEntrada.desconocido));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _entrarConMail() {
    if (_mail.text.trim().isEmpty || _contrasena.text.isEmpty) {
      setState(() => _error = textoFaltanDatos);
      return;
    }
    _intentar(
      () => ref
          .read(repositorioDeSesionProvider)
          .entrarConMail(mail: _mail.text, contrasena: _contrasena.text),
    );
  }

  void _entrarConGoogle() {
    _intentar(() => ref.read(repositorioDeSesionProvider).entrarConGoogle());
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BotonDeGoogle(alTocar: _ocupado ? null : _entrarConGoogle),
          const SizedBox(height: 22),
          const SeparadorConTexto(texto: 'o con tu mail'),
          const SizedBox(height: 22),
          TextField(
            controller: _mail,
            enabled: !_ocupado,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Mail'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contrasena,
            enabled: !_ocupado,
            obscureText: !_mostrarContrasena,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _entrarConMail(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              suffixIcon: IconButton(
                tooltip: _mostrarContrasena
                    ? 'Ocultar la contraseña'
                    : 'Mostrar la contraseña',
                icon: Icon(
                  _mostrarContrasena
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _mostrarContrasena = !_mostrarContrasena),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Aviso(texto: error, tono: TonoDelAviso.error),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _ocupado ? null : _entrarConMail,
            child: _ocupado
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Entrar'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _ocupado
                  ? null
                  : () => widget.alPedirContrasena(_mail.text.trim()),
              child: const Text('¿No tenés contraseña o te la olvidaste?'),
            ),
          ),
        ],
      ),
    );
  }
}
