import { applicationDefault, cert, getApps, initializeApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';

/**
 * El único punto de entrada al Admin SDK. ADR 004: todo acceso a Firestore de
 * la vidriera vive en apps/tienda/src/server/**, nunca en un componente
 * cliente — server-only-guard.sh lo mide.
 *
 * El Admin SDK IGNORA firestore.rules (por diseño: es la identidad de
 * servidor). Eso es lo que permite que la vidriera lea `productos` aunque las
 * reglas denieguen la lectura a cualquier otro cliente (§9.1).
 *
 * Credenciales, en este orden (ADR 008):
 *  1. La service account de .env.example, si están sus dos claves.
 *  2. Si no está ninguna, Application Default Credentials: en App Hosting, la
 *     service account del backend; en la máquina de desarrollo,
 *     `gcloud auth application-default login`.
 *
 * ⚠️ El projectId va SIEMPRE explícito. Con ADC, el proyecto que se "resuelve"
 * sale de la configuración activa de gcloud, y en esta máquina esa
 * configuración apunta a OTRO proyecto (red-social-ryb3mf, medido el
 * 2026-09-10). Sin el projectId, la vidriera leería el catálogo de otro lado,
 * y una colección vacía no tira ningún error.
 */

const PROYECTO = 'bouquet-vinos';

function obtenerApp(): App {
  const existente = getApps();
  if (existente.length > 0) return existente[0]!;

  const projectId = process.env.FIREBASE_PROJECT_ID || PROYECTO;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

  if (clientEmail && privateKey) {
    return initializeApp({ credential: cert({ projectId, clientEmail, privateKey }), projectId });
  }
  if (clientEmail || privateKey) {
    // Media service account es un error de configuración, no un pedido de
    // ADC: caer a otras credenciales en silencio escondería el error.
    throw new Error(
      'FIREBASE_CLIENT_EMAIL y FIREBASE_PRIVATE_KEY van juntas, o no va ninguna ' +
        '(y entonces se usa Application Default Credentials). Ver .env.example.',
    );
  }
  return initializeApp({ credential: applicationDefault(), projectId });
}

export function db(): Firestore {
  return getFirestore(obtenerApp());
}
