import '../../domain/borrador_de_vino.dart';
import '../../domain/fallo_de_catalogo.dart';
import '../textos_del_catalogo.dart';

/// Lo que dice el formulario del vino cuando guardar falla. Igual que el de
/// las bodegas salvo `yaExiste`, que alla habla de una bodega.
String textoDelFalloDelVino(ErrorDeCatalogo error) => switch (error) {
  ErrorDeCatalogo.yaExiste =>
    'Ya hay un vino con esa dirección. Puede que alguien de la familia lo '
        'haya cargado recién: fijate en el catálogo.',
  _ => textoDelFallo(error),
};

/// Como se nombra cada campo en la linea de "falta" junto al boton.
String nombreDelCampo(CampoDelVino campo) => switch (campo) {
  CampoDelVino.nombre => 'el nombre',
  CampoDelVino.bodega => 'la bodega',
  CampoDelVino.varietales => 'las uvas',
  CampoDelVino.color => 'el color',
  CampoDelVino.region => 'la región',
  CampoDelVino.volumen => 'el volumen',
  CampoDelVino.anada => 'la añada',
  CampoDelVino.graduacion => 'la graduación',
  CampoDelVino.descripcion => 'la descripción',
  CampoDelVino.precio => 'el precio',
  CampoDelVino.botellas => 'las botellas',
};

/// "el nombre, la bodega y el precio".
String enumerar(Iterable<String> cosas) {
  final lista = cosas.toList();
  if (lista.length < 2) return lista.join();
  return '${lista.sublist(0, lista.length - 1).join(', ')} y ${lista.last}';
}
