import { COLORES, type Color, type ProductoPublicado } from '@bouquet/contratos';

import { filtrar, type EstadoDelListado } from './filtros';
import { TEXTOS } from './textos';

/* El color, a un toque y arriba de la grilla: es la primera decisión de quien
 * compra vino. Cada pestaña dice cuántos quedan con los otros filtros puestos. */

type Props = {
  productos: readonly ProductoPublicado[];
  estado: EstadoDelListado;
  alCambiar: (color: Color | 'todos') => void;
};

const OPCIONES = ['todos', ...COLORES] as const;

export function PestanasDeColor({ productos, estado, alCambiar }: Props) {
  return (
    <fieldset className="pestanas-color">
      <legend className="sr">{TEXTOS.color}</legend>
      {OPCIONES.map((color) => (
        <label key={color} className="pestanas-color__opcion" htmlFor={`color-${color}`}>
          <input
            type="radio"
            id={`color-${color}`}
            name="color"
            value={color}
            checked={estado.color === color}
            onChange={() => alCambiar(color)}
          />
          <span className="versalita">{TEXTOS.colores[color]}</span>
          <span className="cifra">{filtrar(productos, { ...estado, color }).length}</span>
        </label>
      ))}
    </fieldset>
  );
}
