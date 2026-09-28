import { Field, PanelSection, PanelSectionRow, ToggleField } from "@decky/ui";
import { useEffect, useState } from "react";
import { hdrStatus, setHdr, systemStatus } from "../backend";
import type { SystemStatus } from "../backend";
import type { HdrStatus } from "../types";

const voltios = (uv: number | null | undefined) => (uv == null ? null : `${(uv / 1_000_000).toFixed(2)} V`);
const amperios = (ua: number | null | undefined) => (ua == null ? null : `${(ua / 1_000_000).toFixed(2)} A`);

// NOTA: aqui NO hay selector de perfil de potencia ni control de brillo A PROPOSITO.
//   - El perfil de potencia ya esta en el QAM NATIVO de Steam: su shim
//     (pocknix-steamos-manager) traduce low-power/balanced/performance a nuestro
//     `pocknix-power-profile`. Duplicarlo aqui solo confundia (avisado por Fransis).
//   - El brillo ya lo controla Steam de forma nativa.
// Lo de la bateria es solo LECTURA: lo que Steam no enseña (salud y ciclos, voltaje
// y corriente reales). Lo unico que se toca es el HDR, que gamescope expone como
// atomo X11 y el cliente Steam ARM64 no pone en ningun menu.
export function System() {
  const [status, setStatus] = useState<SystemStatus | null>(null);
  const [error, setError] = useState("");
  const [hdr, setHdrStatus] = useState<HdrStatus | null>(null);
  const [hdrError, setHdrError] = useState("");

  useEffect(() => {
    systemStatus()
      .then(setStatus)
      .catch((err) => setError(String(err)));
  }, []);

  const refrescarHdr = () => {
    hdrStatus().then(setHdrStatus).catch(() => setHdrStatus(null));
  };
  useEffect(refrescarHdr, []);

  const b = status?.battery;
  const detalle = b?.available
    ? [b.status, b.health, b.cycles != null ? `${b.cycles} ciclos` : null, amperios(b.currentNow), voltios(b.voltageNow)]
        .filter(Boolean)
        .join(" · ")
    : "no disponible en este equipo";

  // El backend devuelve el estado REAL tras escribir el atomo, asi que se refleja
  // lo que gamescope acepto (y si no, se vuelve a leer y se revierte el toggle).
  const cambiarHdr = (valor: boolean) => {
    setHdrStatus((cur) => (cur ? { ...cur, enabled: valor } : cur));
    setHdr(valor)
      .then((next) => {
        setHdrStatus(next);
        setHdrError("");
      })
      .catch((err) => {
        setHdrError(String(err));
        refrescarHdr();
      });
  };

  const hdrDescripcion = !hdr
    ? "…"
    : !hdr.available
      ? "HDR no disponible (requiere gamescope)."
      : !hdr.capable
        ? "Este panel no reporta soporte HDR."
        : "High dynamic range en la sesion de juego (650 nits). Los juegos lo piden solos.";

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

      <PanelSection title="DISPLAY">
        <PanelSectionRow>
          <ToggleField
            label="HDR"
            description={hdrDescripcion}
            checked={!!hdr?.enabled}
            disabled={!hdr?.available || !hdr?.capable}
            onChange={cambiarHdr}
          />
        </PanelSectionRow>
        {hdrError ? (
          <PanelSectionRow>
            <Field label="Error" description={hdrError} />
          </PanelSectionRow>
        ) : null}
      </PanelSection>

      {error ? (
        <PanelSectionRow>
          <Field label="Error" description={error} />
        </PanelSectionRow>
      ) : null}
    </>
  );
}
