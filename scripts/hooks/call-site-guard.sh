#!/bin/bash
# call-site-guard.sh - SOFT (PostToolUse)  [NUEVO, no existe en PadelPunilla]
#
# Ataca el modo de falla mas caro y mas repetido del proyecto anterior: la
# feature 100% escrita y 0% alcanzable. Paso CUATRO veces en seis meses.
#
#   - EditCoverSheet: cadena completa de 3 capas, CERO call sites.
#   - Nombre del turno fijo: la puerta solo se dibujaba con 3+ turnos fijos.
#   - Los seguidos: ni un solo read de la subcoleccion desde ningun picker.
#   - ConfianzaPage: pagina huerfana, sin ruta ni navegacion, "59/59 completa".
#
# SALE 0 SIEMPRE. Es un aviso, no un bloqueo: en composicion bottom-up un
# widget hoja legitimamente no tiene consumidores durante los diez minutos que
# tarda en escribirse el que lo compone. Un bloqueo ahi haria el flujo
# imposible. El aviso aparece justo cuando cerras la tarea sin cablearlo.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/_comun.sh"

RUTA=$(leer_ruta "$(cat)")
[ -z "$RUTA" ] && exit 0
[ -f "$RUTA" ] || exit 0
es_generado "$RUTA" && exit 0
case "$RUTA" in *.dart|*.ts|*.tsx) ;; *) exit 0 ;; esac
case "$RUTA" in */test/*|*_test.dart|*.test.*|*.spec.*) exit 0 ;; esac

BASE=$(basename "$RUTA")

case "$RUTA" in
  *.dart)
    SIMBOLOS=$(grep -oE "^(abstract class|class|mixin|enum) [A-Z][A-Za-z0-9_]*" "$RUTA" 2>/dev/null | awk '{print $NF}')
    ;;
  *)
    SIMBOLOS=$(grep -oE "^export (default )?(abstract )?(class|function|const|interface|type|enum) [A-Za-z_][A-Za-z0-9_]*" "$RUTA" 2>/dev/null | awk '{print $NF}')
    ;;
esac
[ -z "$SIMBOLOS" ] && exit 0

DONDE=""
for d in apps packages functions scripts; do
  [ -d "$RAIZ/$d" ] && DONDE="$DONDE $RAIZ/$d"
done
[ -z "$DONDE" ] && exit 0

HUERFANOS=""
for S in $SIMBOLOS; do
  HITS=$(grep -rlE "\b$S\b" $DONDE 2>/dev/null | grep -v "/$BASE$" | head -1)
  [ -z "$HITS" ] && HUERFANOS="$HUERFANOS $S"
done
[ -z "$HUERFANOS" ] && exit 0

avisar "no encuentro quien use:$HUERFANOS" \
  "" \
  "Definido en $RUTA, sin una sola referencia fuera de su propio archivo." \
  "" \
  "Si recien lo creaste y todavia falta componerlo, ignora esto." \
  "Si estas cerrando la tarea, preguntate:" \
  "  - Si es una pagina: esta en el router? Hay un link que la abra?" \
  "  - Si es un sheet o un dialogo: quien lo abre, y esa puerta se dibuja" \
  "    siempre o solo en un caso que casi no ocurre?" \
  "  - Si es un provider: lo consume alguien?" \
  "" \
  "Antes de creer que una feature existe, grepea quien la abre, no si esta" \
  "escrita."

exit 0
