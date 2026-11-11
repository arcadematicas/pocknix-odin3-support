import { Button, ButtonItem, Field, PanelSection, PanelSectionRow, TextField, ToggleField } from "@decky/ui";
import type { Dispatch, SetStateAction } from "react";
import { useEffect, useState } from "react";
import {
  collectReport,
  desktopFlavour,
  oledCareStatus,
  runOledRefresher,
  sendReport,
  setLavdMode,
  setScxMode,
  setScxScheduler,
  switchToDesktop,
  systemStatus,
} from "../backend";
import type { SystemStatus } from "../backend";
import { lavdOptions, scxModeOptions, scxSchedulerOptions } from "../components/GameFields";
import { SelectEdit } from "../components/widgets";
import type { Config, OledCareStatus } from "../types";

// Sabores de escritorio instalados en la consola (backend: py_modules/desktop.py).
const SABORES: Record<string, string> = {
  plasma: "Plasma de escritorio",
  "plasma-mobile": "Plasma Mobile",
};

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
// "hace 3 min" / "hace 2 h": que se vea que el OLED care trabaja de verdad.
function hace(ts: number | null | undefined): string {
  if (!ts) return "todavía no";
  const s = Math.max(0, Math.floor(Date.now() / 1000) - ts);
  if (s < 60) return `hace ${s} s`;
  if (s < 3600) return `hace ${Math.floor(s / 60)} min`;
  return `hace ${Math.floor(s / 3600)} h`;
}

export function System({ config, setConfig }: {
  config: Config;
  setConfig: Dispatch<SetStateAction<Config | null>>;
}) {
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
  const [sabor, setSabor] = useState("");
  const [cambiando, setCambiando] = useState(false);
  const [fallo, setFallo] = useState("");
  const [guardando, setGuardando] = useState(false);
  const [guardado, setGuardado] = useState<{ ok: boolean; path?: string; error?: string; detail?: string } | null>(null);
  const [oled, setOled] = useState<OledCareStatus | null>(null);
  const [refresherMsg, setRefresherMsg] = useState<string | null>(null);

  useEffect(() => {
    systemStatus()
      .then(setStatus)
      .catch((err) => setError(String(err)));
    desktopFlavour()
      .then(setSabor)
      .catch(() => setSabor(""));
    oledCareStatus()
      .then(setOled)
      .catch(() => setOled(null));
  }, []);

  // El scheduler es estado VIVO del sistema, no un ajuste de perfil: se aplica al momento.
  const applyMode = async (setter: (mode: string) => Promise<Config>, mode: string) => {
    try {
      const next = await setter(mode);
      setConfig((current) => (current ? { ...current, lavdMode: next.lavdMode, scxScheduler: next.scxScheduler, scxMode: next.scxMode } : current));
    } catch (err) {
      setError(String(err));
    }
  };

  const runRefresher = () => {
    setRefresherMsg("Refreshing pixels…");
    runOledRefresher()
      .then((next) => {
        setOled(next);
        setRefresherMsg("Listo.");
      })
      .catch((err) => setRefresherMsg(String(err)));
  };

  // Al cambiar de escritorio Steam se cierra y este plugin muere con el: no hay
  // "listo" que mostrar, solo el aviso de que se esta cerrando.
  const cambiarAEscritorio = async (name: "plasma" | "plasma-mobile") => {
    setCambiando(true);
    setFallo("");
    try {
      await switchToDesktop(name);
      setSabor(name);
    } catch (err) {
      setFallo(String(err));
      setCambiando(false);
    }
  };

  const b = status?.battery;
  const detalle = b?.available
    ? [b.status, b.health, b.cycles != null ? `${b.cycles} ciclos` : null, amperios(b.currentNow), voltios(b.voltageNow)]
        .filter(Boolean)
        .join(" · ")
    : "no disponible en este equipo";

  const guardarInforme = async () => {
    setGuardando(true);
    setGuardado(null);
    try {
      setGuardado(await collectReport(texto, Object.keys(areas).filter((k) => areas[k])));
    } catch (err) {
      setGuardado({ ok: false, error: String(err) });
    } finally {
      setGuardando(false);
    }
  };

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
      <PanelSection title="RENDIMIENTO">
        <SelectEdit
          label="Scheduler"
          value={config.scxScheduler || "auto"}
          options={scxSchedulerOptions}
          onChange={(mode) => applyMode(setScxScheduler, mode)}
        />
        {config.scxScheduler === "auto" ? (
          <PanelSectionRow>
            <Field label="Scheduler activo" description={config.scxEffective || "—"} />
          </PanelSectionRow>
        ) : (
          <SelectEdit
            label="Scheduler Mode"
            value={config.scxMode}
            options={scxModeOptions[config.scxScheduler || ""] || lavdOptions}
            onChange={(mode) => applyMode(setScxMode, mode)}
          />
        )}
      </PanelSection>

      <PanelSection title="OLED CARE">
        <PanelSectionRow>
          <ButtonItem
            layout="below"
            description="Refresco anti retención (ruido a pantalla completa, ~9 s)."
            onClick={runRefresher}
          >
            Run Pixel Refresher
          </ButtonItem>
        </PanelSectionRow>
        {refresherMsg ? (
          <PanelSectionRow>
            <Field label="" description={refresherMsg} />
          </PanelSectionRow>
        ) : null}
        <PanelSectionRow>
          <Field
            label="Automático"
            description={
              oled && !oled.available
                ? "No disponible en este equipo."
                : oled && !oled.daemonUp
                  ? "Daemon parado (sin estado todavía)."
                  : oled
                    ? `Cada ${Math.round(oled.idleSeconds / 60)} min inactivo · último: ${hace(oled.lastRefresh)} (${oled.count})`
                    : "…"
            }
          />
        </PanelSectionRow>
        {oled?.lastSkip ? (
          <PanelSectionRow>
            <Field label="Último omitido" description={oled.lastSkip} />
          </PanelSectionRow>
        ) : null}
      </PanelSection>

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

      <PanelSection title="ESCRITORIO">
        <PanelSectionRow>
          <Field
            label={sabor ? `Ahora: ${SABORES[sabor] || sabor}` : "Ahora: …"}
            description="El escritorio que se abre al salir del modo juego."
          />
        </PanelSectionRow>
        <PanelSectionRow>
          <Button onClick={() => cambiarAEscritorio("plasma")} disabled={cambiando}>
            Cambiar a Plasma (escritorio)
          </Button>
        </PanelSectionRow>
        <PanelSectionRow>
          <Button onClick={() => cambiarAEscritorio("plasma-mobile")} disabled={cambiando}>
            Cambiar a Plasma Mobile
          </Button>
        </PanelSectionRow>
        <PanelSectionRow>
          <Field
            description={
              cambiando
                ? "Cerrando el modo juego…"
                : "Steam se cerrará y la consola abrirá el escritorio elegido."
            }
          />
        </PanelSectionRow>
        {fallo ? (
          <PanelSectionRow>
            <Field label="No se pudo cambiar" description={fallo} />
          </PanelSectionRow>
        ) : null}
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
          <Button onClick={guardarInforme} disabled={guardando || !Object.values(areas).some(Boolean)}>
            {guardando ? "Recogiendo..." : "Guardar informe (sin enviar)"}
          </Button>
        </PanelSectionRow>
        {guardado ? (
          <PanelSectionRow>
            <Field
              label={guardado.ok ? "Informe guardado" : "No se pudo recoger"}
              description={guardado.ok ? (guardado.path || "") : [guardado.error, guardado.detail].filter(Boolean).join(" — ")}
            />
          </PanelSectionRow>
        ) : null}
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
