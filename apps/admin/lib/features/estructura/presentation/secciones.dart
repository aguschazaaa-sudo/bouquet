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

/// Las secciones del panel, en orden (HU-01.5). Una ruta sin entrada en esta
/// lista es una pagina huerfana. Resumen (EP-11) va primera: es a donde se
/// entra. Vidriera (EP-09) va ultima: se usa de vez en cuando, y Catalogo y
/// Pedidos todos los dias.
const secciones = [
  Seccion(
    titulo: 'Resumen',
    ruta: Rutas.resumen,
    icono: Icons.today_outlined,
    iconoActivo: Icons.today,
  ),
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
  Seccion(
    titulo: 'Vidriera',
    ruta: Rutas.vidriera,
    icono: Icons.storefront_outlined,
    iconoActivo: Icons.storefront,
  ),
];
