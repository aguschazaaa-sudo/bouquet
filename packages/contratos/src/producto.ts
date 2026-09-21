/**
 * El Producto: el documento de Firestore, lo que se deriva de el, y lo UNICO
 * que llega al navegador.  ADR 008.
 *
 * Lo leen igual tres lados: la vidriera (proyeccion, balde, tope), la futura
 * `crearOrden` (tope y stock) y `firestore.rules`, que copia `VARIETALES` a
 * mano. Por eso `scripts/ci/auditar_varietales.mjs` compara las dos listas y
 * sale con 1 si difieren.
 *
 * La regla que ordena este archivo: la vidriera NUNCA recibe el stock ni las
 * unidades vendidas. Recibe el balde, el tope y el puesto, que son lo que la
 * pantalla necesita y nada que se pueda leer como un numero exacto.
 */

import { centavos, type Centavos } from './dinero.ts';

// ------------------------------------------------------------------ listas

export const TIPOS_DE_PRODUCTO = ['simple', 'compuesto'] as const;
export type TipoDeProducto = (typeof TIPOS_DE_PRODUCTO)[number];

export const COLORES = ['tinto', 'blanco', 'rosado'] as const;
export type Color = (typeof COLORES)[number];

/**
 * Lista CERRADA de uvas. El color del vino va aparte: un rosado de Malbec es
 * Malbec.
 *
 * Un varietal escrito "Cab. Sauv." no es un varietal nuevo: es un filtro que no
 * encuentra nada y un Cabernet que desaparece del catalogo sin que nadie lo
 * note. Agregar uno es un cambio en DOS lugares -esta lista y `firestore.rules`-
 * y CI falla si quedan distintos.
 */
export const VARIETALES = [
  'Malbec',
  'Cabernet Sauvignon',
  'Cabernet Franc',
  'Bonarda',
  'Syrah',
  'Merlot',
  'Pinot Noir',
  'Pinot Grigio',
  'Tannat',
  'Petit Verdot',
  'Tempranillo',
  'Criolla',
  'Chardonnay',
  'Torrontés',
  'Sauvignon Blanc',
  'Semillón',
  'Viognier',
  'Pinot Gris',
] as const;
export type Varietal = (typeof VARIETALES)[number];

/**
 * La graduacion se guarda en DECIMAS de grado y entera, como el precio en
 * centavos: un `14.0` de Dart y un `14` de JS se guardan distinto en Firestore
 * (`doubleValue` contra `integerValue`), y `is int` en las reglas rechazaria
 * uno de los dos segun quien escribio. ADR 013.
 *
 * El piso NO describe a los vinos: atrapa la UNIDAD EQUIVOCADA. Un `14`
 * escrito pensando en 14 % valdria 1,4 %; con el piso en 50 se rechaza, igual
 * que `13.5` (no es entero) y `1350` (se pasa del techo). Cada confusion de
 * unidad posible rebota. `firestore.rules` repite los dos numeros.
 */
export const GRADUACION_MINIMA = 50;
export const GRADUACION_MAXIMA = 250;

/**
 * Tope de la descripcion, en caracteres. El numero no es estetico: el catalogo
 * ENTERO viaja al navegador para filtrarse en memoria (ADR 006), asi que cada
 * caracter lo paga cada visitante, no solo quien abre esa ficha. Con 600 y 200
 * vinos el peor caso son 120 kB crudos, ~35 kB comprimidos.
 *
 * Por eso el tope vive tambien en `firestore.rules` y no solo en el
 * formulario: un formulario se saltea, una regla no.
 */
export const DESCRIPCION_MAXIMA = 600;

// ------------------------------------------------------------------- tipos

export interface FichaVino {
  readonly bodegaId: string;
  readonly varietales: readonly Varietal[];
  readonly color: Color;
  readonly organico: boolean;
  /** null para los sin anada (un espumante NV). */
  readonly anada: number | null;
  readonly region: string;
  readonly volumenMl: number;
  /**
   * DECIMAS de grado, entero: 13,5 % es `135`. null si no se cargo. Ver
   * `GRADUACION_MINIMA` para por que el rango es el que es.
   */
  readonly graduacion: number | null;
  /**
   * Prosa del duenio sobre el vino. null si no se cargo. Llega al comprador:
   * ver `ProductoPublicado.descripcion`. Tope en `DESCRIPCION_MAXIMA`.
   */
  readonly descripcion: string | null;
}

