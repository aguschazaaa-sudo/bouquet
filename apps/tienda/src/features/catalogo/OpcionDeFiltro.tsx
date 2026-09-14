/* Un renglón del panel de filtros: la casilla, el nombre y cuántos vinos
 * quedarían. Con cero no se esconde: queda tenue, para que se entienda por qué
 * elegirla vacía la lista. */

type Props = {
  id: string;
  texto: string;
  cantidad: number;
  marcada: boolean;
  alCambiar: () => void;
};

export function OpcionDeFiltro({ id, texto, cantidad, marcada, alCambiar }: Props) {
  return (
    <label className={`opcion-filtro${cantidad ? '' : ' opcion-filtro--vacia'}`} htmlFor={id}>
      <input type="checkbox" id={id} checked={marcada} onChange={alCambiar} />
      <span className="opcion-filtro__caja" aria-hidden="true" />
      <span className="opcion-filtro__texto">{texto}</span>
      <span className="opcion-filtro__cuenta cifra">{cantidad}</span>
    </label>
  );
}
