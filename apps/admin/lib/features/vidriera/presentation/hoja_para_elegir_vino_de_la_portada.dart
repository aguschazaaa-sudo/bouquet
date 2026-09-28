import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contratos/texto.dart';
import '../../../core/presentation/cargando.dart';
import '../../../core/presentation/fallo_con_reintento.dart';
import '../../../theme/tema.dart';
import '../../catalogo/catalogo_providers.dart';
import '../../catalogo/domain/catalogo.dart';
import '../../catalogo/domain/producto_del_panel.dart';
import '../domain/seleccion_de_la_portada.dart';
import 'textos_de_la_vidriera.dart';

/// Elegir un vino para la portada, de la lista que **ya esta en memoria**:
/// abrirla no lee nada de Firestore. Se busca escribiendo, sin acentos ni
/// mayusculas.
///
/// Un vino que no puede ir **no desaparece**: aparece deshabilitado y dice
/// por que (ya esta, no se ve en la tienda, viene en caja, sin stock). Mismo
/// criterio que la hoja de los pedidos: uno que desaparece es alguien
/// preguntandose donde esta.
///
/// Devuelve el id elegido, o `null` si se cerro sin elegir.
class HojaParaElegirVinoDeLaPortada extends ConsumerStatefulWidget {
  const HojaParaElegirVinoDeLaPortada({super.key, required this.seleccion});

  final SeleccionDeLaPortada seleccion;

  static Future<String?> mostrar(
    BuildContext context,
    SeleccionDeLaPortada seleccion,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => HojaParaElegirVinoDeLaPortada(seleccion: seleccion),
    );
  }

  @override
  ConsumerState<HojaParaElegirVinoDeLaPortada> createState() =>
      _HojaParaElegirVinoDeLaPortadaState();
}

class _HojaParaElegirVinoDeLaPortadaState
    extends ConsumerState<HojaParaElegirVinoDeLaPortada> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final catalogo = ref.watch(catalogoProvider);
    final tema = Theme.of(context);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(textoElegirParaLaPortada, style: tema.textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: textoBuscarUnVino,
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (t) => setState(() => _busqueda = t),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (catalogo) {
              AsyncError() => FalloConReintento(
                texto: textoNoSePudieronLeer,
                alReintentar: () {
                  ref.invalidate(productosProvider);
                  ref.invalidate(bodegasProvider);
                },
              ),
              AsyncData(:final value) => _Lista(
                catalogo: value,
                productos: _filtrar(value),
                seleccion: widget.seleccion,
                alElegir: (id) => Navigator.of(context).pop(id),
              ),
              _ => const Cargando(que: 'Buscando tus vinos…'),
            },
          ),
        ],
      ),
    );
  }

  /// Los que coinciden con lo escrito, por nombre y ordenados por nombre
  /// (el catalogo ya viene ordenado). Sin texto, todos.
  List<ProductoDelPanel> _filtrar(Catalogo catalogo) {
    final q = clave(_busqueda);
    return [
      for (final r in catalogo.renglones)
        if (q.isEmpty || clave(r.producto.nombre).contains(q)) r.producto,
    ];
  }
}

class _Lista extends StatelessWidget {
  const _Lista({
    required this.catalogo,
    required this.productos,
    required this.seleccion,
    required this.alElegir,
  });

  final Catalogo catalogo;
  final List<ProductoDelPanel> productos;
  final SeleccionDeLaPortada seleccion;
  final ValueChanged<String> alElegir;

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) {
      return const Center(child: Text(textoNoHayVinos));
    }
    final tema = Theme.of(context);
    return ListView.builder(
      itemCount: productos.length,
      itemBuilder: (_, i) {
        final p = productos[i];
        final yaEsta = seleccion.contiene(p.id);
        final fuera = fueraDeLaPortada(p, catalogo);
        final sePuede = !yaEsta && fuera == null;
        final bodega = catalogo.bodega(p.bodegaId)?.nombre;
        final detalle = yaEsta
            ? textoYaEstaEnLaPortada
            : fuera != null
            ? textoFueraDeLaPortada(fuera)
            : bodega;
        return ListTile(
          enabled: sePuede,
          title: Text(p.nombre, style: estiloDeNombre()),
          subtitle: detalle == null
              ? null
              : Text(
                  detalle,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
          onTap: sePuede ? () => alElegir(p.id) : null,
        );
      },
    );
  }
}
