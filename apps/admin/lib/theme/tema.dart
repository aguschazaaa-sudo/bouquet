import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// El tema del panel (la mezcla C). Las pantallas piden colores a
/// `Theme.of(context).colorScheme` y nunca a `Tokens`: asi un color cambia en
/// un solo lugar.
///
/// Como se reparte la paleta en el esquema de Material:
///
/// | Rol               | Token          | Uso                                  |
/// |-------------------|----------------|--------------------------------------|
/// | primary           | borgona        | La accion principal y los errores    |
/// | secondary         | dorado         | La marca y la pestana activa, sobre la banda |
/// | surface           | blanco         | Las superficies                      |
/// | onSurface         | tinta1         | El texto                             |
/// | onSurfaceVariant  | tinta3         | Lo accesorio                         |
/// | outline           | tinta3         | El borde de un control               |
/// | outlineVariant    | regla          | Divisiones sin informacion           |
/// | surfaceContainerHighest | papelVentana | Los avisos                      |
/// | inverseSurface    | tinta          | La banda y la barra                  |
/// | onInverseSurface  | marfil         | El texto sobre la banda              |
ThemeData temaDelPanel() {
  const esquema = ColorScheme(
    brightness: Brightness.light,
    primary: Tokens.borgona,
    onPrimary: Tokens.blanco,
    secondary: Tokens.dorado,
    onSecondary: Tokens.tinta,
    error: Tokens.borgona,
    onError: Tokens.blanco,
    surface: Tokens.blanco,
    onSurface: Tokens.tinta1,
    onSurfaceVariant: Tokens.tinta3,
    surfaceContainerLowest: Tokens.blanco,
    surfaceContainerLow: Tokens.papelHondo,
    surfaceContainer: Tokens.papelHondo,
    surfaceContainerHigh: Tokens.papelVentana,
    surfaceContainerHighest: Tokens.papelVentana,
    outline: Tokens.tinta3,
    outlineVariant: Tokens.regla,
    inverseSurface: Tokens.tinta,
    onInverseSurface: Tokens.marfil,
    inversePrimary: Tokens.dorado,
    primaryContainer: Tokens.papelVentana,
    onPrimaryContainer: Tokens.tinta1,
    secondaryContainer: Tokens.papelVentana,
    onSecondaryContainer: Tokens.tinta1,
  );

  final base = ThemeData(colorScheme: esquema, useMaterial3: true);
  final texto = GoogleFonts.archivoTextTheme(
    base.textTheme,
  ).apply(bodyColor: Tokens.tinta1, displayColor: Tokens.tinta1);

  final forma = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Medidas.radio),
  );
  const etiquetaDeBoton = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  OutlineInputBorder borde(Color color, [double ancho = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(Medidas.radio),
        borderSide: BorderSide(color: color, width: ancho),
      );

  return base.copyWith(
    scaffoldBackgroundColor: Tokens.papelHondo,
    textTheme: texto,
    dividerTheme: const DividerThemeData(color: Tokens.regla, thickness: 1),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: Tokens.blanco,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: GoogleFonts.archivo(fontSize: 15, color: Tokens.tinta2),
      border: borde(Tokens.tinta3),
      enabledBorder: borde(Tokens.tinta3),
      focusedBorder: borde(Tokens.borgona, 2),
      errorBorder: borde(Tokens.borgona),
      focusedErrorBorder: borde(Tokens.borgona, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, Medidas.boton),
        shape: forma,
        textStyle: GoogleFonts.archivo(textStyle: etiquetaDeBoton),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, Medidas.boton),
        shape: forma,
        foregroundColor: Tokens.tinta1,
        side: const BorderSide(color: Tokens.tinta3),
        textStyle: GoogleFonts.archivo(
          textStyle: etiquetaDeBoton.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, Medidas.tactil),
        foregroundColor: Tokens.borgona,
        textStyle: GoogleFonts.archivo(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Tokens.borgona,
    ),
  );
}

/// La serif de la marca. Sólo para nombres: la marca y, desde EP-03, los
/// vinos. Todo lo demás es Archivo, y las cifras van con
/// `FontFeature.tabularFigures()` para que una columna no baile.
TextStyle estiloDeNombre({
  double tamano = 19,
  FontWeight peso = FontWeight.w500,
}) => GoogleFonts.newsreader(fontSize: tamano, fontWeight: peso);
