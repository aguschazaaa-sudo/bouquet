#!/bin/bash
# publicar.sh - publica el panel web con los MISMOS bytes que compilo CI.
# openspec/changes/panel-entrar, specs/panel-publicacion.
#
#   bash scripts/panel/publicar.sh preview <run-id> [canal]
#       Exige que la corrida de CI haya terminado en success con el build del
#       panel adentro, baja el artifact `panel-web`, verifica cada hash y el
#       commit, y lo sube a un canal de preview.
#
#   bash scripts/panel/publicar.sh promover [canal]
#       Copia la version del canal a live con `hosting:clone`. No compila ni
#       sube nada: lo que se verifico en el canal es lo que queda publicado.
#
#   bash scripts/panel/publicar.sh verificar <url>
#       Compara el hash de lo que sirve <url> con el SHA256SUMS del build
#       local, con un control negativo, y mira el X-Robots-Tag.
#
# Por que no se compila aca: el panel no compila en esta maquina (CLAUDE.md).
# Por que no `gh run watch`: devuelve 0 en corridas CANCELADAS; la conclusion
# se lee del JSON.
set -euo pipefail

PROYECTO=bouquet-vinos
SITIO=bouquet-vinos
CANAL_POR_DEFECTO=panel
RAIZ=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
BUILD="$RAIZ/apps/admin/build/web"

falla() { echo "NO  $*" >&2; exit 1; }

campo() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const v=process.argv[1].split(".").reduce((o,k)=>o?.[k],JSON.parse(s));console.log(v??"")})' "$1"; }

preview() {
  local run=${1:?falta el id de la corrida}
  local canal=${2:-$CANAL_POR_DEFECTO}

  local datos
  datos=$(gh run view "$run" --json conclusion,status,headSha,jobs)
  [ "$(echo "$datos" | campo status)" = completed ] || falla "la corrida $run no termino"
  [ "$(echo "$datos" | campo conclusion)" = success ] \
    || falla "la corrida $run termino en '$(echo "$datos" | campo conclusion)'"
  local build
  build=$(echo "$datos" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s).jobs.find(j=>j.name==="build_panel");console.log(j?j.conclusion:"no-existe")})')
  [ "$build" = success ] || falla "el job build_panel de la corrida $run esta en '$build' (skipped no cuenta)"
  local sha
  sha=$(echo "$datos" | campo headSha)
  echo "ok  corrida $run: success, build_panel: success, commit $sha"

  local tmp
  tmp=$(mktemp -d)
  gh run download "$run" -n panel-web -D "$tmp"

  ( cd "$tmp" && sha256sum --check --quiet SHA256SUMS ) || falla "un archivo no coincide con su hash"
  # Un archivo de mas, que no esta en la lista, tampoco pasa.
  local listados presentes
  listados=$(wc -l < "$tmp/SHA256SUMS")
  presentes=$(cd "$tmp" && find . -type f ! -name SHA256SUMS | wc -l)
  [ "$listados" -eq "$presentes" ] || falla "hay $presentes archivos y SHA256SUMS lista $listados"
  [ "$(cat "$tmp/COMMIT")" = "$sha" ] || falla "COMMIT dice $(cat "$tmp/COMMIT") y la corrida es de $sha"
  echo "ok  $listados archivos con su hash, commit coincide"

  rm -rf "$BUILD"
  mkdir -p "$(dirname "$BUILD")"
  cp -r "$tmp" "$BUILD"
  rm -rf "$tmp"

  local salida url
  salida=$(firebase hosting:channel:deploy "$canal" --only admin --project "$PROYECTO" --expires 7d --json)
  url=$(echo "$salida" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s.slice(s.indexOf("{")));if(j.status!=="success"){console.error(JSON.stringify(j));process.exit(1)}console.log(Object.values(j.result)[0].url)})')
  echo "ok  canal $canal: $url"
  echo "    verificalo:   bash scripts/panel/publicar.sh verificar $url"
  echo "    y recien ahi: bash scripts/panel/publicar.sh promover $canal"
}

promover() {
  local canal=${1:-$CANAL_POR_DEFECTO}
  firebase hosting:clone "$SITIO:$canal" "$SITIO:live" --project "$PROYECTO"
  echo "ok  $canal promovido a live"
  echo "    verificalo:   bash scripts/panel/publicar.sh verificar https://$SITIO.web.app"
}

verificar() {
  local url=${1:?falta la url}
  url=${url%/}
  [ -f "$BUILD/SHA256SUMS" ] || falla "no hay build local en $BUILD: primero 'preview'"

  local archivo esperado servido
  for archivo in main.dart.js flutter_bootstrap.js index.html COMMIT; do
    esperado=$(grep " \./$archivo\$" "$BUILD/SHA256SUMS" | cut -d' ' -f1)
    [ -n "$esperado" ] || falla "$archivo no esta en SHA256SUMS"
    servido=$(curl -fsS "$url/$archivo" | sha256sum | cut -d' ' -f1)
    [ "$servido" = "$esperado" ] || falla "$url/$archivo no es el del build ($servido)"
    echo "ok  $archivo  ${esperado:0:16}"
  done

  # Control negativo: un archivo inventado lo contesta la reescritura con
  # index.html, y su hash NO puede coincidir con el de main.dart.js. Si
  # coincidiera, la comparacion de arriba no distingue nada.
  esperado=$(grep ' \./main\.dart\.js$' "$BUILD/SHA256SUMS" | cut -d' ' -f1)
  servido=$(curl -fsS "$url/archivo-inventado-de-control.js" | sha256sum | cut -d' ' -f1)
  [ "$servido" != "$esperado" ] || falla "el control negativo coincide: la verificacion no discrimina"
  echo "ok  control negativo: un archivo inventado no pasa por main.dart.js"

  curl -fsSI "$url/" | tr -d '\r' | grep -qi '^x-robots-tag: noindex' \
    || falla "$url/ no manda X-Robots-Tag: noindex"
  echo "ok  X-Robots-Tag: noindex"
  echo "    commit publicado: $(curl -fsS "$url/COMMIT")"
}

case "${1:-}" in
  preview) shift; preview "$@" ;;
  promover) shift; promover "$@" ;;
  verificar) shift; verificar "$@" ;;
  *)
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
