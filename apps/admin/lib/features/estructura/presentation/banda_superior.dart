import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/marca.dart';
import '../../../theme/tokens.dart';
import 'boton_de_cuenta.dart';
import 'secciones.dart';

/// La banda de tinta de arriba. En la compu lleva las pestanas; en el
/// telefono, solo la marca y la cuenta (las secciones van abajo).
class BandaSuperior extends StatelessWidget {
  const BandaSuperior({
    super.key,
    required this.ubicacion,
    required this.ancha,
  });

  final String ubicacion;
  final bool ancha;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Material(
      color: esquema.inverseSurface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: Medidas.banda,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ancha ? 32 : 16),
            child: Row(
              children: [
                Marca(color: esquema.secondary),
                if (ancha) ...[
                  const SizedBox(width: 40),
                  Semantics(
                    container: true,
                    explicitChildNodes: true,
                    label: 'Secciones',
                    child: Row(
                      children: [
                        for (final seccion in secciones)
                          _Pestana(
                            seccion: seccion,
                            activa: seccion.estaActiva(ubicacion),
                          ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                BotonDeCuenta(ancho: ancha),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({required this.seccion, required this.activa});

  final Seccion seccion;
  final bool activa;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: activa,
      child: InkWell(
        onTap: () => context.go(seccion.ruta),
        child: Container(
          height: Medidas.banda,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: activa ? esquema.secondary : esquema.inverseSurface,
                width: 3,
              ),
            ),
          ),
          child: Text(
            seccion.titulo,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: activa ? FontWeight.w600 : FontWeight.w400,
              color: activa
                  ? esquema.onInverseSurface
                  : esquema.onInverseSurface.withValues(alpha: 0.76),
            ),
          ),
        ),
      ),
    );
  }
}
