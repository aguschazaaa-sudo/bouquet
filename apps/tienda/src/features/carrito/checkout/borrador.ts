import { validarDatosDeEntrega, type DatosDeEntrega, type Validacion } from '@bouquet/contratos';

/* Lo que el comprador tiene escrito ahora mismo: strings crudos, tal como los
 * tipeó. NO es `DatosDeEntrega` —eso es el resultado validado, con el teléfono
 * ya en E.164— y la diferencia importa: si el formulario guardara el valor
 * normalizado, alguien que escribe "3548 4" vería su teléfono reescribirse
 * mientras lo escribe.
 *
 * Vive fuera de los componentes para que el validador sea UNO solo: el mismo
 * `validarDatosDeEntrega` de contratos que va a usar `crearOrden`. Dos
 * validadores del mismo dato se desincronizan (LECCIONES 6.4). */

export interface Borrador {
  readonly nombre: string;
  readonly telefono: string;
  readonly email: string;
  readonly codigoPostal: string;
  readonly provincia: string;
  readonly localidad: string;
  readonly calle: string;
  readonly numero: string;
  readonly piso: string;
  readonly referencia: string;
}

export const BORRADOR_VACIO: Borrador = {
  nombre: '',
  telefono: '',
  email: '',
  codigoPostal: '',
  provincia: '',
  localidad: '',
  calle: '',
  numero: '',
  piso: '',
  referencia: '',
};

/**
 * El borrador pasado por el validador de contratos.
 *
 * `propio` no lo escribe el comprador: lo decide la cobertura, y llega desde la
 * cotización. Si se dejara en el formulario, cualquiera podría pedir el reparto
 * nuestro a Ushuaia.
 */
export function validarBorrador(b: Borrador, propio: boolean): Validacion<DatosDeEntrega> {
  return validarDatosDeEntrega({
    nombre: b.nombre,
    telefono: b.telefono,
    email: b.email,
    calle: b.calle,
    numero: b.numero,
    piso: b.piso,
    referencia: b.referencia,
    destino: {
      codigoPostal: b.codigoPostal,
      localidad: b.localidad,
      provincia: b.provincia,
      propio,
    },
  });
}
