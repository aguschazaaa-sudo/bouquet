import Link from 'next/link';

/* Una sección que la navegación ya nombra y que todavía no existe.
 *
 * POR QUÉ ESTÁ EN `shared/` SI EL ADR 006 DICE QUE NADA NACE ACÁ. Porque no
 * pertenece a ninguna feature: es, literalmente, la ausencia de una. Nace
 * usada por cuatro rutas al mismo tiempo, así que la regla de promoción —"baja
 * a shared cuando una segunda feature la importa"— ya está satisfecha el día
 * uno. Elegir una de las cuatro para que la "hospede" sería arbitrario.
 *
 * ⚠️ Y tiene fecha de muerte: cuando las cuatro secciones estén construidas,
 * este archivo no lo abre nadie y `call-site-guard` lo va a decir. Ese aviso
 * es la señal de borrarlo, no de agregarle una prop.
 *
 * El registro es CAVA y corto: voz.md §4.1 fija el registro por el estado del
 * lector, no por la URL, y acá el lector está mirando, no atascado. Lo que sí
 * se respeta sin excepción es §6 — no se promete nada que no se pueda
 * sostener, y "próximamente" es una promesa sin fecha.
 */

type Salida = {
  href: string;
  texto: string;
};

type Props = {
  /** La versalita chica de arriba. Ubica sin repetir el título. */
  rotulo: string;
  titulo: string;
  /** Opcional: el carrito vacío no lleva cuerpo, y es correcto que no lleve. */
  cuerpo?: string;
  /** La salida. Nunca falta: una página sin nada adentro y sin puerta de
   *  salida es un callejón, y el usuario llegó acá desde la barra. */
  salida: Salida;
};

export function PaginaEnObra({ rotulo, titulo, cuerpo, salida }: Props) {
  return (
    <main className="en-obra">
      <div className="en-obra__cartucho cartucho-deco">
        <p className="rotulo">{rotulo}</p>
        <h1 className="display en-obra__titulo">{titulo}</h1>
        <hr className="filete en-obra__filete" />
        {cuerpo ? <p className="prosa en-obra__cuerpo">{cuerpo}</p> : null}
        <Link className="enlace-blando" href={salida.href}>
          {salida.texto}
        </Link>
      </div>
    </main>
  );
}
