/**
 * El unico `initializeApp` del codebase de functions. Dentro de Cloud
 * Functions no hace falta pasar credenciales ni projectId: el runtime los da
 * por el ambiente. Es DISTINTO de `scripts/seed/proyecto.mjs`, que corre en
 * esta maquina y por eso fija projectId a mano (esta en otro proyecto de
 * gcloud) -- adentro de Cloud Functions esa ambiguedad no existe.
 */
import { type App, getApps, initializeApp } from 'firebase-admin/app';

let app: App;

export function appDeFunctions(): App {
  app ??= getApps()[0] ?? initializeApp();
  return app;
}
