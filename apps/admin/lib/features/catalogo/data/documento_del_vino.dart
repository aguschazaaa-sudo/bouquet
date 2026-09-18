/// Los mapas que se escriben en `productos`, **sin Firebase adentro**.
///
/// Viven aparte del repositorio para que `dart test` los pueda cargar:
/// `cloud_firestore` arrastra Flutter, y en esta maquina el panel no compila.
/// Lo unico que no esta aca son los `FieldValue` de los varietales, que el
/// repositorio agrega.
///
/// Los nombres de los campos son los de `firestore.rules`, que cierra el
/// documento con `hasOnly` — tambien adentro de `fichaVino`. Un campo de mas
/// es un `permission-denied`.
library;

import '../domain/escrituras_del_vino.dart';

/// **La unica factory** de un vino nuevo (HU-03.2, ARQUITECTURA §5.2).
///
/// `publicado`, `stock`, `tipo` e `imagenes` **no salen del alta**: un vino
/// nace sin publicar, sin stock —el primero llega por la reposicion, del
/// servidor (HU-05.1)—, simple y sin fotos, lo haya tocado quien lo haya
/// tocado. `publicado` se escribe siempre: un `where('publicado','==',true)`
/// no devuelve los documentos sin el campo.
///
/// La añada y la graduacion vacias **no se escriben**: las reglas aceptan el
/// campo ausente, y un `null` guardado no le dice nada a nadie.
Map<String, Object?> documentoNuevo(AltaDeVino alta) {
  final f = alta.ficha;
  return {
    'tipo': 'simple',
    'slug': alta.slug,
    'nombre': alta.nombre,
    'precio': alta.precio,
    'stock': 0,
    'presentacion': {'botellas': alta.botellas},
    'imagenes': <String>[],
    'publicado': false,
    'fichaVino': {
      'bodegaId': f.bodegaId,
      'varietales': f.varietales,
      'color': alta.color.name,
      'organico': f.organico,
      'region': f.region,
      'volumenMl': f.volumenMl,
      if (f.anada != null) 'anada': f.anada,
      if (f.graduacion != null) 'graduacion': f.graduacion,
    },
  };
}

/// Los campos simples que cambiaron, con **rutas con punto** adentro de
/// `fichaVino`: `update({'fichaVino': {...}})` reemplazaria el mapa entero y
/// pisaria lo que otra persona corrigio en otro campo de la ficha.
///
/// Sin los varietales: van con `arrayUnion`/`arrayRemove`, y eso lo agrega el
/// repositorio. Vaciar la añada o la graduacion escribe `null`, que las
/// reglas aceptan.
Map<String, Object?> camposQueCambiaron(CambiosDeVino c) => {
  if (c.nombre != null) 'nombre': c.nombre,
  if (c.precio != null) 'precio': c.precio,
  if (c.bodegaId != null) 'fichaVino.bodegaId': c.bodegaId,
  if (c.color != null) 'fichaVino.color': c.color!.name,
  if (c.organico != null) 'fichaVino.organico': c.organico,
  if (c.region != null) 'fichaVino.region': c.region,
  if (c.volumenMl != null) 'fichaVino.volumenMl': c.volumenMl,
  if (c.anada != null) 'fichaVino.anada': c.anada!.valor,
  if (c.graduacion != null) 'fichaVino.graduacion': c.graduacion!.valor,
};

/// El campo de los varietales, escrito una sola vez para que el `arrayUnion`
/// y el `arrayRemove` no puedan divergir en una letra.
const campoDeLosVarietales = 'fichaVino.varietales';
