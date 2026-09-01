#!/bin/bash
# commit-reminder.sh - Stop
#
# ===========================================================================
# READ-ONLY. EXIT 0. NUNCA ESCRIBE GIT.
#
# Esto no es una preferencia de estilo. En PadelPunilla habia un watcher de
# auto-commit cableado como hook Stop. Una sesion se corto a mitad de
# escritura y dejo dos archivos de git en NUL (0x00):
#
#   .git/refs/heads/master   41 bytes de ceros
#   .git/index               "bad signature 0x00000000"
#
# Desde ahi todos los auto-commits siguientes fallaron EN SILENCIO, y ~5 dias
# de trabajo quedaron sin commitear. Fue la peor perdida del proyecto.
#
# Este hook solo MIRA. El commit lo hace Claude en conversacion, como ultimo
# paso, leyendo el diff y decidiendo el mensaje. LECCIONES 9.1.
# ===========================================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/_comun.sh"

command -v git >/dev/null 2>&1 || exit 0
git -C "$RAIZ" rev-parse --git-dir >/dev/null 2>&1 || exit 0

SUCIO=$(git -C "$RAIZ" status --porcelain 2>/dev/null | head -20)
[ -z "$SUCIO" ] && exit 0

CUANTOS=$(git -C "$RAIZ" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
printf 'El arbol tiene %s archivo(s) sin commitear:\n\n' "$CUANTOS"
printf '%s\n' "$SUCIO"
[ "$CUANTOS" -gt 20 ] && printf '  ... y %s mas\n' "$((CUANTOS - 20))"
printf '\nCommitear es el anteultimo paso, no el ultimo: despues va el deploy.\n'

exit 0
