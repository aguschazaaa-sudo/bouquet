#!/usr/bin/env bash
# verificar_release.sh - contesta "que hay REALMENTE en produccion",
# no de que color pinto el job.
#
# ===========================================================================
# POR QUE EXISTE ESTE ARCHIVO
#
# WORKFLOWS.md linea 237 -paso 9 del Workflow A, paso 7 de B y D- invocaba
# ./scripts/verificar_release.sh y el archivo NO EXISTIA. Un paso de
# verificacion que apunta a un script inexistente es la peor version del
# problema: falla justo cuando mas se lo necesita, que es despues de un
# deploy.
#
# Es la version automatizable del agente .claude/agents/auditor-produccion.md
# y hace cumplir, comprobacion por comprobacion, la tabla de CLAUDE.md
# "Verificacion - no le creas al color":
#
#   NO PRUEBA NADA            LO QUE SI PRUEBA
#   un job verde              el artifact
#   Deploy: success           la lista de jobs - "skipped" CUENTA como falla
#   gh run watch exit 0       devuelve 0 en corridas CANCELADAS
#   un HTTP 200               el hash del contenido
#   un indice READY           correr la query
#   que la clase exista       grepear quien la abre
#
# LOS DOS CONTROLES SON OBLIGATORIOS Y ESTAN ADENTRO DEL SCRIPT:
#   - POSITIVO: --canario <string>, algo que TIENE que aparecer. Sin el, una
#     respuesta vacia por error de lectura confirma cualquier cosa.
#   - NEGATIVO: se le pide al mismo servidor una ruta INVENTADA. Si esa ruta
#     tambien devuelve 200, la verificacion no esta midiendo nada y el script
#     falla diciendolo con todas las letras.
#
# LO QUE ESTE SCRIPT NO HACE, A PROPOSITO:
#   no despliega, no corre "firebase deploy" -denegado en el harness-, no
#   hace "git push", no escribe nada en el repo. Solo lee y compara.
# ===========================================================================

set -euo pipefail

SEP=$(printf '\037')
OK=0
FALLOS=0
IMPOSIBLES=0
RESUMEN=()

TMP=""
limpiar() { if [ -n "${TMP:-}" ]; then rm -rf "$TMP"; fi; }
trap limpiar EXIT

# --------------------------------------------------------------- presentacion
titulo()   { printf '\n=== %s ===\n' "$1"; }
cmd()      { printf '  $ %s\n' "$1"; }
ok_l()     { printf '  ok     %s\n' "$1"; OK=$((OK+1)); }
falla()    { printf '  FALLO  %s\n' "$1"; FALLOS=$((FALLOS+1)); }
aviso()    { printf '  AVISO  %s\n' "$1"; }
detalle()  { local l; for l in "$@"; do printf '         %s\n' "$l"; done; }
imposible(){ printf '  NO SE PUDO VERIFICAR  %s\n' "$1"; IMPOSIBLES=$((IMPOSIBLES+1)); }

# anotar <estado> <que> <comando> <que devolvio>
anotar() { RESUMEN+=("$1$SEP$2$SEP$3$SEP$4"); }

# necesita <herramienta> <para que>  -> 1 si falta, y lo dice
necesita() {
  if command -v "$1" >/dev/null 2>&1; then return 0; fi
  imposible "falta la herramienta '$1', que es la que $2"
  detalle "Instalala y volve a correr. NO se sigue en silencio: un 'no pude'" \
          "no es un 'esta bien'."
  anotar "NO-VERIF" "$2" "command -v $1" "no instalado"
  return 1
}

hash_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 "$1" | awk '{print $NF}'
  else return 1
  fi
}

# origen_de <url> -> esquema://host[:puerto]
origen_de() {
  printf '%s' "$1" | sed -E 's#^([a-zA-Z][a-zA-Z0-9+.-]*://[^/?#]+).*#\1#'
}

# sin_color: saca los codigos ANSI. El CLI de firebase los emite siempre y
# ensucian tanto la salida como el informe final.
sin_color() { sed "s/$(printf '\033')\[[0-9;]*m//g"; }

