// El espejo en Dart de `packages/contratos/src/stock.ts`. EP-05, ADR 016.
//
// Es lo que el panel y la callable `moverStock` tienen que entender igual: los
// motivos, el tope, la forma de las dos operaciones y la cuenta sobre el
// stock. Vive dos veces por lo mismo que `catalogo_publico.dart`: la logica
// no se transporta en JSON, viajan pares entrada->salida CALCULADOS por el
// TypeScript de hoy (`generated/contratos.json`, seccion `stock`), y
// `test/core/contratos/stock_test.dart` compara contra eso, no contra si
// mismo.
//
// Lo que NO se espeja: `parsearPedidoDeMovimiento`. Ese valida un objeto de
// tipo desconocido que llega por la red; aca las operaciones ya son tipos
// (`int`, no "algo que puede ser un texto"), asi que lo que queda por validar
// es el RANGO -- `esValida`.

/// El stock, despues de cualquier movimiento, no pasa de esto. Espejo de
/// `TOPE_DE_STOCK`.
const topeDeStock = 5000;

/// Por que se corrige un stock. Espejo de `MOTIVOS_DE_AJUSTE`: [clave] **es**
/// el string que viaja a la callable y queda en el registro del movimiento.
enum MotivoDeAjuste {
  conteo('conteo'),
  rotura('rotura'),
  otro('otro');

  const MotivoDeAjuste(this.clave);

  final String clave;

  /// `null` si [valor] no es una de las tres claves conocidas.
  static MotivoDeAjuste? desde(Object? valor) {
    for (final m in values) {
      if (m.clave == valor) return m;
    }
    return null;
  }
}

/// Por que la callable rechazo una operacion sobre el stock de ahora. Espejo
/// de `CODIGOS_DE_RECHAZO`; viaja en `details.codigo` de un `HttpsError`
/// `failed-precondition`.
enum CodigoDeRechazo {
  /// En `corregir`: el stock ya no es el que el operador vio.
  cambioElStock('cambio-el-stock'),

  /// En `reponer`: la suma pasaria de [topeDeStock].
  pasaElTope('pasa-el-tope');

  const CodigoDeRechazo(this.clave);

  final String clave;

  static CodigoDeRechazo? desde(Object? valor) {
    for (final c in values) {
      if (c.clave == valor) return c;
    }
    return null;
  }
}

/// Lo que el operador pide. Dos formas y ninguna mas.
sealed class OperacionDeStock {
  const OperacionDeStock();

  /// Si el pedido pasaria `parsearPedidoDeMovimiento` de TypeScript. El
  /// panel lo usa para no mandar lo que ya se sabe que va a rebotar; la
  /// callable lo vuelve a decidir, y esa es la que vale.
  bool get esValida;

  /// La forma que espera la callable. Las claves, las mismas que arma el
  /// parser de TypeScript.
  Map<String, Object> get aJson;
}

/// Entra mercaderia: suma [cantidad]. No mira cuanto habia -- es conmutativa,
/// asi que dos reposiciones a la vez dan la suma exacta.
final class Reponer extends OperacionDeStock {
  const Reponer(this.cantidad);

  final int cantidad;

  @override
  bool get esValida => cantidad >= 1 && cantidad <= topeDeStock;

  @override
  Map<String, Object> get aJson => {'tipo': 'reponer', 'cantidad': cantidad};
}

/// Se conto el deposito: FIJA el stock en [valor]. Un absoluto pisa las
/// ventas del medio, asi que lleva [visto] -el stock que el operador tenia
/// en pantalla al contar- y la callable lo rechaza si ya no es ese.
final class Corregir extends OperacionDeStock {
  const Corregir({
    required this.visto,
    required this.valor,
    required this.motivo,
  });

  final int visto;
  final int valor;
  final MotivoDeAjuste motivo;

  /// `visto` no tiene tope propio: si un dato anterior a la baranda lo paso,
  /// el operador tiene que poder corregirlo hacia abajo. Y corregir a lo
  /// mismo que ya habia no es una correccion.
  @override
  bool get esValida =>
      visto >= 0 && valor >= 0 && valor <= topeDeStock && valor != visto;

  @override
  Map<String, Object> get aJson => {
    'tipo': 'corregir',
    'visto': visto,
    'valor': valor,
    'motivo': motivo.clave,
  };
}

/// Lo que da [aplicarOperacion].
sealed class ResultadoDeAplicar {
  const ResultadoDeAplicar();
}

final class Aplica extends ResultadoDeAplicar {
  const Aplica(this.despues);

  final int despues;
}

final class Rechaza extends ResultadoDeAplicar {
  const Rechaza(this.codigo);

  final CodigoDeRechazo codigo;
}

/// Espejo de `aplicarOperacion`: la cuenta sobre el stock ACTUAL. La callable
/// la corre adentro de la transaccion con el que acaba de leer; el panel, con
/// el que tiene en pantalla, para decir "queda en N" antes de confirmar.
ResultadoDeAplicar aplicarOperacion(
  int stockActual,
  OperacionDeStock operacion,
) {
  switch (operacion) {
    case Reponer(:final cantidad):
      final despues = stockActual + cantidad;
      return despues > topeDeStock
          ? const Rechaza(CodigoDeRechazo.pasaElTope)
          : Aplica(despues);
    case Corregir(:final visto, :final valor):
      return stockActual == visto
          ? Aplica(valor)
          : const Rechaza(CodigoDeRechazo.cambioElStock);
  }
}
