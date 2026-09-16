#!/usr/bin/env node
// acceso.mjs - dar, quitar y listar el acceso al panel.  HU-01.3,
// openspec/changes/panel-entrar/specs/panel-cuentas.
//
// Uso:
//   node scripts/acceso/acceso.mjs dar <mail>
//   node scripts/acceso/acceso.mjs quitar <mail>
//   node scripts/acceso/acceso.mjs listar
//   ... --emulador      contra el emulador de Auth (proyecto demo-bouquet)
//
// Credenciales: `gcloud auth application-default login`, igual que el seed.
//
// El permiso es el custom claim `rol: admin` (ARQUITECTURA §9.2), y solo lo
// puede escribir el Admin SDK: por eso esto es un script y no una pantalla.
// La pantalla tiene disparador: la primera vez que alguien tenga que esperar
// al desarrollador para entrar.
//
// LAS DOS COSAS QUE ESTE SCRIPT HACE Y NO SE VEN:
//
//  1. Crea la cuenta SIN contrasena. La persona entra con Google, o pide el
//     correo "no tengo contrasena" del panel, que la crea Y verifica el mail.
//     Con el mail verificado, entrar despues con Google no desvincula la
//     contrasena (medido en el emulador el 2026-09-16, design.md §1).
//
//  2. Se NIEGA a habilitar una cuenta con contrasena y el mail sin verificar.
//     La API key web es publica: cualquiera puede registrar el mail de un
//     familiar con una contrasena suya. Si este script le diera el claim a
//     "la cuenta de ese mail", el panel quedaria en manos de quien la
//     registro. Es el registro anticipado, y ningun documento lo tenia.

import { pathToFileURL } from 'node:url';

export const PROYECTO = 'bouquet-vinos';
export const PROYECTO_EMULADOR = 'demo-bouquet';
export const ROL = 'admin';

export class AccesoNegado extends Error {}

/**
 * La conexion, con el projectId FIJO: con ADC y sin projectId el Admin SDK
 * usa el proyecto activo de gcloud, que en esta maquina es otro (medido,
 * scripts/seed/proyecto.mjs).
 */
export async function conectar({ emulador = false } = {}) {
  if (emulador) {
    process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
  } else {
    if (process.env.FIREBASE_AUTH_EMULATOR_HOST) {
      throw new AccesoNegado(
        `FIREBASE_AUTH_EMULATOR_HOST=${process.env.FIREBASE_AUTH_EMULATOR_HOST} ` +
          'esta puesto: el Admin SDK iria al emulador creyendo que es produccion. ' +
          'Usa --emulador, o saca la variable.',
      );
    }
    // Sin esto, cada pedido se factura contra la cuota de las credenciales.
    process.env.GOOGLE_CLOUD_QUOTA_PROJECT = PROYECTO;
  }

  const { applicationDefault, deleteApp, initializeApp } = await import('firebase-admin/app');
  const { getAuth } = await import('firebase-admin/auth');
  const opciones = emulador
    ? { projectId: PROYECTO_EMULADOR }
    : { credential: applicationDefault(), projectId: PROYECTO };
  const app = initializeApp(opciones, `acceso-${process.pid}-${Date.now()}`);
  return { auth: getAuth(app), proyecto: opciones.projectId, cerrar: () => deleteApp(app) };
}

export function normalizarMail(mail) {
  const limpio = String(mail ?? '').trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(limpio)) {
    throw new AccesoNegado(`"${mail ?? ''}" no es un mail.`);
  }
  return limpio;
}

async function buscar(auth, mail) {
  try {
    return await auth.getUserByEmail(mail);
  } catch (e) {
    if (e?.code === 'auth/user-not-found') return null;
    throw e;
  }
}

const proveedores = (usuario) => usuario.providerData.map((p) => p.providerId);