# primer_dicho: la primera linea CON CONTENIDO. Un "head -1" a secas se comia
# el mensaje de error cuando la herramienta abria con una linea en blanco, y
# el informe terminaba diciendo "salio 1: " sin el motivo.
primer_dicho() { sin_color | grep -m1 . || true; }

# --------------------------------------------------------------------- ayuda
uso() {
  cat <<'AYUDA'
verificar_release.sh - verifica que hay REALMENTE en produccion.

USO
  scripts/verificar_release.sh [opciones]

QUE VERIFICAR (hace falta al menos una)
  --run <id>        una corrida de GitHub Actions: conclusion + LA LISTA DE
                    JOBS. Un job "skipped" se reporta como FALLA, no como
                    exito, porque un deploy que no corrio no desplego.
  --url <url>       un front desplegado: baja el contenido y muestra su HASH
                    sha256. El codigo HTTP se informa pero NO es la prueba.
  --functions       las Cloud Functions desplegadas (firebase functions:list).
  --todo            las tres. Si no pasas --run, resuelve la ultima corrida
                    con "gh run list" y dice cual eligio. --url sigue siendo
                    obligatorio: el script no adivina la URL de produccion.

LOS DOS CONTROLES (CLAUDE.md: toda verificacion necesita los dos)
  --canario <str>   CONTROL POSITIVO, repetible. El canario que APARECE: un
                    string que TIENE que estar en el contenido de --url.
                    Ademas se comprueba que sea DISCRIMINANTE: si tambien
                    aparece en la respuesta de la ruta inventada, no distingue
                    nada y falla.
  --canario-ausente <str>
                    El canario que DESAPARECE, repetible. Un string del
                    release VIEJO que ya NO tiene que aparecer. Sin este, un
                    deploy a medias -lo nuevo agregado y lo viejo todavia
                    servido- pasa como exito.
  --funcion <nom>   CONTROL POSITIVO de --functions, repetible. Un nombre que
                    TIENE que estar en la lista.
  --ruta-falsa <p>  CONTROL NEGATIVO. Ruta inventada que se le pide al mismo
                    host y que NO puede devolver 200. Por defecto se genera
                    una al azar. Si devuelve 200, el script FALLA: quiere
                    decir que la verificacion no esta midiendo nada.

OTRAS
  --sin-cache-buster
                    Por defecto se le agrega ?cb=<azar> a la url para saltear
                    el cache del CDN: sin eso podes estar hasheando el release
                    ANTERIOR y darlo por bueno. Usa esta opcion si el host se
                    porta mal con query strings.
  -h, --help        esto.

CODIGOS DE SALIDA
  0   todo lo que se pidio verificar dio evidencia positiva.
  1   algo NO verifico: un job skipped o cancelado, un canario que no
      aparece, una ruta inventada que devuelve 200, una function que falta.
  2   no se pudo verificar: faltan argumentos, o falta gh / firebase / curl.
      NO es un exito.

LO QUE ESTE SCRIPT NO HACE
  No despliega. No corre "firebase deploy" ni "git push". No escribe en el
  repo. Y no usa "gh run watch --exit-status" como prueba: ese comando
  devuelve 0 en corridas CANCELADAS.

EJEMPLOS
  scripts/verificar_release.sh --url https://example.com --canario "Example Domain"
  scripts/verificar_release.sh --run 1234567890
  scripts/verificar_release.sh --functions --funcion alOrdenEscrita
  scripts/verificar_release.sh --url https://tienda.example \
      --canario "Malbec 2021" --canario-ausente "Malbec 2020"
  scripts/verificar_release.sh --todo --url https://tienda.example --canario "Malbec 2021"
AYUDA
}

# ------------------------------------------------------------------ argumentos
RUN_ID=""
URL=""
HACER_FUNCTIONS=0
HACER_TODO=0
RUTA_FALSA=""
CACHE_BUSTER=1
CANARIOS=()
AUSENTES=()
FUNCIONES=()

