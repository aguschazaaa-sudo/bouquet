import { SIN_CARGO, totalConEnvio, type Centavos, type CarritoResuelto } from '@bouquet/contratos';

import { Precio } from '@/shared/ui/Precio';

import { EL_CHECKOUT_NO_COBRA, TEXTOS } from './textos';

/* El pedido y la plata, al costado. Es lo único que se queda pegado en la
 * pantalla mientras se completa el formulario: alguien que está por dejar una
 * dirección tiene que poder ver qué está comprando sin volver atrás.
 *
 * El renglón de la entrega dice "falta la dirección" en vez de $ 0. Un cero es
 * una afirmación —que el envío no cuesta nada— y todavía no sabemos si es
 * cierta. Cuando se sepa, si es sin cargo, lo dice con palabras.
 *
 * ⚠️ `data-checkout-simulado` ES EL GATE, y sale al HTML a propósito:
 * `auditor-produccion` audita con `curl` y no puede grepear un `.ts`. */

type Props = {
  resuelto: CarritoResuelto;
  envio: Centavos | null;
  cajas: number;
  pesoKg: number;
  impedimento: string | null;
  whatsapp: string;
};

export function ElResumen({ resuelto, envio, cajas, pesoKg, impedimento, whatsapp }: Props) {
  const total = totalConEnvio(resuelto.total, envio);
  const vigentes = resuelto.lineas.filter((l) => l.estado === 'vigente' && l.producto !== null);

  return (
    <aside className="resumen papel" {...(EL_CHECKOUT_NO_COBRA ? { 'data-checkout-simulado': 'true' } : {})}>
      <h2 className="resumen__titulo display">{TEXTOS.tuPedido}</h2>

      <ul className="resumen__lineas">
        {vigentes.map((l) => (
          <li key={l.productoId} className="resumen__linea">
            <span className="resumen__cantidad cifra">{l.cantidad}&nbsp;×</span>
            <span className="resumen__nombre">
              {l.producto?.nombre}
              <small>{l.producto?.bodega}</small>
            </span>
            <Precio centavos={l.subtotal} />
          </li>
        ))}
      </ul>

      {cajas > 0 ? <p className="resumen__bultos versalita">{TEXTOS.viajaEn(cajas, pesoKg)}</p> : null}

      <div className="resumen__cuenta">
        <p className="resumen__renglon">
          <span>{TEXTOS.losVinos}</span>
          <Precio centavos={resuelto.total} />
        </p>
        <p className="resumen__renglon">
          <span>{TEXTOS.laEntrega}</span>
          {envio === null ? (
            <span className="resumen__pendiente">{TEXTOS.faltaLaDireccion}</span>
          ) : envio === SIN_CARGO ? (
            <span className="versalita">{TEXTOS.sinCargo}</span>
          ) : (
            <Precio centavos={envio} />
          )}
        </p>
        <p className="resumen__total">
          <span className="versalita">{TEXTOS.total}</span>
          <Precio centavos={total} className="resumen__monto-total" />
        </p>
      </div>

      <p className="resumen__accion">
        <button type="submit" className="boton boton--ancho" disabled={EL_CHECKOUT_NO_COBRA || impedimento !== null}>
          {/* El <span> NO es decorativo: `.boton > span` le da el z-index que lo
            * deja ARRIBA del relleno. Sin él el texto se pinta debajo del
            * ::after y el botón sale vacío — medido en la captura, no leído. */}
          <span>{TEXTOS.irAPagar}</span>
        </button>
      </p>

      {impedimento ? <p className="resumen__impedimento">{impedimento}</p> : null}

      {EL_CHECKOUT_NO_COBRA ? (
        <div className="resumen__gate">
          <p className="resumen__gate-titulo display">{TEXTOS.todaviaNoSeCobra}</p>
          <p>{TEXTOS.todaviaNoSeCobraPorque}</p>
          <a className="enlace-blando" href={whatsapp} target="_blank" rel="noopener noreferrer">
            {TEXTOS.escribinos}
          </a>
        </div>
      ) : (
        <p className="resumen__nota">{TEXTOS.conMercadoPago}</p>
      )}

      <p className="resumen__legal">{TEXTOS.documento}</p>
    </aside>
  );
}