/** Deja la cuenta de `mail` con `rol: admin`, creandola si no existe. */
export async function darAcceso(auth, mail) {
  const email = normalizarMail(mail);
  let usuario = await buscar(auth, email);
  let creada = false;

  if (!usuario) {
    usuario = await auth.createUser({ email });
    creada = true;
  } else if (proveedores(usuario).includes('password') && !usuario.emailVerified) {
    throw new AccesoNegado(
      `${email} tiene una cuenta con contrasena y el mail SIN verificar.\n` +
        'Cualquiera puede registrar un mail ajeno: si esa cuenta no la creo la\n' +
        'persona duena del mail, darle acceso le da el panel a un extrano.\n' +
        'Borrala (consola de Firebase > Authentication) y volve a correr "dar":\n' +
        'la cuenta nueva nace sin contrasena y la persona la crea por correo.',
    );
  }

  const claims = { ...(usuario.customClaims ?? {}), rol: ROL };
  await auth.setCustomUserClaims(usuario.uid, claims);
  return { mail: email, uid: usuario.uid, creada, proveedores: proveedores(usuario) };
}

/** Saca el claim y revoca las sesiones. Un token ya emitido vale hasta una hora. */
export async function quitarAcceso(auth, mail) {
  const email = normalizarMail(mail);
  const usuario = await buscar(auth, email);
  if (!usuario) throw new AccesoNegado(`${email} no tiene cuenta.`);

  const { rol: _rol, ...resto } = usuario.customClaims ?? {};
  await auth.setCustomUserClaims(usuario.uid, Object.keys(resto).length ? resto : null);
  await auth.revokeRefreshTokens(usuario.uid);
  return { mail: email, uid: usuario.uid, teniaAcceso: _rol === ROL };
}

/** Los mails con `rol: admin`, recorriendo todas las paginas. */
export async function listarConAcceso(auth) {
  const mails = [];
  let pagina;
  do {
    const lote = await auth.listUsers(1000, pagina);
    for (const u of lote.users) {
      if (u.customClaims?.rol === ROL) mails.push(u.email ?? `(sin mail) ${u.uid}`);
    }
    pagina = lote.pageToken;
  } while (pagina);
  return mails.sort();
}

async function principal(argv) {
  const emulador = argv.includes('--emulador');
  const [comando, mail] = argv.filter((a) => !a.startsWith('--'));
  if (!['dar', 'quitar', 'listar'].includes(comando) || (comando !== 'listar' && !mail)) {
    console.error('uso: node scripts/acceso/acceso.mjs dar|quitar <mail> | listar  [--emulador]');
    return 2;
  }

  let conexion;
  try {
    conexion = await conectar({ emulador });
  } catch (e) {
    if (!(e instanceof AccesoNegado)) throw e;
    console.error(`NO  ${e.message}`);
    return 1;
  }
  const { auth, proyecto, cerrar } = conexion;
  try {
    console.log(`proyecto: ${proyecto}`);
    if (comando === 'dar') {
      const r = await darAcceso(auth, mail);
      console.log(`ok  ${r.mail} tiene acceso al panel${r.creada ? ' (cuenta nueva, sin contrasena)' : ''}`);
      console.log(
        r.proveedores.length
          ? `    entra con: ${r.proveedores.join(', ')}`
          : '    que entre con Google, o que toque "¿No tenés contraseña?" en el panel',
      );
      console.log('    si ya estaba adentro, que toque "Ya me dieron acceso"');
    } else if (comando === 'quitar') {
      const r = await quitarAcceso(auth, mail);
      console.log(`ok  ${r.mail} ${r.teniaAcceso ? 'ya no tiene' : 'no tenia'} acceso; sesiones revocadas`);
      console.log('    un token ya emitido sigue valiendo para las reglas hasta una hora');
    } else {
      const mails = await listarConAcceso(auth);
      console.log(`${mails.length} con acceso`);
      for (const m of mails) console.log(`  ${m}`);
    }
    return 0;
  } catch (e) {
    if (e instanceof AccesoNegado) {
      console.error(`NO  ${e.message}`);
      return 1;
    }
    throw e;
  } finally {
    await cerrar();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = await principal(process.argv.slice(2));
}