if [ "$#" -eq 0 ]; then
  uso
  printf '\n'
  printf 'NO SE VERIFICO NADA: no pasaste que verificar.\n'
  printf 'Elegi --run, --url, --functions o --todo. Salgo con 2 a proposito:\n'
  printf 'un script de verificacion que sale 0 sin verificar nada es peor que\n'
  printf 'no tener script.\n'
  exit 2
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)     uso; exit 0 ;;
    --run)         RUN_ID="${2:-}"; shift 2 || true ;;
    --url)         URL="${2:-}"; shift 2 || true ;;
    --functions)   HACER_FUNCTIONS=1; shift ;;
    --todo)        HACER_TODO=1; HACER_FUNCTIONS=1; shift ;;
    --canario)     CANARIOS+=("${2:-}"); shift 2 || true ;;
    --canario-ausente) AUSENTES+=("${2:-}"); shift 2 || true ;;
    --funcion)     FUNCIONES+=("${2:-}"); shift 2 || true ;;
    --ruta-falsa)  RUTA_FALSA="${2:-}"; shift 2 || true ;;
    --sin-cache-buster) CACHE_BUSTER=0; shift ;;
    *)
      printf 'Opcion desconocida: %s\n\n' "$1" >&2
      uso >&2
      exit 2
      ;;
  esac
done

if [ "$HACER_TODO" -eq 1 ] && [ -z "$URL" ]; then
  printf 'NO SE VERIFICO NADA: --todo necesita tambien --url <url>.\n' >&2
  printf 'El script no adivina cual es la URL de produccion, y adivinarla seria\n' >&2
  printf 'justo el tipo de suposicion que esta verificacion existe para eliminar.\n' >&2
  exit 2
fi

if [ -z "$RUN_ID" ] && [ -z "$URL" ] && [ "$HACER_FUNCTIONS" -eq 0 ]; then
  printf 'NO SE VERIFICO NADA: falta que verificar.\n' >&2
  printf 'Elegi --run <id>, --url <url>, --functions o --todo.\n' >&2
  exit 2
fi

TMP=$(mktemp -d 2>/dev/null || printf '%s' "${TMPDIR:-/tmp}/verificar-release-$$")
mkdir -p "$TMP"

printf '===========================================================\n'
printf 'verificar_release.sh - evidencia, no colores\n'
printf 'fecha: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
printf '===========================================================\n'

