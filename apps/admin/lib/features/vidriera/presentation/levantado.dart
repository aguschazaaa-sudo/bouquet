import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';

/// Como se ve un renglon mientras se arrastra: sobre una superficie blanca y
/// con sombra, por encima de los demas. Es el `proxyDecorator` de las dos
/// listas de Vidriera.
///
/// ⚠️ El `Material` transparente no es decoracion. El renglon arrastrado se
/// dibuja en el `Overlay`, fuera del `Scaffold`, y el `IconButton` o el
/// `TextButton` que lleva adentro necesitan un `Material` arriba para pintar.
class Levantado extends StatelessWidget {
  const Levantado({
    super.key,
    required this.animacion,
    required this.child,
    this.margenAbajo = 0,
  });

  /// De 0 a 1 al levantarlo, y de vuelta a 0 al soltarlo.
  final Animation<double> animacion;
  final Widget child;

  /// El aire que el renglon deja abajo y que no es parte de su superficie: sin
  /// descontarlo, la sombra dibuja una tarjeta mas alta que la de verdad.
  final double margenAbajo;

  @override
  Widget build(BuildContext context) {
    final superficie = Theme.of(context).colorScheme.surface;

    return AnimatedBuilder(
      animation: animacion,
      builder: (context, renglon) {
        final t = Curves.easeInOut.transform(animacion.value);
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              bottom: margenAbajo,
              child: Material(
                color: superficie,
                elevation: 6 * t,
                borderRadius: BorderRadius.circular(Medidas.radio),
              ),
            ),
            renglon!,
          ],
        );
      },
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
