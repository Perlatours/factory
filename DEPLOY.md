# Deploy del Factory en server (Huawei Cloud ECS)

Monta el factory completo — **DB + panel + skills** — en un único server. Todo corre ahí (la DB
en local del server, el panel en local del server); las skills se ejecutan por SSH contra ese server.

## Server de referencia
- **Huawei Cloud ECS** `factory` · Ubuntu 24.04 · EU-Dublin · EIP `101.46.140.159`
- Security Group `Sys-WebServer` — debe permitir **22 (SSH)** y **3000 (panel)** entrantes.

## Arranque (one-shot)

En el server:

```bash
curl -fsSL https://raw.githubusercontent.com/Perlatours/factory/rehearsal/avoris-pull/scripts/server-bootstrap.sh -o bootstrap.sh
bash bootstrap.sh rehearsal/avoris-pull
```

O si ya clonaste el repo:

```bash
cd ~/factory && bash scripts/server-bootstrap.sh rehearsal/avoris-pull
```

El script: instala Docker (si falta) → clona/actualiza el repo → `docker compose up -d --build`
(levanta `factory-db` + `factory-panel`) → espera la DB → **restaura el snapshot** de
`db/snapshots/` (estado real hasta Fase 5, para continuar donde lo dejamos).

## Acceso
- **Panel:** `http://101.46.140.159:3000` (abre el 3000 en el Security Group)
- **DB:** `docker exec -i factory-db psql -U factory -d factory`
- **Skills:** igual que en local (`docker exec -i factory-db ...`). Para re-correr sandbox/mocktests
  crea `pilots/<slug>/inputs/03-credentials.local.env` (git-ignored, **nunca** se commitea).

## Notas de seguridad
- Postgres **no** se expone a internet: solo el panel (3000). La DB vive en la red interna de compose.
- Las credenciales de proveedor (Avoris PRO, etc.) viven en `*.local.env` git-ignored. No están
  en el repo ni en el snapshot (sanitizado).
- Cambia las passwords por defecto (`factory_local`, `factory_reader_local`) en producción real.