# ============================================================================
# CORRIDA DE GITHUB ACTIONS
# ============================================================================
verificar_corrida() {
  local id="$1"
  titulo "CORRIDA $id - GitHub Actions"
  necesita gh "lee las corridas de GitHub Actions" || return 1

  printf '  (NO se usa "gh run watch --exit-status" como prueba:\n'
  printf '   ese comando devuelve 0 en corridas CANCELADAS)\n'

  local comando="gh run view $id --json conclusion,status,jobs"
  cmd "$comando"

  local salida cod=0
  salida=$(gh run view "$id" --json conclusion,status,jobs --jq '
      "META\t\(.status // "?")\t\(.conclusion // "sin-conclusion")",
      (.jobs[]? | "JOB\t\(.conclusion // "sin-conclusion")\t\(.status // "?")\t\(.name)")
    ' 2>&1) || cod=$?

  if [ "$cod" -ne 0 ]; then
    imposible "gh no pudo leer la corrida $id"
    printf '%s\n' "$salida" | sed 's/^/         /'
    anotar "NO-VERIF" "corrida $id" "$comando" "gh salio $cod: $(printf '%s\n' "$salida" | primer_dicho)"
    return 1
  fi

  local estado="?" conclusion="sin-conclusion"
  local n_jobs=0 n_ok=0 n_skip=0 n_mal=0
  local tipo c s n
  while IFS=$'\t' read -r tipo c s n; do
    [ -z "${tipo:-}" ] && continue
    if [ "$tipo" = "META" ]; then
      estado="$c"; conclusion="$s"; continue
    fi
    n_jobs=$((n_jobs+1))
    case "$c" in
      success)  n_ok=$((n_ok+1));     printf '         job  ok       %s\n' "$n" ;;
      skipped)  n_skip=$((n_skip+1)); printf '         job  SKIPPED  %s\n' "$n" ;;
      *)        n_mal=$((n_mal+1));   printf '         job  %-8s %s (status %s)\n' "$c" "$n" "$s" ;;
    esac
  done <<<"$salida"

  printf '  status=%s  conclusion=%s  jobs=%s (ok=%s skipped=%s otros=%s)\n' \
         "$estado" "$conclusion" "$n_jobs" "$n_ok" "$n_skip" "$n_mal"

  local resultado="status=$estado conclusion=$conclusion; $n_jobs jobs: $n_ok ok, $n_skip SKIPPED, $n_mal otros"
  local malo=0

  # CONTROL POSITIVO de esta comprobacion: tiene que haber jobs.
  if [ "$n_jobs" -eq 0 ]; then
    falla "la corrida no lista NI UN job"
    detalle "Sin control positivo, una lista vacia por error de lectura confirma" \
            "cualquier cosa. Una corrida sin jobs no es una corrida ok."
    malo=1
  fi

  case "$conclusion" in
    success) ;;
    cancelled)
      falla "la corrida esta CANCELADA"
      detalle "Ojo con la trampa: 'gh run watch --exit-status' devuelve 0 aca." \
              "Por eso esta comprobacion mira conclusion y jobs, no un exit code."
      malo=1
      ;;
    *)
      falla "conclusion = $conclusion (no es success)"
      malo=1
      ;;
  esac

  if [ "$n_skip" -gt 0 ]; then
    falla "$n_skip job(s) SKIPPED - eso CUENTA como falla, no como exito"
    detalle "'Deploy: success' con el job de deploy en skipped es un deploy que" \
            "no ocurrio. El verde de arriba lo tapa; la lista de jobs no."
    malo=1
  fi
  if [ "$n_mal" -gt 0 ]; then
    falla "$n_mal job(s) que no terminaron en success"
    malo=1
  fi
  if [ "$malo" -eq 0 ]; then
    ok_l "conclusion success y $n_jobs job(s), ninguno skipped"
  fi

  # LO QUE SI PRUEBA UN JOB VERDE: el artifact. Informativo, no bloquea.
  local artef cmd_art="gh api repos/{owner}/{repo}/actions/runs/$id/artifacts"
  cmd "$cmd_art"
  local cod_art=0
  artef=$(gh api "repos/{owner}/{repo}/actions/runs/$id/artifacts" \
            --jq '.artifacts[]? | "\(.name)\t\(.size_in_bytes) bytes\texpirado=\(.expired)"' 2>&1) || cod_art=$?
  if [ "$cod_art" -ne 0 ]; then
    aviso "no pude listar artifacts: $(printf '%s\n' "$artef" | primer_dicho)"
  elif [ -z "$artef" ]; then
    aviso "la corrida no dejo NINGUN artifact"
    detalle "Un job verde sin artifact no prueba que se haya construido algo." \
            "Si esta corrida tenia que empaquetar, esto es una falla de verdad."
  else
    printf '%s\n' "$artef" | sed 's/^/         artifact  /'
    resultado="$resultado; artifacts: $(printf '%s\n' "$artef" | grep -c . || true)"
  fi

  if [ "$malo" -eq 0 ]; then anotar "OK" "corrida $id" "$comando" "$resultado"
  else anotar "FALLO" "corrida $id" "$comando" "$resultado"; fi
  [ "$malo" -eq 0 ]
}

