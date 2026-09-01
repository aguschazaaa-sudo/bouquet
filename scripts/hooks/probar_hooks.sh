#!/bin/bash
# probar_hooks.sh - verifica que cada hook mide lo que dice medir.
#
# ===========================================================================
# POR QUE ESTE ARCHIVO EXISTE
#
# En PadelPunilla el gate del vault era un NO-OP y nadie lo noto durante
# meses: el PreToolUse leia una ruta y el Stop borraba otra, asi que se
# desbloqueo una vez y no volvio a frenar nunca. Era el hook mas caro del
# sistema y el unico que no medi­a nada.
#
# La leccion no es "revisa los hooks". Es que una verificacion que no se
# puede correr no se corre. Asi que se corre acá, y en CI.
#
# CADA CASO TIENE SU PAR (LECCIONES 2.4):
#   - control positivo: algo que TIENE que bloquear
#   - control negativo: algo parecido que TIENE que pasar
#
# Sin el negativo, un hook roto que bloquea todo pasaria por hook que anda.
# ===========================================================================

set -u
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
HOOKS="scripts/hooks"

TMP="$(pwd)/.tmp-pruebas-hooks"
rm -rf "$TMP"
export CLAUDE_PROJECT_DIR="$TMP"

OK=0
FALLOS=0

# fixture <ruta-relativa> <linea...>
fixture() {
  local rel="$1"; shift
  mkdir -p "$TMP/$(dirname "$rel")"
  printf '%s\n' "$@" > "$TMP/$rel"
  printf '%s/%s' "$TMP" "$rel"
}

# fixture_lineas <ruta-relativa> <n>  - un archivo de exactamente n lineas.
# Va aparte de fixture() a proposito: pasarle $(for ...) por argumentos hace
# que bash separe por espacios y "// linea 1" se convierta en tres lineas.
# Un fixture de 197 lineas que en realidad tiene 591 haria pasar el test por
# el motivo equivocado, que es peor que un rojo.
fixture_lineas() {
  local rel="$1" n="$2" i
  mkdir -p "$TMP/$(dirname "$rel")"
  : > "$TMP/$rel"
  for i in $(seq 1 "$n"); do printf '// linea %s\n' "$i" >> "$TMP/$rel"; done
  printf '%s/%s' "$TMP" "$rel"
}

# correr <hook> <ruta>  -> imprime salida, devuelve exit code
correr() {
  printf '{"tool_input":{"file_path":"%s"}}' "$2" | bash "$HOOKS/$1" 2>&1
}
codigo() {
  printf '{"tool_input":{"file_path":"%s"}}' "$2" | bash "$HOOKS/$1" >/dev/null 2>&1
  echo $?
}

# esperar <esperado> <hook> <ruta> <descripcion>
esperar() {
  local esp="$1" hook="$2" ruta="$3" desc="$4"
  local got; got=$(codigo "$hook" "$ruta")
  if [ "$got" = "$esp" ]; then
    printf '  ok    %-22s %s\n' "$hook" "$desc"
    OK=$((OK+1))
  else
    printf '  FALLO %-22s %s  (esperaba exit %s, dio %s)\n' "$hook" "$desc" "$esp" "$got"
    FALLOS=$((FALLOS+1))
  fi
}

# esperar_texto <patron> <hook> <ruta> <descripcion>
esperar_texto() {
  local pat="$1" hook="$2" ruta="$3" desc="$4"
  if correr "$hook" "$ruta" | grep -q "$pat"; then
    printf '  ok    %-22s %s\n' "$hook" "$desc"
    OK=$((OK+1))
  else
    printf '  FALLO %-22s %s  (no dijo "%s")\n' "$hook" "$desc" "$pat"
    FALLOS=$((FALLOS+1))
  fi
}

# esperar_sin_texto <patron> <hook> <ruta> <descripcion>
esperar_sin_texto() {
  local pat="$1" hook="$2" ruta="$3" desc="$4"
  if correr "$hook" "$ruta" | grep -q "$pat"; then
    printf '  FALLO %-22s %s  (dijo "%s" y no debia)\n' "$hook" "$desc" "$pat"
    FALLOS=$((FALLOS+1))
  else
    printf '  ok    %-22s %s\n' "$hook" "$desc"
    OK=$((OK+1))
  fi
}

