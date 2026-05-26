// Modelo del proceso de la Factory Pull (Fases 0-8) + motor de "siguiente paso".
//
// El panel no solo muestra ESTADO: guía el proceso. Para cada conexión calcula,
// según su estado real (fase + checklist + HITLs), dos lecturas:
//   - Developer  → la acción concreta y el comando exacto a ejecutar.
//   - Quien espera → en lenguaje llano qué se está haciendo y cuál es el próximo hito.
//
// Fuente del proceso: docs/factory_pull/factory_pull_briefing_v0.md + skills /factory-*.

export type Actor = "dev" | "gate" | "engineering";

export type Phase = {
  n: number;
  label: string;
  short: string; // qué pasa aquí, en una línea
  actor: Actor;
  inPlant: boolean; // F0-5 viven en la planta; F6-8 en el repo PerlaHub
};

export const PHASES: Phase[] = [
  { n: 0, label: "Intake", short: "Validar 4 criterios: doc · sandbox · contacto · volumen", actor: "dev", inPlant: true },
  { n: 1, label: "Análisis doc", short: "Leer la doc del provider y clasificar la checklist técnica 🟢🟡🔴", actor: "dev", inPlant: true },
  { n: 2, label: "Sandbox", short: "Validar los endpoints reales del provider contra la doc", actor: "dev", inPlant: true },
  { n: 3, label: "Mock tests", short: "7 casos estándar contra PerlaHub-dev", actor: "dev", inPlant: true },
  { n: 4, label: "Mismatches", short: "Clasificar las diferencias doc ↔ realidad", actor: "dev", inPlant: true },
  { n: 5, label: "Informe", short: "Compilar el informe final → HITL #1 (Pedro)", actor: "dev", inPlant: true },
  { n: 6, label: "Codificación", short: "Implementar el conector (repo PerlaHub, fuera de planta)", actor: "engineering", inPlant: false },
  { n: 7, label: "E2E", short: "Pruebas end-to-end en DEV", actor: "engineering", inPlant: false },
  { n: 8, label: "Go-live", short: "Despliegue a PROD + monitoreo de estabilidad", actor: "engineering", inPlant: false },
];

export function phaseByN(n: number): Phase {
  return PHASES.find((p) => p.n === n) ?? PHASES[0];
}

/** Versión de una línea para las tarjetas del kanban. */
export function compactNextStep(
  status: string,
  currentPhase: number,
  checklist?: { total: number; pending: number }
): string {
  if (status === "rejected_intake") return "Falta input externo";
  if (status === "awaiting_intake") return "Esperando Intake";
  switch (currentPhase) {
    case 0:
      return "Completar Intake";
    case 1:
      return checklist && checklist.pending > 0 ? `Clasificar ${checklist.pending} ítems` : "Finalizar checklist";
    case 2:
      return "Validar sandbox";
    case 3:
      return "Correr mock tests";
    case 4:
      return "Clasificar mismatches";
    case 5:
      return "Compilar informe → Pedro";
    case 6:
      return "Codificación (PerlaHub)";
    case 7:
      return "Pruebas E2E";
    case 8:
      return "Go-live PROD";
    default:
      return "—";
  }
}

export type ChecklistAgg = { total: number; pending: number; green: number; yellow: number; red: number; na: number };
export type HitlLite = { gate_number: number; status: string; notes: string | null; approver: string | null };

export type NextStep = {
  phase: Phase;
  /** acción para el developer (imperativo, corto) */
  devTitle: string;
  /** paso previo: qué dejar y EN QUÉ CARPETA antes de ejecutar el comando */
  prep?: { label: string; path: string };
  /** comandos exactos a ejecutar, en orden */
  devCommands: string[];
  /** contexto extra para el developer */
  devDetail?: string;
  /** estado en lenguaje llano para quien espera */
  watcherStatus: string;
  /** próximo hito visible */
  watcherMilestone: string;
  /** si el avance está bloqueado esperando una decisión humana */
  blockedOn?: string;
  /** tono del bloque: normal | waiting | done | stop */
  tone: "go" | "waiting" | "done" | "stop";
};