# ============================================================================
# FRONT DESPLEGADO
# ============================================================================
verificar_url() {
  local url="$1"
  titulo "FRONT DESPLEGADO - $url"
  necesita curl "trae el contenido publicado" || return 1

  case "$url" in
    http://*|https://*) ;;
    *)
      imposible "la url tiene que empezar con http:// o https:// (llego: $url)"
      anotar "NO-VERIF" "front $url" "-" "url mal formada"
      return 1
      ;;
  esac

  local cuerpo="$TMP/cuerpo.html" err="$TMP/curl.err" codigo="" malo=0

  # CACHE-BUSTER: sin esto el CDN te puede servir el release ANTERIOR y vos
  # hasheas eso, contento. SETUP-PRIMERA-CORRIDA §5.3 lo lista entre las tres
  # cosas que siempre se olvidan.
  local url_pedida="$url" cb=""
  if [ "$CACHE_BUSTER" -eq 1 ]; then
    cb="cb=$(date +%s)-${RANDOM}"
    case "$url" in
      *\?*) url_pedida="$url&$cb" ;;
      *)    url_pedida="$url?$cb" ;;
    esac
  fi

  local comando="curl -sS -L --max-time 30 -o <archivo> -w '%{http_code}' $url_pedida"
  cmd "$comando"
  local cod=0
  codigo=$(curl -sS -L --max-time 30 -o "$cuerpo" -w '%{http_code}' "$url_pedida" 2>"$err") || cod=$?
  if [ "$cod" -ne 0 ]; then
    imposible "curl no pudo traer $url"
    sed 's/^/         /' "$err" 2>/dev/null || true
    anotar "NO-VERIF" "front $url" "$comando" "curl salio $cod: $(primer_dicho < "$err" 2>/dev/null)"
    return 1
  fi

  local bytes hash titulo_html
  bytes=$(wc -c < "$cuerpo" | tr -d ' ')
  if ! hash=$(hash_sha256 "$cuerpo"); then
    imposible "no encontre sha256sum, shasum ni openssl para hashear el contenido"
    anotar "NO-VERIF" "front $url" "$comando" "sin herramienta de hash"
    return 1
  fi
  titulo_html=$(sed -n 's/.*<title[^>]*>\([^<]*\)<\/title>.*/\1/p' "$cuerpo" | head -1)

  if [ "$CACHE_BUSTER" -eq 1 ]; then
    printf '  cache-buster: si (%s). Sin el, podes estar hasheando el release viejo.\n' "$cb"
  else
    printf '  cache-buster: NO (--sin-cache-buster). Si hay CDN adelante, este hash\n'
    printf '                puede ser el del release ANTERIOR.\n'
  fi
  printf '  http %s   <- informativo: un 200 NO prueba nada\n' "$codigo"
  printf '  bytes  : %s\n' "$bytes"
  printf '  sha256 : %s   <- ESTA es la evidencia\n' "$hash"
  if [ -n "$titulo_html" ]; then printf '  <title>: %s\n' "$titulo_html"; fi

  if [ "$codigo" != "200" ]; then
    falla "la url de produccion devolvio $codigo, no 200"
    malo=1
  fi
  if [ "$bytes" -eq 0 ]; then
    falla "el cuerpo vino VACIO: no hay nada que hashear ni que comparar"
    malo=1
  fi

  # ---------------------------------------------------- CONTROL NEGATIVO
  local origen ruta_falsa url_falsa cuerpo_falso="$TMP/cuerpo_falso.html" cod_falso=""
  origen=$(origen_de "$url")
  if [ -n "$RUTA_FALSA" ]; then
    ruta_falsa="$RUTA_FALSA"
  else
    ruta_falsa="no-existe-verificar-release-$(date +%s)-${RANDOM}"
  fi
  url_falsa="$origen/${ruta_falsa#/}"
  if [ "$CACHE_BUSTER" -eq 1 ]; then
    case "$url_falsa" in
      *\?*) url_falsa="$url_falsa&$cb" ;;
      *)    url_falsa="$url_falsa?$cb" ;;
    esac
  fi

  printf '\n  --- CONTROL NEGATIVO (ruta inventada, el mismo curl) ---\n'
  local comando_neg="curl -sS -L --max-time 30 -o <archivo> -w '%{http_code}' $url_falsa"
  cmd "$comando_neg"
  local cod2=0
  cod_falso=$(curl -sS -L --max-time 30 -o "$cuerpo_falso" -w '%{http_code}' "$url_falsa" 2>/dev/null) || cod2=$?
  if [ "$cod2" -ne 0 ] || [ -z "$cod_falso" ] || [ "$cod_falso" = "000" ]; then
    falla "el control negativo no obtuvo respuesta (curl salio $cod2, http '$cod_falso')"
    detalle "El pedido bueno si respondio, asi que esto no es 'el server esta caido':" \
            "es que la comparacion no se pudo hacer. Sin control negativo no se" \
            "puede afirmar que la verificacion discrimine algo."
    malo=1
  elif [ "$cod_falso" = "200" ]; then
    falla "LA RUTA INVENTADA DEVOLVIO 200 - ESTA VERIFICACION NO ESTA MIDIENDO NADA"
    detalle "$url_falsa" \
            "" \
            "El servidor contesta 200 a cualquier cosa: un catch-all, una SPA que" \
            "sirve el index en todas las rutas, o un proxy adelante. Entonces que" \
            "tu url de verdad devuelva 200 no dice absolutamente nada sobre lo que" \
            "se desplego. Verifica por hash y por canario, y arregla el catch-all" \
            "antes de creerle a cualquier chequeo de status contra este host."
    malo=1
  else
    ok_l "la ruta inventada devolvio $cod_falso (no 200): el servidor discrimina"
  fi

  # ---------------------------------------------------- CONTROL POSITIVO
  printf '\n  --- CONTROL POSITIVO (canarios) ---\n'
  if [ "${#CANARIOS[@]}" -eq 0 ]; then
    aviso "no pasaste --canario: esta comprobacion NO tiene control positivo"
    detalle "El hash de arriba prueba que ESTOS bytes se sirvieron. No prueba que" \
            "sean los nuevos. Para eso hace falta un string que antes no estaba." \
            "Volve a correr con: --canario \"algo que solo trae este release\""
  fi
  local c en_bueno en_falso canarios_ok=0
  for c in ${CANARIOS[@]+"${CANARIOS[@]}"}; do
    if [ "${#c}" -lt 3 ]; then
      falla "canario '$c' demasiado corto para ser discriminante (minimo 3 caracteres)"
      malo=1
      continue
    fi
    en_bueno=0
    en_falso=0
    if grep -qF -- "$c" "$cuerpo" 2>/dev/null; then en_bueno=1; fi
    if [ -s "$cuerpo_falso" ] && grep -qF -- "$c" "$cuerpo_falso" 2>/dev/null; then en_falso=1; fi

    if [ "$en_bueno" -eq 0 ]; then
      falla "el canario '$c' NO aparece en el contenido servido"
      detalle "Hash de lo que si se sirvio: $hash" \
              "O el deploy no salio, o salio otra cosa, o el canario esta mal escrito." \
              "Las tres son motivos para no decir que esta verificado."
      malo=1
    elif [ "$en_falso" -eq 1 ]; then
      falla "el canario '$c' aparece TAMBIEN en la ruta inventada: NO ES DISCRIMINANTE"
      detalle "Un string que aparece pase lo que pase no distingue un release del" \
              "anterior ni una pagina de un 404. Elegi uno nuevo de este release."
      malo=1
    else
      ok_l "canario '$c': aparece en el contenido y NO en la ruta inventada"
      canarios_ok=$((canarios_ok + 1))
    fi
  done

  # -------------------------------------- EL CANARIO QUE TIENE QUE DESAPARECER
  # CLAUDE.md: "uno que aparece y otro que desaparece". Sin este, un deploy a
  # medias -lo nuevo agregado y lo viejo todavia servido- pasa como exito.
  if [ "${#AUSENTES[@]}" -gt 0 ]; then
    printf '\n  --- CANARIO QUE TIENE QUE DESAPARECER ---\n'
    if [ "${#CANARIOS[@]}" -eq 0 ]; then
      aviso "pasaste --canario-ausente sin --canario"
      detalle "Un string que no aparece, solo, no distingue 'se actualizo' de" \
              "'me sirvieron una pagina vacia o un 404'. Hacen falta los dos."
    fi
    for c in ${AUSENTES[@]+"${AUSENTES[@]}"}; do
      if [ "${#c}" -lt 3 ]; then
        falla "canario ausente '$c' demasiado corto para significar algo (minimo 3)"
        malo=1
      elif grep -qF -- "$c" "$cuerpo" 2>/dev/null; then
        falla "el canario viejo '$c' TODAVIA aparece: lo anterior sigue publicado"
        detalle "Hash de lo que se sirvio: $hash" \
                "O el deploy no llego, o llego a medias, o el CDN sigue cacheando." \
                "Un release que agrega lo nuevo sin sacar lo viejo no es el release."
        malo=1
      else
        ok_l "canario viejo '$c': ya NO aparece"
      fi
    done
  fi

  local resultado="http=$codigo, $bytes bytes, sha256=$hash; ruta inventada -> http=$cod_falso"
  if [ "${#CANARIOS[@]}" -gt 0 ]; then
    resultado="$resultado; canarios que aparecen: $canarios_ok de ${#CANARIOS[@]}"
  else
    resultado="$resultado; SIN CONTROL POSITIVO (no se paso --canario)"
  fi
  if [ "${#AUSENTES[@]}" -gt 0 ]; then
    resultado="$resultado; canarios que desaparecen: ${#AUSENTES[@]}"
  fi
  if [ "$CACHE_BUSTER" -eq 0 ]; then
    resultado="$resultado; SIN cache-buster"
  fi

  if [ "$malo" -eq 0 ]; then anotar "OK" "front $url" "$comando" "$resultado"
  else anotar "FALLO" "front $url" "$comando" "$resultado"; fi
  [ "$malo" -eq 0 ]
}

