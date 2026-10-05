#!/bin/bash
# preview.sh - la preview cerrada de la vidriera en Firebase App Hosting.
# docs/vault/architecture/decisions/017-preview-cerrada.md
#
#   bash scripts/tienda/preview.sh desplegar
#       Arma la copia autocontenida (`preparar_despliegue.mjs`) y la sube.
#       El deploy sale DESDE `.deploy/tienda`: el CLI empaqueta el directorio
#       que contiene el firebase.json.
#
#   bash scripts/tienda/preview.sh verificar
#       Mide lo que un "Rollout complete" no prueba: el estado real de los
#       rollouts por la API, que cada respuesta lleve noindex, que el catalogo
#       sea el de Firestore, y que los gates sigan CERRADOS.
#
#   bash scripts/tienda/preview.sh alias
#       Publica el alias `bouquet-tienda.web.app` (ADR 031): un sitio de
#       Firebase Hosting SIN archivos que reenvia todo al servicio de Cloud Run
#       de la tienda. `desplegar` lo llama solo; a mano hace falta si el alias
#       quedo sirviendo una pagina vieja.
#
# Desde el 2026-09-30 es la publicacion (el nombre del script quedo de cuando
# era una preview): la URL de App Hosting sigue con noindex, el dominio no
# (paso 2b). El checkout sigue sin cobrar y `verificar` mide que siga asi.
set -euo pipefail

PROYECTO=bouquet-vinos
BACKEND=bouquet-tienda
REGION=us-east4
URL="https://$BACKEND--$PROYECTO.$REGION.hosted.app"
SITIO_ALIAS=bouquet-tienda
URL_ALIAS="https://$SITIO_ALIAS.web.app"
RAIZ=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

falla() { echo "NO  $*" >&2; exit 1; }
ok() { echo "ok  $*"; }

# El alias no tiene bytes propios: su firebase.json es todo lo que es, y vive
# aca. Se arma en `.deploy/alias` (gitignoreado) y NO en el firebase.json de la
# raiz, que es el del panel: asi un deploy de este sitio no puede tocar el otro.
#
# `public` va VACIO a proposito: en Hosting un archivo estatico le gana a la
# reescritura, y un index.html ahi taparia la home de la tienda.
#
# Y publicarlo es tambien PURGARLO: Hosting cachea lo que le contesta Cloud Run
# segun su Cache-Control, la home sale con `s-maxage=31536000`, y lo unico que
# vacia esa cache es una publicacion de este sitio. Sin eso, despues de un
# rollout el alias sirve el HTML del build anterior, que pide chunks que el
# build nuevo ya no tiene.
publicar_alias() {
  local dir="$RAIZ/.deploy/alias"
  rm -rf "$dir"
  mkdir -p "$dir/public"
  cat > "$dir/firebase.json" <<JSON
{
  "hosting": {
    "site": "$SITIO_ALIAS",
    "public": "public",
    "rewrites": [
      { "source": "**", "run": { "serviceId": "$BACKEND", "region": "$REGION" } }
    ]
  }
}
JSON
  echo "{ \"projects\": { \"default\": \"$PROYECTO\" } }" > "$dir/.firebaserc"
  cd "$dir"
  firebase deploy --only "hosting:$SITIO_ALIAS" --project "$PROYECTO"
  echo "    $URL_ALIAS"
}

desplegar() {
  node "$RAIZ/scripts/tienda/preparar_despliegue.mjs"
  cd "$RAIZ/.deploy/tienda"
  firebase deploy --only apphosting --project "$PROYECTO"
  publicar_alias
  echo "    verificalo: bash scripts/tienda/preview.sh verificar"
}

