import { Button, Field, PanelSection, PanelSectionRow, TextField, ToggleField } from "@decky/ui";
import { useEffect, useState } from "react";
import { sendReport, systemStatus } from "../backend";
import type { SystemStatus } from "../backend";

// Areas del informe. "logs" es la pesada: apagada por defecto para que enviar sea rapido.
const AREAS: [string, string, string][] = [
  ["sistema", "Sistema", "kernel, BSP, versiones, bateria, termicas"],
  ["energia", "Energia y ventilador", "perfil, governor, limites, curva"],
  ["audio", "Audio", "sinks, UCM, amplificadores, jack"],
  ["mando", "Mando", "inputplumber, compuesto, calibracion"],
  ["fex", "FEX", "version, binfmt, rootfs"],
  ["wproton", "wproton / Proton", "version, prefijos, herramientas"],
  ["emulacion", "Emulacion", "DeckStation, RetroArch, apps"],
  ["qam", "QAM / Decky", "plugins, loader, errores"],
  ["red", "Red", "wifi, direcciones, DNS, MTU"],
  ["logs", "Logs largos", "journal y dmesg completos (pesa)"],
];

const voltios = (uv: number | null | undefined) => (uv == null ? null : `${(uv / 1_000_000).toFixed(2)} V`);
const amperios = (ua: number | null | undefined) => (ua == null ? null : `${(ua / 1_000_000).toFixed(2)} A`);

// NOTA: aqui NO hay selector de perfil de potencia ni control de brillo A PROPOSITO.
//   - El perfil de potencia ya esta en el QAM NATIVO de Steam: su shim
//     (pocknix-steamos-manager) traduce low-power/balanced/performance a nuestro
//     `pocknix-power-profile`. Duplicarlo aqui solo confundia (avisado por Fransis).
//   - El brillo ya lo controla Steam de forma nativa.
// Lo de la bateria es solo LECTURA: lo que Steam no enseña (salud y ciclos, voltaje
// y corriente reales).
// El HDR ya NO se controla desde aqui: lo gobierna el plugin "Panel de Control"
// (Hooandee) en QAM -> Panel de Control -> Pantalla (desde 15/10/2026, decision de
// Fransis: un unico dueño por funcion).
export function System() {
  const [status, setStatus] = useState<SystemStatus | null>(null);
  const [error, setError] = useState("");
  const [texto, setTexto] = useState("");
  const [enviando, setEnviando] = useState(false);
  const [informe, setInforme] = useState<{ ok: boolean; issue?: string; error?: string; detail?: string } | null>(null);
  const [kind, setKind] = useState<"bug" | "idea">("bug");
  const [areas, setAreas] = useState<Record<string, boolean>>(() => {
    const on: Record<string, boolean> = {};
    for (const [id] of AREAS) on[id] = id !== "logs";
    return on;
  });

  useEffect(() => {
    systemStatus()
      .then(setStatus)
      .catch((err) => setError(String(err)));
  }, []);

  const b = status?.battery;
  const detalle = b?.available
    ? [b.status, b.health, b.cycles != null ? `${b.cycles} ciclos` : null, amperios(b.currentNow), voltios(b.voltageNow)]
        .filter(Boolean)
        .join(" · ")
    : "no disponible en este equipo";

  const enviarInforme = async () => {
    setEnviando(true);
    setInforme(null);
    try {
      setInforme(await sendReport(texto, kind, Object.keys(areas).filter((k) => areas[k])));
    } catch (err) {
      setInforme({ ok: false, error: String(err) });
    } finally {
      setEnviando(false);
    }
  };

  return (
    <>
      <PanelSection title="BATERÍA">
        <PanelSectionRow>
          <Field
            label={b?.capacity != null ? `${b.capacity}%` : "…"}
            description={detalle || "…"}
          />
        </PanelSectionRow>
        <PanelSectionRow>
          <Field
            label=""
            description="El perfil de potencia está en el menú de Steam (⋯ → Rendimiento). El brillo, en los controles nativos."
          />
        </PanelSectionRow>
      </PanelSection>

      {error ? (
        <PanelSectionRow>
          <Field label="Error" description={error} />
        </PanelSectionRow>
      ) : null}

      <PanelSection title="INFORME">
        <PanelSectionRow>
          <Field description="Que quieres mandar:" />
        </PanelSectionRow>
        <PanelSectionRow>
          <Button onClick={() => setKind("bug")}>
            {(kind === "bug" ? "● " : "○ ") + "Reportar un problema"}
          </Button>
        </PanelSectionRow>
        <PanelSectionRow>
          <Button onClick={() => setKind("idea")}>
            {(kind === "idea" ? "● " : "○ ") + "Sugerir una mejora"}
          </Button>
        </PanelSectionRow>
        <PanelSectionRow>
          <Field description="Que incluyo:" />
        </PanelSectionRow>
        {AREAS.map(([id, label, desc]) => (
          <PanelSectionRow key={id}>
            <ToggleField
              label={label}
              description={desc}
              checked={!!areas[id]}
              onChange={(v: boolean) => setAreas({ ...areas, [id]: v })}
            />
          </PanelSectionRow>
        ))}
        <PanelSectionRow>
          <TextField
            label="Descripcion (opcional)"
            value={texto}
            onChange={(e) => setTexto(e.target.value)}
          />
        </PanelSectionRow>
        <PanelSectionRow>
          <Button onClick={enviarInforme} disabled={enviando || !Object.values(areas).some(Boolean)}>
            {enviando ? "Enviando..." : "Enviar informe"}
          </Button>
        </PanelSectionRow>
        {informe ? (
          <PanelSectionRow>
            <Field
              label={informe.ok ? "Informe enviado" : "No se pudo enviar"}
              description={informe.ok ? (informe.issue || "") : [informe.error, informe.detail].filter(Boolean).join(" — ")}
            />
          </PanelSectionRow>
        ) : null}
        <PanelSectionRow>
          <Field
            label=""
            description="Se envia a nuestro GitHub (arcadematicas/calvOS-reports). El informe se redacta antes de salir: sin rutas de usuario, hostname, IP, MAC ni claves."
          />
        </PanelSectionRow>
      </PanelSection>
    </>
  );
}
