import { carritoVacio, parsearCarrito, type Carrito } from '@bouquet/contratos';

/* El carrito en el navegador. ARQUITECTURA §4.4 y ADR 004: no hay colección
 * `carritos`; el carrito es de quien compra y vive en su localStorage. Cero
 * lecturas de Firestore, hoy y después.
 *
 * Guarda `{ version, idCompra, lineas }` y NADA más: ni precio ni nombre
 * (specs/vidriera-carrito). Lo valida `parsearCarrito` de contratos, el mismo
 * parser que va a usar `crearOrden`. Si lo guardado no valida —una cantidad
 * negativa, una versión desconocida—, el carrito arranca vacío con un
 * `idCompra` nuevo, sin romper la página.
 *
 * Si el navegador bloquea localStorage, el carrito vive en memoria durante la
 * visita: el `try` de cada acceso es a propósito, no descuido. */

const CLAVE = 'bouquet.carrito';

/**
 * Lo que ve el servidor: nunca tiene carrito. Sólo sirve para el primer render.
 *
 * ⚠️ Su idCompra es uno que `parsearCarrito` RECHAZA (tiene menos de 16
 * caracteres), a propósito. Si algo leyera el carrito antes de hidratar y lo
 * mandara a `crearOrden`, todos los compradores mandarían la misma clave de
 * idempotencia y la orden de uno le llegaría a otro. Así, rebota
 * (revisor-pagos, 2026-09-11; lo prueba apps/tienda/test/almacen.test.ts).
 */
export const CARRITO_DEL_SERVIDOR: Carrito = { version: 1, idCompra: 'sin-hidratar', lineas: [] };

let actual: Carrito | null = null;
const oyentes = new Set<() => void>();

function nuevoIdCompra(): string {
  const c = globalThis.crypto;
  if (typeof c.randomUUID === 'function') return c.randomUUID();
  return Array.from(c.getRandomValues(new Uint8Array(16)), (b) => b.toString(16).padStart(2, '0')).join('');
}

function escribir(carrito: Carrito) {
  try {
    window.localStorage.setItem(CLAVE, JSON.stringify(carrito));
  } catch {
    // Sin localStorage: queda en memoria (`actual`) durante la visita.
  }
}

function leer(): Carrito {
  let texto: string | null = null;
  try {
    texto = window.localStorage.getItem(CLAVE);
  } catch {
    // Bloqueado: se sigue con un carrito en memoria.
  }
  if (texto !== null) {
    const r = parsearCarrito(texto);
    if (r.ok) return r.valor;
  }
  const vacio = carritoVacio(nuevoIdCompra());
  escribir(vacio);
  return vacio;
}

/** El carrito de ahora. Devuelve SIEMPRE el mismo objeto hasta que cambie. */
export function carritoActual(): Carrito {
  if (actual === null) actual = leer();
  return actual;
}

export function guardarCarrito(carrito: Carrito) {
  actual = carrito;
  escribir(carrito);
  oyentes.forEach((avisar) => avisar());
}

/** Para `useSyncExternalStore`. Otra pestaña que cambie el carrito también avisa. */
export function suscribir(avisar: () => void) {
  oyentes.add(avisar);
  const deOtraPestana = (e: StorageEvent) => {
    if (e.key !== CLAVE) return;
    actual = null;
    avisar();
  };
  window.addEventListener('storage', deOtraPestana);
  return () => {
    oyentes.delete(avisar);
    window.removeEventListener('storage', deOtraPestana);
  };
}
