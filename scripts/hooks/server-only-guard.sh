#!/bin/bash
# server-only-guard.sh - HARD (PostToolUse)  [NUEVO, no existe en PadelPunilla]
#
# El equivalente exacto de layer-boundary, trasladado al stack nuevo.
#
# En Next.js el modo de falla no es "un widget habla con Firestore": es que la
# service account de Firebase termine en el bundle del cliente. Ahi no hay un
# error ni una pantalla rota - hay credenciales de administrador publicadas en
# un archivo .js que cualquiera baja.
#
# ADR 001: todo acceso a datos vive en apps/tienda/src/server/**.

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
case "$RUTA" in *.ts|*.tsx|*.js|*.jsx|*.mjs) ;; *) exit 0 ;; esac
case "$RUTA" in *.test.*|*.spec.*) exit 0 ;; esac

ES_SERVIDOR=0
case "$RUTA" in */apps/tienda/src/server/*) ES_SERVIDOR=1 ;; esac

TIENE_USE_CLIENT=0
head -5 "$RUTA" | grep -qE "^\s*['\"]use client['\"]" && TIENE_USE_CLIENT=1

# 1. El SDK de administrador solo existe del lado servidor.
if [ "$ES_SERVIDOR" -eq 0 ]; then
  if grep -qE "^\s*import\s+.*['\"]firebase-admin" "$RUTA" \
     || grep -qE "require\(['\"]firebase-admin" "$RUTA"; then
    bloquear "$RUTA importa firebase-admin fuera de src/server/." \
      "" \
      "El SDK de administrador ignora las reglas de Firestore y lleva la" \
      "service account adentro. Si entra en un modulo que el cliente puede" \
      "importar, las credenciales viajan al bundle." \
      "" \
      "Move el acceso a datos a apps/tienda/src/server/ y consumilo desde un" \
      "Server Component o una Server Action."
  fi
fi

# 2. Un archivo de src/server/ no puede ser un componente cliente.
if [ "$ES_SERVIDOR" -eq 1 ] && [ "$TIENE_USE_CLIENT" -eq 1 ]; then
  bloquear "$RUTA esta en src/server/ y declara 'use client'." \
    "" \
    "Eso lo empuja al bundle del navegador junto con todo lo que importe." \
    "O sale de src/server/, o deja de ser un componente cliente."
fi

# 3. Un componente cliente no importa de src/server/.
if [ "$TIENE_USE_CLIENT" -eq 1 ]; then
  if grep -qE "^\s*import\s+.*['\"](@/server/|\.\./server/|\./server/)" "$RUTA"; then
    bloquear "$RUTA es 'use client' y esta importando de src/server/." \
      "" \
      "Aunque solo uses un tipo, el import arrastra el modulo al bundle." \
      "Para tipos usa 'import type'. Para datos, recibilos como props desde" \
      "un Server Component."
  fi
fi

# 4. Los secretos no se nombran con el prefijo publico.
# NEXT_PUBLIC_* se inlinea literalmente en el bundle en tiempo de build.
#
# La lista es corta A PROPOSITO. KEY y TOKEN quedan afuera porque
# NEXT_PUBLIC_FIREBASE_API_KEY es legitimamente publica y bloquearla haria
# que este hook grite en el caso normal. Un hook con falsos positivos se deja
# de mirar, que es el mismo modo de falla que un gate siempre rojo
# (LECCIONES 3.7). Las de abajo no tienen uso publico legitimo.
if grep -qE "NEXT_PUBLIC_[A-Z0-9_]*(PRIVATE|SECRET|CREDENTIAL|PASSWORD|SERVICE_ACCOUNT)" "$RUTA"; then
  bloquear "$RUTA usa una variable NEXT_PUBLIC_ con nombre de secreto." \
    "" \
    "Todo lo que empieza con NEXT_PUBLIC_ se inlinea en el bundle en tiempo" \
    "de build. No es una convencion de nombres: es publicacion." \
    "" \
    "Si el valor es secreto, sacale el prefijo y leelo solo desde src/server/."
fi

exit 0
