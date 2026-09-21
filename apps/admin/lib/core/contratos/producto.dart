/// El espejo en Dart de las listas cerradas del Producto, de
/// `packages/contratos/src/producto.ts`. ADR 008 §1 y ADR 013.
///
/// **La lista de varietales vive TRES veces** —`contratos`, `firestore.rules`
/// y aca—, porque ni las reglas ni Dart pueden importar TypeScript. Tres
/// copias del mismo dato se desincronizan, y el modo de falla es silencioso:
/// una uva que el panel ofrece y las reglas no conocen rebota con un
/// `permission-denied` que parece de permisos. Por eso
/// `scripts/ci/auditar_varietales.mjs` compara las tres en el alcance
/// `rapido`, y lee este archivo **entre las marcas**: no las muevas.
///
/// Aca ademas **el orden importa**: el formulario muestra las uvas en este
/// orden y un vino nuevo las guarda en este orden. El auditor lo compara.
library;

/// La lista CERRADA de uvas. Agregar una es un cambio en los tres lugares.
const varietales = <String>[
  // varietales:inicio
  'Malbec',
  'Cabernet Sauvignon',
  'Cabernet Franc',
  'Bonarda',
  'Syrah',
  'Merlot',
  'Pinot Noir',
  'Pinot Grigio',
  'Tannat',
  'Petit Verdot',
  'Tempranillo',
  'Criolla',
  'Chardonnay',
  'Torrontés',
  'Sauvignon Blanc',
  'Semillón',
  'Viognier',
  'Pinot Gris',
  // varietales:fin
];

/// El color del vino. El `name` de cada valor **es** lo que se guarda en
/// `fichaVino.color`: `firestore.rules` acepta `tinto`, `blanco` y `rosado`.
enum ColorDelVino {
  tinto('Tinto'),
  blanco('Blanco'),
  rosado('Rosado');

  const ColorDelVino(this.rotulo);

  /// Lo que se lee en la pantalla.
  final String rotulo;

  /// `null` si el documento trae algo que no es un color conocido: el panel
  /// muestra el vino igual (ADR 012 §7) y el formulario pide elegir.
  static ColorDelVino? desde(String valor) {
    for (final c in values) {
      if (c.name == valor) return c;
    }
    return null;
  }
}

/// La graduacion va en **decimas** de grado y entera: 13,5 % es `135`.
///
/// El piso no describe a los vinos: **atrapa la unidad equivocada**. Un `14`
/// escrito pensando en 14 % valdria 1,4 %, y con el piso rebota. Los mismos
/// dos numeros que `GRADUACION_MINIMA` y `GRADUACION_MAXIMA` de contratos y
/// que `graduacionValida` de las reglas; el auditor compara los tres.
const graduacionMinima = 50;
const graduacionMaxima = 250;

/// Tope de la descripcion, en **caracteres** —no bytes—. Medido contra el
/// emulador: `size()` de las reglas cuenta caracteres, asi que 600 enies
/// entran igual que 600 letras; si contara bytes, el tope real en castellano
/// seria la mitad del que dice el formulario.
///
/// El numero no es estetico: el catalogo **entero** viaja al navegador de cada
/// visitante para filtrarse en memoria (ADR 006). El mismo valor que
/// `DESCRIPCION_MAXIMA` de contratos y que `descripcionValida` de las reglas;
/// el auditor compara los tres.
const descripcionMaxima = 600;
