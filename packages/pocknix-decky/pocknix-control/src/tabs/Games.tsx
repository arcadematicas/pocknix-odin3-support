import { PanelSection, ToggleField } from "@decky/ui";
import type { Dispatch, SetStateAction } from "react";
import { useEffect, useState } from "react";
import { availableCompatTools, registerForCompatTool } from "../lib/compat";
import { syncGameWrapperLaunchOption } from "../lib/launchOptions";
import { SelectEdit } from "../components/widgets";
import { availableGames, editTargetOptions } from "../lib/games";
import { clone } from "../lib/util";
import type { Config } from "../types";

// Pestana Juegos: solo la seleccion de Mesa por juego. El scheduler vive en Sistema y el
// resto de ajustes (FEX, audio, env) se retiraron de la UI el 11/11/2026: no se usaban y
// hacian que este plugin pareciese un segundo panel de control.
export function Games({ config, setConfig }: {
  config: Config;
  setConfig: Dispatch<SetStateAction<Config | null>>;
}) {
  const runtimeGame = config.game;
  const games = availableGames(config);
  const game = config.selectedGame || runtimeGame || null;
  const appid = game?.appid || "";
  const tweaks = config.tweaks;
  const settings: Record<string, any> = appid ? (tweaks.games[appid] as Record<string, any>) || {} : {};
  const perGameEnabled = !!(appid && settings.enabled === true);
  // Un juego es "nativo" cuando Steam no le asigna herramienta de compatibilidad. Solo en
  // ese caso tiene sentido meter el wrapper: a un juego de Proton le pondriamos un ICD de
  // ARM y lo dejariamos sin driver (el wrapper de Proton ya resuelve su Mesa). "known"
  // evita decidir con el valor inicial vacio antes de que Steam conteste.
  const [known, setKnown] = useState(false);
  const [native, setNative] = useState(false);

  useEffect(() => {
    setKnown(false);
    setNative(false);
    if (!appid) return;
    let live = true;
    // Llamada redundante a proposito: fuerza la carga del hook de Steam y, si el callback
    // no llega, dejamos known=false y no tocamos las launch options.
    availableCompatTools(appid).catch(() => {});
    const unregister = registerForCompatTool(appid, (tool) => {
      if (!live) return;
      setNative(tool === "");
      setKnown(true);
    });
    return () => {
      live = false;
      unregister();
    };
  }, [appid]);

  const mesa = String(settings.mesaVersion ?? "");
  const mesaOptions = [{ data: "", label: "System default" }, ...(config.mesaVersions || [])];

  // Self-heal: the token must be there when the tab opens, not only after the dropdown changes
  // (a game can already have a Mesa pick from an older build, and Steam may have dropped it).
  useEffect(() => {
    if (!known || !native || !appid) return;
    void syncGameWrapperLaunchOption(appid, perGameEnabled && mesa !== "");
  }, [known, native, appid, perGameEnabled, mesa]);

  const patchMesa = (value: string) => {
    setConfig((current) => {
      if (!current || !appid) return current;
      const next = clone(current);
      next.tweaks.games[appid] = { ...(next.tweaks.games[appid] || {}), enabled: true, name: game?.name || "", mesaVersion: value };
      return next;
    });
    if (known && native) void syncGameWrapperLaunchOption(appid, value !== "");
  };

  const setPerGameEnabled = (enabled: boolean) => {
    if (!appid) return;
    setConfig((current) => {
      if (!current) return current;
      const next = clone(current);
      next.tweaks.games[appid] = { ...(next.tweaks.games[appid] || {}), enabled, name: game?.name || "" };
      return next;
    });
    if (known && native) void syncGameWrapperLaunchOption(appid, enabled && mesa !== "");
  };

  // "" is the explicit Default target, not "nothing selected"; store a sentinel so it does
  // not fall back to the running game in the selectedGame derivation.
  const setSelectedGame = (value: any) => {
    const id = String(value);
    if (!id) {
      setConfig((current) => (current ? { ...current, selectedGame: { appid: "", name: "Default" } } : current));
      return;
    }
    const saved = games.find((candidate) => candidate.appid === id);
    setConfig((current) => (current ? { ...current, selectedGame: saved || null } : current));
  };

  return (
    <>
      <PanelSection title="JUEGO">
        <SelectEdit label="Game" value={appid} options={editTargetOptions(config)} onChange={setSelectedGame} />
        {appid ? (
          <ToggleField label="Usar ajustes por juego" checked={perGameEnabled} onChange={setPerGameEnabled} />
        ) : null}
      </PanelSection>

      {!appid ? (
        <PanelSection title="MESA (VULKAN)">
          <div className="pocknix-note">Elige un juego para asignarle una versión de Mesa.</div>
        </PanelSection>
      ) : perGameEnabled ? (
        <PanelSection title="MESA (VULKAN)">
          <SelectEdit label="Mesa Version" value={mesa} options={mesaOptions} onChange={patchMesa} />
          <div className="pocknix-note">
            {known && !native
              ? "Este juego usa Proton: su Mesa se elige en el wrapper de Proton."
              : "Se aplica al arrancar el juego (AppImage, .sh o binario)."}
          </div>
        </PanelSection>
      ) : (
        <PanelSection title="MESA (VULKAN)">
          <div className="pocknix-note">Activa "Usar ajustes por juego" para elegir la versión de Mesa.</div>
        </PanelSection>
      )}
    </>
  );
}
