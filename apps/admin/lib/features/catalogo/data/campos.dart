/// Lectura defensiva de un documento crudo de Firestore.
///
/// **Por que hace falta aunque las reglas validen la forma.** El Admin SDK
/// **no pasa por las reglas**: el seed, un trigger o un script escriben lo que
/// quieran. `validarProducto` en `packages/contratos` existe por lo mismo, y
/// ahi esta escrito: *"un documento roto PUEDE existir: esto es lo que impide
/// que tire el render"*.
///
/// La postura del panel es distinta a la de la vidriera, a proposito: la
/// vidriera **descarta** el documento roto, y el panel lo **muestra**. Un vino
/// que el operador no ve es un vino que no puede arreglar.
library;

String textoDe(Object? valor, {String siFalta = ''}) =>
    valor is String ? valor : siFalta;

/// Un texto que puede no estar. **`null` y una cadena en blanco son lo
/// mismo** —"no se cargo"—: las reglas rechazan el blanco, pero el Admin SDK
/// no pasa por las reglas y un documento viejo puede traerlo. Leerlo como
/// `null` evita que la pantalla dibuje una seccion vacia por un espacio.
String? textoOpcionalDe(Object? valor) =>
    valor is String && valor.trim().isNotEmpty ? valor : null;

/// Devuelve `null` si no es un entero. Un `double` NO se convierte: el precio
/// es entero en centavos (ADR 008) y aceptar 1250.5 seria esconder el error.
int? enteroDe(Object? valor) => valor is int ? valor : null;

bool boolDe(Object? valor, {bool siFalta = false}) =>
    valor is bool ? valor : siFalta;

Map<String, Object?> mapaDe(Object? valor) =>
    valor is Map ? valor.cast<String, Object?>() : const {};

/// Los textos de una lista, en su orden. Lo que no es texto se descarta: una
/// uva guardada como numero no es una uva, y el formulario pide elegirla.
List<String> textosDe(Object? valor) => valor is List
    ? [
        for (final v in valor)
          if (v is String) v,
      ]
    : const [];
