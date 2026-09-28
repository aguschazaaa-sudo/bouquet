import '../../../core/presentation/cuando_se_ve.dart';
import '../domain/seleccion_de_la_portada.dart';

/// Lo que dice la seccion Vidriera (EP-09). Para gente no tecnica: que es,
/// que pasa y que hacer.

const textoTituloDeLaPortada = 'La portada';

const textoQueEsLaPortada =
    'Los vinos que se ven en la portada de la tienda, en este orden. Hasta '
    '$lugaresDeLaSeleccion.';

/// HU-09.4: siempre a la vista, y no solo en el aviso de despues de guardar.
const textoCuandoSeVeLaPortada = textoTardaEnLaPortada;

String textoCuantosElegiste(int cuantos) =>
    'Elegiste $cuantos de $lugaresDeLaSeleccion.';

/// Por que la portada no muestra lo que se ve en la lista. Tiene que decir la
/// verdad sobre lo que hay HOY en la tienda (`usaLaReglaEn`).
const textoTodaviaNoElegiste =
    'Todavía no elegiste ninguno: la portada muestra seis vinos elegidos por '
    'ventas, uno de cada color.';

const textoNingunoSeVe =
    'Ninguno de los que elegiste se puede mostrar hoy, así que la portada '
    'muestra seis vinos elegidos por ventas. Sumá uno que esté a la venta.';

const textoAgregarUnVino = 'Agregar un vino';

const textoPortadaLlena =
    'Ya elegiste $lugaresDeLaSeleccion. Para sumar otro, sacá uno.';

/// HU-09.4: despues de cada cambio, para que nadie piense que no se guardo.
const textoGuardado = 'Guardado. $textoTardaEnLaPortada';

const textoSubir = 'Subir';
const textoBajar = 'Bajar';
const textoSacar = 'Sacar de la portada';

const textoVinoQueYaNoExiste = 'Un vino que ya no existe';

/// Por que la portada saltea un vino elegido. Una oracion corta que dice que
/// hacer.
String textoFueraDeLaPortada(FueraDeLaPortada motivo) => switch (motivo) {
  FueraDeLaPortada.noExiste => 'No está en el catálogo: sacalo de acá.',
  FueraDeLaPortada.noEstaEnLaTienda =>
    'No se ve: la tienda no lo muestra. Revisalo en Catálogo.',
  FueraDeLaPortada.enCaja =>
    'No se ve: viene en su propia caja, y la portada muestra botellas.',
  FueraDeLaPortada.agotado => 'No se ve mientras esté sin stock.',
};

// ------------------------------------------------------------ elegir un vino

const textoElegirParaLaPortada = 'Elegir un vino para la portada';
const textoBuscarUnVino = 'Buscar por nombre';
const textoYaEstaEnLaPortada = 'Ya está en la portada';
const textoNoHayVinos = 'No hay vinos con ese nombre.';
const textoNoSePudieronLeer =
    'No pudimos leer tus vinos. Puede ser la conexión; probá de nuevo.';
