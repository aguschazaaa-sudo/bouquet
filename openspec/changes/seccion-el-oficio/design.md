## Context

`/custodia` y `/contacto` son hoy dos `PaginaEnObra`. La navegación las nombra
desde `v0.15.0` y ninguna tiene contenido; la segunda además **no se puede
escribir**, porque su canal depende de una decisión del dueño que sigue abierta
en [`voz.md §12`](../../../docs/vault/design/voz.md).

La forma se eligió **mirándola**, no discutiéndola. Se maquetaron dos
composiciones con el copy real y los tokens del repo —la etiqueta única y la
carta numerada— y el dueño eligió la segunda. La maqueta vive en un artifact y
es la referencia de implementación de este cambio.

⚠️ **Y la maqueta destapó un defecto de método que este documento hereda como
requisito:** su conmutador "Móvil 390" achicaba la caja pero el corte de dos
columnas era una `@media`, que mide el **viewport** y no el contenedor. O sea
que el control decía "estoy mirando el móvil" mientras mostraba escritorio.
Nadie —ni el dueño ni yo— había visto el layout angosto. Es la cuarta vez en
este proyecto que una verificación da verde midiendo la cosa equivocada.

**Restricciones que no se negocian:** `direccion.md §5.3` (el ornamento decó
prohibido), `voz.md §3.2` y `§6` (lo que la marca no puede afirmar), ADR 006
(feature-first y las cinco reglas de `shared/`), los hooks
`widget-size-guard` (200 líneas), `one-widget-per-file` y `no-hardcoded-colors`.

## Goals / Non-Goals

**Goals:**

- Que el argumento *"¿por qué ustedes y no la góndola?"* tenga una URL propia
  que se pueda mandar por WhatsApp y se entienda sin haber visto la home.
- Que la sección enseñe algo verdadero sobre el vino **sin firmar un juicio
  sensorial**: mecanismos verificables, nunca veredictos.
- Cerrar dos placeholders con una sola pieza.
- Que el canal provisorio sea **imposible de publicar por inercia**.

**Non-Goals:**

- Tocar la home. `EscenaCustodia` queda como está.
- Resolver la puerta de edad, las seis fichas en 404 o las licencias de los
  assets. Los tres siguen bloqueando el deploy por su cuenta.
- Bajar vocabulario a `shared/`. Nada nace ahí (ADR 006, regla 1).
- Cobrar. Este cambio no toca plata: no es Workflow D.

## Decisions

### 1. El contenido va en un módulo de datos, no adentro del JSX

`oficio.ts` exporta los tres tramos y los textos; los componentes sólo los
componen.

**Por qué, y son tres razones que apuntan al mismo lado:**

1. `widget-size-guard` bloquea presentación de más de 200 líneas, y esta sección
   tiene ~550 palabras de prosa. Con el texto adentro del JSX, el componente
   nace bloqueado.
2. Las verificaciones de voz de la spec son greps —dialecto de cata,
   exclamaciones, `tú`/`usted`— y un grep necesita **un archivo** al que
   apuntar, no cinco componentes.
3. Es el patrón que `features/landing/seleccion.ts` ya usa.

**Alternativa descartada:** MDX. Trae una dependencia y un pipeline para un
texto que cambia dos veces por año.

### 2. La constante provisoria llega al HTML servido, no sólo al repositorio

`EL_CONTACTO_ES_PROVISORIO` se exporta desde `oficio.ts` **y** se emite como
`data-contacto-provisorio="true"` en el bloque de cierre.

**Por qué la segunda mitad importa:** un `grep` sobre el repo dice qué hay en el
código de esta máquina. `auditor-produccion` audita **producción**, con `curl`,
y no puede grepear un `.ts`. `EscenaSeleccion` ya resolvió esto exactamente así
con `data-muestra`, y este cambio copia el precedente en vez de inventar otro.

Con eso el gate se puede chequear desde los dos lados:

```bash
grep -rn "EL_CONTACTO_ES_PROVISORIO" apps/tienda/src      # el repo
curl -s https://<host>/oficio | grep -c data-contacto-provisorio   # producción
```

**Alternativa descartada:** una variable de entorno. Se olvida de setear, no
deja rastro en el diff y no se ve en el HTML.

### 3. En la página real el corte es `@media`, no `@container`

La maqueta usa un container query **porque tiene que simular un viewport que no
tiene**. La página real no simula nada: su contenedor *es* el viewport.

Se escribe explícito acá para que nadie porte el container query creyendo que
era un arreglo del diseño. Era un arreglo del instrumento.

**Corte: 1000 px.** Por debajo, una columna. La medida de dos columnas a 1080 px
de plancha da ~34ch por columna, que es la medida de párrafo que
`direccion.md §5.1` pide.

### 4. El vocabulario decó nuevo nace en la feature, no en `shared/deco/`

El brazo de filete modulado (`.filete--izq` / `.filete--der`) y la capitular
viven en `apps/tienda/src/features/oficio/oficio.css`.

ADR 006 regla 1: **nada nace en `shared/`**. Bajan el día que una segunda
feature los importe, y esa bajada es un commit propio. `shared/deco/` ya tiene
el cartucho y el filete base, y esta sección los **usa** sin tocarlos.

⚠️ El único cambio en `shared/` sería si el sello necesitara algo que
`.cartucho-deco--trazado` no da. Hoy no lo necesita: se usa tal cual.

