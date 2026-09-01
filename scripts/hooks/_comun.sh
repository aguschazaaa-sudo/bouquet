#!/bin/bash
# _comun.sh - lo que comparten todos los hooks de bouquet.
#
# ===========================================================================
# LA RUTA DE LA BANDERA DEL VAULT SE DEFINE ACA Y EN NINGUN OTRO LADO.
#
# En PadelPunilla el PreToolUse leia  ${CLAUDE_PROJECT_DIR}/.vault-session-ok
# y el Stop borraba              ${CLAUDE_PROJECT_DIR}/.claude/.vault-session-ok
#
# Como el de la raiz nunca se borraba, el gate se desbloqueo UNA vez y no
# volvio a frenar nunca. Era el hook mas caro del sistema y el unico que no
# medi­a nada. Ver DIAGNOSTICO.md, "Lo que NO esta funcionando" #1.
#
# Definirla una sola vez, en un archivo que los dos extremos importan, hace
# que esa clase de bug no se pueda escribir.
# ===========================================================================

RAIZ="${CLAUDE_PROJECT_DIR:-.}"
BANDERA_VAULT="$RAIZ/.claude/.vault-session-ok"

# leer_ruta <json-del-hook>
# Devuelve el file_path normalizado a barras hacia adelante, o vacio.
# Sin python: son 7 hooks por edicion y el arranque del interprete se nota.
leer_ruta() {
  local entrada="$1" p
  p=$(printf '%s' "$entrada" \
      | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
      | head -1)
  [ -z "$p" ] && return 0
  printf '%s' "$p" | tr '\\' '/' | tr -s '/'
}

# bloquear <motivo> [linea...]  -> exit 2
# El mensaje va por STDERR: es el canal que el harness devuelve a Claude
# cuando un hook sale con 2. LECCIONES 9.2: un bloqueo que no dice por que
# es indistinguible de un hook roto, y la reaccion natural -quedarse quieto-
# es exactamente la que no lo destraba.
bloquear() {
  printf 'BLOQUEADO - %s\n' "$1" >&2
  shift
  local l
  for l in "$@"; do printf '  %s\n' "$l" >&2; done
  exit 2
}

# avisar <motivo> [linea...]  -> no corta nada
avisar() {
  printf 'AVISO - %s\n' "$1"
  shift
  local l
  for l in "$@"; do printf '  %s\n' "$l"; done
}

# es_generado <ruta>: archivos que ningun hook de estilo debe juzgar
es_generado() {
  case "$1" in
    *.g.dart|*.freezed.dart|*.gr.dart|*.mocks.dart) return 0 ;;
    */generated/*|*/node_modules/*|*/.next/*|*/build/*) return 0 ;;
    *) return 1 ;;
  esac
}
