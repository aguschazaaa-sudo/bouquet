import type { OpcionDeEnvio } from '@bouquet/contratos';

import { OpcionDeEntrega } from './OpcionDeEntrega';
import { TEXTOS } from './textos';
import type { EstadoDeCotizacion } from './useCotizacion';

/* Cómo viaja: el resultado de cotizar, con sus cuatro estados.
 *
 * Los cuatro existen desde hoy aunque hoy no se puedan disparar todos, porque
 * el que no existe en el código se estrena en producción: `quieta` (todavía no
 * hay código postal), `cotizando`, la lista, y los dos feos —un código postal
 * que no reconocemos y un proveedor que no contesta—.
 *
 * ⚠️ Ninguno de los dos estados feos cierra la puerta. No hay "fuera de zona":
 * a todo el país llegamos, así que lo único que puede pasar es que no sepamos
 * el precio todavía, y para eso la salida es escribirnos. */

type Props = {
  estado: EstadoDeCotizacion;
  elegida: string | null;
  alElegir: (opcion: OpcionDeEnvio) => void;
  whatsapp: string;
};

export function ComoViaja({ estado, elegida, alElegir, whatsapp }: Props) {
  if (estado.fase === 'quieta') return null;

  if (estado.fase === 'cotizando') {
    return (
      <p className="como-viaja__cargando" aria-live="polite">
        {TEXTOS.cotizando}
      </p>
    );
  }

  if (!estado.resultado.ok) {
    const cp = estado.resultado.motivo === 'codigo-postal';
    return (
      <div className="como-viaja__problema" aria-live="polite">
        <p className="como-viaja__titulo display">{cp ? TEXTOS.cpDesconocido : TEXTOS.proveedorCaido}</p>
        <p className="como-viaja__que-hacer">{cp ? TEXTOS.cpDesconocidoQueHacer : TEXTOS.proveedorCaidoQueHacer}</p>
        <a className="enlace-blando" href={whatsapp} target="_blank" rel="noopener noreferrer">
          {TEXTOS.escribinos}
        </a>
      </div>
    );
  }

  const { opciones } = estado.resultado;

  return (
    <div className="como-viaja">
      <p className="rotulo">{TEXTOS.comoViaja}</p>
      <div className="como-viaja__opciones" role="radiogroup" aria-label={TEXTOS.comoViaja}>
        {opciones.map((o) => (
          <OpcionDeEntrega
            key={o.id}
            opcion={o}
            elegida={elegida === o.id}
            alElegir={() => alElegir(o)}
            sola={opciones.length === 1}
          />
        ))}
      </div>
    </div>
  );
}
