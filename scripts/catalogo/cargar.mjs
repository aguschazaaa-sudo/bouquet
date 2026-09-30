#!/usr/bin/env node
// cargar.mjs - da de alta vinos REALES desde un JSON, igual que el panel.
//
// Uso:
//   node scripts/catalogo/cargar.mjs                    muestra lo que cargaria, sin escribir
//   node scripts/catalogo/cargar.mjs --cargar           carga
//   node scripts/catalogo/cargar.mjs --cargar otro.json carga otro archivo (default: carga-inicial.json)
//
// Existe para cargar de una vez los vinos que el duenio ya sabe que tiene
// (2026-09-30): uno por uno desde el panel son 24 formularios y 24 fotos
// buscadas a mano. Lo que escribe es un vino como los que escribe el panel, y
// NO un dato de muestra:
//
//   1. Sin `muestra`. El id es el slug (ADR 013), igual en bodegas.
//   2. Las claves opcionales vacias se omiten, como `documento_del_vino.dart`.
//   3. La foto pasa por `prepararFoto` (../seed/foto.mjs), que es la tuberia
//      que `tuberia.test.ts` compara byte a byte con `procesarFoto`, y va a
//      `productos/{id}/{hash}.webp`, la ruta de la callable.
//   4. Cada documento pasa por `validarProducto` ANTES de escribir nada.
//
// Y lo que no hace, a proposito:
//
//   · NUNCA pisa. Un vino o una bodega que ya existe se saltea: despues de
//     cargado, la verdad es lo que el duenio corrigio en el panel, no este
//     JSON. Por eso se puede volver a correr con la segunda mitad del stock.
//   · Si algun id ya existe como MUESTRA, frena todo: primero se borra la
//     muestra (scripts/seed/borrar.mjs), despues se carga lo real.
//   · El stock nace con el numero del JSON y SIN movimiento en
//     `productos/{id}/movimientos`: no hubo una reposicion, y registrar una
//     seria inventar un hecho. El primer conteo del duenio (moverStock,
//     `corregir`) es el primer movimiento.
//   · No toca la portada ni las cajas sugeridas: son curaduria del duenio.

import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { validarProducto } from '../../packages/contratos/src/producto.ts';
import { prepararFoto } from '../seed/foto.mjs';
import { BUCKET, conectar } from '../seed/proyecto.mjs';

const AQUI = dirname(fileURLToPath(import.meta.url));
const SLUG = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

const cargar = process.argv.includes('--cargar');
const archivo = process.argv.slice(2).find((a) => a.endsWith('.json')) ?? 'carga-inicial.json';
const datos = JSON.parse(readFileSync(join(AQUI, archivo), 'utf8'));

// ------------------------------------------------ validar, sin conectarse

const errores = [];
const bodegas = new Map(datos.bodegas.map((b) => [b.slug, b]));
if (bodegas.size !== datos.bodegas.length) errores.push('hay una bodega repetida');
for (const b of datos.bodegas) {
  if (!SLUG.test(b.slug)) errores.push(`bodega ${b.slug}: slug invalido`);
  if (!b.nombre?.trim()) errores.push(`bodega ${b.slug}: falta el nombre`);
}

const slugs = new Set();
const documentos = [];
for (const v of datos.vinos) {
  if (slugs.has(v.slug)) errores.push(`${v.slug}: repetido`);
  slugs.add(v.slug);
  if (!bodegas.has(v.bodega)) errores.push(`${v.slug}: la bodega ${v.bodega} no esta en la lista`);
  if (v.foto && !existsSync(join(AQUI, 'fotos', v.foto))) errores.push(`${v.slug}: no esta la foto fotos/${v.foto}`);

  const doc = {
    tipo: 'simple',
    slug: v.slug,
    nombre: v.nombre,
    precio: v.precio,
    stock: v.stock,
    presentacion: { botellas: v.botellas ?? 1 },
    imagenes: [],
    publicado: v.publicado,
    fichaVino: {
      bodegaId: v.bodega,
      varietales: v.varietales,
      color: v.color,
      organico: v.organico,
      region: v.region,
      volumenMl: v.volumenMl ?? 750,
      ...(v.anada != null && { anada: v.anada }),
      ...(v.graduacion != null && { graduacion: v.graduacion }),
      ...(v.descripcion != null && { descripcion: v.descripcion }),
    },
  };
  // Con una URL de mentira: la de verdad sale del hash, despues de conectarse,
  // y el contrato solo mira que sea https.
  const valido = validarProducto(v.slug, { ...doc, imagenes: v.foto ? ['https://validar'] : [] });
  if (!valido.ok) errores.push(`${v.slug}: ${valido.motivo}`);
  documentos.push({ v, doc });
}

