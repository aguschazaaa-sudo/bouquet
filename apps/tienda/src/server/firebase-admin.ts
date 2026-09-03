import { cert, getApps, initializeApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';

/**
 * El único punto de entrada al Admin SDK. ADR 004: todo acceso a Firestore de
 * la vidriera vive en apps/tienda/src/server/**, nunca en un componente
 * cliente — server-only-guard.sh lo mide.
 *
 * El Admin SDK IGNORA firestore.rules (por diseño: es la identidad de
 * servidor). Eso es lo que permite que la vidriera lea `productos` aunque las
 * reglas denieguen la lectura a cualquier otro cliente (§9.1).
 */

function credencialesDesdeEnv() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
  if (!projectId || !clientEmail || !privateKey) {
    throw new Error(
      'Faltan credenciales de Firebase Admin: FIREBASE_PROJECT_ID, ' +
        'FIREBASE_CLIENT_EMAIL y FIREBASE_PRIVATE_KEY. Ver .env.example.',
    );
  }
  return { projectId, clientEmail, privateKey };
}

function obtenerApp(): App {
  const existente = getApps();
  if (existente.length > 0) return existente[0]!;
  const { projectId, clientEmail, privateKey } = credencialesDesdeEnv();
  return initializeApp({ credential: cert({ projectId, clientEmail, privateKey }) });
}

export function db(): Firestore {
  return getFirestore(obtenerApp());
}
