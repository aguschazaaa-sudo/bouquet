import type { Centavos, OpcionDeEnvio } from '@bouquet/contratos';

/* Lo que lee el comprador de cada forma de recibir por correo, en UN lugar.
 *
 * Lo usan los dos cotizadores —el simulado y el de Envíopack (ADR 030)— y por
 * eso vive aparte: dos copias del mismo texto se separan en la primera
 * corrección de `voz`, y la pantalla pasa a decir cosas distintas según quién
 * cotizó. El precio y los días los pone quien cotiza; las palabras, no.
 *
 * El `id` es fijo por modalidad: es lo que la pantalla recuerda como elegida, y
 * no puede cambiar porque cambió el proveedor. */

type Cotizado = {
  readonly precio: Centavos;
  readonly desdeDias: number;
  readonly hastaDias: number;
  readonly transportista: string | null;
};

export function aDomicilio({ precio, desdeDias, hastaDias, transportista }: Cotizado): OpcionDeEnvio {
  return {
    id: 'domicilio',
    modalidad: 'domicilio',
    nombre: 'Hasta tu puerta',
    detalle: `Llega en ${desdeDias} a ${hastaDias} días hábiles.`,
    precio,
    desdeDias,
    hastaDias,
    transportista,
  };
}

export function aSucursal({ precio, desdeDias, hastaDias, transportista }: Cotizado): OpcionDeEnvio {
  return {
    id: 'sucursal',
    modalidad: 'sucursal',
    nombre: 'A una sucursal cerca',
    detalle: `Llega en ${desdeDias} a ${hastaDias} días hábiles. Lo retirás con documento.`,
    precio,
    desdeDias,
    hastaDias,
    transportista,
  };
}
