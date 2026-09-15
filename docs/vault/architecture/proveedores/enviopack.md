# Envíopack — proveedor de envío por correo (evaluación)

- **Fecha:** 2026-09-15
- **Estado:** investigación cerrada, **sin adopción decidida**. No hay ADR
  todavía — este documento es el insumo para escribirlo el día que el dueño
  elija proveedor de envío.
- **Qué contesta:** cómo se integra Envíopack de punta a punta (auth, cotizar,
  crear envío, etiqueta, tracking, webhooks), qué formato de datos exige, y
  qué queda como zona gris con el alcohol.
- **Qué NO contesta:** si aprueban la cuenta comercial de bouquet, costos
  reales negociados, plazos de entrega medidos contra un envío real, si piden
  DNI del destinatario, contrareembolso.

**Cómo leer las fuentes de este documento.** Cada afirmación lleva su URL al
lado y sale de la documentación oficial (se hizo fetch de la página para
leerla). Donde dice explícitamente **"verificado con fetch real"** es porque
además se probó contra el servicio de verdad — un registro npm, un status
code — y no sólo se leyó lo que la doc promete. Lo que no tiene ninguna de
las dos cosas está en la última sección, con su disparador.

---

## 0. El nombre, antes que cualquier otra cosa

La empresa se llama **Envíopack**, todo junto. Sitio comercial:
https://www.enviopack.com.ar/. Documentación técnica:
https://developers.enviopack.com.ar/.

⚠️ **`enviospack.com` (con "s" en el medio) es OTRA empresa**, de paquetería
hacia Cuba, sin API pública. Es la trampa más barata de este documento:
alguien busca "envios pack" de memoria, o escribe el dominio a mano, y
termina en el sitio equivocado. Confirmar el nombre exacto (Envíopack, sin
"s") antes de dar de alta cualquier cuenta o de mandar el primer mail
comercial.

## 1. Documentación y acceso

| | |
|---|---|
| Doc técnica | https://developers.enviopack.com.ar/ — abierta, sin login (**verificado con fetch real**) |
| Para operar | hace falta cuenta comercial. Proceso de alta: no verificado |
| Base URL | `https://api.enviopack.com` |
| Límite | 3000 requests / 5 min. https://developers.enviopack.com.ar/ |

## 2. Es un agregador real, no un correo propio

El parámetro `correo` acepta `"oca"`, `"andreani"`, `"fastmail"` entre otros,
y hay `GET /correos` para listar los transportistas disponibles en la
cuenta: https://developers.enviopack.com.ar/correos.

Esto importa para bouquet porque el puerto `ProveedorDeEnvio` en
[`packages/contratos/src/envio.ts`](../../../../packages/contratos/src/envio.ts)
ya está pensado para devolver **una lista** de opciones — el comentario del
archivo dice literalmente *"un agregador devuelve varios correos"*, escrito
antes de que se investigara Envíopack. Calzan sin fricción.

## 3. Autenticación

`POST /auth`, form-urlencoded, con `api-key` + `secret-key` → devuelve
`access_token`. https://developers.enviopack.com.ar/autenticacion

| Detalle | Valor |
|---|---|
| Duración del token | 4 horas, con refresh |
| Cómo viaja | **query param** `?access_token=...` — NO como header `Authorization` |

⚠️ Es lo opuesto a Mercado Pago (ver [`mercado-pago.md`](mercado-pago.md)),
que usa `Authorization: Bearer`. El cliente HTTP del adaptador de envío no
puede copiarse del de pagos.

## 4. Endpoints

| Acción | Endpoint | Doc |
|---|---|---|
| Cotizar costo | `GET /cotizar/costo` | https://developers.enviopack.com.ar/cotiza-un-envio |
| Cotizar precio a domicilio | `GET /cotizar/precio/a-domicilio` | ídem |
| Cotizar precio a sucursal | `GET /cotizar/precio/a-sucursal` | ídem |
| Listar sucursales | `GET /sucursales` (`id_correo`, `id_localidad`) | https://developers.enviopack.com.ar/ |
| Crear envío | `POST /envios` | https://developers.enviopack.com.ar/realiza-un-envio |
| Etiqueta | `GET /envios/[ID]/etiqueta?formato=pdf\|jpg` | ídem |
| Tracking | `GET /envios/[ID]/tracking` | ídem |

## 5. Cotizar — parámetros

