/// Cuantos puestos muestra el panel. Decision mia (ADR 025 §4): para decidir
/// que reponer y que destacar alcanza con la cabeza del ranking, y una lista
/// de doscientos no la lee nadie.
const puestosQueSeMuestran = 10;

/// Lo que dice `metricas/popularidad` (HU-11.3, ADR 025), en tres casos que
/// la pantalla dice distinto.
sealed class LoQueMasSeVende {
  const LoQueMasSeVende();

  /// Arma el caso desde el documento crudo. [datos] es `null` si el documento
  /// no existe; [calculadaEn] ya viene convertida por `data/`, porque el
  /// dominio no conoce el `Timestamp` de Firestore.
  ///
  /// **Solo** `simulada: false` explicito es una medicion: lo escribe el job
  /// `calcularPopularidad`. El documento del seed decia `true`, uno que no
  /// dice nada no puede afirmar que midio, y mostrar un ranking sobre datos
  /// que no se miden es mentirle a quien lo lee (EP-11).
  factory LoQueMasSeVende.desde(
    Map<String, Object?>? datos, {
    required DateTime? calculadaEn,
  }) {
    if (datos == null || datos['simulada'] != false) return const SinMedir();
    final unidades = datos['unidades'];
    final ventanaDias = datos['ventanaDias'];
    final ventas = datos['ventas'];
    if (unidades is! Map ||
        ventanaDias is! int ||
        ventanaDias < 1 ||
        ventas is! int ||
        calculadaEn == null) {
      return const Ilegible();
    }

    final puestos = [
      for (final MapEntry(:key, :value) in unidades.entries)
        if (key is String && value is int && value > 0)
          PuestoDeVenta(productoId: key, unidades: value),
    ];
    // El mismo orden que `armarCatalogo`: mas vendido primero, y a igual
    // venta, por id. `List.sort` de Dart NO es estable, y sin el desempate
    // la lista se reordena sola en cada apertura.
    puestos.sort((a, b) {
      final porVenta = b.unidades.compareTo(a.unidades);
      return porVenta != 0 ? porVenta : a.productoId.compareTo(b.productoId);
    });

    return Medido(
      calculadaEn: calculadaEn,
      ventanaDias: ventanaDias,
      ventas: ventas,
      puestos: puestos.take(puestosQueSeMuestran).toList(),
    );
  }
}

/// No hay medicion: el documento no existe todavia, o es el simulado del
/// seed. La pantalla lo dice, y **no** muestra el ranking simulado.
final class SinMedir extends LoQueMasSeVende {
  const SinMedir();
}

/// Hay un documento que dice ser medido y no se puede leer. No es "no hay
/// ventas": pintarlo asi haria creer que no se vendio nada.
final class Ilegible extends LoQueMasSeVende {
  const Ilegible();
}

/// El ranking medido. [puestos] vacio es real: en la ventana no hubo ventas.
final class Medido extends LoQueMasSeVende {
  const Medido({
    required this.calculadaEn,
    required this.ventanaDias,
    required this.ventas,
    required this.puestos,
  });

  final DateTime calculadaEn;
  final int ventanaDias;

  /// Cuantos pedidos contaron como venta.
  final int ventas;

  /// Ordenados, hasta [puestosQueSeMuestran].
  final List<PuestoDeVenta> puestos;
}

/// Un vino en el ranking. Solo el id: el nombre sale del catalogo en memoria,
/// que es el de hoy —el documento no lo guarda, y uno viejo mentiria.
class PuestoDeVenta {
  const PuestoDeVenta({required this.productoId, required this.unidades});

  final String productoId;

  /// Unidades de venta, no botellas: la misma unidad que la vidriera.
  final int unidades;
}
