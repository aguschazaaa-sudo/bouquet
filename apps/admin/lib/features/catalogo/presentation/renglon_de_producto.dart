import 'package:flutter/material.dart';

import '../../../core/contratos/plata.dart';
import '../../../theme/tema.dart';
import '../../../theme/tokens.dart';
import '../domain/catalogo.dart';
import '../domain/producto_del_panel.dart';
import 'motivo_corto_de_tienda.dart';

/// Un vino en la lista del catalogo (HU-03.1). El renglon de la libreta: la
/// linea de abajo es `filetePapel`, no una `Divider` gris.
///
/// **Tocarlo abre su correccion (HU-03.4).** Es la unica puerta a
/// `/catalogo/vinos/<id>`: sin ella la pagina existe y nadie la abre.
class RenglonDeProducto extends StatelessWidget {
  const RenglonDeProducto({
    super.key,
    required this.renglon,
    required this.alAbrir,
    this.motivoCorto,
  });

  final RenglonDelCatalogo renglon;
  final VoidCallback alAbrir;

  /// Corto: publicado, pero la tienda igual lo descarta (HU-03.7).
  final String? motivoCorto;

  @override
  Widget build(BuildContext context) {
    final p = renglon.producto;
    final bodega = renglon.bodega?.nombre ?? '';
    final sinBodega = renglon.bodega == null;

    return Semantics(
      // Un solo nodo por renglon: sin esto el lector de pantalla lee cuatro
      // fragmentos sueltos y hay que armar el vino en la cabeza.
      container: true,
      button: true,
      label: _paraLeer(p, bodega, sinBodega, motivoCorto),
      hint: 'Corregir',
      excludeSemantics: true,
      onTap: alAbrir,
      child: InkWell(
        onTap: alAbrir,
        child: _cuerpo(context, p, bodega, sinBodega),
      ),
    );
  }

  Widget _cuerpo(
    BuildContext context,
    ProductoDelPanel p,
    String bodega,
    bool sinBodega,
  ) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Tokens.filetePapel)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre.isEmpty ? 'Sin nombre' : p.nombre,
                  style: estiloDeNombre(),
                ),
                const SizedBox(height: 4),
                _Procedencia(bodega: bodega, sinBodega: sinBodega),
                if (p.botellas > 1) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Viene en caja de ${p.botellas}',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                enPesos(p.precio),
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  // Sin esto la columna de precios baila renglon a renglon.
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              _EnLaTienda(publicado: p.publicado),
              if (motivoCorto case final motivo?)
                MotivoCortoDeTienda(texto: motivo),
            ],
          ),
        ],
      ),
    );
  }

  /// Lo que oye quien no ve la pantalla, en el orden en que importa.
  static String _paraLeer(
    ProductoDelPanel p,
    String bodega,
    bool sinBodega,
    String? motivoCorto,
  ) {
    final partes = [
      p.nombre.isEmpty ? 'Sin nombre' : p.nombre,
      if (sinBodega) 'sin bodega, no aparece en la tienda' else bodega,
      enPesos(p.precio),
      if (p.publicado) 'en la tienda' else 'no está en la tienda',
      if (motivoCorto != null) 'pero la tienda no lo muestra: $motivoCorto',
    ];
    return partes.join('. ');
  }
}

/// La bodega, o el aviso de que no existe.
class _Procedencia extends StatelessWidget {
  const _Procedencia({required this.bodega, required this.sinBodega});

  final String bodega;
  final bool sinBodega;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (!sinBodega) {
      return Text(
        bodega.isEmpty ? 'Bodega sin nombre' : bodega,
        style: tema.textTheme.bodyMedium?.copyWith(
          color: tema.colorScheme.onSurfaceVariant,
        ),
      );
    }
    // ⚠️ Este es el caso que `armarCatalogo` descarta SIN AVISAR: un producto
    // de una bodega inexistente no aparece en la vidriera y hoy eso solo se
    // lee en el log del build (ADR 008 §2).
    return Row(
      children: [
        Icon(Icons.error_outline, size: 16, color: tema.colorScheme.error),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Sin bodega: no aparece en la tienda',
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

/// Si la vidriera lo muestra. Lo normal no se anuncia con color: el que
/// resalta es el que falta terminar.
class _EnLaTienda extends StatelessWidget {
  const _EnLaTienda({required this.publicado});

  final bool publicado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // `null` y no un transparente literal: `no-hardcoded-colors.sh` no
        // deja un solo color escrito a mano fuera de `theme/`, y tiene razon
        // — la excepcion del "es solo transparente" es por donde empieza.
        color: publicado ? tema.colorScheme.surfaceContainerHighest : null,
        borderRadius: BorderRadius.circular(6),
        border: publicado
            ? null
            : Border.all(color: tema.colorScheme.onSurfaceVariant),
      ),
      child: Text(
        publicado ? 'En la tienda' : 'Sin publicar',
        style: tema.textTheme.labelSmall?.copyWith(
          color: tema.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
