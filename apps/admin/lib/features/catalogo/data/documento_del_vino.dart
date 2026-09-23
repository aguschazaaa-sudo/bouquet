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
/// `stock` y `tipo` **siguen sin salir del alta**: un vino nace sin stock
/// —el primero llega por la reposicion, del servidor (HU-05.1)— y simple,
/// lo haya tocado quien lo haya tocado.
///
/// `publicado` e `imagenes` SI salen de `alta` desde el 2026-09-23 (ADR 015
/// §5, revierte la exclusion original): la foto se sube mientras el
/// formulario todavia es un borrador -- Storage y la callable `procesarFoto`
/// no piden que el documento exista, solo la ruta `productos/{slug}/...` -- y
/// "Publicar apenas se cargue" es un tilde del mismo formulario. `publicado`
/// se escribe siempre, tilde o no: un `where('publicado','==',true)` no
/// devuelve los documentos sin el campo.
///
/// La añada, la graduacion y la descripcion vacias **no se escriben**: las
/// reglas aceptan el campo ausente, y un `null` guardado no le dice nada a
/// nadie. En la descripcion ademas una cadena en blanco la RECHAZAN: para
/// "sin descripcion" esta el campo ausente o `null`, no `''`.
Map<String, Object?> documentoNuevo(AltaDeVino alta) {
  final f = alta.ficha;
  return {
    'tipo': 'simple',
    'slug': alta.slug,
    'nombre': alta.nombre,
    'precio': alta.precio,
    'stock': 0,
    'presentacion': {'botellas': alta.botellas},
    'imagenes': alta.imagenes,
    'publicado': alta.publicar,
    'fichaVino': {
      'bodegaId': f.bodegaId,
      'varietales': f.varietales,
      'color': alta.color.name,
      'organico': f.organico,
      'region': f.region,
      'volumenMl': f.volumenMl,
      if (f.anada != null) 'anada': f.anada,
      if (f.graduacion != null) 'graduacion': f.graduacion,
      if (f.descripcion != null) 'descripcion': f.descripcion,
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
  if (c.descripcion != null) 'fichaVino.descripcion': c.descripcion!.valor,
};

/// El campo de los varietales, escrito una sola vez para que el `arrayUnion`
/// y el `arrayRemove` no puedan divergir en una letra.
const campoDeLosVarietales = 'fichaVino.varietales';
