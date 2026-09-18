import '../../../core/contratos/texto.dart';
import 'bodega.dart';
import 'producto_del_panel.dart';

/// Un producto con el nombre de su bodega ya resuelto.
///
/// [bodega] en `null` NO es un detalle de render: significa que el producto
/// apunta a un `bodegaId` que no existe, y `armarCatalogo` lo deja **afuera
/// de la vidriera sin avisar** (ADR 008 §2). Es el caso que la pantalla tiene
/// que decir en voz alta.
class RenglonDelCatalogo {
  RenglonDelCatalogo({required this.producto, required this.bodega})
    : _buscable = normalizar('${producto.nombre} ${bodega?.nombre ?? ''}');

  final ProductoDelPanel producto;
  final Bodega? bodega;

  /// Nombre y bodega, normalizados, en un solo texto. Se calcula UNA vez al
  /// armar el catalogo y no por tecla: filtrar 200 productos mientras alguien
  /// escribe son 200 normalizaciones por letra si se hace al reves.
  final String _buscable;

  bool coincideCon(String consultaNormalizada) =>
      _buscable.contains(consultaNormalizada);
}

/// El catalogo del panel: los productos cruzados con sus bodegas, y todo lo
/// que las pantallas preguntan sobre ese cruce.
///
/// **Es Dart puro y tiene tests.** El cruce, el filtro y el conteo por bodega
/// son la logica que decide si HU-02.4 frena un borrado, y eso no puede vivir
/// adentro de un widget que en esta maquina no se puede ni compilar.
///
/// **Cero lecturas de Firestore.** Todo lo de aca sale de los dos streams que
/// ya estan en memoria (ARQUITECTURA §6.3).
class Catalogo {
  Catalogo._({
    required this.bodegas,
    required this.renglones,
    required Map<String, int> vinosPorBodega,
  }) : _vinosPorBodega = vinosPorBodega,
       _vinoPorId = {for (final r in renglones) r.producto.id: r.producto},
       _bodegaPorId = {for (final b in bodegas) b.id: b};

  /// Ordenadas por nombre normalizado: sin eso "Ñandú" cae despues de "Zuccardi".
  final List<Bodega> bodegas;

  /// Ordenados por nombre normalizado, publicados y no publicados juntos.
  final List<RenglonDelCatalogo> renglones;

  final Map<String, int> _vinosPorBodega;
  final Map<String, ProductoDelPanel> _vinoPorId;
  final Map<String, Bodega> _bodegaPorId;

  factory Catalogo.armar({
    required List<ProductoDelPanel> productos,
    required List<Bodega> bodegas,
  }) {
    final porId = {for (final b in bodegas) b.id: b};

    final vinosPorBodega = <String, int>{};
    for (final p in productos) {
      vinosPorBodega[p.bodegaId] = (vinosPorBodega[p.bodegaId] ?? 0) + 1;
    }

    final renglones = [
      for (final p in productos)
        RenglonDelCatalogo(producto: p, bodega: porId[p.bodegaId]),
    ]..sort((a, b) => _porNombre(a.producto.nombre, b.producto.nombre));

    final ordenadas = [...bodegas]
      ..sort((a, b) => _porNombre(a.nombre, b.nombre));

    return Catalogo._(
      bodegas: ordenadas,
      renglones: renglones,
      vinosPorBodega: vinosPorBodega,
    );
  }

  static final vacio = Catalogo.armar(productos: const [], bodegas: const []);

  /// Desempate por el nombre crudo: dos productos con el mismo nombre
  /// normalizado tienen que salir siempre en el mismo orden, o la lista se
  /// reordena sola en cada rebuild.
  static int _porNombre(String a, String b) {
    final orden = normalizar(a).compareTo(normalizar(b));
    return orden != 0 ? orden : a.compareTo(b);
  }

  /// El filtro de HU-03.1: `contains` normalizado sobre nombre y bodega, en
  /// memoria. Una consulta vacia devuelve todo.
  ///
  /// No es difusa a proposito (ARQUITECTURA §7): con menos de 200 productos
  /// no hace falta, y una busqueda difusa aca seria la segunda
  /// implementacion de la busqueda de la vidriera.
  List<RenglonDelCatalogo> filtrar(String consulta) {
    final buscada = normalizar(consulta);
    if (buscada.isEmpty) return renglones;
    return [
      for (final r in renglones)
        if (r.coincideCon(buscada)) r,
    ];
  }

