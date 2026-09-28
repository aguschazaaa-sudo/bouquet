/**
 * La transaccion que aplica lo que dijo el proveedor a una Orden: el unico
 * lugar que escribe `estadoPago` despues de nacer.  La usan el aviso de
 * Mercado Pago y `revisarPago` (HU-08.3): dos caminos, UN nucleo, asi que el
 * mismo hecho que llega por los dos tiene efecto una vez.  ADR 022 §3.
 *
 * Recibe la base por parametro, sin `onRequest` ni `onCall` adentro, para
 * probarla contra el emulador de Firestore sin el de Functions.  Es el molde de
 * `crear.ts` y `cancelar.ts`.
 *
 * EN LA MISMA TRANSACCION (ADR 003, regla 3):
 *
 *  1. Leer la Orden y el marcador del hecho.  Si el marcador existe, el hecho
 *     ya se proceso -aplicado o no- y no se toca nada.
 *  2. Decidir con `resolverConsulta`, sobre la Orden que se ACABA de leer.
 *  3. Crear el marcador, SIEMPRE: lo que no se aplica tambien se registra
 *     (ADR 003, regla 4).  Y si se aplica, escribir `estadoPago` y `pago`.
 *
 * Y lo que NO se hace: tocar `estadoEntrega`.  Un pago que llega sobre una
 * Orden cancelada la deja *"cancelada con pago"*, que es lo que paso.
 */
import { FieldValue, type Firestore } from 'firebase-admin/firestore';

import {
  ESTADOS_PAGO,
  ORIGENES,
  alertaDePago,
  centavos,
  idDelMarcadorDePago,
  pagoDeOrden,
  requiereAtencion,
  resolverConsulta,
  type ConsultaDePago,
  type EstadoPago,
  type MotivoSinAplicar,
  type OrdenParaCobrar,
  type Origen,
} from '@bouquet/contratos';

export type ResultadoDeAplicar =
  /** El pago no trae un id de Orden nuestro: es otra venta de la misma cuenta. */
  | { readonly es: 'sin-orden' }
  | { readonly es: 'orden-inexistente'; readonly ordenId: string }
  /** La Orden tiene un dato que no se puede leer: no se escribe encima. */
  | { readonly es: 'orden-rota'; readonly ordenId: string }
  /** El marcador ya estaba: este hecho ya se proceso. */
  | { readonly es: 'repetido'; readonly ordenId: string; readonly estadoPago: EstadoPago }
  | { readonly es: 'aplicado'; readonly ordenId: string; readonly estadoPago: EstadoPago; readonly cambio: boolean }
  | {
      readonly es: 'sin-aplicar';
      readonly ordenId: string;
      readonly estadoPago: EstadoPago;
      readonly motivo: MotivoSinAplicar;
      /** true si dejo `alertaDePago` en la Orden: movio plata que la Orden no refleja. */
      readonly atencion: boolean;
    };

const esOrigen = (x: unknown): x is Origen => typeof x === 'string' && (ORIGENES as readonly string[]).includes(x);
const esEstadoPago = (x: unknown): x is EstadoPago =>
  typeof x === 'string' && (ESTADOS_PAGO as readonly string[]).includes(x);

function paraCobrar(ordenId: string, datos: Record<string, unknown>): OrdenParaCobrar | null {
  const { origen, estadoPago, total, pago } = datos;
  if (!esOrigen(origen) || !esEstadoPago(estadoPago)) return null;
  if (typeof total !== 'number' || !Number.isSafeInteger(total) || total < 0) return null;
  // La operacion ya aplicada: sin ella no se distingue un segundo cobro.  Un
  // `pago` sin `operacionId` se lee como "ninguna aplicada".
  const aplicada = typeof pago === 'object' && pago !== null ? (pago as Record<string, unknown>).operacionId : undefined;
  return { ordenId, origen, estadoPago, total: centavos(total), operacionId: typeof aplicada === 'string' ? aplicada : null };
}

/**
 * `por` dice quien disparo la consulta: `aviso:mercadopago`, o el uid de quien
 * toco *"volver a consultar"*.  Queda en el marcador.
 */
export async function aplicarConsulta(
  db: Firestore,
  consulta: ConsultaDePago,
  por: string,
): Promise<ResultadoDeAplicar> {
  const { ordenId } = consulta;
  if (ordenId === null) return { es: 'sin-orden' };

  const orden = db.collection('ordenes').doc(ordenId);
  const marcador = orden.collection('marcadores').doc(idDelMarcadorDePago(consulta));

  return db.runTransaction(async (tx): Promise<ResultadoDeAplicar> => {
    const [snap, snapMarcador] = await tx.getAll(orden, marcador);
    if (!snap?.exists) return { es: 'orden-inexistente', ordenId };

    const leida = paraCobrar(ordenId, snap.data() ?? {});
    if (leida === null) return { es: 'orden-rota', ordenId };

    // 1. El hecho ya se proceso.  No se mira si se aplico: un hecho que no se
    //    aplico la primera vez tampoco se aplica ahora (ADR 022 §3).
    if (snapMarcador?.exists) return { es: 'repetido', ordenId, estadoPago: leida.estadoPago };

    // 2. La regla, sobre lo que se acaba de leer.
    const r = resolverConsulta(leida, consulta);

    // 3. El marcador SIEMPRE, y con lo necesario para entender despues que paso.
    //    `create` y no `set`: un choque tiene que fallar, no pisar un marcador.
    tx.create(marcador, {
      aplicado: r.aplica,
      motivo: r.aplica ? null : r.motivo,
      antes: leida.estadoPago,
      despues: r.aplica ? r.estadoPago : leida.estadoPago,
      consulta: { ...pagoDeOrden(consulta), estado: consulta.estado, moneda: consulta.moneda, creadoEn: consulta.creadoEn },
      por,
      en: FieldValue.serverTimestamp(),
    });

    if (!r.aplica) {
      // Lo que movio plata y la Orden no refleja se VE en el panel: la ultima
      // alerta queda en la Orden, sin tocar `estadoPago` ni `pago`.
      const atencion = requiereAtencion(consulta, r);
      if (atencion) {
        tx.update(orden, {
          alertaDePago: { ...alertaDePago(consulta, r.motivo), en: FieldValue.serverTimestamp() },
          actualizadaEn: FieldValue.serverTimestamp(),
        });
      }
      return { es: 'sin-aplicar', ordenId, estadoPago: leida.estadoPago, motivo: r.motivo, atencion };
    }

    tx.update(orden, {
      estadoPago: r.estadoPago,
      pago: { ...pagoDeOrden(consulta), consultadoEn: FieldValue.serverTimestamp() },
      actualizadaEn: FieldValue.serverTimestamp(),
    });
    return { es: 'aplicado', ordenId, estadoPago: r.estadoPago, cambio: r.cambia };
  });
}