### 5. El movimiento es scroll, no reloj, y degrada a página entera

Todo va con `animation-timeline: view()`, adentro de
`@supports (animation-timeline: view())` y `@media (prefers-reduced-motion: no-preference)`.
Cero JavaScript, cero estado, cero observers.

El estado **base** —sin el `@supports`— es la página **dibujada entera**: filetes
a ancho completo, numerales opacos, títulos visibles. Firefox tiene los
timelines detrás de flag, así que ahí la sección se ve completa y quieta, que es
lo correcto. Nada rebota: `direccion.md §8.2`, el vino pesa.

### 6. La composición es bottom-up, y el orden es el orden de construcción

Del componente hoja a la página, nunca al revés:

```
oficio.ts            el contenido y la constante
oficio.css           la hoja de la feature
ReglaNumerada.tsx    el filete partido por el numeral      (hoja)
Tramo.tsx            un tramo entero                        (usa ReglaNumerada)
SelloDeContacto.tsx  el cierre                              (usa cartucho-deco)
SeccionOficio.tsx    compone los tres tramos y el sello
app/oficio/page.tsx  la ruta y su metadata
```

`one-widget-per-file` obliga a un widget público por archivo, así que esta lista
no se puede colapsar aunque las piezas sean chicas.

### 7. `/contacto` redirige; `/custodia` no

`/contacto` → `/oficio#mostrador`, permanente (308), declarado en
`redirects()` de `next.config.ts`. La URL sobrevive porque `voz.md §9.3` y
`§9.5` ya tienen escritos textos que mandan al lector a escribir.

`/custodia` se borra sin redirección: **nada está desplegado**, así que no hay
enlace entrante que preservar. Inventar una redirección para una URL que nunca
existió públicamente es escribir código para un caso que no ocurre.

## Risks / Trade-offs

| Riesgo | Mitigación |
|---|---|
| **El numeral hueco del tramo III se lee como que algo se rompió**, no como una decisión. Lo marcó el dueño en la maqueta | Es lo primero que se mira renderizado. Si falla, el plan B es el mismo numeral macizo con el nombre del tramo en cursiva y el filete al 50 % — la distinción no puede depender de un solo recurso |
| **Dos columnas más altas que el viewport** obligan a subir y bajar para leer un tramo | Cada tramo topea en 4 párrafos cortos. Se mide el alto del bloque a 1440 px: si un tramo pasa el viewport, va a una columna |
| **`-webkit-text-stroke` es no estándar** y sin él el numeral hueco queda invisible (color `transparent`) | El `color: transparent` se declara **junto** al stroke en la misma regla, dentro de un `@supports (-webkit-text-stroke: 1px red)`. Sin soporte, el numeral queda macizo — degradación correcta, no numeral invisible |
| **El copy no pasó por el agente `voz`** | Es tarea explícita, y va **antes** del deploy. `CLAUDE.md` lo exige para todo texto que ve un comprador |
| **El deploy de front reconstruye desde el HEAD pusheado y arrastra todo lo mergeado** | La sección no se publica sola: hay cuatro gates abiertos (edad, fichas 404, licencias, 391 KB de fuentes) y este cambio agrega el quinto. Publicar exige cerrarlos todos, y eso es correcto |
| **La sección repite temas de la home** —custodia, la mesa— y podría leerse como copiada | Son textos distintos con estructura distinta: la home dice tres condiciones, ésta cuenta el viaje de la botella. Se verifica leyendo las dos seguidas, no con un grep |

## Migration Plan

1. Escribir la feature completa con `/custodia` y `/contacto` **todavía vivos**.
   Nada se rompe mientras se construye.
2. Cambiar `secciones.ts` y borrar las dos rutas viejas en el **mismo** commit
   que agrega la redirección. Separarlos deja una ventana con la barra
   apuntando a un 404.
3. `next build` local + `next start`, y **mirar la página renderizada** a 390 px
   y a 1440 px. No `next dev`: en esta máquina `next dev` sólo hidrata en
   `localhost`, no en `127.0.0.1`.
4. `cazador-de-puertas` antes de cerrar: que `SeccionOficio` tenga call site,
   que `/oficio` esté en el sitemap, que `PaginaEnObra` conserve los dos
   consumidores que le quedan.
5. Vault: ADR nuevo + `_index.md`. Después `/commit`.
6. **Sin deploy.** Los cinco gates siguen abiertos, y este cambio termina
   verificado sobre una build de producción local, no sobre producción.

**Rollback:** la feature es un directorio nuevo más tres archivos tocados. Se
revierte con un `git revert` del commit; no hay migración de datos, no hay
estado, no hay nada en Firestore.

## Open Questions

| Pregunta | Quién decide | Disparador |
|---|---|---|
| El WhatsApp real del cliente | el dueño | Antes de bajar `EL_CONTACTO_ES_PROVISORIO` |
| El dominio del que se deriva el mail | el dueño | Idem, y es el mismo día que se puede medir la purga de Cloudflare (ADR 005) |
| Con qué nombre firma quien atiende (`voz.md §12`) | el dueño | Antes del primer aviso automático |
| ¿El numeral hueco se lee como decisión o como defecto? | el dueño, mirando | Al terminar el paso 3 de la migración |
