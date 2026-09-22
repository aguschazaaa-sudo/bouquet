/// ¿La tienda muestra este vino? Y si no, por que (HU-03.7).
///
/// Espeja, EN ORDEN, los pasos de `armarCatalogo` de
/// `packages/contratos/src/producto.ts` (que llama primero a
/// `validarProducto`/`validarFicha`):
///   1. ¿El documento valida? -> `MotivoDeDescarte.noValida`
///   2. ¿El slug choca con otro producto publicado? -> `slugDuplicado`
///   3. ¿Esta publicado? -> `noPublicado`
///   4. ¿Es compuesto? -> `compuesto`
///   5. ¿Su bodega existe? -> `bodegaInexistente`
///
/// **Cero lecturas de Firestore** (ARQUITECTURA §6.3): todo sale de
/// [ProductoDelPanel] y [Catalogo], que el panel ya tiene en memoria por los
/// streams que pintan la lista.
///
/// **Por que no lee un documento crudo, como hace `validarProducto`.** Eso
/// violaria el layer boundary -- `domain/` es Dart puro, sin Firebase -- asi
/// que esta funcion replica solo los campos de `validarProducto`/
/// `validarFicha` que YA ESTAN disponibles SIN AMBIGUEDAD en
/// [ProductoDelPanel]/[FichaDelVino]: el nombre, la direccion (`slug`), la
/// bodega elegida, los varietales (contra la lista cerrada y sin repetidos),
/// el color, la region, el volumen, la anada y la graduacion (si vienen,
/// dentro de rango), la descripcion (si viene, dentro del tope), el precio
/// (si esta publicado) y que cada imagen sea `https://`.
///
/// **Lo que queda afuera, y por que -- medido, no supuesto (hallazgo MEDIO 1
/// de `revisor-pagos`, ADR 014):** `presentacion.botellas < 1`, `organico`
/// mal tipado, `imagenes` AUSENTE (vs. presente y vacia) y un compuesto CON
/// `stock`. No es que sean ambiguos: es que `data/campos.dart` (`enteroDe`,
/// `boolDe`, `textosDe`) ya les puso un valor por omision AL LEER el
/// documento -- `botellas` ausente o < 1 llega aca como `1`, `organico` mal
/// tipado llega como `false`, `imagenes` ausente llega como `[]` igual que
/// una lista vacia real -- y para cuando esta funcion corre, el dato de "algo
/// estaba mal" ya se perdio. Cerrar esto pide que el MAPEO deje de
/// normalizar en silencio, que es un cambio mas grande que esta revision
/// (tocaria como el panel entero lee TODOS los documentos, no solo este
/// camino). El formulario (`borrador_de_vino.dart`) sigue siendo la unica
/// puerta de ESCRITURA y no deja guardar nada de esto roto; lo que puede
/// pasar es que un documento escrito por Admin SDK -el seed, un script- lo
/// tenga, y esta funcion no lo va a detectar todavia.
library;

import '../../../core/contratos/catalogo_publico.dart';
import '../../../core/contratos/producto.dart' as contrato;
import 'catalogo.dart';
import 'producto_del_panel.dart';

/// El resultado de revisar [ProductoDelPanel] contra las mismas reglas que
/// usa la vidriera para armar su catalogo.
class RevisionParaLaTienda {
  const RevisionParaLaTienda._({
    required this.aparece,
    this.motivo,
    this.sinFoto = false,
  });

  /// La tienda lo muestra hoy.
  final bool aparece;

  /// Por que no aparece. `null` cuando [aparece] es `true`.
  final MotivoDeDescarte? motivo;

  /// Aparece, pero sin foto: la ficha se ve con la silueta de botella y el
  /// texto "sin foto" (design.md de `panel-publicar-un-vino`, Decision #1).
  /// No bloquea que [aparece] sea `true`; solo tiene sentido cuando lo es.
  final bool sinFoto;

  const RevisionParaLaTienda._descartado(MotivoDeDescarte motivo)
    : this._(aparece: false, motivo: motivo);

  const RevisionParaLaTienda._visible({required bool sinFoto})
    : this._(aparece: true, sinFoto: sinFoto);
}

