import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../domain/cajas_sugeridas.dart';
import 'manija_para_arrastrar.dart';
import 'textos_de_la_vidriera.dart';

/// Una caja sugerida en la lista (HU-09.3): su nombre, sus seis vinos, y lo
/// que la tienda va a hacer con ella.
///
/// Un lugar que no se llena **no esconde la caja**: se sigue mostrando en la
/// tienda con ese lugar marcado, y aca se dice para que el dueño decida si la
/// cambia. La excepcion es un vino que viene en su propia caja: ahi la tienda
/// no muestra la caja entera, y eso se dice distinto.
///
/// Se ordena arrastrandola desde la manija, a la izquierda y a lo alto de la
/// caja, como los renglones de la portada.
class RenglonDeCaja extends StatelessWidget {
  const RenglonDeCaja({
    super.key,
    required this.caja,
    required this.lugares,
    required this.indice,
    required this.habilitado,
    required this.alCambiar,
    required this.alSacar,
  });

  /// El aire entre una caja y la siguiente. Lo descuenta la sombra de la
  /// caja levantada (`Levantado.margenAbajo`).
  static const separacion = 12.0;

  final CajaSugerida caja;
  final List<LugarDeLaCaja> lugares;

  /// La posicion en la lista, desde 0.
  final int indice;

  /// `false` mientras se guarda otro cambio de las cajas.
  final bool habilitado;

  final VoidCallback alCambiar;
  final VoidCallback alSacar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final noSeMuestra = lugares.any((l) => l.fuera == FueraDeLaCaja.enCaja);
    final marcados = lugares.where((l) => !l.seLlena).length;
    final alerta = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.error,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: separacion),
      padding: const EdgeInsets.fromLTRB(2, 2, 6, 6),
      decoration: BoxDecoration(
        border: Border.all(color: Tokens.filetePapel),
        borderRadius: BorderRadius.circular(Medidas.radio),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ManijaParaArrastrar(indice: indice, habilitada: habilitado),
          Expanded(
            child: Padding(
              // Alinea la primera linea del nombre con el centro de la manija.
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(caja.nombre, style: tema.textTheme.titleMedium),
                  if (noSeMuestra)
                    Text(textoCajaQueNoSeMuestra, style: alerta)
                  else if (marcados > 0)
                    Text(textoLugaresMarcados(marcados), style: alerta),
                  const SizedBox(height: 6),
                  for (final l in lugares)
                    Text(
                      [
                        l.producto?.nombre ?? textoVinoQueYaNoExiste,
                        if (l.fuera case final fuera?) textoFueraDeLaCaja(fuera),
                      ].join(' · '),
                      style: l.seLlena ? tema.textTheme.bodySmall : alerta,
                    ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: habilitado ? alCambiar : null,
                        child: const Text(textoEditar),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: habilitado ? alSacar : null,
                        child: const Text(textoSacarCaja),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
