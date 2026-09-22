import '../../../../core/contratos/catalogo_publico.dart';
import '../../domain/borrador_de_vino.dart';
import '../../domain/fallo_de_catalogo.dart';
import '../textos_del_catalogo.dart';

/// Lo que dice el formulario del vino cuando guardar falla. Igual que el de
/// las bodegas salvo `yaExiste`, que alla habla de una bodega.
String textoDelFalloDelVino(ErrorDeCatalogo error) => switch (error) {
  ErrorDeCatalogo.yaExiste =>
    'Ya hay un vino con esa dirección. Puede que alguien de la familia lo '
        'haya cargado recién: fijate en el catálogo.',
  _ => textoDelFallo(error),
};

/// Como se nombra cada campo en la linea de "falta" junto al boton.
String nombreDelCampo(CampoDelVino campo) => switch (campo) {
  CampoDelVino.nombre => 'el nombre',
  CampoDelVino.bodega => 'la bodega',
  CampoDelVino.varietales => 'las uvas',
  CampoDelVino.color => 'el color',
  CampoDelVino.region => 'la región',
  CampoDelVino.volumen => 'el volumen',
  CampoDelVino.anada => 'la añada',
  CampoDelVino.graduacion => 'la graduación',
  CampoDelVino.descripcion => 'la descripción',
  CampoDelVino.precio => 'el precio',
  CampoDelVino.botellas => 'las botellas',
};

/// "el nombre, la bodega y el precio".
String enumerar(Iterable<String> cosas) {
  final lista = cosas.toList();
  if (lista.length < 2) return lista.join();
  return '${lista.sublist(0, lista.length - 1).join(', ')} y ${lista.last}';
}

/// El balde, en palabras. Espejo de `textoDelBalde` de `producto.ts`:
/// `disponible` no se anuncia, lo normal no se anuncia (mismo criterio que
/// voz.md §9.2, aunque esto es panel y no pasa por `voz`).
String? textoDelBalde(Balde b) => switch (b) {
  Balde.disponible => null,
  Balde.quedanPocas => 'Quedan pocas',
  Balde.agotado => 'Se agotó',
};

/// Por qué la tienda NO muestra HOY este vino (HU-03.7), en el estado REAL
/// -- nunca "qué pasaría si". Espejo, motivo a motivo, de los escenarios de
/// `panel-espejo-vidriera`. Usar junto con `revisarParaLaTienda`, nunca con
/// `revisarParaPublicar`.
String textoDelMotivoEnLaTienda(MotivoDeDescarte motivo) => switch (motivo) {
  MotivoDeDescarte.noValida =>
    'La tienda no lo muestra: algo de la ficha no es válido (el nombre, el '
        'precio, o alguna imagen).',
  MotivoDeDescarte.slugDuplicado =>
    'La tienda deja afuera a los dos: otro vino publicado usa la misma '
        'dirección.',
  MotivoDeDescarte.noPublicado => 'No está en la tienda porque no se publicó.',
  // BAJO 1 de revisor-pagos (ADR 014): esto tambien puede ser un simple
  // sin `stock` -el panel no distingue los dos casos-, asi que el texto no
  // afirma "es compuesto", dice lo que se ve.
  MotivoDeDescarte.compuesto =>
    'Sin stock propio: es un compuesto, o le falta cargar el stock. La '
        'tienda todavía no lo muestra.',
  MotivoDeDescarte.bodegaInexistente =>
    'La tienda lo deja afuera porque su bodega no existe.',
};

/// Antes de publicar (HU-03.6): por qué publicar no está disponible todavía,
/// en condicional -- es lo que PASARÍA si se publica ahora, nunca el estado
/// real. Usar junto con `revisarParaPublicar`.
///
/// `MotivoDeDescarte.noValida` es UNA sola categoría del dominio -- junta
/// nombre vacío, precio en cero e imagen sin `https://` --, así que el texto
/// es genérico y accionable, no un desglose campo por campo que el dominio
/// no da.
String textoDelMotivoParaPublicar(MotivoDeDescarte motivo) => switch (motivo) {
  MotivoDeDescarte.noValida =>
    'Revisá la ficha: algo no está completo. Puede ser el nombre, el '
        'precio -tiene que ser mayor que cero- o que alguna imagen no '
        'empiece con https://.',
  MotivoDeDescarte.slugDuplicado =>
    'Otro vino ya usa esta dirección: la tienda dejaría afuera a los dos.',
  // No debería verse: `revisarParaPublicar` nunca devuelve este motivo (ver
  // `domain/en_la_tienda.dart`). Queda igual por la exhaustividad del switch.
  MotivoDeDescarte.noPublicado => 'Todavía no está publicado.',
  MotivoDeDescarte.compuesto =>
    'Sin stock propio: es un compuesto, o le falta cargar el stock. La '
        'tienda no lo mostraría.',
  MotivoDeDescarte.bodegaInexistente =>
    'La tienda lo dejaría afuera porque su bodega no existe.',
};

/// HU-03.6, "Sin fotos": el aviso que NO frena publicar.
const textoSinFotoAlPublicar =
    'Se va a ver sin foto: todavía no le cargaste ninguna imagen. Podés '
    'publicar igual.';

/// HU-03.7, "Publicado y sin fotos": mismo hecho, en el estado real.
const textoApareceSinFoto = 'Aparece en la tienda, pero sin foto.';

/// HU-03.6, "Un vino de muestra".
const textoVinoDeMuestra = 'Los vinos de muestra los maneja el servidor.';

/// HU-03.6, "El panel no borra": por qué no hay un botón de borrar.
const textoNoSeBorra =
    'No se borra: se saca de la tienda y conserva su id, su dirección y su '
    'historia.';

/// HU-03.5, "Después de confirmar": el número es el de ADR 008, corregido
/// por `revisor-pagos` de 8 a 13 minutos.
const textoAvisoDeAtrasoDePrecio =
    'La tienda puede tardar hasta unos 13 minutos en mostrarlo.';
