#!/bin/bash
# no-hardcoded-colors.sh - HARD (PostToolUse)
#
# Cero colores literales fuera de los archivos de tema / tokens.
#
# Es una regla incomoda y por eso funciona: la excepcion del "gris neutro" es
# exactamente por donde se rompe un sistema de temas. bouquet tiene tema claro
# y oscuro; nada de eso sobrevive a 40 Colors.grey sueltos.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/_comun.sh"

RUTA=$(leer_ruta "$(cat)")
[ -z "$RUTA" ] && exit 0
[ -f "$RUTA" ] || exit 0
es_generado "$RUTA" && exit 0

# --- Panel en Flutter ------------------------------------------------------
case "$RUTA" in
  */apps/admin/lib/theme/*) exit 0 ;;
  */apps/admin/lib/*.dart)
    if grep -qE "Color\(0x|Color\.fromARGB|Color\.fromRGBO|\bColors\.[a-zA-Z]" "$RUTA"; then
      EJEMPLO=$(grep -nE "Color\(0x|Color\.fromARGB|Color\.fromRGBO|\bColors\.[a-zA-Z]" "$RUTA" | head -3)
      bloquear "$RUTA tiene un color literal." \
        "" \
        "$EJEMPLO" \
        "" \
        "Usa Theme.of(context).colorScheme. Sin excepciones, tampoco para" \
        "grises: la excepcion del gris neutro es por donde se rompe un" \
        "sistema de temas."
    fi
    exit 0
    ;;
esac

# --- Vidriera en Next.js ---------------------------------------------------
case "$RUTA" in
  */apps/tienda/src/tokens/*|*/apps/tienda/src/app/globals.css) exit 0 ;;
  */apps/tienda/src/*.css|*/apps/tienda/src/*.tsx|*/apps/tienda/src/*.ts)
    # Se excluyen las lineas con href= y las anclas de ruta: un href="#abc"
    # tiene tres caracteres hex y no es un color. Falso positivo conocido,
    # descartado a proposito.
    HALLAZGOS=$(grep -nE "#([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b|\brgba?\(|\bhsla?\(" "$RUTA" \
                | grep -vE "href=|to=\"#|id=\"#" | head -3)
    if [ -n "$HALLAZGOS" ]; then
      bloquear "$RUTA tiene un color literal." \
        "" \
        "$HALLAZGOS" \
        "" \
        "Usa los tokens de apps/tienda/src/tokens/. Un color suelto no" \
        "aparece en ninguna auditoria de tema y sobrevive a cualquier" \
        "rediseno."
    fi
    exit 0
    ;;
esac

exit 0
