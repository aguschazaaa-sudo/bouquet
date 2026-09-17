import 'package:flutter/painting.dart';

/// Los colores del panel. Este archivo y `tema.dart` son los UNICOS lugares
/// de `lib/` con literales de color (`no-hardcoded-colors.sh`).
///
/// Los nombres son los de `docs/vault/design/tokens.md` y los valores son los
/// que resuelve `apps/tienda/src/shared/tokens/tokens.css`: los `color-mix()`
/// calculados en srgb u oklab, igual que el navegador. Controles del calculo:
/// negro sobre blanco 21,00 y dorado sobre tinta 8,80, el mismo numero que
/// midio `direccion.md §2.1`.
///
/// La mezcla C (2026-09-16): los colores de la planilla —banda de tinta con el
/// dorado, superficies blancas sobre papel hondo— con la busqueda y los
/// renglones de la libreta.
abstract final class Tokens {
  // La marca. Salen del PNG del logo, no del PDF (direccion.md §2.0).
  static const borgona = Color(0xFF762D2D);
  static const dorado = Color(0xFFD2AE6D);

  // La banda: la unica superficie oscura del panel.
  static const tinta = Color(0xFF1A1210);

  /// Sobre la banda. El `--marfil-2` de la vidriera (marfil 76 % sobre
  /// tinta, 9,59:1) sale de pintar este color con alpha 0.76 encima de la
  /// banda: las pestanas que no estan activas.
  static const marfil = Color(0xFFF5EFE4);

  // El papel: el fondo de todas las pantallas.
  static const blanco = Color(0xFFFFFFFF);

  /// marfil 92 % + dorado, oklab. El fondo detras de las superficies.
  static const papelHondo = Color(0xFFF2EADB);

  /// marfil 84 % + dorado, oklab. Detras de la botella y de los avisos.
  static const papelVentana = Color(0xFFEFE5D1);

  static const tinta1 = tinta;

  /// tinta 80 % + marfil: 10,43:1 sobre blanco.
  static const tinta2 = Color(0xFF463E3A);

  /// tinta 64 % + marfil: 6,03 sobre blanco y 5,04 sobre papel hondo. El
  /// piso del texto, y el borde de todo control.
  static const tinta3 = Color(0xFF69625C);

  /// tinta 16 % + marfil: 1,60 sobre blanco. Divisiones SIN informacion;
  /// nunca el unico borde de un control.
  static const regla = Color(0xFFD2CCC2);

  /// `--filete-papel` de la vidriera. 3,86 sobre blanco: alcanza para una
  /// linea que se VE —el renglon de la libreta, la direccion visual que
  /// eligio el dueno— y no para texto. Mas fuerte que `regla`, que a 1,60 no
  /// se distingue del papel a un metro del deposito.
  static const filetePapel = Color(0xFF997E51);
}

/// Las medidas que se repiten.
abstract final class Medidas {
  static const radio = 10.0;
  static const radioSuperficie = 12.0;

  /// El minimo tactil. 44 lo pide la guia; los botones del panel van a 52
  /// porque los usa gente parada en el deposito.
  static const tactil = 44.0;
  static const boton = 52.0;

  /// Desde este ancho la navegacion va arriba; por debajo, abajo.
  static const anchoDeEscritorio = 840.0;

  static const banda = 64.0;
}
