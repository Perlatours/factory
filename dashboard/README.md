# Factory · Panel de control

**NO es BI. Es la pantalla operativa del piso de planta.**

> 📖 Guía completa de qué muestra cada pantalla + workflow developer → [`../docs/USAGE.md`](../docs/USAGE.md)

## Arrancar

```bash
cd dashboard
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
streamlit run app.py
```

Abre http://localhost:8501

## Requisitos previos

- Container `factory-db` corriendo (`bash ../scripts/init-db.sh`)
- `.streamlit/secrets.toml` configurado (copia de `secrets.toml.example`)

## 4 Pantallas

1. **Piso de planta** — kanban por fase con filtros. Lo que se mira a diario.
2. **Por conexión** — drill-down: HITLs, phase log, checklist, sorpresas.
3. **Aprendizaje cross-conexión** — top filas 🔴, sorpresas resueltas, insumo Anexo D.
4. **Métricas** — vacía hasta ≥5 cierres reales. No la mires antes.

## Banner HITLs

Arriba del todo, siempre visible. Color según `días esperando`:
- 🟡 Hay HITLs pendientes pero ninguno >2 días
- 🔴 Al menos un HITL >2 días sin resolver
- ✅ Sin HITLs pendientes

## Refresh

Botón "↻ Refresh" arriba a la derecha. Limpia cache (TTL default: 60s).
