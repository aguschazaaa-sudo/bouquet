/// El documento de una Orden, leido **sin Firebase adentro**.
///
/// Vive aparte del repositorio para que `dart test` lo pueda cargar:
/// `cloud_firestore` arrastra Flutter. La hora llega ya convertida.
library;

import '../../../core/contratos/despacho.dart';
import '../../../core/contratos/estado_entrega.dart';
import '../../../core/contratos/estado_pago.dart';
import '../../../core/contratos/pedido.dart';
import '../../catalogo/data/campos.dart';
import '../domain/despacho_de_orden.dart';
import '../domain/orden.dart';

/// `null` si el documento **no se puede leer como una Orden**: falta lo que la
/// define (`numero`, los dos estados, el origen, los `items`, el total) o trae un
/// valor que este panel no conoce.
///
/// **Nunca lanza.** El Admin SDK no pasa por las reglas, asi que un documento
/// roto PUEDE existir; el repositorio los cuenta y la pantalla dice cuantos hay,
/// en vez de esconderlos. Un pedido que el operador no ve es un pedido que no
/// prepara.
///
/// Lo que se perdona: el contacto y la entrega. Sus textos vienen `''` si faltan
/// y la pantalla los muestra como se pueda, porque con el numero y los items
/// alcanza para reconocer el pedido. Y lo de EP-07 -`despacho`, `entregaFallida`,
/// `cancelacion`-: uno raro queda en `null` y el pedido se ve igual.
///
/// [horaDe] convierte un `Timestamp` anidado (`despacho.en`) sin que este
/// archivo conozca Firebase: la pasa el repositorio.
Orden? ordenDesde(
  String id,
  Map<String, Object?> datos, {
  DateTime? creadaEn,
  DateTime? Function(Object?) horaDe = _sinHora,
}) {
  final numero = enteroDe(datos['numero']);
  final total = enteroDe(datos['total']);
  final origen = Origen.desde(datos['origen']);
  final estadoPago = _estadoPago(datos['estadoPago']);
  final estadoEntrega = _estadoEntrega(datos['estadoEntrega']);
  if (numero == null ||
      total == null ||
      origen == null ||
      estadoPago == null ||
      estadoEntrega == null) {
    return null;
  }

  final items = _items(datos['items']);
  if (items == null) return null;

  final contacto = mapaDe(datos['contacto']);
  final entrega = mapaDe(datos['entrega']);
  final destino = mapaDe(entrega['destino']);

  return Orden(
    id: id,
    numero: numero,
    origen: origen,
    estadoPago: estadoPago,
    estadoEntrega: estadoEntrega,
    items: items,
    // Sin subtotal escrito, es el total: con `envio: null` son lo mismo.
    subtotal: enteroDe(datos['subtotal']) ?? total,
    total: total,
    contacto: ContactoDeOrden(
      nombre: textoDe(contacto['nombre']),
      telefonoE164: textoDe(contacto['telefonoE164']),
      email: textoOpcionalDe(contacto['email']),
    ),
    entrega: EntregaDeOrden(
      calle: textoDe(entrega['calle']),
      numero: textoDe(entrega['numero']),
      piso: textoOpcionalDe(entrega['piso']),
      referencia: textoOpcionalDe(entrega['referencia']),
      codigoPostal: textoDe(destino['codigoPostal']),
      localidad: textoDe(destino['localidad']),
      provincia: textoDe(destino['provincia']),
    ),
    creadaEn: creadaEn,
    notasOperador: textoOpcionalDe(datos['notasOperador']),
    despacho: _despacho(datos['despacho'], horaDe),
    entregaFallida: _entregaFallida(datos['entregaFallida'], horaDe),
    cancelacion: _cancelacion(datos['cancelacion'], horaDe),
  );
}

DateTime? _sinHora(Object? _) => null;

DespachoDeOrden? _despacho(Object? valor, DateTime? Function(Object?) hora) {
  if (valor is! Map) return null;
  final correo = Correo.desde(valor['correo']);
  if (correo == null) return null;
  return DespachoDeOrden(
    correo: correo,
    seguimiento: textoOpcionalDe(valor['seguimiento']),
    en: hora(valor['en']),
  );
}

EntregaFallida? _entregaFallida(
  Object? valor,
  DateTime? Function(Object?) hora,
) {
  if (valor is! Map) return null;
  final motivo = MotivoDeFalla.desde(valor['motivo']);
  if (motivo == null) return null;
  return EntregaFallida(motivo: motivo, en: hora(valor['en']));
}

/// Una cancelacion se lee aunque traiga un motivo desconocido: lo que importa
/// que se vea es `sinReponer`, lo que una persona tiene que resolver.
CancelacionDeOrden? _cancelacion(
  Object? valor,
  DateTime? Function(Object?) hora,
) {
  if (valor is! Map) return null;
  return CancelacionDeOrden(
    motivo: MotivoDeCancelacion.desde(valor['motivo']),
    en: hora(valor['en']),
    sinReponer: lineasSinReponerDesde(valor['sinReponer']),
  );
}

/// Las lineas que no volvieron al stock, de la Orden o de la respuesta de
/// `cancelarOrden` (la misma forma). Una linea sin id o sin cantidad no se
/// inventa: se saltea.
///
/// La cantidad se lee con [_unidades] y no con `enteroDe`: en la web la respuesta
/// de una callable puede traer un entero como `double`, y `enteroDe` lo daria por
/// ausente -- la linea que una persona tiene que resolver desapareceria.
List<LineaSinReponer> lineasSinReponerDesde(Object? valor) {
  if (valor is! List) return const [];
  return [
    for (final crudo in valor)
      if (crudo is Map)
        if ((crudo['productoId'], _unidades(crudo['cantidad'])) case (
          final String productoId,
          final int cantidad,
        ))
          LineaSinReponer(
            productoId: productoId,
            nombre: textoOpcionalDe(crudo['nombre']) ?? productoId,
            cantidad: cantidad,
            motivo: MotivoSinReponer.desde(crudo['motivo']),
          ),
  ];
}

EstadoPago? _estadoPago(Object? valor) {
  for (final e in EstadoPago.values) {
    if (e.name == valor) return e;
  }
  return null;
}

EstadoEntrega? _estadoEntrega(Object? valor) {
  for (final e in EstadoEntrega.values) {
    if (e.name == valor) return e;
  }
  return null;
}

/// `null` si `items` no es una lista no vacia de lineas validas: una Orden sin
/// nada que preparar no es una Orden.
List<ItemDeOrden>? _items(Object? valor) {
  if (valor is! List || valor.isEmpty) return null;
  final items = <ItemDeOrden>[];
  for (final crudo in valor) {
    if (crudo is! Map) return null;
    final m = mapaDe(crudo);
    final cantidad = enteroDe(m['cantidad']);
    final precio = enteroDe(m['precioUnitario']);
    final botellas = enteroDe(m['botellas']);
    final nombre = m['nombre'];
    final productoId = m['productoId'];
    if (cantidad == null ||
        cantidad < 1 ||
        precio == null ||
        botellas == null ||
        botellas < 1 ||
        nombre is! String ||
        productoId is! String) {
      return null;
    }
    items.add(
      ItemDeOrden(
        productoId: productoId,
        nombre: nombre,
        precioUnitario: precio,
        cantidad: cantidad,
        botellas: botellas,
      ),
    );
  }
  return items;
}

int? _unidades(Object? valor) =>
    valor is num && valor.isFinite && valor == valor.truncateToDouble()
    ? valor.toInt()
    : null;
