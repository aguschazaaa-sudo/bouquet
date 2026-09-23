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
import {
  BALDES,
  BODEGAS_DE_MUESTRA,
  CASOS_DE_BALDE,
  CASOS_DE_DESCARTE,
  CLASES_DE_DESCARTE,
  TOPE_POR_PEDIDO,
  UMBRAL_QUEDAN_POCAS,
  armarCatalogo,
  balde,
  tope,
} from '../src/producto.ts';
import { proyectarEstadoPublico } from '../src/proyeccion.ts';
import {
  CASOS_DE_MOVIMIENTO,
  CODIGOS_DE_RECHAZO,
  MOTIVOS_DE_AJUSTE,
  TOPE_DE_STOCK,
  aplicarOperacion,
  parsearPedidoDeMovimiento,
} from '../src/stock.ts';

const AQUI = dirname(fileURLToPath(import.meta.url));
export const DESTINO = join(AQUI, '..', 'generated', 'contratos.json');

/**
 * Las fixtures del catalogo, CALCULADAS con el `balde`, el `tope` y el
 * `armarCatalogo` de hoy -- ninguna salida esta escrita a mano.
 *
 * `armarCatalogo` se llama UNA sola vez sobre todos los documentos porque el
 * slug duplicado solo existe de a dos, y cada caso se busca despues POR ID.
 * Que los ids no se repitan lo afirma un test de `producto.test.ts`: con un id
 * repetido, dos casos leerian el mismo motivo y uno de los dos seria teatro.
 */
function fixturesDelCatalogo() {
  const armado = armarCatalogo(
    CASOS_DE_DESCARTE.map((c) => c.documento),
    BODEGAS_DE_MUESTRA,
    undefined,
  );
  const motivoPorId = new Map(armado.descartes.map((d) => [d.id, d.motivo]));
  const enCatalogo = new Set(armado.catalogo.productos.map((p) => p.id));

  return {
    baldes: [...BALDES],
    umbralQuedanPocas: UMBRAL_QUEDAN_POCAS,
    topePorPedido: TOPE_POR_PEDIDO,
    clasesDeDescarte: [...CLASES_DE_DESCARTE],
    // Las bodegas que existen para estas fixtures: sin ellas, "bodega
    // inexistente" no se puede reproducir del otro lado.
    bodegas: BODEGAS_DE_MUESTRA.map((b) => ({ id: b.id, datos: b.datos })),
    casosDeBalde: CASOS_DE_BALDE.map((c) => ({
      porque: c.porque,
      stock: c.stock,
      botellas: c.botellas,
      balde: balde({ stock: c.stock, presentacion: { botellas: c.botellas } }),
      tope: tope({ stock: c.stock }),
    })),
    casosDeDescarte: CASOS_DE_DESCARTE.map((c) => ({
      porque: c.porque,
      clase: c.clase,
      id: c.documento.id,
      documento: c.documento.datos,
      // Las dos salidas: si aparece en la vidriera, y con que palabras quedo
      // afuera. `motivo` es null cuando entra.
      entra: enCatalogo.has(c.documento.id),
      motivo: motivoPorId.get(c.documento.id) ?? null,
    })),
  };
}

/**
 * Las fixtures de mover el stock, CALCULADAS con el parser y la cuenta de hoy.
 * `valido` es lo que dice `parsearPedidoDeMovimiento`; `resultado` es lo que
 * dice `aplicarOperacion` sobre el stock del caso -- `null` si ni siquiera
 * es una operacion valida.  El panel las verifica contra su espejo en Dart.
 */
function fixturesDelStock() {
  return {
    motivosDeAjuste: [...MOTIVOS_DE_AJUSTE],
    topeDeStock: TOPE_DE_STOCK,
    codigosDeRechazo: [...CODIGOS_DE_RECHAZO],
    casos: CASOS_DE_MOVIMIENTO.map((c) => {
      // El id y el producto son de relleno: lo que se prueba es la operacion.
      const pedido = parsearPedidoDeMovimiento({
        productoId: 'caso',
        idMovimiento: 'caso-de-movimiento-0001',
        operacion: c.operacion,
      });
      return {
        porque: c.porque,
        stock: c.stock,
        operacion: c.operacion,
        valido: pedido.ok,
        resultado: pedido.ok ? aplicarOperacion(c.stock, pedido.valor.operacion) : null,
      };
    }),
  };
}

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
    // El panel tiene que decir lo mismo que la vidriera sobre si un vino se
    // ve y, cuando no se ve, por que. La regla vive en `balde`, `tope` y
    // `armarCatalogo`, y NO se puede transportar en JSON: viajan documentos
    // de ejemplo con el motivo que `armarCatalogo` les puso HOY.
    //
    // Sin esto el panel reimplementa el descarte, las dos se desincronizan y
    // el modo de falla es silencioso: un vino publicado que no aparece nunca.
    catalogo: fixturesDelCatalogo(),
    stock: fixturesDelStock(),
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
