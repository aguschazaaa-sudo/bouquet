import type { HTMLInputTypeAttribute } from 'react';

/* Un campo del formulario: rótulo arriba, filete abajo, sin caja.
 *
 * direccion.md §6 no deja cards ni pills, así que el campo NO es un recuadro
 * redondeado: es una línea. El filete usa `--filete-papel`, que está al 72 %
 * justamente para que una línea que delimita un control llegue a 3:1 (WCAG
 * 1.4.11); al 80 %, como venía de la maqueta, daba 2,81.
 *
 * La pista va en el rótulo y no como `placeholder`: un placeholder desaparece
 * cuando se escribe, que es cuando hace falta. */

type Props = {
  id: string;
  rotulo: string;
  valor: string;
  alCambiar: (valor: string) => void;
  pista?: string;
  ejemplo?: string;
  tipo?: HTMLInputTypeAttribute;
  autocomplete?: string;
  modoDeTeclado?: 'text' | 'numeric' | 'tel' | 'email';
  largoMaximo?: number;
  cifra?: boolean;
  requerido?: boolean;
};

export function CampoDeTexto({
  id,
  rotulo,
  valor,
  alCambiar,
  pista,
  ejemplo,
  tipo = 'text',
  autocomplete,
  modoDeTeclado,
  largoMaximo,
  cifra = false,
  requerido = false,
}: Props) {
  return (
    <p className="campo">
      <label className="campo__rotulo versalita" htmlFor={id}>
        {rotulo}
        {pista ? <em>{pista}</em> : null}
      </label>
      <input
        id={id}
        name={id}
        type={tipo}
        className={`campo__control${cifra ? ' cifra' : ''}`}
        value={valor}
        onChange={(e) => alCambiar(e.target.value)}
        placeholder={ejemplo}
        autoComplete={autocomplete}
        inputMode={modoDeTeclado}
        maxLength={largoMaximo}
        required={requerido}
      />
    </p>
  );
}
