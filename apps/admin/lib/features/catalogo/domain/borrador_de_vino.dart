/// El formulario de un vino, en Dart puro. ADR 013 §4.
///
/// **Por que aca y no en el widget:** el panel no compila en esta maquina, y
/// `dart test` si corre. Todo lo que puede equivocarse —que falta, que choca,
/// que cambio— vive aca y tiene tests; el widget lee una [Revision] y nada
/// mas.
library;

import '../../../core/contratos/producto.dart';
import '../../../core/contratos/texto.dart';
import 'catalogo.dart';
import 'escrituras_del_vino.dart';
import 'ficha_del_vino.dart';
import 'numeros_escritos.dart';
import 'producto_del_panel.dart';

/// Cada campo que puede tener un problema, para decirlo **al lado del campo**.
enum CampoDelVino {
  nombre,
  bodega,
  varietales,
  color,
  region,
  volumen,
  anada,
  graduacion,
  descripcion,
  precio,
  botellas,
}

/// Una unidad de venta de mas de 12 botellas no es algo que venda una
/// vinoteca, y el tope por pedido ya es 12 unidades (ADR 008 §2).
const botellasMaximas = 12;

/// Lo que se escribio, tal cual. Los numeros son **texto**: un precio a medio
/// escribir todavia no es un numero, y el campo tiene que mostrarlo como esta.
class BorradorDeVino {
  const BorradorDeVino({
    this.original,
    this.nombre = '',
    this.bodegaId,
    this.varietales = const [],
    this.color,
    this.organico = false,
    this.region = '',
    this.volumen = '750',
    this.anada = '',
    this.graduacion = '',
    this.descripcion = '',
    this.precio = '',
    this.botellas = 1,
  });

  /// El formulario de HU-03.4: lo que el vino tiene hoy, escrito como lo
  /// escribiria una persona.
  factory BorradorDeVino.desde(ProductoDelPanel p) {
    final f = p.ficha;
    return BorradorDeVino(
      original: p,
      nombre: p.nombre,
      bodegaId: f.bodegaId.isEmpty ? null : f.bodegaId,
      varietales: f.varietales,
      color: f.color,
      organico: f.organico,
      region: f.region,
      volumen: f.volumenMl?.toString() ?? '',
      anada: f.anada?.toString() ?? '',
      graduacion: f.graduacion == null
          ? ''
          : graduacionParaEscribir(f.graduacion!),
      descripcion: f.descripcion ?? '',
      precio: pesosParaEscribir(p.precio),
      botellas: p.botellas,
    );
  }

  /// El vino **como se abrio**, o `null` en un alta. Los cambios se comparan
  /// contra este y no contra el que llega despues por el stream: lo que otra
  /// persona cambio mientras tanto en otro campo no viaja.
  final ProductoDelPanel? original;

  final String nombre;
  final String? bodegaId;
  final List<String> varietales;
  final ColorDelVino? color;
  final bool organico;
  final String region;
  final String volumen;
  final String anada;
  final String graduacion;

  /// La prosa del dueño, tal cual se escribe. Vacia es "no hay", y se guarda
  /// como `null`: una cadena en blanco la rechazan las reglas.
  final String descripcion;

  final String precio;
  final int botellas;

  bool get esNuevo => original == null;

  /// El precio de un vino que esta en la tienda es HU-03.5, Workflow D: aca
  /// se ve y no se toca (ADR 013 §9).
  bool get precioFijo => original?.publicado ?? false;

  BorradorDeVino conNombre(String v) => _con(nombre: v);
  BorradorDeVino conBodega(String id) => _con(bodegaId: id);
  BorradorDeVino conColor(ColorDelVino c) => _con(color: c);
  BorradorDeVino conOrganico(bool v) => _con(organico: v);
  BorradorDeVino conRegion(String v) => _con(region: v);
  BorradorDeVino conVolumen(String v) => _con(volumen: v);
  BorradorDeVino conAnada(String v) => _con(anada: v);
  BorradorDeVino conGraduacion(String v) => _con(graduacion: v);

  /// **Sin la puerta de [precioFijo], a proposito.** La descripcion no es
  /// plata: corregirle una falta de ortografia a un vino que esta en la
  /// tienda no puede obligar a sacarlo primero.
  BorradorDeVino conDescripcion(String v) => _con(descripcion: v);

  BorradorDeVino conPrecio(String v) => precioFijo ? this : _con(precio: v);

  /// Las botellas solo se eligen en el alta: despues son inmutables.
  BorradorDeVino conBotellas(int v) => esNuevo ? _con(botellas: v) : this;

  BorradorDeVino conVarietal(String uva, {required bool elegida}) {
    final sin = [
      for (final v in varietales)
        if (v != uva) v,
    ];
    return _con(varietales: elegida ? [...sin, uva] : sin);
  }