verificar() {
  local token api
  token=$(gcloud auth print-access-token 2>/dev/null) || falla "sin sesion de gcloud"
  api="https://firebaseapphosting.googleapis.com/v1/projects/$PROYECTO/locations/$REGION/backends/$BACKEND"

  # 1. El estado REAL del ultimo rollout, y que reciba todo el trafico. El
  # texto del CLI dijo "complete" con un rollout FAILED ya una vez.
  local ultimo trafico
  ultimo=$(curl -s -H "Authorization: Bearer $token" -H "x-goog-user-project: $PROYECTO" "$api/rollouts" \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=(JSON.parse(s).rollouts||[]).sort((a,b)=>b.createTime.localeCompare(a.createTime))[0];console.log(r?r.name.split("/").pop()+" "+r.state:"ninguno")})')
  [ "${ultimo##* }" = SUCCEEDED ] || falla "el ultimo rollout esta en '$ultimo'"
  trafico=$(curl -s -H "Authorization: Bearer $token" -H "x-goog-user-project: $PROYECTO" "$api/traffic" \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);console.log(((j.current||j).splits||[]).map(x=>x.build.split("/").pop()+"="+x.percent+"%").join(","))})')
  case "$trafico" in *"${ultimo%% *}=100%"*) ;; *) falla "el trafico no es 100% del ultimo rollout: $trafico" ;; esac
  ok "rollout ${ultimo%% *}: SUCCEEDED, con el 100% del trafico"

  # 2. noindex en CADA respuesta: paginas, 404 y assets. Un header puesto solo
  # en las paginas felices deja indexar el resto.
  local ruta cabeza codigo robots esperado
  for ruta in / /vinos /oficio /carrito /pedido /ruta-inventada-de-control /vinos/slug-inventado-de-control; do
    cabeza=$(curl -s -o /dev/null -D - "$URL$ruta" | tr -d '\r')
    codigo=$(echo "$cabeza" | head -1 | awk '{print $2}')
    robots=$(echo "$cabeza" | grep -i '^x-robots-tag' | cut -d: -f2- | xargs || true)
    case "$ruta" in *inventad*) esperado=404 ;; *) esperado=200 ;; esac
    [ "$codigo" = "$esperado" ] || falla "$ruta dio $codigo y se esperaba $esperado"
    case "$robots" in *noindex*) ;; *) falla "$ruta NO manda X-Robots-Tag: noindex (dice '${robots:-nada}')" ;; esac
  done
  ok "7 rutas con el codigo esperado y noindex en todas, los 404 incluidos"

  # 2b. Y el DOMINIO, al reves: el mismo codigo y SIN noindex. Es el control
  # negativo del paso 2 -- el header va por host (next.config.ts), y un
  # `noindex` en el dominio deja la tienda afuera de Google sin un solo error.
  # Solo si se pasa: `DOMINIO=ejemplo.com.ar bash scripts/tienda/preview.sh verificar`.
  if [ -n "${DOMINIO:-}" ]; then
    for ruta in / /vinos /oficio /ruta-inventada-de-control; do
      cabeza=$(curl -s -o /dev/null -D - "https://$DOMINIO$ruta" | tr -d '\r')
      codigo=$(echo "$cabeza" | head -1 | awk '{print $2}')
      robots=$(echo "$cabeza" | grep -i '^x-robots-tag' | cut -d: -f2- | xargs || true)
      case "$ruta" in *inventad*) esperado=404 ;; *) esperado=200 ;; esac
      [ "$codigo" = "$esperado" ] || falla "$DOMINIO$ruta dio $codigo y se esperaba $esperado"
      case "$robots" in *noindex*) falla "$DOMINIO$ruta manda noindex: Google no la indexa" ;; esac
    done
    ok "$DOMINIO: 4 rutas con el codigo esperado y SIN noindex"
  fi

  # 3. El catalogo que se ve es el de Firestore, no una pagina vacia con 200.
  local vinos publicados enlaces
  vinos=$(mktemp)
  curl -s "$URL/vinos" -o "$vinos"
  enlaces=$(grep -oE 'href="/vinos/[a-z0-9-]+"' "$vinos" | sort -u | wc -l)
  publicados=$(curl -s -H "Authorization: Bearer $token" -H "x-goog-user-project: $PROYECTO" \
    "https://firestore.googleapis.com/v1/projects/$PROYECTO/databases/(default)/documents/productos?pageSize=300&mask.fieldPaths=publicado" \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const ds=JSON.parse(s).documents||[];console.log(ds.filter(d=>d.fields.publicado&&d.fields.publicado.booleanValue===true).length)})')
  rm -f "$vinos"
  [ "$enlaces" -gt 0 ] || falla "/vinos no enlaza ninguna ficha"
  ok "/vinos enlaza $enlaces fichas; Firestore tiene $publicados publicados (pueden diferir: armarCatalogo descarta los que no validan)"

  # 4. Los gates de deploy siguen CERRADOS: esto es una preview. Con un control
  # negativo, porque un grep que da cero por error confirma cualquier cosa.
  local chunks n contacto inventado
  chunks=$(mktemp -d)
  for src in $(curl -s "$URL/pedido" | grep -oE '/_next/static/[^"]+\.js' | sort -u); do
    curl -s "$URL$src" -o "$chunks/$(echo "$src" | tr '/' '_')"
  done
  # `|| true`: con pipefail, un grep -l que NO encuentra nada sale con 1 -- que
  # es exactamente lo que tiene que pasar con el control negativo -- y set -e
  # mataba el script en silencio, sin decir cual paso fallo.
  n=$( (grep -l 'data-checkout-simulado' "$chunks"/* 2>/dev/null || true) | wc -l)
  inventado=$( (grep -l 'data-zz-inventado-2026' "$chunks"/* 2>/dev/null || true) | wc -l)
  rm -rf "$chunks"
  [ "$n" -ge 1 ] || falla "el gate del checkout no esta en el JavaScript: el 'Pagar' podria estar cobrando"
  [ "$inventado" -eq 0 ] || falla "el control negativo del gate coincide: la medicion no discrimina"
  contacto=$(curl -s "$URL/oficio" | grep -c 'data-contacto-provisorio' || true)
  [ "$contacto" -ge 1 ] || falla "el gate del contacto provisorio no aparece en /oficio"
  ok "gates cerrados: checkout que no cobra y contacto provisorio (con control negativo)"

  # 5. La puerta de edad (ARQUITECTURA 9.5), en tres cosas que un 200 no prueba:
  # que el telon este en el HTML de cada ruta y no solo en la home; que el
  # script que lo esconde para quien ya entro venga ANTES (si viene despues, el
  # telon parpadea en cada carga); y que el contenido siga entero debajo -- un
  # telon que bloquea el render deja a Google sin nada que indexar.
  local html telon script fichas
  for ruta in / /vinos /oficio /carrito; do
    html=$(curl -s "$URL$ruta")
    telon=$( (echo "$html" | grep -bo 'data-fase="puesta"' || true) | head -1 | cut -d: -f1)
    script=$( (echo "$html" | grep -bo 'localStorage.getItem("bouquet.edad")' || true) | head -1 | cut -d: -f1)
    [ -n "$telon" ] || falla "$ruta no trae la puerta de edad en el HTML"
    [ -n "$script" ] || falla "$ruta no trae el script que recuerda la edad"
    [ "$script" -lt "$telon" ] || falla "$ruta: el script de la edad viene DESPUES del telon (byte $script > $telon)"
  done
  html=$(curl -s "$URL/vinos")
  fichas=$(echo "$html" | grep -oE 'href="/vinos/[a-z0-9-]+"' | sort -u | wc -l)
  [ "$fichas" -gt 0 ] || falla "/vinos trae el telon pero no las fichas: el telon esta bloqueando el render"
  inventado=$(echo "$html" | grep -c 'data-fase="zz-inventada-2026"' || true)
  [ "$inventado" -eq 0 ] || falla "el control negativo del telon coincide: la medicion no discrimina"
  ok "puerta de edad en 4 rutas, con el script antes del telon y $fichas fichas debajo (con control negativo)"
  echo "    $URL"

  # 6. El alias (ADR 031), al final a proposito: si falla, todo lo de arriba
  # -- que es la tienda -- ya quedo dicho. Es el link que se le muestra a
  # alguien, y un alias roto no avisa: da 403 con la tienda sana detras.
  #
  # El `noindex` hace dos trabajos: prueba que la respuesta salio de Next y no
  # de Hosting (el 404 propio de Hosting no lo trae), y que el alias no compite
  # en Google con el dominio el dia que exista.
  for ruta in / /vinos /oficio /ruta-inventada-de-control; do
    cabeza=$(curl -s -o /dev/null -D - "$URL_ALIAS$ruta" | tr -d '\r')
    codigo=$(echo "$cabeza" | head -1 | awk '{print $2}')
    robots=$(echo "$cabeza" | grep -i '^x-robots-tag' | cut -d: -f2- | xargs || true)
    [ "$codigo" != 403 ] || falla "el alias $URL_ALIAS$ruta da 403: Cloud Run no acepta llamadas publicas. Falta allUsers como roles/run.invoker en el servicio $BACKEND ($REGION), ver ADR 031"
    case "$ruta" in *inventad*) esperado=404 ;; *) esperado=200 ;; esac
    [ "$codigo" = "$esperado" ] || falla "el alias $URL_ALIAS$ruta dio $codigo y se esperaba $esperado"
    case "$robots" in *noindex*) ;; *) falla "el alias $URL_ALIAS$ruta NO manda X-Robots-Tag: noindex (dice '${robots:-nada}')" ;; esac
  done
  ok "alias: 4 rutas con el codigo esperado y noindex, el 404 incluido"

  # Y que sirva EL MISMO build. Hosting cachea la home y /oficio un anio
  # (medido: X-Cache HIT con s-maxage=31536000) y solo una publicacion del
  # alias lo vacia: un rollout sin `alias` detras deja el link mostrando la
  # tienda de antes, con 200 y todo en orden. Las dos paginas son estaticas,
  # asi que por los dos caminos salen byte a byte iguales (medido). El telon
  # es el control positivo: dos cuerpos vacios tambien son iguales.
  local origen
  for ruta in / /oficio; do
    html=$(curl -s "$URL_ALIAS$ruta")
    origen=$(curl -s "$URL$ruta")
    telon=$(echo "$html" | grep -c 'data-fase="puesta"' || true)
    [ "$telon" -ge 1 ] || falla "el alias $URL_ALIAS$ruta no trae la puerta de edad: no es la tienda"
    [ "$html" = "$origen" ] || falla "el alias sirve OTRO build en $ruta (${#html} caracteres contra ${#origen}): bash scripts/tienda/preview.sh alias"
  done
  ok "alias: / y /oficio son byte a byte las de $URL"
  echo "    $URL_ALIAS"
}

case "${1:-}" in
  desplegar) desplegar ;;
  verificar) verificar ;;
  alias) publicar_alias ;;
  *)
    sed -n '2,23p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
