/**
 * El nucleo de `calcularPopularidad`: lee las Ordenes de la ventana, cuenta
 * las unidades vendidas de cada vino y reescribe `metricas/popularidad`
 * entero. HU-11.3, ADR 025.
 *
 * Recibe la base y el instante por parametro, sin `onSchedule` adentro, para
 * poder probarlo contra el emulador de Firestore SIN levantar el de Functions
 * -cuyo discovery no completa en esta maquina-. Es el molde de `guardar.ts`.
 *
 * IDEMPOTENTE POR CONSTRUCCION, que es todo el punto de recalcular en vez de
 * acumular (ADR 008):
 *   - La ventana la fija `ahora`, que el job saca de la hora PROGRAMADA de la
 *     corrida y no del reloj: un reintento de la misma corrida mira las mismas
 *     Ordenes, aunque arranque una hora despues.
 *   - `contarPopularidad` es pura y ordena las claves.
 *   - El `set` reescribe el documento ENTERO, sin merge: dos corridas dan el
 *     mismo documento, y no hay un marcador que perder entre dos escrituras
 *     -no hay dos escrituras-.
 *
 * SIN TRANSACCION, a proposito: una Orden que cambia de estado mientras se lee
 * la ventana entra con el estado que tenia al leerla, y la corrida de manana
 * la cuenta bien. Un ranking de 90 dias no se mueve por un pedido de hoy.
 */
import { Timestamp, type Firestore } from 'firebase-admin/firestore';

import { contarPopularidad, inicioDeLaVentana, VENTANA_DE_POPULARIDAD_DIAS } from '@bouquet/contratos';

export interface ResultadoDelCalculo {
  /** Cuantas Ordenes se leyeron: es lo que cuesta la corrida, en lecturas. */
  readonly leidas: number;
  /** Cuantas contaron como venta. */
  readonly ventas: number;
  /** Cuantos vinos distintos vendieron algo. */
  readonly vinos: number;
  /** Documentos que no se pudieron leer como Orden. */
  readonly ilegibles: number;
}

export async function calcularPopularidad(db: Firestore, ahora: Date): Promise<ResultadoDelCalculo> {
  const desde = inicioDeLaVentana(ahora);

  // Un rango sobre UN campo: el indice automatico de `creadaEn`, cero indices
  // compuestos. El `select` baja lo que viaja, no lo que se cobra: cada Orden
  // de la ventana es una lectura igual (el presupuesto esta en ADR 025).
  //
  // El tope de arriba es `ahora`, no "hasta el final": una Orden creada
  // despues de la hora programada queda para la corrida de manana, y un
  // reintento cuenta exactamente lo mismo que el primer intento.
  const instantanea = await db
    .collection('ordenes')
    .where('creadaEn', '>=', Timestamp.fromDate(desde))
    .where('creadaEn', '<', Timestamp.fromDate(ahora))
    .select('estadoPago', 'estadoEntrega', 'items')
    .get();

  const contada = contarPopularidad(instantanea.docs.map((d) => d.data()));

  // `simulada: false` es lo que el panel mira para creerle
  // (`LoQueMasSeVende.desde`): el documento que escribia el seed decia `true`.
  await db.doc('metricas/popularidad').set({
    simulada: false,
    calculadaEn: Timestamp.fromDate(ahora),
    desde: Timestamp.fromDate(desde),
    ventanaDias: VENTANA_DE_POPULARIDAD_DIAS,
    ventas: contada.ventas,
    unidades: contada.unidades,
  });

  return {
    leidas: instantanea.size,
    ventas: contada.ventas,
    vinos: Object.keys(contada.unidades).length,
    ilegibles: contada.ilegibles,
  };
}
