import { ButtonItem, Field, PanelSection, PanelSectionRow, SliderField, ToggleField } from "@decky/ui";
import { useEffect, useState } from "react";
import { systemSetBacklight, systemSetProfile, systemStatus } from "../backend";
import type { SystemStatus } from "../backend";

const voltios = (uv: number | null | undefined) => (uv == null ? "-" : `${(uv / 1_000_000).toFixed(2)} V`);
const amperios = (ua: number | null | undefined) => (ua == null ? "-" : `${(ua / 1_000_000).toFixed(2)} A`);

// La salud que da el driver viene como texto ("Good", "Normal"...); si ademas
// tenemos capacidad real y de diseno, el backend calcula un %.
const salud = (status: SystemStatus) => {
  const b = status.battery;
  if (!b.available) return "no disponible";
  const partes = [b.health, b.cycles != null ? `${b.cycles} ciclos` : null].filter(Boolean);
  return partes.length ? partes.join(" · ") : "-";
};

export function System() {
  const [status, setStatus] = useState<SystemStatus | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  const refresh = () => {
    systemStatus()
      .then(setStatus)
      .catch((err) => setError(String(err)));
  };
  useEffect(refresh, []);

  const pick = (id: string) => {
    setBusy(true);
    setError("");
    systemSetProfile(id)
      .then((next) => setStatus((cur) => (cur ? { ...cur, profile: next.profile } : cur)))
      .catch((err) => setError(String(err)))
      .finally(() => setBusy(false));
  };

  const setBrightness = (percent: number) => {
    systemSetBacklight(percent)
      .then((bl) => setStatus((cur) => (cur ? { ...cur, backlight: bl } : cur)))
      .catch((err) => setError(String(err)));
  };

  const b = status?.battery;
  const bl = status?.backlight;

  return (
    <>
      <PanelSection title="PERFIL DE POTENCIA">
        <PanelSectionRow>
          <Field
            label="Actual"
            description="Limita la frecuencia máxima de CPU y GPU. 'Bajo' alarga mucho la batería; 'Alto' no pone límites."
          />
        </PanelSectionRow>
        {status?.profiles.map((p) => (
          <PanelSectionRow key={p.id}>
            <ButtonItem
              layout="below"
              disabled={busy || status.profile === p.id}
              description={status.profile === p.id ? "En uso" : undefined}
              onClick={() => pick(p.id)}
            >
              {p.label}
            </ButtonItem>
          </PanelSectionRow>
        ))}
        {message ? (
          <PanelSectionRow>
            <Field label="" description={message} />
          </PanelSectionRow>
        ) : null}
      </PanelSection>

      <PanelSection title="BATERÍA">
        <PanelSectionRow>
          <Field
            label={b?.capacity != null ? `${b.capacity}%` : "…"}
            description={
              b?.available
                ? [b.status, salud(status!), amperios(b.currentNow), voltios(b.voltageNow)]
                    .filter((x) => x && x !== "-")
                    .join(" · ")
                : "no disponible en este equipo"
            }
          />
        </PanelSectionRow>
      </PanelSection>

      {bl?.available && (
        <PanelSection title="BRILLO">
          <PanelSectionRow>
            <SliderField
              label={`${bl.percent}%`}
              value={bl.percent ?? 0}
              min={1}
              max={100}
              step={5}
              showValue={false}
              onChange={setBrightness}
            />
          </PanelSectionRow>
        </PanelSection>
      )}

      {error ? (
        <PanelSectionRow>
          <Field label="Error" description={error} />
        </PanelSectionRow>
      ) : null}
    </>
  );
}
