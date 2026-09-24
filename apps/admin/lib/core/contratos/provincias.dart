// El espejo en Dart de `PROVINCIAS`, de `packages/contratos/src/envio.ts`.
// HU-10.1, ADR 018.
//
// El codigo ISO **no es decorativo**: es lo que un correo argentino espera en
// el campo `provincia` al cotizar y al despachar (ISO 3166-2:AR sin el prefijo
// `AR-`). Guardar "Cordoba" como texto obliga a traducirlo en el momento
// equivocado, asi que el codigo viaja desde el formulario. Se espeja y no se
// vuelve a escribir "de memoria": `test/core/contratos/pedido_test.dart` la
// compara contra `generated/contratos.json`.

/// Una de las 24 jurisdicciones. [iso] es lo que se guarda; [nombre] lo que se
/// lee, **con tilde**: no es una nota para quien programa, es lo que ve la
/// persona en el selector.
class Provincia {
  const Provincia(this.iso, this.nombre);

  final String iso;
  final String nombre;
}

const provincias = <Provincia>[
  Provincia('B', 'Buenos Aires'),
  Provincia('C', 'Ciudad de Buenos Aires'),
  Provincia('K', 'Catamarca'),
  Provincia('H', 'Chaco'),
  Provincia('U', 'Chubut'),
  Provincia('X', 'Córdoba'),
  Provincia('W', 'Corrientes'),
  Provincia('E', 'Entre Ríos'),
  Provincia('P', 'Formosa'),
  Provincia('Y', 'Jujuy'),
  Provincia('L', 'La Pampa'),
  Provincia('F', 'La Rioja'),
  Provincia('M', 'Mendoza'),
  Provincia('N', 'Misiones'),
  Provincia('Q', 'Neuquén'),
  Provincia('R', 'Río Negro'),
  Provincia('A', 'Salta'),
  Provincia('J', 'San Juan'),
  Provincia('D', 'San Luis'),
  Provincia('Z', 'Santa Cruz'),
  Provincia('S', 'Santa Fe'),
  Provincia('G', 'Santiago del Estero'),
  Provincia('V', 'Tierra del Fuego'),
  Provincia('T', 'Tucumán'),
];

/// `true` si [iso] es uno de los 24 codigos. Espejo de `esProvinciaIso`.
bool esProvinciaIso(String iso) => provincias.any((p) => p.iso == iso);

/// El nombre de una provincia, o `null` si [iso] no es un codigo conocido.
String? nombreDeProvincia(String iso) {
  for (final p in provincias) {
    if (p.iso == iso) return p.nombre;
  }
  return null;
}
