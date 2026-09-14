import { BotellaSvg } from './BotellaSvg';
import type { VinoDeLaSeleccion } from '@/features/landing/seleccion';

/* La tarjeta de la selección.
 *
 * direccion.md §8.1 declara DOS registros fotográficos y dice que la tensión
 * entre ellos se resuelve separando, no promediando. Ésta es el registro
 * FICHA: recorte consistente, misma altura de botella, misma perspectiva. Es
 * la que deja comparar. El registro RETRATO —ambientado, una luz cálida,
 * caída profunda— vive en los planos de las escenas, y es el que vende.
 *
 * Una grilla de fotos ambientadas es imposible de comparar; una landing de
 * recortes sobre fondo plano es un catálogo de mayorista. Son dos trabajos
 * distintos sobre el mismo producto.
 *
 * Y la tarjeta es un RETRATO VERTICAL, no un tile cuadrado: una botella es
 * 1:4,5, y meterla en un cuadrado obliga a achicarla hasta que el vino es un
 * detalle y el espacio vacío es el protagonista. Es la razón, medible, por la
 * que las tiendas de vino se ven a supermercado (direccion.md §7.1).
 *
 * La ventana lleva la FOTO del catálogo, que es para lo que se dejó en 9:16.
 * La foto de bodega trae fondo blanco, y la ventana se prende para absorberlo
 * (landing.css). Sin foto, vuelve la silueta dibujada.
 *
 * ⚠️ SIN PRECIO. Es lo que mantiene la landing 100 % estática y fuera del
 * circuito de purga por tag de ADR 005. El precio vive en la ficha, que sí se
 * invalida. Y no se "oculta por estilo": no está en los datos (seleccion.ts).
 *
 * Tampoco hay línea de guarda. Los seis de muestra decían "Acostada desde
 * marzo", y ningún dato del producto lo sostiene: voz.md §6 no deja afirmar lo
 * que no se puede sostener. Vuelve el día que exista la fecha de ingreso.
 */

type Props = {
  vino: VinoDeLaSeleccion;
};

export function TarjetaVino({ vino }: Props) {
  return (
    <a className="tarjeta" href={`/vinos/${vino.slug}`} data-vidrio={vino.color}>
      <figure className="cartucho">
        <div className="cartucho__interior">
          <div className={vino.foto ? 'tarjeta__ventana tarjeta__ventana--foto' : 'tarjeta__ventana'}>
            {/* Decorativa: el enlace ya se llama como el vino. */}
            {vino.foto ? (
              <img className="tarjeta__foto" src={vino.foto} alt="" loading="lazy" decoding="async" />
            ) : (
              <BotellaSvg forma={vino.forma} />
            )}
          </div>

          <figcaption>
            <h3 className="display tarjeta__nombre">{vino.nombre}</h3>

            {/* voz.md §7.2: sustantivos, no adjetivos. El dato es más elegante
                que el elogio, y además es lo único verificable. */}
            <p className="versalita tarjeta__datos">
              {vino.bodega}
              <br />
              {vino.anada === null ? vino.uvas : `${vino.uvas} · ${vino.anada}`}
              <br />
              {vino.region}
            </p>
          </figcaption>
        </div>
      </figure>
    </a>
  );
}
