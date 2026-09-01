#!/bin/bash
# doc-reminder.sh - SOFT (Stop)
#
# Avisa si cambio codigo sin que cambiara docs/vault/.
#
# El vault de PadelPunilla documentaba la INTENCION y no el comportamiento, y
# el diagnostico correcto era estructural, no de disciplina: el vault se
# escribe cuando se PROPONE el codigo, y nadie vuelve a mirarlo cuando la
# ultima pieza no se cablea. Este hook no arregla eso -eso lo arregla
# _verdad.md, generado desde el codigo- pero al menos hace ruido.
#
# Sale 0 siempre.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/_comun.sh"

command -v git >/dev/null 2>&1 || exit 0
git -C "$RAIZ" rev-parse --git-dir >/dev/null 2>&1 || exit 0

CAMBIOS=$(git -C "$RAIZ" status --porcelain 2>/dev/null)
[ -z "$CAMBIOS" ] && exit 0

TOCO_CODIGO=$(printf '%s\n' "$CAMBIOS" | grep -cE " (apps|functions|packages)/")
TOCO_VAULT=$(printf '%s\n' "$CAMBIOS" | grep -cE " docs/vault/")

[ "$TOCO_CODIGO" -eq 0 ] && exit 0
[ "$TOCO_VAULT" -gt 0 ] && exit 0

avisar "cambio codigo y no cambio docs/vault/." \
  "" \
  "$TOCO_CODIGO archivo(s) de apps/, functions/ o packages/ modificados." \
  "" \
  "No hace falta documentar cada edicion. Si hace falta cuando:" \
  "  - se tomo una decision -> ADR nuevo en architecture/decisions/" \
  "  - cambio el estado del proyecto -> _index.md (tope: 5 entradas)" \
  "  - aparecio un termino del dominio -> domain/glossary.md" \
  "  - una feature quedo utilizable -> features/<feature>/overview.md" \
  "" \
  "Y si escribis un pendiente, lleva FECHA y DISPARADOR. Un pendiente sin" \
  "disparador es un pendiente que nadie va a cerrar."

exit 0
