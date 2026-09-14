#!/usr/bin/env node
// borrar.mjs - borra lo que sembro seed.mjs, y NADA mas.  specs/datos-de-muestra.
//
// Uso:
//   node scripts/seed/borrar.mjs            muestra lo que borraria, sin borrar
//   node scripts/seed/borrar.mjs --borrar   borra
//
// Borra por la LISTA DE IDS de catalogo.json, nunca por
// `where('muestra', '==', true)`. La query parece equivalente y no lo es: el
// dia que un producto real quede marcado por error -un import, un panel con
// un bug, una copia de un documento de muestra-, la query lo borra con los
// demas. La lista solo puede borrar lo que el seed escribio.
//
// Y aun por la lista, cada documento se lee antes: si no dice `muestra: true`,
// no se borra.

import { conectar, leerCatalogo, rutasSembradas } from './proyecto.mjs';

const borrar = process.argv.includes('--borrar');
const catalogo = leerCatalogo();
const { db, bucket } = await conectar();

let borrados = 0;
const ajenos = new Set();
for (const ruta of rutasSembradas(catalogo)) {
  const snap = await db.doc(ruta).get();
  if (!snap.exists) continue;
  if (snap.get('muestra') !== true) {
    console.log(`se queda  ${ruta}: no es de muestra`);
    ajenos.add(ruta);
    continue;
  }
  if (borrar) await snap.ref.delete();
  console.log(`${borrar ? 'borrado ' : 'borraria'}  ${ruta}`);
  borrados++;
}

// Las fotos de un producto que NO es de muestra se quedan con su documento.
let fotos = 0;
for (const v of catalogo.vinos) {
  if (ajenos.has(`productos/${v.id}`)) continue;
  const [archivos] = await bucket.getFiles({ prefix: `productos/${v.id}/` });
  for (const f of archivos) {
    if (borrar) await f.delete();
    fotos++;
  }
}

console.log(
  `\n${borrar ? 'borrados' : 'se borrarian'}: ${borrados} documentos y ${fotos} fotos de ${db.projectId}` +
    (borrar ? '' : '\n(nada se borro: correr con --borrar)'),
);
