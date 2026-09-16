import 'package:flutter/material.dart';

import '../../../app/rutas.dart';

/// Una entrada de la navegacion.
class Seccion {
  const Seccion({
    required this.titulo,
    required this.ruta,
    required this.icono,
    required this.iconoActivo,
  });

  final String titulo;
  final String ruta;
  final IconData icono;
  final IconData iconoActivo;

  bool estaActiva(String ubicacion) =>
      ubicacion == ruta || ubicacion.startsWith('$ruta/');
}

/// Las secciones del panel, en orden (HU-01.5). La vidriera curada (EP-09)
/// se suma aca el dia que tenga ruta: una ruta sin entrada en esta lista es
/// una pagina huerfana.
const secciones = [
  Seccion(
    titulo: 'Catálogo',
    ruta: Rutas.catalogo,
    icono: Icons.wine_bar_outlined,
    iconoActivo: Icons.wine_bar,
  ),
  Seccion(
    titulo: 'Pedidos',
    ruta: Rutas.pedidos,
    icono: Icons.receipt_long_outlined,
    iconoActivo: Icons.receipt_long,
  ),
];
