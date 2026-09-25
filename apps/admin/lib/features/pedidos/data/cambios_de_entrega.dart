/// Lo que se escribe en la Orden por cada paso del eje de entrega, **sin
/// Firebase adentro** para que `dart test` lo pueda cargar. EP-07, ADR 019.
///
/// Cada paso escribe su estado, `actualizadaEn` y, si lo lleva, SU campo -- y
/// ningun otro: las reglas rechazan una clave de mas (`editaSolo`), asi que un
/// mapa con algo extra no es un detalle, es un boton que siempre falla.
library;

import '../domain/paso_de_entrega.dart';

/// [horaDelServidor] es `FieldValue.serverTimestamp()`, que pasa quien llama:
/// las reglas exigen que `despacho.en` y `entregaFallida.en` sean la hora del
/// servidor, no la del telefono.
Map<String, Object?> cambiosDe(
  PasoDeEntrega paso, {
  required Object horaDelServidor,
}) {
  final base = <String, Object?>{
    'estadoEntrega': paso.destino.name,
    'actualizadaEn': horaDelServidor,
  };
  return switch (paso) {
    Preparar() || Entregar() => base,
    Despachar(:final correo, :final seguimiento) => {
      ...base,
      // `seguimiento` va SIEMPRE, aunque sea null: las reglas piden la clave.
      'despacho': {
        'correo': correo.clave,
        'seguimiento': seguimiento,
        'en': horaDelServidor,
      },
    },
    NoSeEntrego(:final motivo) => {
      ...base,
      'entregaFallida': {'motivo': motivo.clave, 'en': horaDelServidor},
    },
  };
}
