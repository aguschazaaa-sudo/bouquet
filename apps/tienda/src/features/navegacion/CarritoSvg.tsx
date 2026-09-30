/* El glifo del carrito: la bolsa de Heroicons (`shopping-bag`, outline, MIT).
 *
 * POR QUÉ UN ÍCONO AJENO. Cinco glifos dibujados a mano fallaron seguidos —un
 * asa de canasta, un moño de regalo, un pendrive, un octógono que en la barra
 * se leía como un FRASCO—. La razón es la misma en todos: un ícono que se lee
 * a 20px lo resuelve un oficio, no un intento. Se eligió mirando nueve bolsas
 * de cinco librerías renderizadas dentro de la barra real: ésta se leía como
 * bolsa al primer golpe de vista —trapecio de base recta, asa en arco y dos
 * ojales—. Las descartadas y el porqué están en el ADR 008 §8.
 *
 * Es UN ícono copiado, no la librería instalada: 600 bytes contra una
 * dependencia que no se va a usar de nuevo. El `viewBox` 24x24 es el de
 * Heroicons; no tocarlo, el path está dibujado contra esa grilla.
 *
 * El trazo NO es el de Heroicons (`round`/`round`). Lo pone
 * `.carrito-svg__trazo` en navegacion.css: grosor constante como la copa
 * (direccion.md §6) y `miter` + `butt`, el filo recto del cartucho. Las
 * esquinas redondeadas de la bolsa vienen en la geometría del path y eso no se
 * endereza desde el CSS —se midió—; lo que cambia es el peso y las puntas.
 */

type Props = {
  className?: string;
};

export function CarritoSvg({ className }: Props) {
  const clases = ['carrito-svg', className].filter(Boolean).join(' ');

  return (
    <svg
      className={clases}
      viewBox="0 0 24 24"
      role="presentation"
      aria-hidden="true"
      fill="none"
    >
      <path
        className="carrito-svg__trazo"
        d="M15.75 10.5V6a3.75 3.75 0 1 0-7.5 0v4.5m11.356-1.993 1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 0 1-1.12-1.243l1.264-12A1.125 1.125 0 0 1 5.513 7.5h12.974c.576 0 1.059.435 1.119 1.007ZM8.625 10.5a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm7.5 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
      />
    </svg>
  );
}
