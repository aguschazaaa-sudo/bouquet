import '../../../core/contratos/catalogo_publico.dart';
import '../domain/fallo_de_catalogo.dart';

/// Lo que dice la pantalla cuando algo del catalogo falla. Para gente no
/// tecnica: que paso y que hacer, sin codigos de Firebase.
String textoDelFallo(ErrorDeCatalogo error) => switch (error) {
  ErrorDeCatalogo.sinPermiso =>
    'Tu cuenta no tiene permiso para esto. Si te lo acaban de dar, salí y '
        'volvé a entrar.',
  ErrorDeCatalogo.sinConexion =>
    'No hay conexión. Revisá internet y probá de nuevo.',
  ErrorDeCatalogo.yaExiste =>
    'Ya existe una bodega con ese nombre. Puede que alguien de la familia la '
        'haya cargado recién.',
  ErrorDeCatalogo.desconocido =>
    'Algo falló y no sabemos qué. Probá de nuevo en un rato; si sigue, '
        'avisale al desarrollador.',
};

/// Lo que dice el borrado cuando la pregunta fresca a Firestore encuentra
/// vinos que el catalogo en memoria no tenia (HU-02.4).
const textoSeLeCargaronVinos =
    'No la borramos: alguien le cargó un vino mientras mirabas esta pantalla. '
    'Actualizá para verlo.';

const textoNombreSinSlug =
    'Ese nombre no sirve: tiene que tener al menos una letra o un número.';

/// El motivo corto para el renglon del catalogo (HU-03.7): un vino
/// PUBLICADO que la tienda igual descarta. Mas breve que
/// `textoDelMotivoEnLaTienda` de la pagina del vino -- ahi hay espacio para
/// una oracion, en el renglon no.
String textoCortoDelMotivo(MotivoDeDescarte motivo) => switch (motivo) {
  MotivoDeDescarte.noValida => 'la ficha tiene un problema',
  MotivoDeDescarte.slugDuplicado => 'dirección repetida',
  MotivoDeDescarte.noPublicado => 'no publicado',
  MotivoDeDescarte.compuesto => 'compuesto, sin stock propio',
  MotivoDeDescarte.bodegaInexistente => 'bodega inexistente',
};