echo "=== widget-size-guard (limite 200) ==="
GRANDE=$(fixture_lineas "apps/admin/lib/features/catalogo/presentation/grande.dart" 210)
CHICO=$(fixture_lineas "apps/admin/lib/features/catalogo/presentation/chico.dart" 197)
LIMITE=$(fixture_lineas "apps/admin/lib/features/catalogo/presentation/justo.dart" 200)
esperar 2 widget-size-guard.sh "$GRANDE" "210 lineas bloquea"
esperar 0 widget-size-guard.sh "$CHICO"  "197 lineas pasa"
esperar 0 widget-size-guard.sh "$LIMITE" "200 lineas justas pasan (el limite es > 200)"
TEST_GRANDE=$(fixture_lineas "apps/admin/test/features/grande_test.dart" 210)
esperar 0 widget-size-guard.sh "$TEST_GRANDE" "210 lineas en test/ pasa"

echo "=== layer-boundary ==="
D1=$(fixture "apps/admin/lib/features/orden/domain/orden.dart" \
  "import 'package:cloud_firestore/cloud_firestore.dart';" "class Orden {}")
D2=$(fixture "apps/admin/lib/features/orden/domain/puro.dart" \
  "import 'package:meta/meta.dart';" "class Orden {}")
esperar 2 layer-boundary.sh "$D1" "domain con Firestore bloquea"
esperar 0 layer-boundary.sh "$D2" "domain puro pasa"
P1=$(fixture "apps/admin/lib/features/orden/presentation/lista.dart" \
  "import '../data/orden_repository.dart';" "class Lista {}")
esperar 2 layer-boundary.sh "$P1" "presentation -> data bloquea"
P2=$(fixture "apps/admin/lib/features/orden/presentation/tile.dart" \
  "import 'package:cloud_firestore/cloud_firestore.dart';" "class Tile {}")
esperar 2 layer-boundary.sh "$P2" "presentation con SDK bloquea (regla 4, la que faltaba)"
P3=$(fixture "apps/admin/lib/features/orden/presentation/ok.dart" \
  "import 'package:flutter/material.dart';" "class Ok {}")
esperar 0 layer-boundary.sh "$P3" "presentation con Flutter pasa"

echo "=== server-only-guard ==="
S1=$(fixture "apps/tienda/src/components/Grilla.tsx" \
  "import { getFirestore } from 'firebase-admin/firestore';" "export function Grilla() {}")
esperar 2 server-only-guard.sh "$S1" "firebase-admin en components bloquea"
S2=$(fixture "apps/tienda/src/server/catalogo.ts" \
  "import { getFirestore } from 'firebase-admin/firestore';" "export async function leer() {}")
esperar 0 server-only-guard.sh "$S2" "firebase-admin en src/server pasa"
S3=$(fixture "apps/tienda/src/server/malo.ts" "'use client'" "export const x = 1;")
esperar 2 server-only-guard.sh "$S3" "'use client' dentro de src/server bloquea"
S4=$(fixture "apps/tienda/src/components/Carrito.tsx" \
  "'use client'" "import { leer } from '@/server/catalogo';" "export function Carrito() {}")
esperar 2 server-only-guard.sh "$S4" "cliente importando src/server bloquea"
S5=$(fixture "apps/tienda/src/lib/pago.ts" \
  "const k = process.env.NEXT_PUBLIC_MP_SECRET;" "export const k2 = k;")
esperar 2 server-only-guard.sh "$S5" "NEXT_PUBLIC_*_SECRET bloquea"
S6=$(fixture "apps/tienda/src/lib/firebase.ts" \
  "const k = process.env.NEXT_PUBLIC_FIREBASE_API_KEY;" "export const k2 = k;")
esperar 0 server-only-guard.sh "$S6" "NEXT_PUBLIC_FIREBASE_API_KEY pasa (es publica de verdad)"

echo "=== one-widget-per-file ==="
W1=$(fixture "apps/admin/lib/features/orden/presentation/dos.dart" \
  "class Uno extends StatelessWidget {}" "class Dos extends StatelessWidget {}")
