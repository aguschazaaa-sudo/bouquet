// iconos_del_panel.mjs - el favicon y los iconos de la app web del panel,
// hechos con el isotipo (la copa) del PNG de la marca.
//
//   node scripts/assets/iconos_del_panel.mjs
//
// Escribe en apps/admin/web/: favicon.png e icons/Icon-{192,512}.png y sus
// versiones maskable. El fondo es tinta: sobre oscuro el borgona solo se ve
// si una linea dorada lo delimita (direccion.md §2.2), y en la copa lo hace.
//
// La copa se recorta sola: es todo lo que queda por encima del wordmark,
// recortado a los pixeles que no son transparentes. Re-ejecutable.

import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import sharp from 'sharp';

const RAIZ = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const LOGO = join(RAIZ, 'docs', 'marca', 'logo-bouquet-rgb.png');
const WEB = join(RAIZ, 'apps', 'admin', 'web');
const TINTA = '#1a1210';

// El wordmark empieza cerca del 62 % del alto (medido sobre el PNG de
// 3508 x 2481: la copa termina en y ~ 1530 y BOUQUET empieza en ~ 1640).
const FIN_DE_LA_COPA = 0.64;

async function copa() {
  const { width, height } = await sharp(LOGO).metadata();
  const recorte = await sharp(LOGO)
    .extract({ left: 0, top: 0, width, height: Math.round(height * FIN_DE_LA_COPA) })
    .png()
    .toBuffer();
  const sola = await sharp(recorte).trim().png().toBuffer({ resolveWithObject: true });
  const { width: w, height: h } = sola.info;
  // Control: la copa es mas alta que ancha. Si el recorte agarro el wordmark,
  // sale apaisada y esto frena antes de escribir iconos que mienten.
  if (!(h > w)) throw new Error(`la copa recortada mide ${w}x${h}: no parece la copa`);
  return sola.data;
}

async function icono(isotipo, lado, proporcion, destino) {
  const alto = Math.round(lado * proporcion);
  const figura = await sharp(isotipo).resize({ height: alto }).png().toBuffer();
  await sharp({ create: { width: lado, height: lado, channels: 4, background: TINTA } })
    .composite([{ input: figura, gravity: 'center' }])
    .png()
    .toFile(destino);
  console.log(`ok  ${destino.slice(RAIZ.length + 1)}  ${lado}px`);
}

const isotipo = await copa();
mkdirSync(join(WEB, 'icons'), { recursive: true });
await icono(isotipo, 48, 0.8, join(WEB, 'favicon.png'));
await icono(isotipo, 192, 0.7, join(WEB, 'icons', 'Icon-192.png'));
await icono(isotipo, 512, 0.7, join(WEB, 'icons', 'Icon-512.png'));
// Maskable: el sistema puede recortar hasta un circulo del 80 %; la figura
// va mas chica para que la copa no pierda el pie.
await icono(isotipo, 192, 0.52, join(WEB, 'icons', 'Icon-maskable-192.png'));
await icono(isotipo, 512, 0.52, join(WEB, 'icons', 'Icon-maskable-512.png'));
