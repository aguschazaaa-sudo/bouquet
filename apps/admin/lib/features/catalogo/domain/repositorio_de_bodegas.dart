import 'bodega.dart';

/// Todo lo que el panel sabe hacer con las bodegas. La implementacion vive en
/// `data/`; las pantallas la piden por `catalogo_providers.dart`.
abstract interface class RepositorioDeBodegas {
  /// Las bodegas, cada vez que cambian.
  ///
  /// Un stream y no un `get()`: con `get()` cada navegacion entre secciones
  /// puede releer todo, y con el stream las lecturas iniciales se pagan una
  /// vez por sesion y cada cambio cuesta **una** — la del documento que
  /// cambio (ARQUITECTURA §6.3).
  Stream<List<Bodega>> cambios();

  /// Lanza [FalloDeCatalogo]. El documento nace con exactamente
  /// `{nombre, slug}`: es lo que cierra `firestore.rules`.
  Future<void> crear({required String nombre, required String slug});

  /// Corrige el nombre. **No manda el slug**: el de una bodega no cambia
  /// nunca. Las reglas permitirian mandarlo; la restriccion es del panel y
  /// esta dicha para que no se lea como si la hicieran cumplir las reglas.
  ///
  /// Lanza [FalloDeCatalogo].
  Future<void> corregirNombre({required String id, required String nombre});

  /// Le pregunta a Firestore, **ahora**, si algun producto apunta a esta
  /// bodega (HU-02.4).
  ///
  /// El renglon ya lo sabe por el catalogo en memoria; esto existe para la
  /// ventana entre que se abrio la pantalla y se apreto el boton. Cuesta
  /// **una lectura** —`limit(1)`— y no necesita indice compuesto: es igualdad
  /// sobre un campo anidado, que Firestore indexa solo.
  ///
  /// Lanza [FalloDeCatalogo].
  Future<bool> tieneVinos(String bodegaId);

  /// Borra la bodega. **Quien llama tiene que haber comprobado
  /// [tieneVinos] primero**: `armarCatalogo` deja afuera, sin error, los
  /// productos de una bodega que no existe, asi que borrar una con vinos los
  /// **despublica en silencio** (ADR 008 §2).
  ///
  /// Lanza [FalloDeCatalogo].
  Future<void> borrar(String id);
}
