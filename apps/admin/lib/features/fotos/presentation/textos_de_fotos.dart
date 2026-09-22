import '../domain/fallo_de_fotos.dart';
import '../domain/formato_de_foto.dart' show topeDeBytes;
import '../domain/foto_del_vino.dart' show topeDeFotos;

/// Los textos de la sección de fotos. **No pasan por la skill `voz`**: esa
/// cura lo que lee un comprador, y esto lo lee la familia que carga el
/// catálogo. Sí aplica el mismo criterio del proyecto -- decir la
/// consecuencia en la tienda, no el código técnico del SDK -- porque es la
/// misma razón por la que funciona: "no anda" no dice qué hacer.

const textoTituloDeLaSeccion = 'Fotos';

/// Spec panel-vino, "Un alta sin guardar": la ruta de Storage y el
/// `arrayUnion` necesitan el id del producto, que un borrador todavía no
/// tiene.
const textoGuardarPrimero =
    'Guardá el vino primero: las fotos necesitan que ya tenga una '
    'dirección.';

/// Spec panel-vino "Un vino sin fotos" y panel-fotos-vino "Quitar la única
/// foto de un vino publicado" -- las dos son el mismo estado
/// (`imagenes.isEmpty`), y las dos piden la misma consecuencia: qué va a
/// mostrar la tienda mientras no haya ninguna.
const textoSinFotosTodavia =
    'Todavía no tiene fotos: la tienda va a dibujar la silueta de una '
    'botella genérica. Podés dejarlo publicado igual, la foto no es '
    'requisito.';

const textoTomarFoto = 'Sacar una foto';
const textoElegirDeGaleria = 'Elegir de la galería';
const textoSubiendo = 'Subiendo…';
const textoQuitarFoto = 'Sacar esta foto';

/// Spec "No recortó nada": la CONSECUENCIA en la tienda -- el fondo no
/// desaparece --, no el `0 %` crudo que informó `procesarFoto`.
const textoNoRecorto =
    'El fondo no desaparece: así la va a mostrar la tienda, con el '
    'rectángulo detrás de la botella.';

/// Spec "Quedó por debajo del alto objetivo".
const textoQuedoChica =
    'Se va a ver borrosa en la ficha: quedó más chica que lo ideal.';

/// Spec "Un vino no pasa de diez fotos": se dice ANTES de subir, sin gastar
/// nada -- ver `boton_de_agregar_foto.dart`.
const textoTopeDeFotos =
    'Este vino ya tiene $topeDeFotos fotos, el máximo. Sacá alguna para '
    'agregar otra.';

/// Spec "Una foto de 8 MB del teléfono": con el peso y el tope, no un
/// "unauthorized" que se lee como permisos.
String textoPesaDeMas(int bytesDelArchivo) {
  final mb = (bytesDelArchivo / (1024 * 1024)).toStringAsFixed(1);
  final tope = (topeDeBytes / (1024 * 1024)).toStringAsFixed(0);
  return 'Pesa $mb MB, más del máximo de $tope MB. Elegí una foto más '
      'liviana.';
}

/// Igual que [textoPesaDeMas] pero sin el peso real -- para cuando el
/// rechazo llega del repositorio (`FalloDeFotos`, `codigo` nunca va a la
/// pantalla) y no del chequeo previo del botón, que sí conoce los bytes.
String get _textoPesaDeMasGenerico =>
    'Pesa más del máximo permitido. Elegí una foto más liviana.';

/// La consecuencia en la tienda de cada [ErrorDeFotos], nunca el código del
/// SDK que lo originó (spec "Una subida que falla se ve, y dice cuál
/// falló").
String textoDelFalloDeFotos(ErrorDeFotos error) => switch (error) {
  ErrorDeFotos.sinPermiso => 'Tu cuenta no tiene permiso para subir fotos.',
  ErrorDeFotos.sinConexion => 'No hay conexión. Probá de nuevo cuando vuelva.',
  ErrorDeFotos.noEsImagen =>
    'Eso no es una foto (jpg, png o webp): no la subimos.',
  ErrorDeFotos.pesaDeMas => _textoPesaDeMasGenerico,
  ErrorDeFotos.fallaLaTransformacion =>
    'No pudimos procesarla. Probá con otra foto.',
  ErrorDeFotos.desconocido => 'Algo falló al subirla. Probá de nuevo.',
};

/// Spec panel-vino, "El aviso de sin foto que ya existe lleva a la
/// solución".
const textoIrACargarFoto = 'Ir a cargar una foto';
