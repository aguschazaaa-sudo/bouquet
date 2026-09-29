/// Una caja mientras se arma o se corrige (HU-09.2, HU-09.3), en Dart puro.
///
/// Seis lugares que empiezan vacios. Lo que mas vale de la historia es que
/// el panel **diga cuantos faltan antes de guardar** y no deje elegir un vino
/// que viene en caja: la callable lo rechazaria igual, pero despues del toque.
library;

import '../../../core/contratos/texto.dart';
import 'cajas_sugeridas.dart';

/// Lo que impide guardar, en el orden en que se lo dice.
enum ProblemaDeLaCaja { sinNombre, nombreLargo, nombreSinLetras, nombreRepetido, faltanVinos }

class BorradorDeCaja {
  const BorradorDeCaja._({required this.nombre, required this.lugares});

  /// Una caja nueva: sin nombre y con los seis lugares vacios.
  BorradorDeCaja.nueva()
    : nombre = '',
      lugares = List.unmodifiable(List<String?>.filled(botellasPorCaja, null));

  /// Corregir una que ya existe.
  BorradorDeCaja.desde(CajaSugerida caja)
    : nombre = caja.nombre,
      lugares = List.unmodifiable(caja.productoIds);

  final String nombre;

  /// Siempre [botellasPorCaja] lugares; `null` es un lugar vacio.
  final List<String?> lugares;

  int get faltan => lugares.where((l) => l == null).length;

  BorradorDeCaja conNombre(String nombre) =>
      BorradorDeCaja._(nombre: nombre, lugares: lugares);

  BorradorDeCaja conVino(int lugar, String productoId) => BorradorDeCaja._(
    nombre: nombre,
    lugares: List.unmodifiable([...lugares]..[lugar] = productoId),
  );

  BorradorDeCaja sinVino(int lugar) => BorradorDeCaja._(
    nombre: nombre,
    lugares: List.unmodifiable([...lugares]..[lugar] = null),
  );

  /// El primer problema, o `null` si se puede guardar. [otras] son las cajas
  /// que ya existen, sin la que se esta corrigiendo: dos nombres que dan el
  /// mismo slug quedarian afuera LOS DOS de la tienda, y la callable los
  /// rechaza (`armarCajasSugeridas`).
  ProblemaDeLaCaja? problema(List<CajaSugerida> otras) {
    final n = nombre.trim();
    if (n.isEmpty) return ProblemaDeLaCaja.sinNombre;
    if (n.length > largoDelNombreDeCaja) return ProblemaDeLaCaja.nombreLargo;
    final slug = aSlug(n);
    if (slug.isEmpty) return ProblemaDeLaCaja.nombreSinLetras;
    if (otras.any((c) => aSlug(c.nombre) == slug)) {
      return ProblemaDeLaCaja.nombreRepetido;
    }
    if (faltan > 0) return ProblemaDeLaCaja.faltanVinos;
    return null;
  }

  /// La caja lista para guardar. Solo tiene sentido sin [problema]: con
  /// lugares vacios, falla.
  CajaSugerida get caja => CajaSugerida(
    slug: aSlug(nombre.trim()),
    nombre: nombre.trim(),
    productoIds: List.unmodifiable(lugares.cast<String>()),
  );
}
