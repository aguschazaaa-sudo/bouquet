import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../acceso/acceso_providers.dart';
import '../../acceso/domain/sesion.dart';

/// Quien entro y como salir. En la compu, el mail y "Salir" a la vista; en el
/// telefono, un icono que abre una hoja con lo mismo.
class BotonDeCuenta extends ConsumerWidget {
  const BotonDeCuenta({super.key, required this.ancho});

  final bool ancho;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esquema = Theme.of(context).colorScheme;
    final sesion = ref.watch(sesionProvider).valueOrNull;
    final mail = sesion is Operador ? sesion.mail : '';
    void salir() => ref.read(repositorioDeSesionProvider).salir();

    if (ancho) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: esquema.onInverseSurface.withValues(alpha: 0.76),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: salir,
            style: TextButton.styleFrom(foregroundColor: esquema.secondary),
            child: const Text('Salir'),
          ),
        ],
      );
    }

    return IconButton(
      tooltip: 'Tu cuenta',
      color: esquema.onInverseSurface,
      icon: const Icon(Icons.account_circle_outlined),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (hoja) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Entraste como',
                  style: Theme.of(hoja).textTheme.bodySmall?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(mail, style: Theme.of(hoja).textTheme.titleMedium),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(hoja).pop();
                    salir();
                  },
                  child: const Text('Salir'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
