#!/bin/bash
# post-task-reminder.sh - Stop
#
# Borra la bandera del vault para que el gate vuelva a frenar en la proxima
# sesion, y recuerda que el workflow NO termina en commit.
#
# La ruta sale de _comun.sh: es LA MISMA VARIABLE que lee vault-precheck.sh.
# Ver el comentario de _comun.sh para por que esto importa tanto.
#
# Sale 0 siempre: un Stop hook que sale distinto de 0 impide terminar el turno.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/_comun.sh"

rm -f "$BANDERA_VAULT" 2>/dev/null

cat << 'EOF'
Antes de dar la tarea por cerrada:

  1. docs/vault/ actualizado? Si cambio una decision, va al ADR, no al _index.
  2. Lo que escribiste, se puede ABRIR? (grepea quien lo usa, no si existe)
  3. Cuando digas que algo funciona, deci COMO lo verificaste.
     Un job verde no prueba que compilo; el artifact si.
  4. Commitear NO es entregar. Un cambio commiteado sigue sin estar en
     produccion hasta que corra el deploy Y se verifique.

EOF
exit 0
