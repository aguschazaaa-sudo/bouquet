import { PROVINCIAS } from '@bouquet/contratos';

import { CampoDeTexto } from './CampoDeTexto';
import { TEXTOS } from './textos';
import type { Borrador } from './borrador';

/* II. A dónde va. El código postal primero, porque es el que decide todo lo
 * demás: si lo llevamos nosotros o va por correo, cuánto sale y en cuántos
 * días. La provincia y la localidad vuelven de la cotización ya puestas, y
 * quedan editables — una banda de códigos postales cubre más de una provincia
 * y el que vive ahí sabe más que nuestra tabla.
 *
 * ⚠️ NO HAY SELECTOR DE "CÓMO LO RECIBÍS". Preguntarle al comprador si quiere
 * reparto propio o correo sería pedirle que sepa algo que nosotros ya sabemos:
 * depende de dónde vive. Las opciones que aparecen debajo ya son las que su
 * dirección permite.
 *
 * La calle y el número van separados porque separados los pide el correo
 * (`calle` y `numero` en el despacho): partir "Av. San Martín 1234" después,
 * con la dirección ya guardada, es adivinar dónde termina el nombre. */

type Props = {
  borrador: Borrador;
  alCambiar: (campo: keyof Borrador, valor: string) => void;
  eco: string | null;
  cotizacion: React.ReactNode;
};

export function ADondeVa({ borrador, alCambiar, eco, cotizacion }: Props) {
  return (
    <section className="parte-checkout">
      <h2 className="parte-checkout__titulo display">
        <span className="parte-checkout__numero versalita">II</span>
        {TEXTOS.aDondeVa}
      </h2>
      <div className="parte-checkout__cuerpo">
        <div className="campos campos--par">
          <div>
            <CampoDeTexto
              id="codigoPostal"
              rotulo={TEXTOS.codigoPostal}
              valor={borrador.codigoPostal}
              alCambiar={(v) => alCambiar('codigoPostal', v.replace(/\D/g, '').slice(0, 4))}
              autocomplete="postal-code"
              modoDeTeclado="numeric"
              ejemplo="5176"
              largoMaximo={4}
              cifra
              requerido
            />
            <p className="campo__eco" aria-live="polite">
              {eco ?? TEXTOS.escribiElCp}
            </p>
          </div>
          <p className="campo">
            <label className="campo__rotulo versalita" htmlFor="provincia">
              {TEXTOS.provincia}
            </label>
            <select
              id="provincia"
              name="provincia"
              className="campo__control"
              value={borrador.provincia}
              onChange={(e) => alCambiar('provincia', e.target.value)}
              required
            >
              <option value="" disabled />
              {PROVINCIAS.map((p) => (
                <option key={p.iso} value={p.iso}>
                  {p.nombre}
                </option>
              ))}
            </select>
          </p>
          <div className="campo--ancho">
            <CampoDeTexto
              id="localidad"
              rotulo={TEXTOS.localidad}
              valor={borrador.localidad}
              alCambiar={(v) => alCambiar('localidad', v)}
              autocomplete="address-level2"
              largoMaximo={120}
              requerido
            />
          </div>
          <CampoDeTexto
            id="calle"
            rotulo={TEXTOS.calle}
            valor={borrador.calle}
            alCambiar={(v) => alCambiar('calle', v)}
            autocomplete="address-line1"
            ejemplo="Av. San Martín"
            largoMaximo={120}
            requerido
          />
          <CampoDeTexto
            id="numero"
            rotulo={TEXTOS.numero}
            valor={borrador.numero}
            alCambiar={(v) => alCambiar('numero', v)}
            modoDeTeclado="numeric"
            ejemplo="1234"
            largoMaximo={12}
            cifra
            requerido
          />
          <CampoDeTexto
            id="piso"
            rotulo={TEXTOS.piso}
            pista={TEXTOS.pisoPista}
            valor={borrador.piso}
            alCambiar={(v) => alCambiar('piso', v)}
            autocomplete="address-line2"
            ejemplo="3.º B"
            largoMaximo={40}
          />
          <div className="campo--ancho">
            <CampoDeTexto
              id="referencia"
              rotulo={TEXTOS.referencia}
              valor={borrador.referencia}
              alCambiar={(v) => alCambiar('referencia', v)}
              ejemplo="Portón verde, al lado del kiosco"
              largoMaximo={200}
            />
          </div>
        </div>
        {cotizacion}
      </div>
    </section>
  );
}