interface ProductoBase {
  readonly id: string;
  readonly slug: string;
  readonly nombre: string;
  /** Centavos de la UNIDAD DE VENTA: en una caja de 2, la caja entera. */
  readonly precio: Centavos;
  /** Inmutable: una caja de 2 es OTRO producto, con su propio inventario. */
  readonly presentacion: { readonly botellas: number };
  readonly imagenes: readonly string[];
  readonly publicado: boolean;
  /** Solo en los datos de prueba de stage. Lo escribe solo el servidor. */
  readonly muestra: boolean;
  readonly fichaVino: FichaVino;
}

export interface ProductoSimple extends ProductoBase {
  readonly tipo: 'simple';
  /** Unidades de VENTA, no botellas. Lo escribe solo el servidor. */
  readonly stock: number;
}

/**
 * Previsto, no construido: una caja mixta deriva su stock de sus componentes
 * simples y no tiene uno propio. Ningun consumidor deduce el tipo por la falta
 * de `stock`: por eso `tipo` existe y es inmutable.
 */
export interface ProductoCompuesto extends ProductoBase {
  readonly tipo: 'compuesto';
}

export type Producto = ProductoSimple | ProductoCompuesto;

// ------------------------------------------------------ balde, tope, corte

export const BALDES = ['disponible', 'quedan-pocas', 'agotado'] as const;
export type Balde = (typeof BALDES)[number];

/** En BOTELLAS: tres cajas de 2 son seis botellas, y eso ya es poco. */
export const UMBRAL_QUEDAN_POCAS = 6;

/** En unidades de venta, por producto y por pedido. */
export const TOPE_POR_PEDIDO = 12;

type ConStock = { readonly stock: number; readonly presentacion: { readonly botellas: number } };

/**
 * true si el producto TRAE SU PROPIA CAJA, asi que puede viajar solo.
 *
 * Se DERIVA de la presentacion y no es un campo del documento: una unidad de
 * venta de mas de una botella es, por definicion, una caja -- el dueno lo dijo
 * asi el 2026-09-15: *"vienen en cajas, tienen su propio packaging, asi que
 * pueden viajar solos"*. El dia que exista un pack de dos SIN caja propia -dos
 * botellas atadas con un piolin- esto deja de ser derivable y pasa a ser un
 * campo del documento, de `firestore.rules` y del panel. Hoy no existe.
 *
 * Decide TRES cosas, y las tres estan en ADR 009 §10:
 *   1. No cuenta para la caja de seis (`botellasSueltas`).
 *   2. Viaja en su propio bulto (`cargaDelPedido` -> `bultosDelPedido`).
 *   3. No puede formar parte de una caja armada (`verificarComposicion`).
 *
 * Toma `{ botellas }` y no un Producto entero para que sirva igual con la
 * proyeccion -que aplana `presentacion`- y con el documento, donde se llama
 * `viajaSolo(p.presentacion)`.
 */
export function viajaSolo(p: { readonly botellas: number }): boolean {
  return p.botellas > 1;
}

export function balde(p: ConStock): Balde {
  if (p.stock <= 0) return 'agotado';
  if (p.stock * p.presentacion.botellas <= UMBRAL_QUEDAN_POCAS) return 'quedan-pocas';
  return 'disponible';
}

/**
 * `max(0, min(stock, 12))`. Por debajo de 12 el tope ES el stock exacto y llega
 * al navegador. Se acepta a sabiendas (ADR 008): la pantalla nunca lo afirma y
 * `crearOrden` valida contra el stock real.
 */
export function tope(p: { readonly stock: number }): number {
  return Math.max(0, Math.min(p.stock, TOPE_POR_PEDIDO));
}

/**
 * La unica fuente del texto del balde, igual que ROTULOS lo es del estado de la
 * Orden. `disponible` no dice nada: lo normal no se anuncia. voz.md §9.2.
 */
const TEXTOS_DEL_BALDE: Readonly<Record<Balde, string | null>> = {
  disponible: null,
  'quedan-pocas': 'Quedan pocas',
  agotado: 'Se agotó',
};

export function textoDelBalde(b: Balde): string | null {
  return TEXTOS_DEL_BALDE[b];
}

/** Un varietal es cepa; dos o mas, corte. Ningun documento lo guarda aparte. */
export function esCorte(varietales: readonly unknown[]): boolean {
  return varietales.length > 1;
}

// ---------------------------------------------------------------- validar

export type Validacion<T> = { readonly ok: true; readonly valor: T } | { readonly ok: false; readonly motivo: string };

const SLUG = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

function esObjeto(x: unknown): x is Record<string, unknown> {
  return typeof x === 'object' && x !== null && !Array.isArray(x);
}