function providerName(displayName: string): string {
  // "Avoris (Polaris) — Pull nativo" -> "Avoris"
  return displayName.split(/[—(]/)[0].trim() || displayName;
}

export type NextStepInput = {
  slug: string;
  displayName: string;
  status: string;
  currentPhase: number;
  checklist: ChecklistAgg;
  hitls: HitlLite[];
};

export function computeNextStep(input: NextStepInput): NextStep {
  const { slug, displayName, status, currentPhase, checklist, hitls } = input;
  const provider = providerName(displayName);
  const phase = phaseByN(currentPhase);
  const marked = checklist.total - checklist.pending;

  // --- Intake rechazado: bloqueado por input externo ---
  if (status === "rejected_intake") {
    return {
      phase: phaseByN(0),
      devTitle: "Intake rechazado — faltan criterios",
      devCommands: [`/factory-update ${slug} --intake-retry`],
      devDetail: "Cuando el proveedor aporte la doc / sandbox / contacto / volumen que falta, reintenta el Intake.",
      watcherStatus: `Bloqueado en la puerta de entrada: falta información del proveedor (${provider}).`,
      watcherMilestone: "Reanudar cuando llegue el input pendiente.",
      blockedOn: "input externo del proveedor",
      tone: "stop",
    };
  }

  // --- HITL #1 listo y esperando a Pedro (se setea al finalizar checklist / informe) ---
  const gate1 = hitls.find((h) => h.gate_number === 1);
  if (gate1 && gate1.status === "pending" && gate1.notes && currentPhase >= 1 && currentPhase <= 5) {
    return {
      phase,
      devTitle: "Revisar el análisis con Pedro (HITL #1)",
      devCommands: [`/factory-review ${slug}`],
      devDetail:
        "No es un sello: Claude propone cada 🟡/🔴 con su solución y Pedro valida o ajusta cada una. " +
        "Al terminar la discusión se aprueba la puerta. (Evita el --hitl-approve directo: aprobaría todo a ciegas.)",
      watcherStatus: `Análisis de ${provider} listo (checklist + hallazgos). En revisión con Pedro.`,
      watcherMilestone: "Discutir y aprobar HITL #1 → desbloquea la siguiente fase.",
      blockedOn: "revisión humana (discusión con Pedro)",
      tone: "waiting",
    };
  }

  switch (currentPhase) {
    case 1: {
      if (checklist.total > 0 && checklist.pending > 0) {
        return {
          phase,
          devTitle: `Clasificar la checklist técnica · ${marked}/${checklist.total}`,
          prep: {
            label: "Coloca la doc del proveedor (Swagger / Postman / PDF + ejemplos request·response) en",
            path: `pilots/${slug}/inputs/doc/`,
          },
          devCommands: [`/factory-pull ${slug}`],
          devDetail:
            `Claude lee la doc de inputs/doc/, clasifica las ${checklist.pending} filas pendientes ` +
            "(🟢 directo · 🟡 interpretación · 🔴 gap) y te pregunta solo las dudosas. " +
            `Equivale a decirle: «clasifica la checklist de ${slug} leyendo la doc».`,
          watcherStatus: `Analizando la documentación de ${provider}: ${marked} de ${checklist.total} puntos técnicos revisados.`,
          watcherMilestone: "Checklist completa → informe técnico para Pedro (HITL #1).",
          tone: "go",
        };
      }
      // todas marcadas → finalizar
      return {
        phase,
        devTitle: "Checklist completa — finalizar análisis",
        devCommands: [`/factory-checklist finalize ${slug}`],
        devDetail: "Cierra la Fase 1 y habilita HITL #1 (revisión de Pedro).",
        watcherStatus: `Documentación de ${provider} analizada al 100% (${checklist.total} puntos).`,
        watcherMilestone: "Habilitar la revisión de Pedro.",
        tone: "go",
      };
    }
    case 2:
      return {
        phase,
        devTitle: "Validar el sandbox del proveedor",
        prep: {
          label: "Copia el .example a tus credenciales sandbox reales (git-ignored) en",
          path: `pilots/${slug}/inputs/03-credentials.local.env`,
        },
        devCommands: [`/factory-sandbox validate ${slug}`],
        devDetail: "Lanza ~6 endpoints en paralelo (auth, search, statics, prebook, book) y compara contra la doc. Si hay mismatch → se registra como sorpresa.",
        watcherStatus: `Probando la conexión real con ${provider} (disponibilidad, precios, reservas de prueba).`,
        watcherMilestone: "Sandbox OK → pruebas de integración (mock tests).",
        tone: "go",
      };
    case 3:
      return {
        phase,
        devTitle: "Correr los 7 mock tests",
        devCommands: [`/factory-mocktests run ${slug} --env perlahub-dev`, `/factory-mocktests result ${slug}`],
        devDetail: "Casos: 1 noche · multi-noche · multi-room · multi-ocupación · cambio de divisa · fechas borde · cancelación. Cualquier fail → parar y revisar.",
        watcherStatus: `Ejecutando pruebas de integración de ${provider} en el entorno de desarrollo.`,
        watcherMilestone: "Mock tests en verde → clasificar diferencias.",
        tone: "go",
      };
    case 4:
      return {
        phase,
        devTitle: "Clasificar mismatches",
        devCommands: [`/factory-mismatches classify ${slug}`],
        devDetail: "Separa lo conocido (catálogo Anexo D) de lo genuinamente nuevo. Lo nuevo dispara HITL #3.",
        watcherStatus: `Catalogando las diferencias entre la doc de ${provider} y su comportamiento real.`,
        watcherMilestone: "Mismatches clasificados → informe final.",
        tone: "go",
      };
    case 5:
      return {
        phase,
        devTitle: "Compilar el informe final",
        devCommands: [`bash scripts/dump-pilot.sh ${slug}`],
        devDetail: "Reúne score real, wrappers necesarios y recomendación (proceder/pivotar). Deja HITL #1 listo para Pedro.",
        watcherStatus: `Redactando el informe técnico final de ${provider}.`,
        watcherMilestone: "Entregar informe → aprobación de Pedro (HITL #1).",
        tone: "go",
      };
    case 6:
    case 7:
    case 8:
      return {
        phase,
        devTitle: "Fuera de la planta — repo PerlaHub",
        devCommands: [],
        devDetail: "Codificación (F6), E2E (F7) y go-live (F8) se ejecutan en el repo del conector con intervención humana. La planta solo registra el commit y el outcome.",
        watcherStatus: `${provider} pasó el análisis. Ahora en ${phase.label.toLowerCase()} dentro del producto.`,
        watcherMilestone: currentPhase === 8 ? "Estabilizar métricas en PROD → cierre (DoD)." : "Llegar a producción.",
        tone: currentPhase === 8 ? "done" : "go",
      };
    default:
      // Fase 0 sin rechazo: intake en curso
      return {
        phase: phaseByN(0),
        devTitle: "Completar el Intake",
        devCommands: [
          `/factory-new ${slug} --type pull --display "..." --contact "..." --doc-url ... --sandbox-ok yes --volume "..."`,
        ],
        devDetail:
          "Un solo comando valida los 4 criterios y, si cumplen, crea la conexión en la DB Y su carpeta " +
          `pilots/${slug}/ (inputs · evidence · outputs) desde la plantilla. Nadie crea la carpeta a mano. Entra a la línea en Fase 1.`,
        watcherStatus: `Evaluando si ${provider} cumple los requisitos para entrar a fabricación.`,
        watcherMilestone: "Intake aprobado → análisis de documentación.",
        tone: "go",
      };
  }
}
