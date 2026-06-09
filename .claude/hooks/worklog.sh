#!/usr/bin/env bash
# worklog.sh <kind> — registra un evento de trabajo en factory-db.
# kind: 'prompt' (UserPromptSubmit) | 'skill' (PostToolUse matcher=Skill)
# Non-blocking por diseño: cualquier fallo (docker abajo, etc.) -> exit 0, no rompe el flujo.
KIND="${1:-event}"
PAYLOAD="$(cat)"

python3 - "$KIND" "$PAYLOAD" <<'PY' 2>/dev/null || true
import sys, json, subprocess, re

kind = sys.argv[1]
try:
    d = json.loads(sys.argv[2])
except Exception:
    sys.exit(0)

SLUG_RE = re.compile(r'([a-z0-9]+-(?:pull|push|pushin|pushout|espejo))')
actor, role, etype, slug, detail = 'Santi', 'developer', kind, None, None

if kind == 'prompt':
    p = (d.get('prompt') or '').strip().replace('\n', ' ')
    if not p:
        sys.exit(0)
    actor, role, etype, detail = 'Santi', 'developer', 'prompt', p[:140]
    m = SLUG_RE.search(p)
    if m: slug = m.group(1)

elif kind == 'skill':
    ti = d.get('tool_input') or {}
    sk = (ti.get('skill') or '').strip()
    args = (ti.get('args') or '').strip()
    # solo skills del factory cuentan como "trabajo del proceso"
    if not sk.startswith('factory'):
        sys.exit(0)
    detail = (sk + ' ' + args).strip()[:140]
    etype = 'skill'
    # rol real: aprobaciones HITL -> Pedro; el resto lo ejecuta Santi (vía Claude)
    if sk == 'factory-update' and 'hitl' in args.lower():
        actor, role = 'Pedro', 'approver'
    else:
        actor, role = 'Santi', 'executor'
    m = SLUG_RE.search(args)
    if m: slug = m.group(1)
else:
    sys.exit(0)

def q(s):
    return 'NULL' if s is None else "'" + str(s).replace("'", "''") + "'"

sql = ("INSERT INTO work_log (actor, role, event_type, connection_slug, detail) "
       f"VALUES ({q(actor)},{q(role)},{q(etype)},{q(slug)},{q(detail)});")
subprocess.run(
    ['docker', 'exec', '-i', 'factory-db', 'psql', '-U', 'factory', '-d', 'factory', '-q', '-c', sql],
    timeout=6, capture_output=True,
)
PY
exit 0
