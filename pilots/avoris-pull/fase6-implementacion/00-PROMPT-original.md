# Fase 6 — Implementación conector Avoris · PROMPT ORIGINAL (verbatim)

_Guardado 2026-06-09. Trabajo autónomo ≈12h sin interacción de usuario. Al terminar: lanzar revisión contra estos criterios._

## Prompt del usuario (Pedro)

> Inicia la fase de implementación, teniendo en cuenta que debe completarse sobre el directorio "C:\Workspace\Perlatours\PerlaHub\Connectors\Accommodation" que ya está en el repositorio de PerlaHub sobre una rama dedicada a este desarrollo, APIs separadas para 1-Search/prebook, 2-book,cancel,getBooking y 3-statics (como el resto de conectores). Durante el desarrollo, las llamadas a Provider no serán reales, devolviendo el contenido de los mocks almacenados durante el proceso de factory. No debes parar hasta poder levantar todas las apis y completar todas las operaciones contra los mocks. En este punto, si se dispone de credenciales de acceso a avoris-PRO (test no funciona), levantar apis 1 y 3 y validar que realizan llamadas correctas a destino real. A partir de este momento no tendrás interacción de usuario hasta dentro de unas 12 horas, por lo que cualquier detalle detectado documentalo en un fichero sobre este repositorio de factory, si es bloqueante evalua la mejor opción de seguir y documenta duda + opciones evaluadas + decisión para obtener el objetivo de que esté lo más completo posible. No entra como objetivo de esta fase, levantar todo el sistema de PerlaHub para pruebas integradas, sólo validar APIs de conector. Como es un trabajo extenso y éste un promt denso, guarda este prompt y cuando el proceso acabe, se lance una revisión de lo generado validando que cumple lo indicado aquí.

## Criterios de aceptación (extraídos del prompt)

1. **Ubicación:** implementación en `C:\Workspace\Perlatours\PerlaHub\Connectors\Accommodation` (repo PerlaHub).
2. **Rama dedicada** a este desarrollo en el repo PerlaHub.
3. **3 APIs separadas** (como el resto de conectores):
   - **API 1** — Search / Prebook
   - **API 2** — Book / Cancel / GetBooking
   - **API 3** — Statics
4. **Provider mockeado en dev:** las llamadas al provider NO son reales; devuelven el contenido de los **mocks almacenados en factory** (`pilots/avoris-pull/evidence/`).
5. **Objetivo mínimo (no parar hasta lograrlo):** levantar las 3 APIs y **completar todas las operaciones contra los mocks**.
6. **Validación PRO (condicional):** si hay credenciales avoris-PRO (TST no funciona) → levantar **API 1 y 3** y validar que hacen **llamadas correctas a destino real**.
7. **Fuera de alcance:** levantar todo PerlaHub para pruebas integradas. Solo validar las APIs del conector.
8. **Autonomía:** sin interacción ~12h. Documentar todo detalle en el repo factory. Bloqueos → documentar **duda + opciones evaluadas + decisión** y continuar para maximizar completitud.
9. **Cierre:** al acabar, lanzar **revisión** de lo generado validando que cumple lo aquí indicado.

## Insumos de implementación
- `pilots/avoris-pull/outputs/informe-ajustes-revision.md` (§5 checklist de implementación, §0 principio P7, §1 cableado)
- `pilots/avoris-pull/outputs/informe.md`, `mismatches-classified.md`
- Mocks: `pilots/avoris-pull/evidence/{mocktests-20260609, sandbox-pro-20260609-e2e, sandbox-pro-20260604}/`
- Contrato canónico: `C:\Workspace\Perlatours\PerlaHub\Connectors\Core\Accommodation`
- Decisiones Pull P1–P7: `catalog/decisions-p1-p6.md` / `docs/factory_pull/factory_pull_validaciones.md`
