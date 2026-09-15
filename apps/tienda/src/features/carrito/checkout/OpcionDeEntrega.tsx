import { formatearARS, type OpcionDeEnvio } from '@bouquet/contratos';

import { TEXTOS } from './textos';

/* Un renglón de "cómo viaja". Es un radio, no una tarjeta: el renglón elegido
 * se marca con fondo `--papel-hondo` —el token que existe exactamente para "el
 * renglón activo"— y un filete borgoña a la izquierda.
 *
 * El nombre del correo NO se muestra. El comprador elige entre "hasta tu
 * puerta" y "a una sucursal": quién lo lleve es problema nuestro, y ponerlo en
 * pantalla obliga a explicar por qué esta vez es OCA y la anterior Andreani.
 * El dato viaja igual —`transportista`— para el panel y el despacho. */

type Props = {
  opcion: OpcionDeEnvio;
  elegida: boolean;
  alElegir: () => void;
  sola: boolean;
};

export function OpcionDeEntrega({ opcion, elegida, alElegir, sola }: Props) {
  const gratis = opcion.precio === 0;

  return (
    <label className={`opcion-entrega${sola ? ' opcion-entrega--sola' : ''}`}>
      <input
        type="radio"
        name="como-viaja"
        value={opcion.id}
        checked={elegida}
        onChange={alElegir}
        className="opcion-entrega__radio"
      />
      <span className="opcion-entrega__marca" aria-hidden="true" />
      <span className="opcion-entrega__nombre display">{opcion.nombre}</span>
      <span className={`opcion-entrega__precio${gratis ? ' versalita' : ' precio-cifra'}`}>
        {gratis ? TEXTOS.sinCargo : formatearARS(opcion.precio)}
      </span>
      <span className="opcion-entrega__detalle">{opcion.detalle}</span>
    </label>
  );
}
