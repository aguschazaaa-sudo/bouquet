/* La mayoría de edad, recordada. ARQUITECTURA §9.5 pide que la elección se
 * recuerde, y parallax.md §10.2 fija qué se guarda: un booleano y una fecha,
 * en `localStorage` —la misma decisión que el carrito—. **No se pide ni se
 * guarda la fecha de nacimiento**: la verificación real es el documento en la
 * entrega, y eso lo dice el telón.
 *
 * Vive en un módulo neutro, y no adentro de `PuertaDeEdad.tsx`, por una
 * frontera y no por gusto: `PuertaDeEdad` es `'use client'`, y lo que exporta
 * un módulo de cliente le llega al servidor como una REFERENCIA, no como su
 * valor. `app/layout.tsx` necesita la cadena de verdad para el script en
 * línea, así que la clave y el formato salen de acá, y los leen los dos
 * extremos. Escritos en dos lados, se desincronizan el día que alguien los
 * renombre — y lo que se rompe es que quien ya entró vuelve a ver el telón.
 */

/** La clave de `localStorage`. */
export const CLAVE_EDAD = 'bouquet.edad';

/** Lo que se guarda al aceptar. Lo lee `SCRIPT_EDAD`, y el test prueba que
 *  lo que escribe uno es lo que acepta el otro. */
export function marcaDeMayoria(ahora: Date): string {
  return JSON.stringify({ mayor: true, fecha: ahora.toISOString() });
}

/* El script en línea que corre ANTES de que el telón se pinte.
 *
 * ⚠️ Va como primer hijo del `<body>`, y no en un `useEffect`. Un efecto corre
 * después del primer pintado, así que quien ya entró vería el telón
 * PARPADEAR en cada carga (parallax.md §10.2, requisito 2) — y una pantalla
 * entera que parpadea se lee como un sitio roto. Acá el atributo ya está
 * puesto cuando el navegador llega a `.puerta`, y `edad.css` la esconde sin un
 * solo frame de telón.
 *
 * `JSON.parse` de algo que no es JSON tira, y `localStorage` tira en el modo
 * privado de algunos navegadores: el `try` es para que en los dos casos la
 * página abra igual, con el telón puesto. Y no bloquea el render de nada: el
 * contenido está entero en el HTML (ARQUITECTURA §9.5). */
export const SCRIPT_EDAD =
  `try{var m=JSON.parse(localStorage.getItem(${JSON.stringify(CLAVE_EDAD)}));` +
  `if(m&&m.mayor===true)document.documentElement.dataset.edad='ok'}catch(e){}`;

/* Sin JavaScript el telón no se puede levantar ni recordar, así que mostrarlo
 * dejaría el sitio detrás de una puerta que no abre. Se esconde.
 *
 * ⚠️ Es una decisión de producto, y está escrita para que se pueda discutir:
 * sin JavaScript se puede MIRAR el catálogo pero no comprar, porque el
 * carrito vive en `localStorage` y el pedido lo arma un componente de cliente.
 * Nadie llega a una compra sin haber pasado por el telón. */
export const ESTILO_SIN_SCRIPT = '.puerta{display:none}';
