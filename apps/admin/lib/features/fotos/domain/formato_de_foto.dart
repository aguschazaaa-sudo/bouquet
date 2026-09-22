import 'dart:typed_data';

/// El ESPEJO en Dart de `functions/src/foto/validar.ts`: que es una imagen
/// que la vidriera puede servir, mirando los BYTES del archivo, **nunca** el
/// nombre ni la extension del path ni el `mimeType` que informa el selector.
///
/// Es mas estricto que ARQUITECTURA §5.4 regla 1 -que pide derivar la
/// extension del `mimeType`-, no menos: en Android el `mimeType` de
/// `image_picker` puede llegar `null`, y la tentacion en ese caso es caer al
/// `path` -que en web ES UN BLOB URL, la trampa que vivio desde el commit
/// inicial en PadelPunilla (design.md decision 3, ARQUITECTURA §5.4). Leer
/// los primeros bytes resuelve las dos plataformas con un solo camino, y de
/// paso rechaza un PDF renombrado `foto.jpg` antes de gastar una subida.
///
/// Lista cerrada, igual que el lado de TypeScript: `jpeg`, `png`, `webp`.
enum FormatoDeFoto { jpeg, png, webp }

const Map<FormatoDeFoto, String> _contentType = {
  FormatoDeFoto.jpeg: 'image/jpeg',
  FormatoDeFoto.png: 'image/png',
  FormatoDeFoto.webp: 'image/webp',
};

/// La extension de un solo segmento para el nombre del crudo en Storage
/// (`productos/{productoId}/{archivo}`, ARQUITECTURA §5.4 regla 2). No es la
/// extension del archivo original -esa nunca se lee-, es la que corresponde
/// a los bytes detectados.
const Map<FormatoDeFoto, String> _extension = {
  FormatoDeFoto.jpeg: 'jpg',
  FormatoDeFoto.png: 'png',
  FormatoDeFoto.webp: 'webp',
};

/// `null` cuando los bytes no son de ninguno de los tres formatos que la
/// vidriera sabe servir: incluye un PDF, un HEIC, o cualquier otra cosa con
/// un nombre de archivo enganoso.
///
/// Los mismos umbrales que `detectarFormato` de `validar.ts`, byte a byte:
/// JPEG `FF D8 FF`; PNG `89 50 4E 47 0D 0A 1A 0A`; WebP `RIFF` en 0-3 y
/// `WEBP` en 8-11.
FormatoDeFoto? detectarFormato(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return FormatoDeFoto.jpeg;
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return FormatoDeFoto.png;
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 && // "RIFF"
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] ==
          0x50 // "WEBP"
          ) {
    return FormatoDeFoto.webp;
  }
  return null;
}

String contentTypeDe(FormatoDeFoto formato) => _contentType[formato]!;

String extensionDe(FormatoDeFoto formato) => _extension[formato]!;

/// 5 MB, el mismo tope que `pesaMenosDe5MB()` de `storage.rules` y que
/// `TOPE_DE_BYTES` de `validar.ts`. Repetido a proposito: la regla ya lo
/// aplica del lado del bucket devolviendo `unauthorized` -que parece un
/// problema de permisos y es un problema de tamano-, asi que el panel tiene
/// que avisar ANTES de subir, con el peso (spec "El panel mide el peso antes
/// de subir").
const topeDeBytes = 5 * 1024 * 1024;
