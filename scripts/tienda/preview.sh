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
# Esto NO es la publicacion de la tienda: los gates de deploy siguen abiertos
# (puerta de edad, contacto provisorio, el checkout que no cobra).
set -euo pipefail

PROYECTO=bouquet-vinos
BACKEND=bouquet-tienda
REGION=us-east4
URL="https://$BACKEND--$PROYECTO.$REGION.hosted.app"
RAIZ=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

falla() { echo "NO  $*" >&2; exit 1; }
ok() { echo "ok  $*"; }

desplegar() {
  node "$RAIZ/scripts/tienda/preparar_despliegue.mjs"
  cd "$RAIZ/.deploy/tienda"
  firebase deploy --only apphosting --project "$PROYECTO"
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
  echo "    $URL"
}

case "${1:-}" in
  desplegar) desplegar ;;
  verificar) verificar ;;
  *)
    sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