# ============================================================================
# CLOUD FUNCTIONS
# ============================================================================
verificar_functions() {
  titulo "CLOUD FUNCTIONS"
  necesita firebase "lista las functions desplegadas" || return 1

  local comando="firebase functions:list"
  cmd "$comando"
  local salida cod=0 malo=0
  salida=$(firebase functions:list 2>&1 | sin_color) || cod=$?

  printf '%s\n' "$salida" | sed 's/^/         /'

  if [ "$cod" -ne 0 ]; then
    imposible "firebase functions:list salio $cod"
    detalle "Causas tipicas: no hay proyecto activo (falta .firebaserc), no hay" \
            "sesion (firebase login), o el proyecto todavia no tiene functions." \
            "Esto NO se reporta como exito: no se sabe que hay en produccion."
    anotar "NO-VERIF" "cloud functions" "$comando" "salio $cod: $(printf '%s\n' "$salida" | primer_dicho)"
    return 1
  fi

  # CONTROL POSITIVO de esta comprobacion: la lista no puede venir vacia.
  local nombres cantidad
  nombres=$(printf '%s\n' "$salida" \
            | sed -n 's/^[^A-Za-z0-9]*\([A-Za-z_][A-Za-z0-9_-]*\).*/\1/p' \
            | grep -viE '^(function|name|version|trigger|location|memory|runtime|id|codebase)$' || true)
  cantidad=$(printf '%s\n' "$nombres" | grep -c . || true)

  if [ "${cantidad:-0}" -eq 0 ]; then
    falla "la lista de functions vino VACIA"
    detalle "Sin control positivo, una lista vacia por error de lectura confirma" \
            "cualquier cosa. Y si de verdad no hay functions desplegadas, entonces" \
            "no hay backend en produccion - que es justo lo que habia que saber."
    malo=1
  else
    ok_l "$cantidad function(s) listada(s) por el servidor"
  fi

  local f
  for f in ${FUNCIONES[@]+"${FUNCIONES[@]}"}; do
    if printf '%s' "$salida" | grep -qF -- "$f"; then
      ok_l "control positivo: la function '$f' esta en la lista"
    else
      falla "la function '$f' NO esta desplegada"
      detalle "Una UI que la llame va a romper en produccion. Functions primero," \
              "front despues: el orden de deploy de CLAUDE.md no es decorativo."
      malo=1
    fi
  done

  local resultado="$cantidad function(s)"
  if [ "${#FUNCIONES[@]}" -gt 0 ]; then
    resultado="$resultado; buscadas por nombre: ${#FUNCIONES[@]}"
  fi
  if [ "$malo" -eq 0 ]; then anotar "OK" "cloud functions" "$comando" "$resultado"
  else anotar "FALLO" "cloud functions" "$comando" "$resultado"; fi
  [ "$malo" -eq 0 ]
}