esperar 2 one-widget-per-file.sh "$W1" "dos widgets publicos bloquea"
W2=$(fixture "apps/admin/lib/features/orden/presentation/uno.dart" \
  "class Uno extends StatefulWidget {}" "class _UnoState extends State<Uno> {}")
esperar 0 one-widget-per-file.sh "$W2" "widget + _State privado pasa"

echo "=== no-hardcoded-colors ==="
C1=$(fixture "apps/admin/lib/features/orden/presentation/color.dart" \
  "final c = Colors.grey;")
esperar 2 no-hardcoded-colors.sh "$C1" "Colors.grey bloquea (sin excepcion para grises)"
C2=$(fixture "apps/admin/lib/theme/colores.dart" "final c = Color(0xFF112233);")
esperar 0 no-hardcoded-colors.sh "$C2" "literal dentro de theme/ pasa"
C3=$(fixture "apps/tienda/src/components/Boton.tsx" "const s = { color: '#1a2b3c' };")
esperar 2 no-hardcoded-colors.sh "$C3" "hex en la tienda bloquea"
C4=$(fixture "apps/tienda/src/components/Nav.tsx" "const l = <a href=\"#abc\">ir</a>;")
esperar 0 no-hardcoded-colors.sh "$C4" "href=\"#abc\" pasa (falso positivo descartado)"

echo "=== vault-precheck (el que en PadelPunilla era un no-op) ==="
V1=$(fixture "apps/admin/lib/features/orden/presentation/nueva.dart" "class Nueva {}")
VDOC=$(fixture "docs/vault/_index.md" "# doc")
rm -f "$TMP/.claude/.vault-session-ok"
esperar 2 vault-precheck.sh "$V1"   "sin bandera, codigo bloquea"
esperar 0 vault-precheck.sh "$VDOC" "sin bandera, docs pasan"
mkdir -p "$TMP/.claude" && echo ok > "$TMP/.claude/.vault-session-ok"
esperar 0 vault-precheck.sh "$V1"   "con bandera, codigo pasa"
bash "$HOOKS/post-task-reminder.sh" >/dev/null 2>&1
if [ -f "$TMP/.claude/.vault-session-ok" ]; then
  printf '  FALLO %-22s %s\n' "post-task-reminder.sh" "el Stop NO borro la bandera que lee el PreToolUse"
  FALLOS=$((FALLOS+1))
else
  printf '  ok    %-22s %s\n' "post-task-reminder.sh" "el Stop borra LA MISMA ruta que lee el PreToolUse"
  OK=$((OK+1))
fi
esperar 2 vault-precheck.sh "$V1" "despues del Stop, vuelve a bloquear"

echo "=== call-site-guard (SOFT: avisa, no bloquea) ==="
H1=$(fixture "apps/admin/lib/features/orden/presentation/huerfano.dart" \
  "class SheetHuerfano extends StatelessWidget {}")
esperar 0 call-site-guard.sh "$H1" "sale 0 aunque este huerfano"
esperar_texto "AVISO" call-site-guard.sh "$H1" "avisa que nadie lo referencia"
fixture "apps/admin/lib/features/orden/presentation/usa.dart" \
  "import 'huerfano.dart';" "final x = SheetHuerfano();" > /dev/null
esperar_sin_texto "AVISO" call-site-guard.sh "$H1" "calla cuando alguien si lo usa"

echo "=== extraccion de ruta en formato Windows ==="
WIN=$(printf '%s' "$GRANDE" | sed 's#/#\\\\#g')
GOT=$(printf '{"tool_input":{"file_path":"%s"}}' "$WIN" | bash "$HOOKS/widget-size-guard.sh" >/dev/null 2>&1; echo $?)
if [ "$GOT" = "2" ]; then
  printf '  ok    %-22s %s\n' "_comun.sh" "ruta con backslashes se normaliza y bloquea igual"
  OK=$((OK+1))
else
  printf '  FALLO %-22s %s  (dio %s)\n' "_comun.sh" "ruta con backslashes" "$GOT"
  FALLOS=$((FALLOS+1))
fi

rm -rf "$TMP"
echo
echo "-------------------------------------------"
printf 'ok: %s   fallos: %s\n' "$OK" "$FALLOS"
[ "$FALLOS" -eq 0 ] || exit 1
echo "Todos los hooks miden lo que dicen medir."
