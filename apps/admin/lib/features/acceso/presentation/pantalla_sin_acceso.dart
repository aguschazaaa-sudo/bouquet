import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/aviso.dart';
import '../../../theme/tokens.dart';
import '../acceso_providers.dart';
import '../domain/repositorio_de_sesion.dart';
import '../domain/sesion.dart';
import 'panel_de_marca.dart';
import 'textos_de_acceso.dart';

/// `/sin-acceso` (HU-01.2): una cuenta que entro y no tiene el claim, o cuyo
/// token no se pudo leer. Las dos cosas se dicen distinto: un corte de red no
/// es un permiso que falta.
class PantallaSinAcceso extends ConsumerStatefulWidget {
  const PantallaSinAcceso({super.key});

  @override
  ConsumerState<PantallaSinAcceso> createState() => _PantallaSinAccesoState();
}

class _PantallaSinAccesoState extends ConsumerState<PantallaSinAcceso> {
  bool _ocupado = false;
  bool _sigueSinAcceso = false;
  String? _error;

  /// El claim nuevo no llega hasta que el token se renueva. Renovar e
  /// invalidar la sesion; si ahora es operador, el enrutador se lo lleva.
  Future<void> _revisar() async {
    setState(() {
      _ocupado = true;
      _error = null;
      _sigueSinAcceso = false;
    });
    try {
      await ref.read(repositorioDeSesionProvider).renovarPermiso();
      ref.invalidate(sesionProvider);
      final sesion = await ref.read(sesionProvider.future);
      if (mounted && sesion is! Operador) {
        setState(() => _sigueSinAcceso = true);
      }
    } on FalloDeEntrada catch (e) {
      if (mounted) setState(() => _error = textoDelError(e.error));
    } catch (e) {
      debugPrint('Revisar el permiso fallo: $e');
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
    final sesion = ref.watch(sesionProvider).valueOrNull;
    final mail = switch (sesion) {
      SinPermiso(:final mail) || Inaccesible(:final mail) => mail,
      _ => '',
    };
    final inaccesible = sesion is Inaccesible;
    final error = _error;

    return Scaffold(
      body: Column(
        children: [
          const PanelDeMarca(ancho: false),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.surface,
                    borderRadius: BorderRadius.circular(
                      Medidas.radioSuperficie,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          inaccesible
                              ? 'No pudimos revisar tu cuenta'
                              : 'Tu cuenta todavía no tiene acceso',
                          style: tema.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Entraste como '),
                            TextSpan(
                              text: mail.isEmpty ? 'una cuenta sin mail' : mail,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: inaccesible
                                  ? ', pero no pudimos confirmar si tiene '
                                        'acceso. Suele ser la conexión.'
                                  : ', pero esa cuenta no está habilitada '
                                        'para el panel.',
                            ),
                          ],
                        ),
                        style: tema.textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                      if (!inaccesible) ...[
                        const SizedBox(height: 16),
                        const Aviso(
                          texto:
                              'Si el dueño te lo acaba de dar, tocá «Ya me '
                              'dieron acceso»: el permiso nuevo no llega hasta '
                              'que la cuenta se vuelve a revisar.',
                        ),
                      ],
                      if (_sigueSinAcceso) ...[
                        const SizedBox(height: 16),
                        const Aviso(
                          tono: TonoDelAviso.error,
                          texto:
                              'Tu cuenta sigue sin acceso. Si el dueño ya te '
                              'lo dio, esperá un minuto y probá de nuevo.',
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Aviso(texto: error, tono: TonoDelAviso.error),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _ocupado ? null : _revisar,
                        child: Text(
                          inaccesible
                              ? 'Probar de nuevo'
                              : 'Ya me dieron acceso',
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _ocupado
                            ? null
                            : () =>
                                  ref.read(repositorioDeSesionProvider).salir(),
                        child: const Text('Entrar con otra cuenta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
