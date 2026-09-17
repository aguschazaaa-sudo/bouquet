import 'package:flutter/material.dart';

import '../domain/bodega.dart';
import '../domain/fallo_de_catalogo.dart';
import '../domain/repositorio_de_bodegas.dart';
import 'textos_del_catalogo.dart';

/// El borrado de una bodega (HU-02.4), con sus dos barandas.
///
/// **Por que hay DOS.** La primera la pone el renglon: con vinos, el boton no
/// existe. La segunda es esta — le pregunta a Firestore **ahora**— y existe
/// por la ventana entre que se abrio la pantalla y se apreto el boton. Sin
/// ella, alguien que carga un vino desde otra compu en ese rato se queda con
/// el vino despublicado y sin un solo error.
///
/// **Por que no esta en las reglas:** contar los vinos de una bodega dentro
/// de `firestore.rules` serian `get()` facturados por evaluacion, invisibles
/// en cualquier auditoria porque no aparecen en ninguna query. Es el costo
/// que ADR 008 evita con el custom claim.
///
/// Devuelve el texto del problema, o `null` si se borro.
Future<String?> borrarBodega({
  required BuildContext context,
  required RepositorioDeBodegas repositorio,
  required Bodega bodega,
}) async {
  final confirmo = await _confirmar(context, bodega);
  if (confirmo != true) return null;

  try {
    // La pregunta fresca, contra el servidor y no contra la cache.
    if (await repositorio.tieneVinos(bodega.id)) return textoSeLeCargaronVinos;
    await repositorio.borrar(bodega.id);
    return null;
  } on FalloDeCatalogo catch (e) {
    // ⚠️ Un `catch`, no un `finally`: HU-04.4. Un fallo que se pierde no
    // genera reportes, genera la sensacion de que "no anda".
    return textoDelFallo(e.error);
  }
}

/// Se confirma porque **no tiene vuelta atras**, que es el unico criterio del
/// panel para pedir un paso mas.
Future<bool?> _confirmar(BuildContext context, Bodega bodega) {
  final nombre = bodega.nombre.isEmpty ? 'esta bodega' : '"${bodega.nombre}"';
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Borrar la bodega?'),
      content: Text(
        'Vas a borrar $nombre. No tiene ningún vino, así que no se cae nada '
        'de la tienda — pero esto no se puede deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No, dejala'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Sí, borrala'),
        ),
      ],
    ),
  );
}
