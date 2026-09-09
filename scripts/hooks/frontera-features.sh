#!/bin/bash
# frontera-features.sh - HARD (PostToolUse)
#
# La frontera de la arquitectura screaming de la vidriera (ADR 006).
#
# POR QUE EXISTE. El ADR fija cinco reglas contra el cajon de sastre, y cuatro
# se sostienen leyendo. La tercera no: "shared/ no importa de features/, y las
# features no se importan entre si". Es la unica direccional, la unica que se
# viola con una sola linea de import, y la unica que -si se viola- deshace las
# otras cuatro en silencio. El dia que shared/ importa una feature, dejo de ser
# compartido y paso a ser el centro de un grafo ciclico; nadie lo nota hasta
# que hay que mover algo.
#
# CLAUDE.md lo dice sin ambiguedad: "las fronteras por ruta las miden los
# hooks, no el frontmatter". En PadelPunilla un widget importo cloud_firestore
# desde el commit inicial pese a que el agente lo prohibia en su texto.
#
# QUE NO MIDE. La regla 1 (nada nace en shared/) y la 4 (tope de carpetas) son
# de criterio, no de ruta: las mide una persona leyendo el diff. Este hook no
# finge medirlas.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/_comun.sh"

RUTA=$(leer_ruta "$(cat)")
[ -z "$RUTA" ] && exit 0
[ -f "$RUTA" ] || exit 0
es_generado "$RUTA" && exit 0

case "$RUTA" in
  */apps/tienda/src/*) ;;
  *) exit 0 ;;
esac
case "$RUTA" in *.ts|*.tsx) ;; *) exit 0 ;; esac
case "$RUTA" in */test/*|*.test.*|*.spec.*) exit 0 ;; esac

# ---------------------------------------------------------------------------
# 1. shared/ no puede importar de features/
# ---------------------------------------------------------------------------
case "$RUTA" in
  */apps/tienda/src/shared/*)
    HALLAZGOS=$(grep -nE "from '(@/features/|\.\./\.\./features/)" "$RUTA" | head -3)
    if [ -n "$HALLAZGOS" ]; then
      bloquear "$RUTA esta en shared/ e importa de features/." \
        "" \
        "$HALLAZGOS" \
        "" \
        "ADR 006 regla 3. Una pieza de shared/ que conoce una feature no es" \
        "compartida: es esa feature con la puerta abierta, y el dia que la" \
        "feature se borre esto queda apuntando al vacio." \
        "" \
        "Salidas, en orden: (a) la pieza no era de shared, bajala a la" \
        "feature que la usa; (b) lo que necesitas de la feature es en" \
        "realidad un tipo o un dato compartido, subilo a shared o a" \
        "packages/contratos; (c) invertilo: que la feature le PASE el dato" \
        "por props en vez de que shared vaya a buscarlo."
    fi
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# 2. Una feature no puede importar de otra
# ---------------------------------------------------------------------------
case "$RUTA" in
  */apps/tienda/src/features/*)
    # El nombre de la feature propia: lo que hay entre features/ y la barra.
    MIA=${RUTA#*/apps/tienda/src/features/}
    MIA=${MIA%%/*}
    HALLAZGOS=$(grep -nE "from '@/features/" "$RUTA" \
                | grep -vE "from '@/features/$MIA/" | head -3)
    if [ -n "$HALLAZGOS" ]; then
      bloquear "$RUTA importa de OTRA feature." \
        "" \
        "$HALLAZGOS" \
        "" \
        "ADR 006 regla 3. Su feature es '$MIA'. Dos features que se importan" \
        "son una sola feature con dos nombres, y ninguna de las dos se puede" \
        "borrar sin romper la otra." \
        "" \
        "Lo que las dos necesitan va a shared/ -y ahi si esta bien que este," \
        "porque una SEGUNDA feature lo pidio: esa es exactamente la regla de" \
        "promocion del ADR 006, y este bloqueo es el momento de aplicarla."
    fi
    exit 0
    ;;
esac

exit 0