/// La unica funcion que decide si [producto] aparece en la tienda. Nada en
/// `presentation/` recalcula esto mirando los campos por separado -- mismo
/// criterio que ADR 002 con `proyectarEstadoPublico`.
RevisionParaLaTienda revisarParaLaTienda(
  ProductoDelPanel producto,
  Catalogo catalogo,
) {
  if (!_valida(producto)) {
    return const RevisionParaLaTienda._descartado(MotivoDeDescarte.noValida);
  }

  // ⚠️ NO mirar `choque.bloquea`: esa bandera contesta "¿se puede GUARDAR
  // este alta?" (ADR 013 §1 -- un choque contra un vino de MUESTRA se avisa
  // y no frena el alta, porque la base no lo rechaza). `armarCatalogo`
  // pregunta otra cosa: `vecesPorSlug` cuenta TODOS los documentos crudos,
  // de muestra o no, y descarta a los dos apenas el slug se repite -- antes
  // de mirar `publicado`. Usar `bloquea` acá daba un falso "aparece" para el
  // primer vino real que compartiera nombre con uno de muestra: los dos
  // quedaban afuera de la vidriera y el panel decía que uno estaba adentro
  // (hallazgo ALTO 2 de `revisor-pagos`, ADR 014, medido corriendo
  // `armarCatalogo` de verdad).
  if (catalogo.quienTiene(producto.slug, exceptoId: producto.id) != null) {
    return const RevisionParaLaTienda._descartado(
      MotivoDeDescarte.slugDuplicado,
    );
  }

  if (!producto.publicado) {
    return const RevisionParaLaTienda._descartado(MotivoDeDescarte.noPublicado);
  }

  // Un compuesto no tiene stock propio (ADR 009 §10), y hoy no hay forma de
  // distinguir eso de un documento simple al que le falta el campo: el
  // panel no da de alta compuestos todavia (Non-goal de este change, EP-05),
  // asi que en la practica un stock nulo en un vino publicado y valido solo
  // puede venir de un compuesto escrito a mano.
  if (producto.stock == null) {
    return const RevisionParaLaTienda._descartado(MotivoDeDescarte.compuesto);
  }

  if (catalogo.bodega(producto.bodegaId) == null) {
    return const RevisionParaLaTienda._descartado(
      MotivoDeDescarte.bodegaInexistente,
    );
  }

  return RevisionParaLaTienda._visible(sinFoto: producto.imagenes.isEmpty);
}

/// ¿Aparecería en la tienda SI se publicara ahora? (HU-03.6, la revisión
/// previa antes de tocar "Poner en la tienda".)
///
/// **Por qué no alcanza con [revisarParaLaTienda].** Antes de publicar,
/// `producto.publicado` todavía es `false`, y esa función siempre devolvería
/// `MotivoDeDescarte.noPublicado` -- tapando cualquier otro motivo real
/// (precio en cero, bodega inexistente, una imagen sin `https://`) que recién
/// se vería DESPUÉS de tocar el interruptor, cuando ya es tarde para
/// avisarlo. Acá se revisa como si `publicado` ya fuera `true`, así que el
/// resultado **nunca** puede ser `noPublicado`.
///
/// Un vino que ya está publicado se revisa tal cual está: no hay nada
/// hipotético que simular.
RevisionParaLaTienda revisarParaPublicar(
  ProductoDelPanel producto,
  Catalogo catalogo,
) {
  if (producto.publicado) return revisarParaLaTienda(producto, catalogo);
  return revisarParaLaTienda(
    ProductoDelPanel(
      id: producto.id,
      slug: producto.slug,
      nombre: producto.nombre,
      precio: producto.precio,
      publicado: true,
      ficha: producto.ficha,
      botellas: producto.botellas,
      stock: producto.stock,
      muestra: producto.muestra,
      imagenes: producto.imagenes,
    ),
    catalogo,
  );
}

/// La direccion: espejo del `SLUG` de `packages/contratos/src/producto.ts`.
/// Minusculas, digitos y guiones simples entre grupos -- ni al principio, ni
/// al final, ni duplicados.
final _slug = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

/// Espejo de lo que `validarProducto`/`validarFicha` pueden verificar sobre
/// lo que YA esta en memoria. Ver el comentario del archivo para lo que se
/// deja afuera y por que.
bool _valida(ProductoDelPanel p) {
  final f = p.ficha;
  if (p.nombre.trim().isEmpty) return false;
  if (!_slug.hasMatch(p.slug)) return false;
  if (f.bodegaId.trim().isEmpty) return false;
  if (f.varietales.isEmpty) return false;
  if (f.varietales.any((v) => !contrato.varietales.contains(v))) {
    return false;
  }
  if (f.varietales.toSet().length != f.varietales.length) return false;
  if (f.color == null) return false;
  if (f.region.trim().isEmpty) return false;
  // `volumenMl` NO es opcional en `FichaVino` (a diferencia de anada,
  // graduacion y descripcion): `null` aca es siempre invalido, nunca "no
  // cargado".
  if (f.volumenMl == null || f.volumenMl! <= 0) return false;
  // `anada`/`graduacion` SI son opcionales: `null` es "no cargada", valido.
  // Sólo se chequea el rango cuando el dato esta presente.
  if (f.anada != null && f.anada! <= 1800) return false;
  if (f.graduacion != null &&
      (f.graduacion! < contrato.graduacionMinima ||
          f.graduacion! > contrato.graduacionMaxima)) {
    return false;
  }
  if (f.descripcion != null &&
      f.descripcion!.length > contrato.descripcionMaxima) {
    return false;
  }
  // Espejo de `precioCoherente`/ADR 014 §2: un publicado necesita precio.
  // Un borrador (no publicado) puede seguir en 0.
  if (p.publicado && p.precio <= 0) return false;
  if (p.imagenes.any((u) => !u.startsWith('https://'))) return false;
  return true;
}
