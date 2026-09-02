#!/usr/bin/env bash
# Restaura las skills de terceros declaradas en skills-lock.json.
#
# POR QUE EXISTE (no revertir):
# `.agents/skills/` y `.claude/skills/` estan en .gitignore a proposito
# (SKILLS-AGENTES-MCP.md §3.5: una skill del ecosistema copiada al repo queda
# congelada y no se actualiza nunca). El lockfile es la declaracion.
#
# Y `npx skills experimental_install` NO alcanza solo: medido el 2026-09-02,
# restaura `.agents/skills/` pero NO recrea los symlinks de `.claude/skills/`,
# que son los que Claude Code lee. Un clon quedaria con las skills en disco e
# invisibles para el agente. Este script cierra ese hueco.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f skills-lock.json ] || { echo "FALTA skills-lock.json"; exit 1; }

echo "==> 1/3  restaurando contenido desde skills-lock.json"
npx --yes skills experimental_install

echo "==> 2/3  recreando los symlinks que Claude Code lee"
mkdir -p .claude/skills
creados=0
for dir in .agents/skills/*/; do
  [ -d "$dir" ] || continue
  nombre="$(basename "$dir")"
  destino=".claude/skills/$nombre"
  [ -e "$destino" ] && continue
  ln -s "../../.agents/skills/$nombre" "$destino"
  creados=$((creados + 1))
done
echo "    symlinks creados: $creados"

echo "==> 3/3  verificando"
declaradas=$(grep -cE '^\s{4}"[a-z0-9-]+": \{' skills-lock.json)
enlazadas=$(ls .claude/skills 2>/dev/null | wc -l)
echo "    declaradas en el lock: $declaradas"
echo "    enlazadas y legibles:  $enlazadas"

# control positivo: una skill que TIENE que estar y su SKILL.md tiene que leerse
if [ ! -r .claude/skills/openspec-propose/SKILL.md ]; then
  echo "FALLO: el control positivo (openspec-propose/SKILL.md) no se puede leer"
  exit 1
fi
# control negativo: algo que NO tiene que existir
if [ -e .claude/skills/skill-que-no-existe ]; then
  echo "FALLO: el control negativo existe — la verificacion no mide nada"
  exit 1
fi

[ "$declaradas" -eq "$enlazadas" ] || {
  echo "FALLO: $declaradas declaradas != $enlazadas enlazadas"; exit 1; }
echo "OK — $enlazadas skills restauradas y verificadas"