  BorradorDeVino _con({
    String? nombre,
    String? bodegaId,
    List<String>? varietales,
    ColorDelVino? color,
    bool? organico,
    String? region,
    String? volumen,
    String? anada,
    String? graduacion,
    String? descripcion,
    String? precio,
    int? botellas,
  }) => BorradorDeVino(
    original: original,
    nombre: nombre ?? this.nombre,
    bodegaId: bodegaId ?? this.bodegaId,
    varietales: varietales ?? this.varietales,
    color: color ?? this.color,
    organico: organico ?? this.organico,
    region: region ?? this.region,
    volumen: volumen ?? this.volumen,
    anada: anada ?? this.anada,
    graduacion: graduacion ?? this.graduacion,
    descripcion: descripcion ?? this.descripcion,
    precio: precio ?? this.precio,
    botellas: botellas ?? this.botellas,
  );

  /// La **unica** fuente de "¿se puede guardar?": el boton, los mensajes al
  /// lado de cada campo y la confirmacion de la caja leen esto.
  ///
  /// [anioActual] entra de afuera para que el test no dependa del reloj.
  Revision revisar(Catalogo catalogo, {required int anioActual}) =>
      _Revisor(this, catalogo, anioActual).revisar();
}

/// Lo que el formulario sabe de un borrador.
class Revision {
  const Revision({
    required this.problemas,
    required this.slug,
    this.choque,
    this.precio,
    this.alta,
    this.cambios,
  });

  final Map<CampoDelVino, String> problemas;

  /// La direccion del vino: derivada del nombre en un alta, la de siempre en
  /// una correccion.
  final String slug;

  /// Otro vino con la misma direccion. Si [ChoqueDeDireccion.bloquea], el
  /// problema ya esta en [CampoDelVino.nombre]; si no, es un aviso.
  final ChoqueDeDireccion? choque;

  /// El precio leido, para la vista previa aunque falte otra cosa.
  final int? precio;

  /// Solo en un alta sin problemas.
  final AltaDeVino? alta;

  /// Solo en una correccion sin problemas. Puede no tener nada adentro.
  final CambiosDeVino? cambios;

  String? problemaDe(CampoDelVino campo) => problemas[campo];

  bool get sePuedeGuardar => alta != null || (cambios?.hayAlgo ?? false);

  /// HU-03.3: una caja no tiene vuelta atras y cambia que significa cada
  /// unidad de stock. Se confirma; la botella suelta no (ADR 013 §8).
  bool get pideConfirmarLaCaja => (alta?.botellas ?? 1) > 1;
}

/// El trabajo de [BorradorDeVino.revisar], separado para que cada campo sea
/// una funcion corta.
class _Revisor {
  _Revisor(this.b, this.catalogo, this.anioActual);

  final BorradorDeVino b;
  final Catalogo catalogo;
  final int anioActual;
  final problemas = <CampoDelVino, String>{};

  Revision revisar() {
    final nombre = b.nombre.trim();
    final region = b.region.trim();
    final slug = b.original?.slug ?? aSlug(nombre);
    final choque = b.esNuevo ? catalogo.quienTiene(slug) : null;

    _nombre(nombre, slug, choque);
    _bodega();
    final varietales = _varietales();
    if (b.color == null) problemas[CampoDelVino.color] = 'Elegí el color.';
    if (region.isEmpty) problemas[CampoDelVino.region] = 'Falta la región.';
    final volumen = _volumen();
    final anada = _anada();
    final graduacion = _leer(
      CampoDelVino.graduacion,
      leerGraduacion(b.graduacion),
    );
    final descripcion = _descripcion();
    final precio = b.precioFijo ? b.original!.precio : _precio();
    if (b.botellas < 1 || b.botellas > botellasMaximas) {
      problemas[CampoDelVino.botellas] = 'Entre 1 y $botellasMaximas botellas.';
    }

    if (problemas.isNotEmpty) {
      return Revision(
        problemas: problemas,
        slug: slug,
        choque: choque,
        precio: precio,
      );
    }

    final ficha = FichaDelVino(
      bodegaId: b.bodegaId!,
      varietales: varietales,
      color: b.color,
      organico: b.organico,
      anada: anada,
      region: region,
      volumenMl: volumen,
      graduacion: graduacion,
      descripcion: descripcion,
    );
    final original = b.original;
    return Revision(
      problemas: const {},
      slug: slug,
      choque: choque,
      precio: precio,
      alta: original == null
          ? AltaDeVino(
              slug: slug,
              nombre: nombre,
              ficha: ficha,
              precio: precio!,
              botellas: b.botellas,
            )
          : null,
      cambios: original == null
          ? null
          : _cambios(original, nombre, ficha, precio!),
    );
  }

