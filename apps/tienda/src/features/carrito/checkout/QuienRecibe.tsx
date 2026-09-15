import { CampoDeTexto } from './CampoDeTexto';
import { TEXTOS } from './textos';
import type { Borrador } from './borrador';

/* I. Quién lo recibe. Tres campos y ninguno de más.
 *
 * El teléfono es el que importa: es el canal (voz.md §9.6, "te escribimos por
 * WhatsApp cuando salga") y el que después se normaliza a E.164.
 *
 * ⚠️ EL EMAIL ES OPCIONAL, y es una decisión, no un olvido. El comprobante NO
 * se manda por mail: vive en una URL y el link viaja por WhatsApp. Pedirlo
 * obligatorio sería cobrarle un campo a alguien para un mail que no existe. */

type Props = {
  borrador: Borrador;
  alCambiar: (campo: keyof Borrador, valor: string) => void;
};

export function QuienRecibe({ borrador, alCambiar }: Props) {
  return (
    <section className="parte-checkout">
      <h2 className="parte-checkout__titulo display">
        <span className="parte-checkout__numero versalita">I</span>
        {TEXTOS.quienRecibe}
      </h2>
      <div className="parte-checkout__cuerpo campos campos--par">
        <div className="campo--ancho">
          <CampoDeTexto
            id="nombre"
            rotulo={TEXTOS.nombre}
            valor={borrador.nombre}
            alCambiar={(v) => alCambiar('nombre', v)}
            autocomplete="name"
            largoMaximo={120}
            requerido
          />
        </div>
        <CampoDeTexto
          id="telefono"
          rotulo={TEXTOS.telefono}
          pista={TEXTOS.telefonoPista}
          valor={borrador.telefono}
          alCambiar={(v) => alCambiar('telefono', v)}
          tipo="tel"
          autocomplete="tel"
          modoDeTeclado="tel"
          ejemplo="3548 41-2233"
          cifra
          requerido
        />
        <CampoDeTexto
          id="email"
          rotulo={TEXTOS.email}
          pista={TEXTOS.emailPista}
          valor={borrador.email}
          alCambiar={(v) => alCambiar('email', v)}
          tipo="email"
          autocomplete="email"
          modoDeTeclado="email"
          ejemplo="vos@ejemplo.com"
        />
      </div>
    </section>
  );
}
