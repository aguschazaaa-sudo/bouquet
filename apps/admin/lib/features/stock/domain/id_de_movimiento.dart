import 'dart:math';

/// Un `idMovimiento` nuevo: 32 caracteres hexadecimales, que entran en los 16
/// a 64 de `[A-Za-z0-9_-]` que acepta el parser de `contratos`.
///
/// Es la clave de idempotencia de `moverStock`. Se genera **al abrir la
/// hoja**, no al apretar el boton: un doble toque o un reintento tras un
/// timeout reusan el mismo y la callable los reconoce como UN movimiento. Si
/// se generara al apretar, cada toque seria un movimiento distinto y la
/// reposicion se sumaria dos veces.
///
/// `Random.secure()` y no `Random()`: dos operadores con la hoja abierta a la
/// vez no pueden chocar de id.
String nuevoIdDeMovimiento([Random? azar]) {
  final r = azar ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