| Parámetro | Formato | Nota |
|---|---|---|
| `provincia` | ISO 3166-2:AR **sin** el prefijo `AR-` (ej. `"C"`) | Coincide exacto con `ProvinciaIso` de `envio.ts` — mismo código, cero traducción |
| `codigo_postal` | 4 dígitos | |
| `peso` | kg, 2 decimales | |
| `paquetes` | opcional, `"20x2x10,20x2x10"` (alto×ancho×largo cm, uno por bulto) | ⚠️ el orden es alto×ancho×largo, no largo×ancho×alto |
| `despacho` / `modalidad` | `D` domicilio · `S` sucursal | |
| `servicio` | `N` estándar · `P` prioritario · `X` express · `R` devoluciones | |
| `localidad` | ID | obligatorio **sólo** para a-sucursal |

https://developers.enviopack.com.ar/cotiza-un-envio

### Respuesta (ejemplo real de la doc)

```json
{"correo":{"id":"oca","nombre":"OCA"},"despacho":"D","modalidad":"S","servicio":"N","peso_desde":"1.00","peso_hasta":"2.00","valor":"44.85","horas_entrega":72,"cumplimiento":94,"anomalos":5}
```

⚠️ **`valor` viene como string**, no número — el adaptador tiene que
parsearlo antes de convertirlo a `Centavos`. ⚠️ **`horas_entrega` es horas,
no una fecha ni un rango de días**: `OpcionDeEnvio.desdeDias` /
`.hastaDias` (en `envio.ts`) se derivan dividiendo por 24, no se copian
directo.

## 6. Crear envío

`POST /envios` con `destinatario` (máx 50 caracteres), `modalidad`, `calle`,
`numero`, `piso`, `depto`, `codigo_postal`, `provincia`, `localidad` (acá
texto, no ID), `productos[]`, `usa_seguro`.
https://developers.enviopack.com.ar/realiza-un-envio

Devuelve `id`, `tracking_number`, `estado` (`B|C|E|P`), `costo_envio`,
`costo_seguro`, `peso_aforado`.

⚠️ No confirmado qué significa cada letra de `estado` — no apareció una
tabla completa en la página revisada.

## 7. Webhooks

Dos eventos: `envio-procesado` y `envio-cambio-condicion`.
https://developers.enviopack.com.ar/notificaciones

| Detalle | Valor |
|---|---|
| Método | **GET**, no POST — con `?tipo=...&id=...` en la query |
| Timeout de respuesta | ≤ 5 segundos, responder 200 |
| Reintentos | 10 veces cada 2 minutos |
| Configuración | desde el panel web, **no por API** |

⚠️ La doc pide **explícitamente no hacer polling** de tracking: usar los
webhooks. Es consistente con la regla 1 de
[ADR 003](../decisions/003-pagos.md) para pagos —la fuente de verdad es la
consulta, no el cuerpo del webhook— y acá es todavía más literal: el
webhook llega por GET, así que ni siquiera trae cuerpo. Hay que ir a buscar
el estado con `GET /envios/[ID]/tracking` al recibirlo, igual que se
consulta `GET /v1/payments/{id}` en Mercado Pago.

## 8. Seguro y contrareembolso

- **Seguro: sí.** `usa_seguro` al crear el envío, `costo_seguro` en la
  respuesta.
- **Contrareembolso: no se encontró mención** en la documentación revisada.
  No confirmado — ver §12.

## 9. SDK / integración

**No hay SDK oficial de Node ni TypeScript.** Verificado con fetch real:
`https://registry.npmjs.org/enviopack` da **404**. Existe uno no oficial,
marcado "under development": https://github.com/Fblind/enviopack-node — no
evaluado para producción. La integración de bouquet va por `fetch` directo,
igual que hoy no hay dependencia madura que instalar.

## 10. Peso y medidas de una caja de 6 — estimados, no medidos

| | Valor |
|---|---|
| Peso | ~8 kg |
| Medidas | ~34 × 24 × 18 cm |

Fuentes:
https://www.catadelvino.com/blog-cata-vino/cuales-medidas-caja-6-botellas-vino
y https://www.espaciovino.com.ar/envios (vinoteca argentina que factura el
envío por caja de 8 kg).

Estos números **ya están en código**: `CAJA_KG` y `CAJA_CM` en
[`packages/contratos/src/envio.ts`](../../../../packages/contratos/src/envio.ts),
con el mismo comentario de que son estimados. ⚠️ **Son estimados, no
medidos** — el disparador para corregirlos es pesar y medir una caja real de
bouquet antes del primer cobro de envío: cotizar con 8 kg cuando la caja
real pesa 8,6 es un error de precio, no un redondeo.

## 11. Cómo calza con el puerto que ya existe

