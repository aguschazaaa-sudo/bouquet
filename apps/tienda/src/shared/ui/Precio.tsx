import { formatearARS, type Centavos } from '@bouquet/contratos';

/* El precio, en cifras tabulares. ADR 008, design.md §9.
 *
 * NACE EN `shared/` y no en una feature, porque lo importan `catalogo/` y
 * `carrito/` desde el día uno: la regla 1 de ADR 006 —baja cuando una segunda
 * feature la pide— ya está satisfecha el día uno. No sabe de vino, sabe de
 * centavos.
 *
 * El texto sale del formateador canónico de contratos, así que la tarjeta, la
 * ficha y el total del carrito dicen el número con la misma función. Los
 * centavos van aparte y más tenues: el formateador los escribe, pero el ojo
 * compara la parte entera.
 */

type Props = {
  centavos: Centavos;
  className?: string;
};

export function Precio({ centavos, className }: Props) {
  const texto = formatearARS(centavos);
  const coma = texto.lastIndexOf(',');
  const clases = ['precio-cifra', className].filter(Boolean).join(' ');

  if (coma < 0) return <span className={clases}>{texto}</span>;
  return (
    <span className={clases}>
      {texto.slice(0, coma)}
      <span className="precio-cifra__centavos">{texto.slice(coma)}</span>
    </span>
  );
}
