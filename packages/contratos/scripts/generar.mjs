#!/usr/bin/env node
// generar.mjs - emite generated/contratos.json desde el TypeScript.
//
// Ese JSON es lo unico que el panel en Flutter puede leer para verificar que
// su enum de Dart dice lo mismo que el contrato. Se commitea a proposito: el
// test de Dart tiene que poder correr sin Node.
//
// La frescura la verifica scripts/ci/auditar_estados.mjs. Sin esa
// verificacion el JSON envejece, el test de Dart pasa contra un contrato que
// ya no existe, y el test se vuelve teatro.

import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import {
  ESTADOS_ENTREGA,
  ESTADOS_PAGO,
  NACE_ENTREGA,
  NACE_PAGO,
  TRANSICIONES_ENTREGA,
  TRANSICIONES_PAGO,
} from '../src/orden.ts';
import { ESTADOS_PUBLICOS, REQUIEREN_ACCION, ROTULOS } from '../src/proyeccion.ts';
import { MONTOS_DE_MUESTRA, centavos, formatearARS } from '../src/dinero.ts';
import {
  ENTRADAS_DE_TEXTO,
  PARES_DE_TEXTO,
  aSlug,
  clave,
  normalizar,
  seParecen,
} from '../src/texto.ts';
import { proyectarEstadoPublico } from '../src/proyeccion.ts';

const AQUI = dirname(fileURLToPath(import.meta.url));
export const DESTINO = join(AQUI, '..', 'generated', 'contratos.json');

export function construirContrato() {
  // La tabla de proyeccion completa va en el JSON a proposito: asi el lado de
  // Dart no re-implementa la logica -la LEE-, y no hay dos implementaciones
  // del mismo rotulo esperando a desincronizarse.
  const proyeccion = {};
  for (const pago of ESTADOS_PAGO) {
    for (const entrega of ESTADOS_ENTREGA) {
      proyeccion[`${pago}|${entrega}`] = proyectarEstadoPublico(pago, entrega);
    }
  }

  return {
    version: 1,
    generadoPor: 'packages/contratos/scripts/generar.mjs',
    noEditarAMano: true,
    pago: {
      estados: [...ESTADOS_PAGO],
      naceEn: [...NACE_PAGO],
      transiciones: Object.fromEntries(
        ESTADOS_PAGO.map((e) => [e, [...TRANSICIONES_PAGO[e]]]),
      ),
    },
    entrega: {
      estados: [...ESTADOS_ENTREGA],
      naceEn: [...NACE_ENTREGA],
      transiciones: Object.fromEntries(
        ESTADOS_ENTREGA.map((e) => [e, [...TRANSICIONES_ENTREGA[e]]]),
      ),
    },
    // ARQUITECTURA §7: la normalizacion vive en UN lugar, y el panel la
    // espeja en Dart.  Lo que viaja NO es la implementacion -no se puede
    // transportar en JSON- sino pares entrada->salida CALCULADOS ACA por el
    // TypeScript de hoy.  Asi el test de Dart no puede pasar contra una
    // version vieja sin que auditar_estados.mjs lo cante primero.
    texto: {
      casos: ENTRADAS_DE_TEXTO.map((entrada) => ({
        entrada,
        normalizar: normalizar(entrada),
        clave: clave(entrada),
        aSlug: aSlug(entrada),
      })),
      pares: PARES_DE_TEXTO.map(([a, b]) => ({ a, b, seParecen: seParecen(a, b) })),
    },
    // El panel muestra los mismos precios que la vidriera. El formato de
    // es-AR usa punto para los miles, coma para los decimales y un espacio
    // que no es el de la barra espaciadora: escrito a ojo del otro lado da
    // OTRO NUMERO, no un numero mal alineado.
    plata: {
      casos: MONTOS_DE_MUESTRA.map((c) => ({ centavos: c, ars: formatearARS(centavos(c)) })),
    },
    publico: {
      estados: [...ESTADOS_PUBLICOS],
      requierenAccion: [...REQUIEREN_ACCION],
      rotulos: ROTULOS,
      proyeccion,
    },
  };
}

/** Serializacion estable: dos corridas iguales dan bytes iguales. */
export function serializar(contrato) {
  return JSON.stringify(contrato, null, 2) + '\n';
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  writeFileSync(DESTINO, serializar(construirContrato()), 'utf8');
  console.log(`escrito: ${DESTINO}`);
}
