import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contratos/plata.dart';
import '../../../core/contratos/texto.dart';
import '../../../core/presentation/cargando.dart';
import '../../../core/presentation/fallo_con_reintento.dart';
import '../../../theme/tema.dart';
import '../../catalogo/catalogo_providers.dart';
import '../../catalogo/domain/producto_del_panel.dart';
import '../domain/linea_a_cargar.dart';
import 'textos_de_carga.dart';

/// Elegir un vino de la lista que **ya esta en memoria** (HU-10.1): abrirla no
/// lee nada de Firestore. Se busca escribiendo, sin acentos ni mayusculas.
///
/// **Un vino que no se puede vender no desaparece**: aparece deshabilitado y
/// dice por que (*"de muestra"*, *"sin stock: cargalo primero en Stock"*). Uno
/// que desaparece de la lista es un operador preguntandose donde esta. Y uno que
/// se puede vender pero **la tienda no muestra** lo dice tambien: se vende igual
/// (ADR 018 §5), pero conviene saberlo (ADR 014: despublicar es sacar de la
/// venta).
///
/// Devuelve el vino elegido, o `null` si se cerro sin elegir.
class HojaParaElegirVino extends ConsumerStatefulWidget {
  const HojaParaElegirVino({super.key});

  static Future<ProductoDelPanel?> mostrar(BuildContext context) {
    return showModalBottomSheet<ProductoDelPanel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const HojaParaElegirVino(),
    );
  }

  @override
  ConsumerState<HojaParaElegirVino> createState() => _HojaParaElegirVinoState();
}

class _HojaParaElegirVinoState extends ConsumerState<HojaParaElegirVino> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final productos = ref.watch(productosProvider);
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
                Text(textoElegirUnVino, style: tema.textTheme.titleLarge),
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
            child: switch (productos) {
              AsyncError() => FalloConReintento(
                texto: textoNoSePudieronLeerLosVinos,
                alReintentar: () => ref.invalidate(productosProvider),
              ),
              AsyncData(:final value) => _Lista(
                productos: _filtrar(value),
                alElegir: (p) => Navigator.of(context).pop(p),
              ),
              _ => const Cargando(que: 'Buscando tus vinos…'),
            },
          ),
        ],
      ),
    );
  }

  /// Los que coinciden con lo escrito, por nombre, ordenados por nombre. Sin
  /// texto, todos.
  List<ProductoDelPanel> _filtrar(List<ProductoDelPanel> todos) {
    final q = clave(_busqueda);
    final entran = [
      for (final p in todos)
        if (q.isEmpty || clave(p.nombre).contains(q)) p,
    ];
    entran.sort((a, b) => clave(a.nombre).compareTo(clave(b.nombre)));
    return entran;
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.productos, required this.alElegir});

  final List<ProductoDelPanel> productos;
  final ValueChanged<ProductoDelPanel> alElegir;

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
        final motivo = motivoDeQueNoSeVende(p);
        final detalle = [
          if (motivo != null)
            textoDeMotivoNoElegible(motivo)
          else ...[
            'quedan ${p.stock}',
            enPesos(p.precio),
            if (!p.publicado) textoNoEstaEnLaTienda,
          ],
        ].join(' · ');
        return ListTile(
          enabled: motivo == null,
          title: Text(p.nombre, style: estiloDeNombre()),
          subtitle: Text(
            detalle,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: motivo == null ? () => alElegir(p) : null,
        );
      },
    );
  }
}
