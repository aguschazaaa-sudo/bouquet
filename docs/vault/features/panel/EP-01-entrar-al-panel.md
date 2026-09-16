# EP-01 — Entrar al panel

> Hito 1 · Workflow A · [volver al mapa](overview.md)

**Objetivo:** que sólo quien tiene permiso entre, que quien no lo tiene sepa
por qué, y que el panel se use igual desde la compu y desde el teléfono.

**Fuera de alcance:** cuentas de compradores —el checkout es sin registro
([ARQUITECTURA §5.1](../../../../ARQUITECTURA.md#51-colecciones))— y el rol
repartidor.

---

## HU-01.1 — Entrar con mi cuenta

**Como** operador, **quiero** entrar al panel con mi cuenta, **para** que sólo
quien tiene permiso vea los pedidos y el catálogo.

- **Ya decidido:** el permiso es el custom claim `rol: admin`, no un documento
  `usuarios/{uid}`. Un `get()` en las reglas se factura en cada evaluación
  ([ARQUITECTURA §9.2](../../../../ARQUITECTURA.md#92-el-rol-va-en-un-custom-claim-no-en-un-documento)).
  `firebase_auth` ya está en `pubspec.yaml`.
- **Decidido por el dueño:** **las dos formas**, mail y contraseña o cuenta de
  Google (*"creo que ambos"*: se confirma en los requerimientos).
- ⚠️ **Dos formas de entrar con el mismo mail tienen una trampa.** Según la
  documentación de Firebase Auth, Google es proveedor **confiable** de las
  direcciones `@gmail.com`: si alguien creó su cuenta con contraseña **sin
  verificar el mail** y después entra con Google, la contraseña se desvincula.
  Se prueba en el emulador de Auth antes de escribir la pantalla. La parte
  buena: con *una cuenta por mail*, las dos formas caen en el mismo `uid` y el
  claim se asigna una sola vez.
- **Ojo en Android:** entrar con Google exige registrar en Firebase la huella
  SHA-1 de **la clave con la que se firma la APK**. Con la de depuración anda
  en la prueba y falla en la APK repartida.

## HU-01.2 — Saber por qué no puedo entrar

**Como** persona con cuenta pero sin permiso, **quiero** que el panel me diga
que no tengo acceso, **para** no confundir un permiso que falta con un panel
roto.

- **Ya decidido:** las reglas le devuelven `permission-denied` a toda lectura
  sin el claim. Si ese error se traga, la pantalla queda vacía y parece que no
  hay datos: es el fallo invisible de
  [ARQUITECTURA §5.4](../../../../ARQUITECTURA.md#54-fotos-de-producto-la-regla-de-la-extensión),
  regla 4, en otra pantalla.
- **Ojo:** el claim nuevo no llega hasta que el token se renueva. Alguien a
  quien le acaban de dar acceso ve "sin permiso" hasta que vuelve a entrar, y
  la pantalla lo tiene que decir.

## HU-01.3 — Dar y quitar acceso

**Como** dueño, **quiero** darle acceso al panel a otra persona y
quitárselo, **para** no compartir mi contraseña.

- **Ya decidido:** el claim lo escribe sólo el Admin SDK. Desde el navegador no
  se puede.
- **Decidido por el dueño:** es un negocio familiar y **todos pueden todo**. Un
  solo rol, sin permisos por sección.
- **Propuesta:** la primera versión es un **script** en `scripts/` (habilitador
  H4): en una familia, dar acceso pasa pocas veces. La pantalla tiene
  disparador: la primera vez que alguien tenga que esperar al desarrollador
  para entrar.

## HU-01.4 — Usarlo desde la compu y desde el teléfono

**Como** operador, **quiero** abrir el panel en el navegador de la compu y en
el teléfono, **para** cargar vinos sentado y despachar parado en el depósito.

- **Ya decidido:** Flutter web + Android
  ([ADR 001](../../architecture/decisions/001-stack.md)). Web va a Firebase
  Hosting ([ARQUITECTURA §10](../../../../ARQUITECTURA.md#10-deploy-y-entornos)).
- **Ojo:** el panel **no compila en esta máquina** (`CLAUDE.md`). Cada vuelta
  de prueba pasa por CI y tarda minutos, y todavía no hay workflow de deploy
  (habilitador H3).
- **Decidido por el dueño:** Android es **una APK**, y hace falta desde el
  hito 2, por los avisos de pedido (HU-06.5). En el hito 1 alcanza con la web,
  que también abre en el navegador del teléfono.
- **Abierto:** cómo se reparte y cómo se mantiene al día (habilitador H5 del
  [mapa](overview.md)): una APK no se actualiza sola.

## HU-01.5 — Moverme entre secciones

**Como** operador, **quiero** una navegación con **Catálogo** y **Pedidos**
—y después **Vidriera**—, **para** llegar a lo que necesito en un toque.

- **Ya decidido:** lo usa gente no técnica: la claridad es el requisito.
  Riverpod para el estado ([ADR 001](../../architecture/decisions/001-stack.md)).
- **Antes del primer widget:** la dirección visual del panel (`/disenio`,
  habilitador H2).
- **Ojo:** una sección que existe y no está en la navegación es la página
  huérfana de PadelPunilla, *"59/59 completa"* y sin ruta.
