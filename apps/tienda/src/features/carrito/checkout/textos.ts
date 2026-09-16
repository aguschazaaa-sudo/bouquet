/* Las cadenas de checkout/, juntas, para que `voz` las cure sin abrir un
 * componente. Registro MOSTRADOR sin excepción (voz.md §4.1): acá no hay
 * ceremonia, hay una persona completando datos para que le llegue vino.
 *
 * ⚠️ La palabra "checkout" no aparece en ninguna pantalla: el cliente lee
 * "terminar la compra" (voz.md §7.3). Y "Envío"/"Zona" tampoco: lee "la
 * entrega" y "a dónde va". */

/* El plural de la caja, una sola vez. Estaba escrito dos: como `TEXTOS.cajas`,
 * que no abria nadie, y repetido adentro de `viajaEn`. Es el defecto que `voz`
 * encontro la vez pasada con `vaDeA`. */
const cajas = (n: number) => (n === 1 ? 'una caja' : `${n} cajas`);

export const TEXTOS = {
  titulo: 'Terminar la compra',
  bajada: 'Dos cosas: quién lo recibe y a dónde va. Después te llevamos a pagar.',
  volver: 'Volver al pedido',

  // --- I. quién recibe ---
  quienRecibe: 'Quién lo recibe',
  nombre: 'Nombre y apellido',
  telefono: 'Teléfono',
  telefonoPista: 'por acá te escribimos',
  email: 'Email',
  emailPista: 'opcional',

  // --- II. a dónde va ---
  aDondeVa: 'A dónde va',
  codigoPostal: 'Código postal',
  provincia: 'Provincia',
  localidad: 'Localidad',
  calle: 'Calle',
  numero: 'Número',
  piso: 'Piso y depto',
  pisoPista: 'si hace falta',
  referencia: 'Entre calles o alguna referencia',
  comoViaja: 'Cómo viaja',
  cotizando: 'Buscando cómo llega…',
  escribiElCp: 'Escribilo y buscamos cómo llega.',
  loLlevamosNosotros: 'lo llevamos nosotros',

  // --- los estados feos de la cotización ---
  cpDesconocido: 'Ese código postal no nos suena.',
  cpDesconocidoQueHacer: 'Revisalo, o escribinos y lo resolvemos a mano. A todo el país llegamos.',
  proveedorCaido: 'No pudimos calcular el envío ahora.',
  proveedorCaidoQueHacer: 'Probá de nuevo en un minuto, o escribinos y lo cerramos a mano.',
  escribinos: 'Escribinos por WhatsApp',

  // --- III. el resumen y la plata ---
  tuPedido: 'Tu pedido',
  losVinos: 'Los vinos',
  laEntrega: 'La entrega',
  faltaLaDireccion: 'falta la dirección',
  sinCargo: 'Sin cargo',
  total: 'Total',
  irAPagar: 'Ir a pagar',
  conMercadoPago: 'Se paga con Mercado Pago. Te llevamos y volvés acá.',
  documento: 'En la entrega se pide documento: lo tiene que recibir alguien mayor de 18.',

  // --- lo que falta para poder pagar ---
  faltanDatos: 'Completá los datos de arriba para seguir.',
  faltaElEnvio: 'Elegí cómo viaja para ver el total.',
  /* Dice "sueltas" desde el 2026-09-15: lo que viene en su propia caja no
   * cuenta para las seis, así que sin esa palabra alguien con seis botellas en
   * pantalla lee que le faltan seis más (ADR 009 §10). */
  cajaIncompleta: 'Las botellas sueltas viajan de a seis. Volvé al pedido y completá la caja.',
  /* Y el pedido vacío es otra cosa, con su propia frase: esta pantalla le
   * contestaba con la regla de la caja a alguien que no tenía nada adentro. */
  pedidoVacio: 'Todavía no hay nada en tu pedido.',

  // --- el gate ---
  todaviaNoSeCobra: 'Todavía no se puede pagar.',
  todaviaNoSeCobraPorque: 'Esta pantalla está armada y el cobro todavía no. Si querés el pedido ahora, escribinos y lo cerramos a mano.',

  // --- cuentas ---
  cajas,
  viajaEn: (n: number, kg: number) => `Viaja en ${cajas(n)} · ${kg} kg`,
} as const;

/**
 * EL GATE DE DEPLOY, y es el sexto.
 *
 * Mientras esté en `true` el botón no lleva a ningún lado: `crearOrden` no
 * existe, no hay preferencia de Mercado Pago y no hay webhook. CLAUDE.md lo
 * dice sin rodeos — *un "Pagar" que llegue antes que su webhook es una venta
 * que se cobra y no se registra*.
 *
 * Se apaga el día que existan las tres cosas, no antes. Y como
 * `auditor-produccion` audita con `curl` y no puede grepear un `.ts`, la
 * constante VIAJA AL HTML como `data-checkout-simulado`:
 *
 *     grep -rn "EL_CHECKOUT_NO_COBRA" apps/tienda/src          # el repo
 *     curl -s https://<host>/pedido | grep -o data-checkout-simulado | wc -l
 */
export const EL_CHECKOUT_NO_COBRA = true;
