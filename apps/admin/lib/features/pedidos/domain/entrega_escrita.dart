import '../../../core/contratos/pedido.dart';
import '../../../core/contratos/telefono.dart';

/// Los campos obligatorios del formulario de "a quien y a donde", **en el orden
/// en que se llenan**: el primer problema es el que se marca.
///
/// Cuatro, no siete (ADR 027): el codigo postal, la provincia y el numero
/// aparte eran de la vidriera, que cotiza con ellos. Un pedido de WhatsApp no
/// cotiza -el precio y el correo se arreglan por el chat, la etiqueta se hace a
/// mano-, asi que no evitaban ninguna perdida.
enum CampoDeEntrega { nombre, telefono, direccion, localidad }

/// Lo que el operador escribio de quien recibe y a donde va (HU-10.1).
///
/// **Espeja `validarEntregaDelPanel`** de `packages/contratos`, el que corre en
/// el servidor. El panel valida antes de mandar para no gastar un viaje, pero
/// **quien decide es el servidor**: si los dos difieren, el servidor rechaza con
/// `invalid-argument` y el formulario lo muestra como un fallo
/// (`datosInvalidos`).
///
/// Son textos crudos, tal como se tipearon: el telefono se pega **como vino del
/// chat** y [telefonoNormalizado] dice como va a quedar.
class EntregaEscrita {
  const EntregaEscrita({
    this.nombre = '',
    this.telefono = '',
    this.direccion = '',
    this.detalle = '',
    this.localidad = '',
  });

  final String nombre;
  final String telefono;

  /// Calle y numero juntos, como se dicen: *"San Martín 120"*. Viaja como
  /// `calle`.
  final String direccion;

  /// Piso, depto o referencia, en uno y opcional. Viaja como `referencia`.
  final String detalle;
  final String localidad;

  /// `null` si el numero no se puede normalizar. Es lo que se le muestra al
  /// operador ANTES de confirmar, y lo que viaja al servidor.
  String? get telefonoNormalizado => normalizarTelefonoAR(telefono);

  /// `true` si [texto], sin los espacios de los costados, entra en el largo del
  /// campo [clave] (`largosDeEntrega`): los mismos topes que el servidor.
  static bool _entra(String texto, String clave) =>
      texto.trim().length <= largosDeEntrega[clave]!;

  bool esValido(CampoDeEntrega campo) => switch (campo) {
    CampoDeEntrega.nombre =>
      nombre.trim().length >= 2 && _entra(nombre, 'nombre'),
    CampoDeEntrega.telefono => telefonoNormalizado != null,
    CampoDeEntrega.direccion =>
      direccion.trim().length >= 2 && _entra(direccion, 'calle'),
    CampoDeEntrega.localidad =>
      localidad.trim().isNotEmpty && _entra(localidad, 'localidad'),
  };

  /// El detalle es opcional, pero con tope: no tiene un [CampoDeEntrega] propio
  /// porque estar vacio nunca bloquea el boton.
  bool get opcionalesEntran => _entra(detalle, 'referencia');

  /// El primer campo invalido en el orden del formulario, o `null` si esta todo.
  CampoDeEntrega? get primerProblema {
    for (final c in CampoDeEntrega.values) {
      if (!esValido(c)) return c;
    }
    return null;
  }

  /// Se puede mandar: ningun campo obligatorio falla y el opcional entra.
  bool get sePuedeMandar => primerProblema == null && opcionalesEntran;

  EntregaEscrita copiarCon({
    String? nombre,
    String? telefono,
    String? direccion,
    String? detalle,
    String? localidad,
  }) => EntregaEscrita(
    nombre: nombre ?? this.nombre,
    telefono: telefono ?? this.telefono,
    direccion: direccion ?? this.direccion,
    detalle: detalle ?? this.detalle,
    localidad: localidad ?? this.localidad,
  );

  /// Lo que viaja a la callable, en la forma corta de `validarEntregaDelPanel`:
  /// sin numero aparte, sin codigo postal, sin provincia y sin mail, que el
  /// servidor escribe `null`. El telefono va **normalizado**: es lo que el
  /// operador vio antes de confirmar, y el servidor lo vuelve a normalizar a lo
  /// mismo (la normalizacion es idempotente y esta espejada con fixtures).
  Map<String, Object?> get aJson => {
    'nombre': nombre.trim(),
    'telefono': telefonoNormalizado ?? telefono.trim(),
    'calle': direccion.trim(),
    'referencia': detalle.trim(),
    'destino': {'localidad': localidad.trim()},
  };
}
