#!/bin/bash
# layer-boundary.sh - HARD (PostToolUse)
#
# Cuatro reglas. Las tres primeras son las de PadelPunilla; la CUARTA es el
# agujero real que alla dejo pasar un widget hablando con Firestore DESDE EL
# COMMIT INICIAL, pese a que el agente de presentacion lo prohibia en su texto.
#
# LECCIONES 9.3: lo que no esta en un hook, no esta. Un prompt describe la
# intencion; un hook mide el resultado.
#
# Ojo: agregar la regla 4 va a romper archivos existentes el dia que los haya.
# Eso ES el punto.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/_comun.sh"

RUTA=$(leer_ruta "$(cat)")
[ -z "$RUTA" ] && exit 0
[ -f "$RUTA" ] || exit 0
es_generado "$RUTA" && exit 0
case "$RUTA" in *.dart) ;; *) exit 0 ;; esac
case "$RUTA" in */test/*|*_test.dart) exit 0 ;; esac

# 1. domain es Dart puro: ni Firebase, ni Flutter, ni HTTP.
case "$RUTA" in
  */domain/*)
    if grep -qE "^\s*import\s+'package:(cloud_firestore|firebase_[a-z_]+|cloud_functions|flutter/|http/|dio/)" "$RUTA"; then
      bloquear "$RUTA es domain y no puede importar Firebase, Flutter ni HTTP." \
        "" \
        "domain es Dart puro: entidades, value objects, interfaces de repositorio" \
        "y casos de uso. Si necesita datos, define la interfaz aca y la" \
        "implementacion va en data/."
    fi
    ;;
esac

# 2. data no conoce presentation.
case "$RUTA" in
  */data/*)
    if grep -qE "^\s*import\s+.*/presentation/" "$RUTA"; then
      bloquear "$RUTA es data y esta importando presentation." \
        "" \
        "La dependencia va en un solo sentido: presentation -> domain <- data."
    fi
    ;;
esac

# 3. presentation no conoce data.
# 4. presentation no toca el SDK de Firebase directo.  <-- LA QUE FALTABA
case "$RUTA" in
  */presentation/*)
    if grep -qE "^\s*import\s+.*/data/" "$RUTA"; then
      bloquear "$RUTA es presentation y esta importando data." \
        "" \
        "Pedile al provider, no al repositorio concreto."
    fi
    if grep -qE "^\s*import\s+'package:(cloud_firestore|firebase_storage|firebase_auth|cloud_functions|firebase_core)" "$RUTA"; then
      bloquear "$RUTA usa el SDK de Firebase directo." \
        "" \
        "Va por un repositorio. En PadelPunilla un widget convivio con" \
        "cloud_firestore + firebase_storage desde el commit inicial porque" \
        "esta regla estaba escrita en un prompt y no en un hook." \
        "" \
        "Y el costo no fue teorico: la subida de fotos fallaba en web y el" \
        "bug vivio meses sin un solo reporte (LECCIONES 4.4)."
    fi
    ;;
esac

exit 0
