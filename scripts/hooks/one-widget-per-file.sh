#!/bin/bash
# one-widget-per-file.sh - HARD (PostToolUse)
#
# Un widget publico por archivo.
#
# Es lo que hace posible la composicion bottom-up: si un archivo puede tener
# tres widgets, "partir" un widget grande se hace con metodos privados y no se
# parte nada. Junto con widget-size-guard cierran los dos caminos.
#
# Las clases privadas (_FooState, _Fila) NO cuentan: _FooState extends
# State<Foo> es el patron normal de un StatefulWidget.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/_comun.sh"

RUTA=$(leer_ruta "$(cat)")
[ -z "$RUTA" ] && exit 0
[ -f "$RUTA" ] || exit 0
es_generado "$RUTA" && exit 0
case "$RUTA" in */apps/admin/lib/*.dart) ;; *) exit 0 ;; esac
case "$RUTA" in */test/*|*_test.dart) exit 0 ;; esac

PUBLICOS=$(grep -cE "^class [A-Z][A-Za-z0-9_]* extends (StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget|HookWidget|HookConsumerWidget)\b" "$RUTA")
[ "$PUBLICOS" -le 1 ] && exit 0

NOMBRES=$(grep -oE "^class [A-Z][A-Za-z0-9_]* extends (StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget|HookWidget|HookConsumerWidget)\b" "$RUTA" | awk '{print $2}' | tr '\n' ' ')

bloquear "$RUTA declara $PUBLICOS widgets publicos: $NOMBRES" \
  "" \
  "Uno por archivo. Cada widget a su propio archivo, y este los compone." \
  "" \
  "Las clases privadas (_FooState, _Fila) no cuentan y no hace falta sacarlas."