  void _nombre(String nombre, String slug, ChoqueDeDireccion? choque) {
    if (nombre.isEmpty) {
      problemas[CampoDelVino.nombre] = 'Falta el nombre.';
    } else if (slug.isEmpty) {
      problemas[CampoDelVino.nombre] =
          'El nombre necesita letras o números: de ahí sale su dirección en '
          'la tienda.';
    } else if (choque != null && choque.bloquea) {
      problemas[CampoDelVino.nombre] =
          'Ya hay un vino con esta dirección: «${choque.vino.nombre}». '
          'Cambiale el nombre, por ejemplo sumándole la bodega.';
    }
  }

  /// Vacia es `null`, no `''`: las reglas rechazan el blanco, y dos maneras
  /// de decir nada serian dos de leerla.
  ///
  /// El tope se mide sobre el texto YA RECORTADO, que es lo que se escribe.
  /// Medirlo sobre lo tecleado rebotaria un texto que cabe.
  String? _descripcion() {
    final texto = b.descripcion.trim();
    if (texto.isEmpty) return null;
    if (texto.length > descripcionMaxima) {
      final sobran = texto.length - descripcionMaxima;
      problemas[CampoDelVino.descripcion] =
          'Sobran $sobran ${sobran == 1 ? 'caracter' : 'caracteres'}: '
          'el máximo es $descripcionMaxima.';
      return null;
    }
    return texto;
  }

  void _bodega() {
    final id = b.bodegaId;
    if (id == null) {
      problemas[CampoDelVino.bodega] = 'Elegí la bodega.';
    } else if (catalogo.bodega(id) == null) {
      problemas[CampoDelVino.bodega] = 'Esa bodega ya no existe: elegí otra.';
    }
  }

  /// En un alta, en el orden de la lista cerrada: los chips no muestran un
  /// orden de eleccion, y guardarlo seria guardar algo que nadie vio.
  List<String> _varietales() {
    final fuera = [
      for (final v in b.varietales)
        if (!varietales.contains(v)) v,
    ];
    if (b.varietales.isEmpty) {
      problemas[CampoDelVino.varietales] = 'Elegí al menos una uva.';
    } else if (fuera.isNotEmpty) {
      problemas[CampoDelVino.varietales] =
          '«${fuera.join('», «')}» no está en la lista de uvas: sacala para '
          'poder guardar.';
    }
    return [
      for (final v in varietales)
        if (b.varietales.contains(v)) v,
    ];
  }

  int? _volumen() {
    final ml = RegExp(r'^\d{1,5}$').hasMatch(b.volumen.trim())
        ? int.parse(b.volumen.trim())
        : null;
    if (b.volumen.trim().isEmpty) {
      problemas[CampoDelVino.volumen] = 'Falta el volumen.';
    } else if (ml == null || ml <= 0) {
      problemas[CampoDelVino.volumen] = 'El volumen va en mililitros: 750.';
    }
    return ml;
  }

  int? _anada() {
    final t = b.anada.trim();
    if (t.isEmpty) return null;
    final anio = RegExp(r'^\d{4}$').hasMatch(t) ? int.parse(t) : null;
    if (anio == null || anio <= 1800) {
      problemas[CampoDelVino.anada] = 'La añada es el año de cosecha: 2021.';
    } else if (anio > anioActual) {
      problemas[CampoDelVino.anada] = 'Esa añada todavía no llegó.';
    }
    return anio;
  }

  int? _precio() {
    final l = leerPesos(b.precio);
    if (l.estaVacia) {
      problemas[CampoDelVino.precio] = 'Falta el precio.';
    } else if (l.problema != null) {
      problemas[CampoDelVino.precio] = l.problema!;
    } else if (l.valor == 0) {
      problemas[CampoDelVino.precio] =
          'El precio tiene que ser mayor que cero.';
    }
    return l.valor;
  }

  int? _leer(CampoDelVino campo, Lectura l) {
    if (l.problema != null) problemas[campo] = l.problema!;
    return l.valor;
  }

  CambiosDeVino _cambios(
    ProductoDelPanel o,
    String nombre,
    FichaDelVino f,
    int precio,
  ) {
    final antes = o.ficha;
    T? si<T>(T nuevo, T viejo) => nuevo == viejo ? null : nuevo;
    return CambiosDeVino(
      nombre: si(nombre, o.nombre),
      bodegaId: si(f.bodegaId, antes.bodegaId),
      color: si<ColorDelVino?>(f.color, antes.color),
      organico: si(f.organico, antes.organico),
      region: si(f.region, antes.region),
      volumenMl: si<int?>(f.volumenMl, antes.volumenMl),
      anada: f.anada == antes.anada ? null : Cambio(f.anada),
      graduacion: f.graduacion == antes.graduacion
          ? null
          : Cambio(f.graduacion),
      descripcion: f.descripcion == antes.descripcion
          ? null
          : Cambio(f.descripcion),
      precio: b.precioFijo ? null : si(precio, o.precio),
      varietalesAgregados: [
        for (final v in f.varietales)
          if (!antes.varietales.contains(v)) v,
      ],
      varietalesQuitados: [
        for (final v in antes.varietales)
          if (!b.varietales.contains(v)) v,
      ],
    );
  }
}