  /// Cuantos productos apuntan a esta bodega. **Cero lecturas**: sale del
  /// conteo que se armo al cruzar.
  int vinosDe(String bodegaId) => _vinosPorBodega[bodegaId] ?? 0;

  /// La bodega cuyo nombre es el mismo, escrito como sea (HU-02.2).
  ///
  /// [exceptoId] es para la edicion: una bodega siempre tiene el mismo nombre
  /// que ella misma, y avisarlo seria ruido.
  Bodega? conElMismoNombre(String nombre, {String? exceptoId}) {
    final buscada = clave(nombre);
    if (buscada.isEmpty) return null;
    for (final b in bodegas) {
      if (b.id != exceptoId && clave(b.nombre) == buscada) return b;
    }
    return null;
  }

  /// Las bodegas parecidas a [nombre] —"Catena" contra "Catena Zapata"—
  /// **sin** la que se llama exactamente igual, que se avisa aparte y con
  /// otras palabras.
  List<Bodega> parecidasA(String nombre, {String? exceptoId}) {
    final buscada = clave(nombre);
    if (buscada.isEmpty) return const [];
    return [
      for (final b in bodegas)
        if (b.id != exceptoId &&
            clave(b.nombre) != buscada &&
            seParecen(b.nombre, nombre))
          b,
    ];
  }

  /// El vino a corregir, de lo que ya esta en memoria: abrir el formulario
  /// cuesta **cero** lecturas (HU-03.4).
  ProductoDelPanel? vino(String id) => _vinoPorId[id];

  Bodega? bodega(String id) => _bodegaPorId[id];

  /// Quien ya tiene la direccion [slug], o `null` si esta libre. ADR 013 §1.
  ///
  /// **Primero el id**: desde ADR 013 el id de un vino nuevo ES su slug, asi
  /// que un documento con ese id hace rechazar el alta en la base — sea de
  /// muestra o no. **Despues el slug**: un vino real con esa direccion
  /// dejaria dos iguales, y `armarCatalogo` descarta los dos. Uno de muestra
  /// solo choca en la vidriera y solo si los dos se publican: se avisa, no se
  /// frena.
  ChoqueDeDireccion? quienTiene(String slug) {
    if (slug.isEmpty) return null;
    final mismoId = _vinoPorId[slug];
    if (mismoId != null) return ChoqueDeDireccion(mismoId, bloquea: true);
    ChoqueDeDireccion? deMuestra;
    for (final r in renglones) {
      final p = r.producto;
      if (p.slug != slug) continue;
      if (!p.muestra) return ChoqueDeDireccion(p, bloquea: true);
      deMuestra ??= ChoqueDeDireccion(p, bloquea: false);
    }
    return deMuestra;
  }

  /// Las regiones que ya usan los vinos, **una por clave**: "Valle de Uco" y
  /// "valle de uco" son la misma y se ofrece la primera que aparece en orden.
  /// Sugerirlas es lo que evita la tercera forma de escribir Mendoza.
  List<String> get _regiones {
    final porClave = <String, String>{};
    for (final r in renglones) {
      final region = r.producto.ficha.region.trim();
      final k = clave(region);
      if (k.isNotEmpty) porClave.putIfAbsent(k, () => region);
    }
    return porClave.values.toList()..sort(_porNombre);
  }

  /// Las regiones en uso que contienen [escrito], normalizado. Vacio
  /// devuelve todas.
  List<String> regionesCon(String escrito) {
    final buscada = normalizar(escrito);
    return [
      for (final r in _regiones)
        if (normalizar(r).contains(buscada)) r,
    ];
  }
}

/// Un vino que ya tiene la direccion que se quiere usar.
class ChoqueDeDireccion {
  const ChoqueDeDireccion(this.vino, {required this.bloquea});

  final ProductoDelPanel vino;

  /// `true` si guardar no se puede: la base lo rechazaria, o quedarian dos
  /// vinos reales con la misma direccion. `false` es uno de muestra.
  final bool bloquea;
}