function esEntero(x: unknown): x is number {
  return typeof x === 'number' && Number.isSafeInteger(x);
}

function esTextoNoVacio(x: unknown): x is string {
  return typeof x === 'string' && x.trim().length > 0;
}

function incluye<T extends string>(lista: readonly T[], x: unknown): x is T {
  return typeof x === 'string' && (lista as readonly string[]).includes(x);
}

function validarFicha(f: unknown): Validacion<FichaVino> {
  if (!esObjeto(f)) return { ok: false, motivo: 'fichaVino no es un mapa' };
  if (!esTextoNoVacio(f.bodegaId)) return { ok: false, motivo: 'fichaVino.bodegaId falta' };
  const v = f.varietales;
  if (!Array.isArray(v) || v.length === 0) {
    return { ok: false, motivo: 'fichaVino.varietales tiene que ser una lista no vacia' };
  }
  const fuera = v.filter((x) => !incluye(VARIETALES, x));
  if (fuera.length) {
    return { ok: false, motivo: `varietales fuera de la lista cerrada: ${JSON.stringify(fuera)}` };
  }
  if (new Set(v).size !== v.length) return { ok: false, motivo: 'fichaVino.varietales repite una uva' };
  if (!incluye(COLORES, f.color)) return { ok: false, motivo: `fichaVino.color invalido: ${String(f.color)}` };
  if (typeof f.organico !== 'boolean') return { ok: false, motivo: 'fichaVino.organico no es bool' };
  const anada = f.anada ?? null;
  if (anada !== null && !(esEntero(anada) && anada > 1800)) {
    return { ok: false, motivo: `fichaVino.anada invalida: ${String(anada)}` };
  }
  if (!esTextoNoVacio(f.region)) return { ok: false, motivo: 'fichaVino.region falta' };
  if (!(esEntero(f.volumenMl) && f.volumenMl > 0)) return { ok: false, motivo: 'fichaVino.volumenMl invalido' };
  const graduacion = f.graduacion ?? null;
  if (graduacion !== null && !esGraduacion(graduacion)) {
    return { ok: false, motivo: `fichaVino.graduacion invalida (decimas, ${GRADUACION_MINIMA}-${GRADUACION_MAXIMA}): ${String(graduacion)}` };
  }
  // Ausente y null son lo mismo: "no se cargo". Una cadena en blanco NO: para
  // eso esta null, y admitir las dos formas dejaria dos maneras de decir nada.
  // El largo se mide sobre el texto CRUDO, que es lo que miran las reglas.
  const cruda = f.descripcion ?? null;
  if (cruda !== null) {
    if (typeof cruda !== 'string') {
      return { ok: false, motivo: `fichaVino.descripcion no es un texto: ${String(cruda)}` };
    }
    if (cruda.trim().length === 0) {
      return { ok: false, motivo: 'fichaVino.descripcion en blanco: para "sin descripcion" va null' };
    }
    if (cruda.length > DESCRIPCION_MAXIMA) {
      return { ok: false, motivo: `fichaVino.descripcion se pasa de ${DESCRIPCION_MAXIMA}: ${cruda.length}` };
    }
  }
  const descripcion = cruda === null ? null : (cruda as string).trim();
  return {
    ok: true,
    valor: {
      bodegaId: f.bodegaId,
      varietales: v as Varietal[],
      color: f.color,
      organico: f.organico,
      anada,
      region: f.region,
      volumenMl: f.volumenMl,
      graduacion,
      descripcion,
    },
  };
}

/** Entero en decimas, dentro del rango. Ver `GRADUACION_MINIMA`. */
function esGraduacion(x: unknown): x is number {
  return esEntero(x) && x >= GRADUACION_MINIMA && x <= GRADUACION_MAXIMA;
}

/**
 * Valida un documento crudo de `productos`. El Admin SDK no pasa por las
 * reglas, asi que un documento roto PUEDE existir: esto es lo que impide que
 * tire el render que comparten las tres pantallas.
 */
