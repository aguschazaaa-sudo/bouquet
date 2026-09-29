/**
 * `calcularPopularidad` -- el job que mide lo que se vende. HU-11.3, ADR 025.
 *
 * Hasta hoy `metricas/popularidad` lo escribia solo el seed, con numeros
 * inventados y `simulada: true`, y EP-11 lo dejo escrito: *"hasta el job, esta
 * pantalla no existe"*. Este es el job.
 *
 * Corre una vez por dia, de madrugada en Cordoba: el ranking mira 90 dias, asi
 * que recalcularlo mas seguido gasta lecturas sin mover nada que se vea.
 *
 * La hora de la corrida sale de `scheduleTime`, la PROGRAMADA, y no del reloj:
 * un reintento de la misma corrida recalcula la misma ventana (`calcular.ts`).
 */
import { getFirestore } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { appDeFunctions } from '../firebase.ts';
import { calcularPopularidad as calcularEnFirestore } from './calcular.ts';

export const calcularPopularidad = onSchedule(
  {
    schedule: 'every day 05:00',
    timeZone: 'America/Argentina/Cordoba',
    region: 'us-central1',
    // Recalcular es idempotente: reintentar no infla nada.
    retryCount: 2,
  },
  async (evento) => {
    const programada = new Date(evento.scheduleTime);
    // Una corrida a mano (`gcloud scheduler jobs run`) tambien trae la hora;
    // si alguna vez no la trae, el reloj es la mejor aproximacion.
    const ahora = Number.isNaN(programada.getTime()) ? new Date() : programada;

    const r = await calcularEnFirestore(getFirestore(appDeFunctions()), ahora);
    (r.ilegibles > 0 ? logger.warn : logger.info)('popularidad recalculada', { ...r, ahora: ahora.toISOString() });
  },
);
