import '../../../core/presentation/cuando_se_ve.dart';
import '../domain/borrador_de_caja.dart';
import '../domain/cajas_sugeridas.dart';
import '../domain/fallo_de_las_cajas.dart';
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

/// Debajo de la lista, cuando hay dos o mas: la manija sola no avisa que se
/// arrastra. [que] es *"cada vino"* o *"cada caja"*.
String textoComoOrdenar(String que) =>
    'Para cambiar el orden, arrastrá $que desde los puntitos de la izquierda.';

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

// ---------------------------------------------------- cajas sugeridas (ADR 024)

const textoTituloDeLasCajas = 'Cajas sugeridas';

const textoQueSonLasCajas =
    'Cajas de $botellasPorCaja ya armadas que se ofrecen en Vinos. Quien la '
    'elige la recibe en su carrito y puede cambiarla. Hasta $topeDeCajas.';

/// HU-09.4: las cajas se ven en `/vinos`, que se rearma solo.
const textoCuandoSeVenLasCajas = textoTardaEnLaTienda;

const textoCajasGuardadas = 'Guardado. $textoTardaEnLaTienda';

const textoTodaviaNoHayCajas =
    'Todavía no hay cajas sugeridas: en Vinos no aparece la fila de cajas.';

const textoArmarUnaCaja = 'Armar una caja';
const textoCajasLlenas =
    'Ya hay $topeDeCajas cajas. Para sumar otra, sacá una.';

const textoEditar = 'Cambiar';
const textoSacarCaja = 'Sacar';
const textoDeshacer = 'Deshacer';
const textoCajaSacada = 'Caja sacada.';

/// Una caja con un vino que viene en su propia caja no se muestra ENTERA
/// (ADR 009 §10): no es un lugar marcado, es la caja que falta.
const textoCajaQueNoSeMuestra =
    'No se muestra: tiene un vino que viene en su propia caja. Cambialo.';

String textoLugaresMarcados(int cuantos) => cuantos == 1
    ? 'Un lugar se ve marcado en la tienda: quien la elija recibe una botella '
          'menos.'
    : '$cuantos lugares se ven marcados en la tienda: quien la elija recibe '
          '$cuantos botellas menos.';

/// Por que un lugar no se llena. Corto: va al lado del nombre del vino.
String textoFueraDeLaCaja(FueraDeLaCaja motivo) => switch (motivo) {
  FueraDeLaCaja.noExiste => 'ya no está en el catálogo',
  FueraDeLaCaja.noEstaEnLaTienda => 'no está en la tienda',
  FueraDeLaCaja.enCaja => 'viene en su propia caja',
  FueraDeLaCaja.agotado => 'sin stock',
  FueraDeLaCaja.sinSuficiente => 'no alcanza el stock para otra',
};

// -------------------------------------------------------- armar una caja

const textoNuevaCaja = 'Armar una caja';
const textoCambiarCaja = 'Cambiar la caja';
const textoNombreDeLaCaja = 'Nombre de la caja';
const textoAyudaDelNombre = 'Como se va a ver en Vinos: "Seis tintos"';
const textoElegirParaLaCaja = 'Elegir un vino para la caja';
const textoLugarVacio = 'Elegí un vino';
const textoVaciarLugar = 'Vaciar este lugar';
const textoGuardarCaja = 'Guardar la caja';

String textoLugar(int n) => 'Lugar $n';

String textoFaltan(int faltan) => faltan == 1
    ? 'Falta 1 vino para completar la caja.'
    : 'Faltan $faltan vinos para completar la caja.';

String textoDelProblema(ProblemaDeLaCaja p, int faltan) => switch (p) {
  ProblemaDeLaCaja.sinNombre => 'Ponele un nombre.',
  ProblemaDeLaCaja.nombreLargo =>
    'El nombre es largo: hasta $largoDelNombreDeCaja letras.',
  ProblemaDeLaCaja.nombreSinLetras =>
    'El nombre tiene que tener al menos una letra o un número.',
  ProblemaDeLaCaja.nombreRepetido =>
    'Ya hay una caja que se llama así. La tienda dejaría afuera a las dos.',
  ProblemaDeLaCaja.faltanVinos => textoFaltan(faltan),
};

/// Lo que dice la pantalla cuando `guardarCajasSugeridas` no guardo.
String textoDelFalloDeLasCajas(FalloDeLasCajas f) => switch (f.error) {
  ErrorDeLasCajas.sinPermiso =>
    'Tu cuenta no tiene permiso para esto. Si te lo acaban de dar, salí y '
        'volvé a entrar.',
  ErrorDeLasCajas.sinConexion =>
    'No hay conexión: no se guardó. Revisá internet y probá de nuevo.',
  ErrorDeLasCajas.noCierra =>
    'No se guardó: ${f.caja == null ? 'una caja' : '"${f.caja}"'} tiene un '
        'vino que ya no existe o que viene en su propia caja. Cambialo y '
        'probá de nuevo.',
  ErrorDeLasCajas.noValida =>
    'No se guardó: alguien cambió las cajas al mismo tiempo. Mirá cómo '
        'quedaron y probá de nuevo.',
  ErrorDeLasCajas.desconocido =>
    'Algo falló y no se guardó. Probá de nuevo en un rato; si sigue, '
        'avisale al desarrollador.',
};
