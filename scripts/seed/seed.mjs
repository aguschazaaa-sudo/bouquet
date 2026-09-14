#!/usr/bin/env node
// seed.mjs - siembra los datos de MUESTRA de stage en bouquet-vinos.
// specs/datos-de-muestra, ADR 008.
//
// Uso:
//   node scripts/seed/seed.mjs                          siembra (re-ejecutable)
//   node scripts/seed/seed.mjs --probar-foto <archivo>  chequea fotos sin conectarse a nada
//
// Credenciales: `gcloud auth application-default login`. La baranda del
// proyecto vive en proyecto.mjs.
//
// Las reglas que hace cumplir:
//   1. Re-ejecutable: ids deterministas y set(), nunca add(); cada foto se
//      nombra por el hash de su contenido. Dos corridas dejan lo mismo.
//   2. Ninguna foto es un placeholder ni algo que no sea una imagen.
//   3. Todo documento lleva `muestra: true`, y un documento con el mismo id que
//      NO sea de muestra frena la corrida entera antes de escribir.
//   4. Cada producto pasa por `validarProducto` de contratos antes de
//      escribirse: si el seed no cumple el contrato, la vidriera lo descartaria
//      en silencio.

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import sharp from 'sharp';

import { validarProducto } from '../../packages/contratos/src/producto.ts';
import { BUCKET, conectar, leerCatalogo, rutasSembradas } from './proyecto.mjs';

const AQUI = dirname(fileURLToPath(import.meta.url));
const sha256 = (buf) => createHash('sha256').update(buf).digest('hex');

/**
 * Las imagenes genericas de "no disponible" que sirven las vinotecas en lugar
 * de la foto. Se reconocen por el hash exacto del archivo: la de Jumbo
 * aparecio como candidata para Don Nicanor (2026-09-10). La lista crece cuando
 * aparezca otra; un placeholder nuevo pasa hasta que alguien lo agregue.
 */
const PLACEHOLDERS = new Map([
  ['929c8b2ca776c84d023085e52155f059b74941295ad0b079030f8d18442f5e47', 'Jumbo, "Imagen no disponible"'],
]);

/**
 * WebP, recortada al borde de la botella. El recorte lo pidieron las dos
 * maquetas por separado: `object-fit` iguala la caja, no la botella, y sin
 * recortar el fondo una botella ocupa el 81 % del alto y otra el 100 %.
 */
async function prepararFoto(ruta) {
  const original = readFileSync(ruta);
  const placeholder = PLACEHOLDERS.get(sha256(original));
  if (placeholder) return { ok: false, motivo: `es un placeholder (${placeholder})` };

  let formato;
  try {
    formato = (await sharp(original).metadata()).format;
  } catch {
    return { ok: false, motivo: 'no es una imagen' };
  }
  if (!['jpeg', 'png', 'webp'].includes(formato)) return { ok: false, motivo: `formato ${formato}` };

  const webp = await sharp(original)
    .trim({ threshold: 12 })
    .resize({ height: 1200, withoutEnlargement: true })
    .webp({ quality: 82 })
    .toBuffer();
  return { ok: true, webp, hash: sha256(webp).slice(0, 16) };
}

// ------------------------------------------------------ --probar-foto

if (process.argv[2] === '--probar-foto') {
  for (const ruta of process.argv.slice(3)) {
    const r = await prepararFoto(ruta);
    console.log(r.ok ? `ok         ${ruta} -> ${r.hash}.webp (${r.webp.length} bytes)` : `RECHAZADA  ${ruta}: ${r.motivo}`);
  }
  process.exit(0);
}

// ---------------------------------------------------------------- siembra

const catalogo = leerCatalogo();
const { db, bucket, Timestamp } = await conectar();

// Nada con el mismo id que no sea de muestra: si existe, se frena todo.
const snaps = await db.getAll(...rutasSembradas(catalogo).map((r) => db.doc(r)));
const ajenos = snaps.filter((s) => s.exists && s.get('muestra') !== true).map((s) => s.ref.path);
if (ajenos.length) {
  console.error(`::error::estos documentos existen y NO son de muestra; no se toca nada:\n  ${ajenos.join('\n  ')}`);
  process.exit(1);
}

async function subirFoto(id, foto) {
  const destino = `productos/${id}/${foto.hash}.webp`;
  const archivo = bucket.file(destino);
  const [existe] = await archivo.exists();
  if (!existe) {
    await archivo.save(foto.webp, {
      resumable: false,
      contentType: 'image/webp',
      metadata: { cacheControl: 'public, max-age=31536000, immutable' },
    });
  }
  // Una carpeta, un archivo: lo que haya quedado de una foto anterior se va.
  const [archivos] = await bucket.getFiles({ prefix: `productos/${id}/` });
  for (const f of archivos) if (f.name !== destino) await f.delete();
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(destino)}?alt=media`;
}

const lote = db.batch();
for (const b of catalogo.bodegas) {
  lote.set(db.doc(`bodegas/${b.id}`), { nombre: b.nombre, slug: b.slug, muestra: true });
}

let conFoto = 0;
for (const v of catalogo.vinos) {
  const imagenes = [];
  if (v.foto) {
    const foto = await prepararFoto(join(AQUI, 'fotos', v.foto));
    if (foto.ok) {
      imagenes.push(await subirFoto(v.id, foto));
      conFoto++;
    } else {
      console.warn(`--  ${v.slug}: la foto no se sube (${foto.motivo}); queda sin foto`);
    }
  }
  const doc = {
    tipo: 'simple',
    slug: v.slug,
    nombre: v.nombre,
    precio: v.precio,
    stock: v.stock,
    presentacion: { botellas: v.botellas },
    imagenes,
    publicado: true,
    muestra: true,
    fichaVino: {
      bodegaId: v.bodegaId,
      varietales: v.varietales,
      color: v.color,
      organico: v.organico,
      anada: v.anada,
      region: v.region,
      volumenMl: v.volumenMl,
    },
  };
  const valido = validarProducto(v.id, doc);
  if (!valido.ok) {
    console.error(`::error::${v.id} no cumple el contrato: ${valido.motivo}`);
    process.exit(1);
  }
  lote.set(db.doc(`productos/${v.id}`), doc);
}

// Recalculada entera y con set() sin merge: correrla dos veces da lo mismo.
lote.set(db.doc('metricas/popularidad'), {
  simulada: true,
  muestra: true,
  calculadaEn: Timestamp.now(),
  unidades: Object.fromEntries(catalogo.vinos.map((v) => [v.id, v.unidades])),
});

await lote.commit();
console.log(
  `sembrado en ${db.projectId}: ${catalogo.vinos.length} productos (${conFoto} con foto), ` +
    `${catalogo.bodegas.length} bodegas y metricas/popularidad (simulada)`,
);
