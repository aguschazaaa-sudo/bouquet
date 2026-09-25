/// Lo que se escribe en la Orden al anotar (HU-07.7), **sin Firebase adentro**
/// para que `dart test` lo pueda cargar. Mismo reparto que
/// `cambios_de_entrega.dart`.
///
/// Solo `notasOperador` y `actualizadaEn`: es lo que acepta `anota()` en las
/// reglas. **No lleva `estadoEntrega`**, asi que anotar nunca pisa un paso que
/// otra persona dio mientras se escribia.
library;

/// [nota] ya pasada por `notaAGuardar`. `null` borra la nota con [borrar], que
/// es `FieldValue.delete()`: las reglas aceptan un pedido sin la clave.
/// [horaDelServidor] es `FieldValue.serverTimestamp()`.
Map<String, Object?> cambiosDeNota(
  String? nota, {
  required Object horaDelServidor,
  required Object borrar,
}) => {'notasOperador': nota ?? borrar, 'actualizadaEn': horaDelServidor};
