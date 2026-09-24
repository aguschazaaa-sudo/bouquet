import 'package:flutter/material.dart';

import '../../../core/contratos/plata.dart';
import '../../../core/presentation/aviso.dart';
import '../../../theme/tokens.dart';
import '../domain/fallo_de_pedidos.dart';
import '../domain/pedido_a_cargar.dart';
import 'textos_de_carga.dart';
import 'textos_de_pedidos.dart';

/// Lo de abajo del formulario de cargar un pedido (HU-10.1): el total de lista,
/// lo que salio mal si algo salio mal, y el boton.
///
/// - El total dice **"Total de lista"**, no *"cobrado"*: el cobro va por fuera.
/// - Un fallo se dice **con lo que hay que hacer**, y un **`yaEstaHecho`** ofrece
///   **abrir el pedido que ya existe** en vez de cargar otro: otro seria un pedido
///   duplicado (ADR 018 §10). Con ese fallo, confirmar queda apagado.
/// - El boton NO se apaga por un dato que falta: se puede tocar, y entonces marca
///   el campo. Un boton apagado sin decir por que es un boton que "no anda".
class PieDeCarga extends StatelessWidget {
  const PieDeCarga({
    super.key,
    required this.pedido,
    required this.guardando,
    required this.faltaAlgo,
    required this.alConfirmar,
    required this.alAbrirElExistente,
    this.fallo,
    this.nombreDelVino,
  });

  final PedidoACargar pedido;
  final bool guardando;

  /// El operador ya intento confirmar y falta un dato: se avisa arriba del boton.
  final bool faltaAlgo;
  final VoidCallback alConfirmar;
  final VoidCallback alAbrirElExistente;
  final FalloDePedidos? fallo;

  /// El nombre del vino que fallo, ya resuelto (el id no se muestra).
  final String? nombreDelVino;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final yaExiste = fallo?.error == ErrorDePedido.yaEstaHecho;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$textoTotalDeLista · ${textoBotellas(pedido.botellasEnTotal)}',
                style: tema.textTheme.titleMedium,
              ),
            ),
            Text(
              enPesos(pedido.totalDeLista),
              style: tema.textTheme.titleMedium,
            ),
          ],
        ),
        if (faltaAlgo) ...[
          const SizedBox(height: 12),
          const Aviso(texto: textoFaltaAlgo, tono: TonoDelAviso.error),
        ],
        if (fallo case final f?) ...[
          const SizedBox(height: 12),
          Aviso(
            texto: textoDelFalloDePedidos(f, nombre: nombreDelVino),
            tono: TonoDelAviso.error,
          ),
          if (yaExiste && f.numero != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: alAbrirElExistente,
              child: Text(textoAbrirElPedido(f.numero!)),
            ),
          ],
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: Medidas.boton,
          child: FilledButton(
            onPressed: guardando || yaExiste ? null : alConfirmar,
            child: Text(
              guardando ? textoCargandoElPedido : textoCargarElPedido,
            ),
          ),
        ),
      ],
    );
  }
}
