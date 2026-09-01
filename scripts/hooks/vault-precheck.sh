#!/bin/bash
# vault-precheck.sh - HARD (PreToolUse sobre Edit|Write)
#
# Frena la PRIMERA escritura de codigo de la sesion hasta que se confirme que
# se leyo el vault. La bandera sale de _comun.sh: la misma variable que borra
# post-task-reminder.sh. Una sola ruta, en los dos extremos.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/_comun.sh"

RUTA=$(leer_ruta "$(cat)")
[ -z "$RUTA" ] && exit 0

# Solo codigo de produccion. Docs, scripts, config y tests pasan libres:
# el gate existe para que no se toque el producto sin contexto, no para
# hacer friccion en todo.
case "$RUTA" in
  */apps/admin/lib/*|*/apps/tienda/src/*|*/functions/src/*|*/packages/*/src/*) ;;
  *) exit 0 ;;
esac

[ -f "$BANDERA_VAULT" ] && exit 0

bloquear "escritura de codigo frenada hasta leer el vault." \
  "" \
  "Archivo: $RUTA" \
  "" \
  "Antes de escribir codigo:" \
  "  1. Lee docs/vault/_index.md" \
  "  2. Lee el ADR de lo que vas a tocar (docs/vault/architecture/decisions/)" \
  "  3. Si tocas una feature, lee su overview en docs/vault/features/" \
  "" \
  "Para confirmar y desbloquear, escribi cualquier contenido en:" \
  "  .claude/.vault-session-ok" \
  "" \
  "La bandera se borra sola al terminar el turno, asi que el gate vuelve a" \
  "frenar en la proxima sesion. Eso es a proposito."
