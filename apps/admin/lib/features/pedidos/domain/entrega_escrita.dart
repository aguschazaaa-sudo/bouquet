import '../../../core/contratos/pedido.dart';
import '../../../core/contratos/provincias.dart';
import '../../../core/contratos/telefono.dart';

/// Los campos del formulario de "a quien y a donde", **en el orden en que se
/// llenan**: el primer problema es el que se marca.
enum CampoDeEntrega {
  nombre,
  telefono,
  email,
  calle,
  numero,
  codigoPostal,
  localidad,
  provincia,
}

/// Lo que el operador escribio de quien recibe y a donde va (HU-10.1).
///
/// **Espeja `validarDatosDeEntrega`** de `packages/contratos`, que es el mismo
/// validador que usa la vidriera y el que corre en el servidor. El panel valida
/// antes de mandar para no gastar un viaje, pero **quien decide es el
/// servidor**: si los dos difieren, el servidor rechaza con `invalid-argument`
/// y el formulario lo muestra como un fallo (`datosInvalidos`).
///
/// Son textos crudos, tal como se tipearon: el telefono se pega **como vino del
/// chat** y [telefonoNormalizado] dice como va a quedar.
class EntregaEscrita {
  const EntregaEscrita({
    this.nombre = '',
    this.telefono = '',
    this.email = '',
    this.calle = '',
    this.numero = '',
    this.piso = '',
    this.referencia = '',
    this.codigoPostal = '',
    this.localidad = '',
    this.provincia = '',
  });

  final String nombre;
  final String telefono;
  final String email;
  final String calle;
  final String numero;
  final String piso;
  final String referencia;
  final String codigoPostal;
  final String localidad;

  /// El codigo ISO (`X`), no el nombre.
  final String provincia;

  static final _forma = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _cuatroDigitos = RegExp(r'^\d{4}$');

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
    // El mail es opcional: en blanco esta bien, escrito tiene que tener forma.
    CampoDeEntrega.email =>
      email.trim().isEmpty ||
          (_forma.hasMatch(email.trim()) && _entra(email, 'email')),
    CampoDeEntrega.calle => calle.trim().length >= 2 && _entra(calle, 'calle'),
    CampoDeEntrega.numero =>
      numero.trim().isNotEmpty && _entra(numero, 'numero'),
    CampoDeEntrega.codigoPostal => _cuatroDigitos.hasMatch(codigoPostal.trim()),
    CampoDeEntrega.localidad =>
      localidad.trim().isNotEmpty && _entra(localidad, 'localidad'),
    CampoDeEntrega.provincia => esProvinciaIso(provincia),
  };

  /// El piso y la referencia son opcionales, pero con tope: no tienen un
  /// [CampoDeEntrega] propio porque estar vacios nunca bloquea el boton.
  bool get opcionalesEntran =>
      _entra(piso, 'piso') && _entra(referencia, 'referencia');

  /// El primer campo invalido en el orden del formulario, o `null` si esta todo.
  CampoDeEntrega? get primerProblema {
    for (final c in CampoDeEntrega.values) {
      if (!esValido(c)) return c;
    }
    return null;
  }

  /// Se puede mandar: ningun campo obligatorio falla y los opcionales entran.
  bool get sePuedeMandar => primerProblema == null && opcionalesEntran;

  EntregaEscrita copiarCon({
    String? nombre,
    String? telefono,
    String? email,
    String? calle,
    String? numero,
    String? piso,
    String? referencia,
    String? codigoPostal,
    String? localidad,
    String? provincia,
  }) => EntregaEscrita(
    nombre: nombre ?? this.nombre,
    telefono: telefono ?? this.telefono,
    email: email ?? this.email,
    calle: calle ?? this.calle,
    numero: numero ?? this.numero,
    piso: piso ?? this.piso,
    referencia: referencia ?? this.referencia,
    codigoPostal: codigoPostal ?? this.codigoPostal,
    localidad: localidad ?? this.localidad,
    provincia: provincia ?? this.provincia,
  );

  /// Lo que viaja a la callable. El telefono va **normalizado**: es lo que el
  /// operador vio antes de confirmar, y el servidor lo vuelve a normalizar a lo
  /// mismo (la normalizacion es idempotente y esta espejada con fixtures).
  Map<String, Object?> get aJson => {
    'nombre': nombre.trim(),
    'telefono': telefonoNormalizado ?? telefono.trim(),
    'email': email.trim(),
    'calle': calle.trim(),
    'numero': numero.trim(),
    'piso': piso.trim(),
    'referencia': referencia.trim(),
    'destino': {
      'codigoPostal': codigoPostal.trim(),
      'localidad': localidad.trim(),
      'provincia': provincia,
    },
  };
}