# ============================================================================
# ORQUESTACION
# ============================================================================
if [ "$HACER_TODO" -eq 1 ] && [ -z "$RUN_ID" ]; then
  titulo "RESOLVIENDO LA ULTIMA CORRIDA (--todo sin --run)"
  if necesita gh "lee las corridas de GitHub Actions"; then
    cmd "gh run list --limit 1 --json databaseId,workflowName,headBranch,conclusion"
    ULTIMA=$(gh run list --limit 1 \
              --json databaseId,workflowName,headBranch,conclusion \
              --jq '.[0] | "\(.databaseId)\t\(.workflowName)\t\(.headBranch)\t\(.conclusion)"' 2>&1) || ULTIMA=""
    RUN_ID=$(printf '%s' "$ULTIMA" | cut -f1)
    if [ -n "$RUN_ID" ] && printf '%s' "$RUN_ID" | grep -qE '^[0-9]+$'; then
      printf '  corrida elegida: %s   (%s / %s / %s)\n' \
             "$RUN_ID" \
             "$(printf '%s' "$ULTIMA" | cut -f2)" \
             "$(printf '%s' "$ULTIMA" | cut -f3)" \
             "$(printf '%s' "$ULTIMA" | cut -f4)"
    else
      RUN_ID=""
      imposible "no pude resolver la ultima corrida con gh run list"
      printf '%s\n' "$ULTIMA" | sed 's/^/         /'
      anotar "NO-VERIF" "ultima corrida" "gh run list --limit 1" "no devolvio un id"
    fi
  fi
