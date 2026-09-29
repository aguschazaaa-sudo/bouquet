import '../../../core/contratos/plata.dart';
import '../../../core/presentation/cuando_se_ve.dart';
import '../domain/envio_sin_cargo.dart';

/// Lo que dice el bloque de la entrega sin cargo (HU-11.1, ADR 026). Aparte de
/// `textos_de_la_vidriera.dart` para que ninguno de los dos pase las 200
/// lineas de `widget-size-guard`.

const textoTituloDelEnvio = 'La entrega sin cargo';

const textoQueEsElEnvio =
    'Desde qué monto de vinos no se cobra la entrega, para que convenga '
    'llevar más. Vale para todas las formas de entrega.';

String textoEnvioDesde(int centavos) =>
    'Desde ${enPesos(centavos)} en vinos, la entrega sale sin cargo.';

const textoEnvioApagado = 'Hoy la entrega se cobra siempre.';

/// El documento existe y no se puede leer: la tienda cobra la entrega, que es
/// lo seguro, y hay que volver a fijarlo.
const textoEnvioRoto =
    'El monto guardado no se puede leer, así que la tienda cobra la entrega. '
    'Volvé a fijarlo.';

const textoFijarMonto = 'Fijar un monto';
const textoCambiarMonto = 'Cambiar el monto';
const textoCobrarSiempre = 'Cobrar siempre la entrega';

const textoCampoDelMonto = 'Desde cuánto, en pesos';
const textoAyudaDelMonto = 'La suma de los vinos, sin la entrega.';
const textoEscribiUnMonto = 'Escribí un monto.';
const textoGuardarMonto = 'Guardar';
const textoCancelar = 'Cancelar';

// --------------------------------------------------- la baranda del servidor

const textoAntesDeGuardar = '¿Lo guardo así?';
const textoGuardarIgual = 'Guardar igual';
const textoCorregirlo = 'Corregirlo';

/// Por que la callable pregunta, con los dos montos a la vista: el que se
/// escribio y el que lo hace sospechoso.
String textoDeLaPregunta(int monto, PideConfirmar pregunta) =>
    switch (pregunta.motivo) {
      MotivoParaConfirmar.debajoDeUnaCaja =>
        'Con ${enPesos(monto)}, una caja de seis a precio típico '
            '(${enPesos(pregunta.referencia)}) ya llega: casi todos los '
            'pedidos van a salir sin cargo.',
      MotivoParaConfirmar.menosDeLaMitad =>
        '${enPesos(monto)} es menos de la mitad de lo que había '
            '(${enPesos(pregunta.referencia)}).',
    };

// ------------------------------------------------------------- despues

/// HU-09.4: despues de guardar, cuando se ve. `/pedido` se rearma como el
/// catalogo, asi que tarda lo mismo.
const textoEnvioGuardado = 'Guardado. $textoTardaEnLaTienda';
const textoEnvioApagadoGuardado =
    'Listo: la entrega se cobra siempre. $textoTardaEnLaTienda';

String textoDelFalloDelEnvio(ErrorDelEnvio e) => switch (e) {
  ErrorDelEnvio.sinPermiso =>
    'Tu cuenta no tiene permiso para cambiarlo. Volvé a entrar.',
  ErrorDelEnvio.sinConexion =>
    'No se pudo guardar: no hay conexión. Probá de nuevo.',
  ErrorDelEnvio.noValido =>
    'Ese monto no se puede guardar: va en pesos enteros, hasta 100 millones.',
  ErrorDelEnvio.desconocido =>
    'No se pudo confirmar si se guardó. Mirá el monto de arriba antes de '
        'volver a intentar.',
};
