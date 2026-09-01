#!/bin/bash
# widget-size-guard.sh - HARD (PostToolUse)
#
# Maximo 200 lineas por archivo de presentacion. Es el hook que mas veces
# tuvo razon en PadelPunilla: bloqueo un archivo con 208 y lo dejo pasar con
# 197. Es lo que hace posible la composicion bottom-up.
#
# El limite es > 200, no >= 200. Aun asi, dejar margen: quedar clavado en el
# limite hace que cualquier edicion futura rompa el gate (LECCIONES 9.2).
#
# Los tests quedan afuera a proposito: partir un suite en dos para bajar de
# 200 lineas no arregla nada, solo esconde la cobertura en mas archivos.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/_comun.sh"

MAX=200

RUTA=$(leer_ruta "$(cat)")
[ -z "$RUTA" ] && exit 0
[ -f "$RUTA" ] || exit 0
es_generado "$RUTA" && exit 0

case "$RUTA" in
  */test/*|*/tests/*|*_test.dart|*.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx) exit 0 ;;
esac

APLICA=0
case "$RUTA" in
  */apps/admin/lib/*/presentation/*.dart) APLICA=1 ;;
  */apps/tienda/src/components/*.tsx)     APLICA=1 ;;
  */apps/tienda/src/app/*.tsx)            APLICA=1 ;;
esac
[ "$APLICA" -eq 0 ] && exit 0

LINEAS=$(wc -l < "$RUTA" 2>/dev/null | tr -d ' ')
[ -z "$LINEAS" ] && exit 0
[ "$LINEAS" -le "$MAX" ] && exit 0

bloquear "$RUTA tiene $LINEAS lineas (maximo $MAX)." \
  "" \
  "Parti el widget, no lo comprimas." \
  "Metodos privados _buildAlgo() NO cuentan como partir: el archivo sigue" \
  "teniendo un solo widget gigante y one-widget-per-file bloquea el otro" \
  "camino. Sacá el subarbol a su propio archivo y componelo desde acá."