fi

if [ -n "$RUN_ID" ]; then verificar_corrida "$RUN_ID" || true; fi
if [ -n "$URL" ]; then verificar_url "$URL" || true; fi
if [ "$HACER_FUNCTIONS" -eq 1 ]; then verificar_functions || true; fi

# ============================================================================
# EL INFORME - que se verifico, CON QUE COMANDO, y que devolvio
# ============================================================================
printf '\n===========================================================\n'
printf 'QUE SE VERIFICO, CON QUE COMANDO, Y QUE DEVOLVIO\n'
printf '===========================================================\n'

if [ "${#RESUMEN[@]}" -eq 0 ]; then
  printf '  (nada: ninguna comprobacion llego a ejecutarse)\n'
else
  for LINEA in ${RESUMEN[@]+"${RESUMEN[@]}"}; do
    IFS="$SEP" read -r E_ESTADO E_QUE E_CMD E_RES <<<"$LINEA"
    printf '\n  [%s] %s\n' "$E_ESTADO" "$E_QUE"
    printf '        comando : %s\n' "$E_CMD"
    printf '        devolvio: %s\n' "$E_RES"
  done
fi

printf '\n-----------------------------------------------------------\n'
printf 'ok: %s   fallos: %s   no verificables: %s\n' "$OK" "$FALLOS" "$IMPOSIBLES"

if [ "$FALLOS" -gt 0 ]; then
  printf 'VEREDICTO: NO PASA - %s comprobacion(es) sin evidencia positiva.\n' "$FALLOS"
  printf 'No lo llames desplegado: llamalo publicado y sin verificar.\n'
  exit 1
fi
if [ "$IMPOSIBLES" -gt 0 ]; then
  printf 'VEREDICTO: NO SE PUDO VERIFICAR - %s comprobacion(es) sin herramienta\n' "$IMPOSIBLES"
  printf 'o sin datos. Un "no pude" no es un "esta bien".\n'
  exit 2
fi
printf 'VEREDICTO: PASA - %s comprobacion(es), con la evidencia de arriba.\n' "$OK"
printf 'Prueba exactamente lo que dice cada linea "devolvio". Nada mas que eso.\n'
exit 0