export function validarProducto(id: string, datos: unknown): Validacion<Producto> {
  if (!esObjeto(datos)) return { ok: false, motivo: 'el documento no es un mapa' };
  const d = datos;
  if (!incluye(TIPOS_DE_PRODUCTO, d.tipo)) return { ok: false, motivo: `tipo invalido: ${String(d.tipo)}` };
  if (!(typeof d.slug === 'string' && SLUG.test(d.slug))) {
    return { ok: false, motivo: `slug invalido: ${String(d.slug)}` };
  }
  if (!esTextoNoVacio(d.nombre)) return { ok: false, motivo: 'nombre falta' };
  if (!(esEntero(d.precio) && d.precio >= 0)) return { ok: false, motivo: 'precio falta o no es entero >= 0' };
  const p = d.presentacion;
  if (!(esObjeto(p) && esEntero(p.botellas) && p.botellas >= 1)) {
    return { ok: false, motivo: 'presentacion.botellas falta o es < 1' };
  }
  const imagenes = d.imagenes;
  if (!(Array.isArray(imagenes) && imagenes.every((u) => typeof u === 'string' && u.startsWith('https://')))) {
    return { ok: false, motivo: 'imagenes no es una lista de URLs https' };
  }
  if (typeof d.publicado !== 'boolean') return { ok: false, motivo: 'publicado no es bool' };
  // ESPEJA `precioCoherente` DE firestore.rules, y no es redundante con el:
  // la vidriera lee con el Admin SDK (`applicationDefault()` en
  // apps/tienda/src/server/firebase-admin.ts), que NO PASA POR LAS REGLAS.
  // La ultima puerta antes del comprador es esta funcion, no la regla.
  //
  // Sin esto, un documento escrito por el seed, por una reposicion o por un
  // script con `publicado: true` y `precio: 0` se proyecta, se muestra en
  // $ 0,00, y el dia que exista crearOrden un `precioUnitarioVisto: 0`
  // COINCIDE. Es el hallazgo 2 de revisor-pagos (ADR 008), cuya otra mitad
  // cierra la regla.
  if (d.publicado && d.precio <= 0) {
    return { ok: false, motivo: 'publicado con precio 0: un vino en la tienda necesita precio' };
  }
  const muestra = d.muestra ?? false;
  if (typeof muestra !== 'boolean') return { ok: false, motivo: 'muestra no es bool' };
  const ficha = validarFicha(d.fichaVino);
  if (!ficha.ok) return ficha;

  const base = {
    id,
    slug: d.slug,
    nombre: d.nombre,
    precio: centavos(d.precio),
    presentacion: { botellas: p.botellas },
    imagenes: imagenes as string[],
    publicado: d.publicado,
    muestra,
    fichaVino: ficha.valor,
  };

  if (d.tipo === 'compuesto') {
    if ('stock' in d) return { ok: false, motivo: 'un compuesto no tiene stock propio' };
    return { ok: true, valor: { ...base, tipo: 'compuesto' } };
  }
  if (!esEntero(d.stock)) return { ok: false, motivo: 'stock falta o no es entero' };
  return { ok: true, valor: { ...base, tipo: 'simple', stock: d.stock } };
}

// ------------------------------------------------------------ proyeccion

/** Lo unico de un producto que llega al navegador. Sin stock, sin unidades. */
export interface ProductoPublicado {
  readonly id: string;
  readonly slug: string;
  readonly nombre: string;
  readonly bodega: string;
  readonly precio: Centavos;
  readonly botellas: number;
  readonly volumenMl: number;
  readonly imagenes: readonly string[];
  readonly color: Color;
  readonly organico: boolean;
  readonly varietales: readonly Varietal[];
  readonly esCorte: boolean;
  readonly anada: number | null;
  readonly region: string;
  /**
   * La prosa del duenio, ya recortada. null si no cargo ninguna, y entonces la
   * ficha NO dibuja la seccion: ni titulo solo ni relleno.
   *
   * Se renderiza como TEXTO PLANO. La escribe una persona en un formulario,
   * no un editor de confianza: nunca `dangerouslySetInnerHTML`.
   */
  readonly descripcion: string | null;
  readonly balde: Balde;
  readonly tope: number;
  /** 1 es el mas vendido; null si no hay metricas. Nunca las unidades. */
  readonly puesto: number | null;
}

export function proyectarProducto(p: ProductoSimple, bodega: string, puesto: number | null): ProductoPublicado {
  const f = p.fichaVino;
  return {
    id: p.id,
    slug: p.slug,
    nombre: p.nombre,
    bodega,
    precio: p.precio,
    botellas: p.presentacion.botellas,
    volumenMl: f.volumenMl,
    imagenes: [...p.imagenes],
    color: f.color,
    organico: f.organico,
    varietales: [...f.varietales],
    esCorte: esCorte(f.varietales),
    anada: f.anada,
    region: f.region,
    descripcion: f.descripcion,
    balde: balde(p),
    tope: tope(p),
    puesto,
  };
}

// ------------------------------------------------------------- catalogo

export interface DocumentoCrudo {
  readonly id: string;
  readonly datos: unknown;
}

