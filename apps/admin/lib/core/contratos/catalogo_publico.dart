// El espejo en Dart de balde, tope y las clases de descarte de
// `packages/contratos/src/producto.ts`. ADR 008, ADR 014, y design.md de
// `panel-publicar-un-vino` (Decision #2).
//
// Por que vive dos veces mas —aca y en `contratos`—: "lo que viaja NO es la
// implementacion -no se puede transportar en JSON- sino pares
// entrada->salida CALCULADOS ACA por el TypeScript de hoy"
// (packages/contratos/scripts/generar.mjs). El test que verifica este
// archivo compara contra `generated/contratos.json`, no contra si mismo:
// "la unidad externa es el JSON, no el Dart" (design.md, Decision #2).
//
// `balde`, `tope` y `armarCatalogo` de TypeScript NO se tocan ni se
// reimplementan: este archivo solo espeja el calculo de balde/tope, que es
// aritmetica simple y segura de copiar. Los MOTIVOS de descarte que decide
// `armarCatalogo` los replica `domain/en_la_tienda.dart`, sobre lo que ya
// esta en memoria; este archivo solo nombra las categorias.

import 'dart:math' as math;

/// En BOTELLAS: tres cajas de 2 son seis botellas, y eso ya es poco. Espejo
/// de `UMBRAL_QUEDAN_POCAS`.
const umbralQuedanPocas = 6;

/// En unidades de venta, por producto y por pedido. Espejo de
/// `TOPE_POR_PEDIDO`.
const topePorPedido = 12;

/// Espejo de `BALDES` de `producto.ts`. [clave] **es** el string que trae
/// `generated/contratos.json` y el que usa la vidriera: con guion, no
/// camelCase, porque asi lo definio TypeScript.
enum Balde {
  disponible('disponible'),
  quedanPocas('quedan-pocas'),
  agotado('agotado');

  const Balde(this.clave);

  final String clave;

  /// `null` si [valor] no es una de las tres claves conocidas.
  static Balde? desde(String valor) {
    for (final b in values) {
      if (b.clave == valor) return b;
    }
    return null;
  }
}

/// Espejo de `balde()` de `producto.ts`. **El calculo se hace en BOTELLAS**,
/// no en unidades de venta: una caja de 6 con 4 unidades de stock son 24
/// botellas (disponible); una caja de 6 con 1 unidad son 6 botellas (quedan
/// pocas).
Balde balde({required int stock, required int botellas}) {
  if (stock <= 0) return Balde.agotado;
  if (stock * botellas <= umbralQuedanPocas) return Balde.quedanPocas;
  return Balde.disponible;
}

/// Espejo de `tope()` de `producto.ts`: `max(0, min(stock, topePorPedido))`.
/// Un stock negativo (una reposicion que se equivoco) da 0, no un numero
/// negativo que la pantalla sumaria.
int tope({required int stock}) => math.max(0, math.min(stock, topePorPedido));

/// El balde, en palabras. Espejo de `textoDelBalde` de `producto.ts`:
/// `disponible` no se anuncia, lo normal no se anuncia (mismo criterio que
/// voz.md §9.2, aunque esto es panel y no pasa por `voz`).
///
/// Vive aca, con [Balde], y no en un feature: lo usan la ficha del vino
/// (`catalogo`) y la seccion de stock (`stock`), y ninguno de los dos puede
/// importar al otro.
String? textoDelBalde(Balde b) => switch (b) {
  Balde.disponible => null,
  Balde.quedanPocas => 'Quedan pocas',
  Balde.agotado => 'Se agotó',
};

/// Espejo de `CLASES_DE_DESCARTE` de `producto.ts`, sin `'entra'`: las cinco
/// razones por las que `armarCatalogo` deja a un producto afuera de la
/// vidriera. `domain/en_la_tienda.dart` decide cual aplica a un producto del
/// panel; este archivo solo nombra las categorias, igual que este mismo
/// enum nombra los baldes.
enum MotivoDeDescarte {
  /// El documento no pasa `validarProducto`/`validarFicha`: falta un campo,
  /// un precio publicado en 0, una imagen que no es `https://`, etc.
  noValida('no-valida'),

  /// Otro producto publicado usa el mismo slug: `armarCatalogo` descarta a
  /// LOS DOS, porque elegir uno seria elegir al azar que precio se cobra.
  slugDuplicado('slug-duplicado'),

  /// `publicado` es `false`.
  noPublicado('no-publicado'),

  /// `tipo == 'compuesto'`: la vidriera todavia no deriva su stock.
  compuesto('compuesto'),

  /// `fichaVino.bodegaId` no tiene una bodega con ese id en `bodegas`.
  bodegaInexistente('bodega-inexistente');

  const MotivoDeDescarte(this.clave);

  final String clave;

  /// `null` si [valor] no es una de las cinco claves conocidas.
  static MotivoDeDescarte? desde(String valor) {
    for (final m in values) {
      if (m.clave == valor) return m;
    }
    return null;
  }
}
