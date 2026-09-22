/**
 * La tuberia de recorte de una foto de producto. `scripts/seed/seed.mjs` y
 * `functions/src/foto/tuberia.ts` tienen que aplicar los MISMOS tres pasos
 * con los MISMOS numeros, o la foto que sube el panel se ve distinta de la
 * que puso el seed.
 *
 * `contratos` no importa `sharp` a proposito: su cero-dependencias es una
 * decision del proyecto en una maquina de 7,9 GB
 * (openspec/changes/panel-fotos-de-un-vino/design.md, decision 4). Asi que
 * esto NO es una funcion que transforma una imagen -esa vive en cada lado,
 * duplicada en tres lineas-, es la CONSTANTE que impide que las dos copias
 * diverjan en los numeros.
 *
 * Lo que las mantiene iguales no es la disciplina: es
 * `functions/test/foto/tuberia.test.ts`, que procesa la misma foto por los
 * dos caminos y exige el mismo SHA-256. Si alguien cambia un numero de un
 * lado y no del otro, ese test se pone rojo.
 *
 * A diferencia de `texto.ts` o `dinero.ts`, esto NO tiene fixtures para el
 * panel en Dart: el panel nunca corre esta tuberia. Sube el crudo y la
 * callable la aplica. Dart no necesita espejarla, solo mostrar lo que la
 * callable devuelve.
 */
export const TUBERIA_DE_FOTO = {
  /** Umbral de `sharp().trim({ threshold })`: cuanto tiene que variar un
   *  pixel del borde para dejar de considerarse fondo uniforme. */
  umbralRecorte: 12,
  /** Alto de `sharp().resize({ height })`, en pixeles. `withoutEnlargement`
   *  va del lado de quien llama: una foto mas chica no se agranda. */
  alto: 1200,
  /** Calidad de `sharp().webp({ quality })`, de 0 a 100. */
  calidadWebp: 82,
} as const;