if (errores.length) {
  console.error(`::error::${archivo} no se carga:\n  ${errores.join('\n  ')}`);
  process.exit(1);
}

// ------------------------------------------------------------- conectar

const { db, bucket } = await conectar();

const refsBodegas = datos.bodegas.map((b) => db.doc(`bodegas/${b.slug}`));
const refsVinos = documentos.map(({ v }) => db.doc(`productos/${v.slug}`));
const existentes = await db.getAll(...refsBodegas, ...refsVinos);
const muestra = existentes.filter((s) => s.exists && s.get('muestra') === true).map((s) => s.ref.path);
if (muestra.length) {
  console.error(`::error::estos ids existen como MUESTRA; borrala primero (scripts/seed/borrar.mjs):\n  ${muestra.join('\n  ')}`);
  process.exit(1);
}
const yaExiste = new Set(existentes.filter((s) => s.exists).map((s) => s.ref.path));

async function subirFoto(id, foto) {
  const destino = `productos/${id}/${foto.hash}.webp`;
  const archivoFinal = bucket.file(destino);
  const [existe] = await archivoFinal.exists();
  if (!existe) {
    await archivoFinal.save(foto.webp, {
      resumable: false,
      contentType: 'image/webp',
      metadata: { cacheControl: 'public, max-age=31536000, immutable' },
    });
  }
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(destino)}?alt=media`;
}

const lote = db.batch();
let nuevasBodegas = 0;
for (const b of datos.bodegas) {
  const ruta = `bodegas/${b.slug}`;
  if (yaExiste.has(ruta)) {
    console.log(`se queda   ${ruta}: ya existe`);
    continue;
  }
  console.log(`${cargar ? 'crea      ' : 'crearia   '} ${ruta}`);
  lote.create(db.doc(ruta), { nombre: b.nombre, slug: b.slug });
  nuevasBodegas++;
}

let nuevosVinos = 0;
for (const { v, doc } of documentos) {
  const ruta = `productos/${v.slug}`;
  if (yaExiste.has(ruta)) {
    console.log(`se queda   ${ruta}: ya existe, lo que cambio el panel manda`);
    continue;
  }
  let imagenes = [];
  if (v.foto) {
    const foto = await prepararFoto(join(AQUI, 'fotos', v.foto));
    if (!foto.ok) {
      console.error(`::error::${v.slug}: la foto no sirve (${foto.motivo}); no se carga nada`);
      process.exit(1);
    }
    imagenes = cargar ? [await subirFoto(v.slug, foto)] : [`(${foto.hash}.webp)`];
  }
  const precio = `$ ${(v.precio / 100).toLocaleString('es-AR')}`;
  console.log(
    `${cargar ? 'crea      ' : 'crearia   '} ${ruta} | ${precio} | stock ${v.stock} | ` +
      `${v.publicado ? 'publicado' : 'BORRADOR'} | foto ${imagenes[0] ?? 'no'}`,
  );
  lote.create(db.doc(ruta), { ...doc, imagenes });
  nuevosVinos++;
}

if (cargar && nuevasBodegas + nuevosVinos > 0) await lote.commit();
console.log(
  `\n${cargar ? 'cargados' : 'se cargarian'}: ${nuevosVinos} vinos y ${nuevasBodegas} bodegas en ${db.projectId}` +
    (cargar ? '' : '\n(nada se escribio: correr con --cargar)'),
);