`ProveedorDeEnvio.cotizar(destino, bultos)` en
[`packages/contratos/src/envio.ts`](../../../../packages/contratos/src/envio.ts)
devuelve `Promise<readonly OpcionDeEnvio[]>`. Un adaptador de Envíopack
tendría que:

1. Cotizar contra `/cotizar/precio/a-domicilio` y
   `/cotizar/precio/a-sucursal` (dos llamadas, no una) por cada `correo`
   relevante.
2. Convertir cada respuesta a un `OpcionDeEnvio`, parseando `valor` (string
   → `Centavos`) y derivando `desdeDias`/`hastaDias` de `horas_entrega`.
3. Dejar `transportista` = `correo.nombre` de la respuesta, y
   `nombre`/`detalle` como texto propio de bouquet — nunca el nombre crudo
   del correo. Misma regla que ADR 003 fija para el rótulo de pago: no se
   arma la UI a partir de datos crudos del proveedor.

`propio` (el reparto en el valle de Punilla) queda **fuera de Envíopack por
completo**: es la tabla de cobertura propia de bouquet, no una modalidad que
cotice un correo. `DestinoDeEnvio.propio` en `envio.ts` ya lo modela así.

## 12. Alcohol — zona gris, con disparador

Ningún correo revisado prohíbe explícitamente el alcohol por escrito, y
ninguno lo permite por escrito tampoco:

| Correo | Qué dice | Fuente |
|---|---|---|
| Correo Argentino | Lista de prohibidos que no nombra bebidas | https://www.correoargentino.com.ar/que-productos-no-puedo-enviar-por-correo-argentino |
| Andreani | Prohíbe "elementos líquidos y/o frágiles" en términos generales, sin mencionar alcohol específicamente | https://apidestinatarios.andreani.com/terminosycondicioneseandreani.pdf |
| OCA | No se pudo verificar la lista | — |

⚠️ **Es zona gris, no un permiso.** "No está prohibido por escrito" no es
"está permitido". **Disparador: confirmarlo con Envíopack por contacto
comercial directo, antes de habilitar el primer envío real con vino
adentro** — no antes, porque hasta no tener cuenta activa no hay a quién
preguntarle con autoridad sobre esto.

## 13. Dato legal aparte — no es de Envíopack, pero cruza acá

En CABA, la Ley 3361 obliga al vendedor a verificar la mayoría de edad (18)
y exigir documento en la entrega a domicilio, con la entrega restringida a
franja horaria 8–24 hs.
https://boletinoficial.buenosaires.gob.ar/normativaba/norma/140166

No es un requisito de Envíopack: es un requisito legal que **cualquier**
transportista tiene que poder cumplir en el momento de la entrega, y hoy no
está confirmado que un cadete de correo tercerizado vaya a pedir DNI en la
puerta. Cruza con [ARQUITECTURA
§9.5](../../../../ARQUITECTURA.md#95-alcohol-y-edad) (alcohol y edad).

## 14. Alternativas — una línea cada una

| Proveedor | Nota | Fuente |
|---|---|---|
| Andreani (directo, sin agregador) | SDK oficial sólo PHP | https://developers.andreani.com/documentacion · https://github.com/andreani-publico/sdk-php |
| Correo Argentino PAQ.AR | Integración propia, no agregada | https://integracion.correoargentino.com.ar |
| Shipnow | No se encontró documentación técnica pública propia | https://www.shipnow.com.ar/ |
| Zippin | Doc técnica propia | https://docs.zipnova.com/envios/ |

---

## Lo que NO está confirmado

| Punto | Disparador |
|---|---|
| Si Envíopack (o el correo detrás) exige DNI del destinatario al entregar | Antes de habilitar el primer envío real — cruza con la Ley 3361 (§13) |
| Contrareembolso | Antes de ofrecerlo como medio de pago, si algún día se evalúa |
| Campos completos de `GET /sucursales` | Al implementar la modalidad "a sucursal" en el checkout |
| Estructura completa de `productos[]` / el objeto "pedido" en `POST /envios` | Al escribir el adaptador |
| Costos comerciales reales (tarifas negociadas, no de lista) | Al dar de alta la cuenta comercial |
| Significado de cada letra de `estado` (`B\|C\|E\|P`) al crear un envío | Al escribir el adaptador — releer la doc completa o preguntar por soporte |
| Si Envíopack permite explícitamente el transporte de alcohol | Antes de habilitar el primer envío real con vino — contacto comercial directo (§12) |
| Peso y medidas reales de una caja de 6 de bouquet | Antes del primer cobro de envío — pesar una caja física |
| Proceso de alta de la cuenta comercial (tiempos, requisitos) | Cuando el dueño decida avanzar con este proveedor |