export interface Descarte {
  readonly id: string;
  readonly motivo: string;
}

export interface Catalogo {
  readonly productos: readonly ProductoPublicado[];
  /** false si `metricas/popularidad` no existe o no tiene ventas: el orden no se ofrece. */
  readonly hayPopularidad: boolean;
  /** true si algun producto es de muestra. Viaja al HTML como gate de deploy. */
  readonly deMuestra: boolean;
}

export interface CatalogoArmado {
  readonly catalogo: Catalogo;
  /** Lo que quedo afuera y por que. Lo loguea el servidor; no llega a la pagina. */
  readonly descartes: readonly Descarte[];
}

function leerUnidades(popularidad: unknown, descartes: Descarte[]): Map<string, number> | null {
  if (popularidad === undefined || popularidad === null) return null;
  const u = esObjeto(popularidad) ? popularidad.unidades : undefined;
  if (!esObjeto(u) || !Object.values(u).every((n) => esEntero(n) && n >= 0)) {
    descartes.push({ id: 'metricas/popularidad', motivo: 'unidades no es un mapa de enteros >= 0' });
    return null;
  }
  return new Map(Object.entries(u) as [string, number][]);
}

/**
 * La proyeccion entera, en una pasada. La consumen `/vinos`, `/vinos/[slug]` y
 * `/carrito`: un documento roto se EXCLUYE y se informa en `descartes`, nunca
 * tira el render.
 *
 * Dos productos con el mismo slug quedan afuera LOS DOS: elegir uno seria
 * elegir al azar cual de los dos precios se cobra.
 */
export function armarCatalogo(
  productos: readonly DocumentoCrudo[],
  bodegas: readonly DocumentoCrudo[],
  popularidad: unknown,
): CatalogoArmado {
  const descartes: Descarte[] = [];

  const nombreDeBodega = new Map<string, string>();
  for (const b of bodegas) {
    if (esObjeto(b.datos) && esTextoNoVacio(b.datos.nombre)) nombreDeBodega.set(b.id, b.datos.nombre);
    else descartes.push({ id: `bodegas/${b.id}`, motivo: 'nombre falta' });
  }

  const vecesPorSlug = new Map<string, number>();
  for (const d of productos) {
    const slug = esObjeto(d.datos) ? d.datos.slug : undefined;
    if (typeof slug === 'string') vecesPorSlug.set(slug, (vecesPorSlug.get(slug) ?? 0) + 1);
  }

  const vigentes: { producto: ProductoSimple; bodega: string }[] = [];
  for (const d of productos) {
    const v = validarProducto(d.id, d.datos);
    if (!v.ok) {
      descartes.push({ id: d.id, motivo: v.motivo });
      continue;
    }
    const p = v.valor;
    if ((vecesPorSlug.get(p.slug) ?? 0) > 1) {
      descartes.push({ id: d.id, motivo: `slug duplicado: ${p.slug}` });
      continue;
    }
    if (!p.publicado) {
      descartes.push({ id: d.id, motivo: 'no publicado' });
      continue;
    }
    if (p.tipo === 'compuesto') {
      descartes.push({ id: d.id, motivo: 'compuesto: la vidriera todavia no deriva su stock' });
      continue;
    }
    const bodega = nombreDeBodega.get(p.fichaVino.bodegaId);
    if (bodega === undefined) {
      descartes.push({ id: d.id, motivo: `bodega inexistente: ${p.fichaVino.bodegaId}` });
      continue;
    }
    vigentes.push({ producto: p, bodega });
  }

  const unidades = leerUnidades(popularidad, descartes);
  const vendidas = (id: string) => unidades?.get(id) ?? 0;
  const hayPopularidad = vigentes.some(({ producto }) => vendidas(producto.id) > 0);

  // Desempate por id: dos corridas sobre los mismos datos dan el mismo orden.
  const puestos = new Map<string, number>();
  if (hayPopularidad) {
    [...vigentes]
      .sort((a, b) => vendidas(b.producto.id) - vendidas(a.producto.id) || a.producto.id.localeCompare(b.producto.id))
      .forEach(({ producto }, i) => puestos.set(producto.id, i + 1));
  }

  const proyectados = vigentes
    .map(({ producto, bodega }) => proyectarProducto(producto, bodega, puestos.get(producto.id) ?? null))
    .sort((a, b) => a.id.localeCompare(b.id));

  return {
    catalogo: {
      productos: proyectados,
      hayPopularidad,
      deMuestra: vigentes.some(({ producto }) => producto.muestra),
    },
    descartes,
  };
}
