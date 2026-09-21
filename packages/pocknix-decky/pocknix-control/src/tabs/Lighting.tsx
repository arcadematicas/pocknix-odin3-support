import { ButtonItem, Field, PanelSection, PanelSectionRow, ToggleField } from "@decky/ui";
import type { Dispatch, SetStateAction } from "react";
import { useEffect, useState } from "react";
import { oledCareStatus, runOledRefresher, setLed, setLedEnabled, setLedLinked, setLedSideEnabled, setLedSides } from "../backend";
import { ColorControls } from "../components/ColorControls";
import { hsvToRgb, rgbToHsv } from "../lib/rgb";
import type { Config, LedSide, LedSideKey, OledCareStatus } from "../types";

// Stored RGB holds the full-value color; the kernel multicolor class scales each
// channel by brightness/max_brightness, so dimming is linear and the color survives.
function commit(side: LedSideKey, hsv: [number, number, number], brightness: number, setConfig: Dispatch<SetStateAction<Config | null>>, reload: () => void) {
  const [r, g, b] = hsvToRgb(hsv[0], hsv[1], 100);
  setLed(side, r, g, b, brightness)
    .then((next) => setConfig((cur) => (cur ? { ...cur, led: next } : cur)))
    .catch(() => reload());
}

function sideHsv(side: LedSide): [number, number, number] {
  return rgbToHsv(side.r, side.g, side.b);
}

// "hace 3 min" / "hace 2 h" — para que se vea que el OLED care trabaja de verdad.
function hace(ts: number | null | undefined): string {
  if (!ts) return "todavía no";
  const s = Math.max(0, Math.floor(Date.now() / 1000) - ts);
  if (s < 60) return `hace ${s} s`;
  if (s < 3600) return `hace ${Math.floor(s / 60)} min`;
  return `hace ${Math.floor(s / 3600)} h`;
}

export function Lighting({ config, setConfig, reload }: {
  config: Config;
  setConfig: Dispatch<SetStateAction<Config | null>>;
  reload: () => void;
}) {
  const led = config.led;
  const leftHsv = sideHsv(led.left);
  const rightHsv = sideHsv(led.right);
  const [refresherMsg, setRefresherMsg] = useState<string | null>(null);
  const [oled, setOled] = useState<OledCareStatus | null>(null);

  const refrescarEstado = () => {
    oledCareStatus().then(setOled).catch(() => setOled(null));
  };
  useEffect(refrescarEstado, []);

  const commitLeft = (hsv: [number, number, number], brightness: number) => commit("left", hsv, brightness, setConfig, reload);
  const commitRight = (hsv: [number, number, number], brightness: number) => commit("right", hsv, brightness, setConfig, reload);
  const commitBoth = (hsv: [number, number, number], brightness: number) => commit("both", hsv, brightness, setConfig, reload);

  // Apagado individual de un stick (como en Android): conserva color y brillo.
  const toggleSide = (side: "left" | "right", value: boolean) =>
    setLedSideEnabled(side, value)
      .then((next) => setConfig((cur) => (cur ? { ...cur, led: next } : cur)))
      .catch(() => reload());

  const runRefresher = () => {
    setRefresherMsg("Refreshing pixels…");
    runOledRefresher()
      .then((status) => {
        setOled(status);
        setRefresherMsg(status.running ? "Pixel refresh in progress (~9s)." : "Pixel refresh finished.");
        window.setTimeout(refrescarEstado, 12000);
      })
      .catch((error) => setRefresherMsg(String(error)));
  };

  return (
    <>
      <PanelSection title="STICK LIGHTS">
        <PanelSectionRow>
          <ToggleField
            label="Enable"
            checked={led.enabled}
            onChange={(value) =>
              setLedEnabled(value)
                .then((next) => setConfig((cur) => (cur ? { ...cur, led: next } : cur)))
                .catch(() => reload())
            }
          />
        </PanelSectionRow>
        <PanelSectionRow>
          <ToggleField
            label="Link Left & Right"
            description="Match both sticks to the same color."
            checked={led.linked}
            disabled={!led.enabled}
            onChange={(value) =>
              setLedLinked(value)
                .then((next) => setConfig((cur) => (cur ? { ...cur, led: next } : cur)))
                .catch(() => reload())
            }
          />
        </PanelSectionRow>
        {led.sidesAvailable && (
          <PanelSectionRow>
            <ToggleField
              label="Side Lights"
              description="Match the side lighting to the sticks."
              checked={led.sides}
              disabled={!led.enabled}
              onChange={(value) =>
                setLedSides(value)
                  .then((next) => setConfig((cur) => (cur ? { ...cur, led: next } : cur)))
                  .catch(() => reload())
              }
            />
          </PanelSectionRow>
        )}
      </PanelSection>

      {led.enabled && (
        led.linked ? (
          <PanelSection title="BOTH STICKS">
            <ColorControls zone="both" hsv={leftHsv} brightness={led.left.brightness} onCommit={commitBoth} />
          </PanelSection>
        ) : (
          <>
            <PanelSection title="LEFT STICK">
              <PanelSectionRow>
                <ToggleField
                  label="Enable"
                  description="Turn this stick off on its own (keeps its color)."
                  checked={led.left.enabled}
                  onChange={(value) => toggleSide("left", value)}
                />
              </PanelSectionRow>
              {led.left.enabled && (
                <ColorControls zone="left" hsv={leftHsv} brightness={led.left.brightness} onCommit={commitLeft} />
              )}
            </PanelSection>
            <PanelSection title="RIGHT STICK">
              <PanelSectionRow>
                <ToggleField
                  label="Enable"
                  description="Turn this stick off on its own (keeps its color)."
                  checked={led.right.enabled}
                  onChange={(value) => toggleSide("right", value)}
                />
              </PanelSectionRow>
              {led.right.enabled && (
                <ColorControls zone="right" hsv={rightHsv} brightness={led.right.brightness} onCommit={commitRight} />
              )}
            </PanelSection>
          </>
        )
      )}

      <PanelSection title="OLED CARE">
        <PanelSectionRow>
          <ButtonItem
            layout="below"
            description="Run the anti image-retention pixel refresh (fullscreen noise, ~9s)."
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
            label="Automatic"
            description={
              oled && !oled.available
                ? "Not available on this device."
                : oled && !oled.daemonUp
                  ? "Daemon not running (no state yet)."
                  : oled
                    ? `Every ${Math.round(oled.idleSeconds / 60)} min idle · last: ${hace(oled.lastRefresh)} (${oled.count})`
                    : "…"
            }
          />
        </PanelSectionRow>
        {oled?.lastSkip ? (
          <PanelSectionRow>
            <Field label="Last skip" description={oled.lastSkip} />
          </PanelSectionRow>
        ) : null}
      </PanelSection>
    </>
  );
}
