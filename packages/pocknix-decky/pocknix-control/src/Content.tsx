import { Field, PanelSection, Tabs } from "@decky/ui";
import { useCallback, useEffect, useRef, useState } from "react";
import type { ReactNode } from "react";
import { getConfig, saveTweaks } from "./backend";
import { usePatchTweaks } from "./hooks/usePatchTweaks";
import { tabIcons } from "./icons";
import { currentGame } from "./lib/games";
import { styles } from "./styles";
import { System } from "./tabs/System";
import { Games } from "./tabs/Games";
import { Updater } from "./tabs/Updater";
import type { Config } from "./types";

export function Content() {
  const [tab, setTab] = useState("Games");
  const [config, setConfig] = useState<Config | null>(null);
  const [message, setMessage] = useState("Loading");
  const savedTweaksSnapshot = useRef("");
  const load = useCallback(async () => {
    try {
      const next = await getConfig();
      next.game = currentGame();
      next.selectedGame = next.game || null;
      savedTweaksSnapshot.current = JSON.stringify(next.tweaks);
      setConfig(next);
    } catch (error) {
      setMessage(String(error));
    }
  }, []);
  useEffect(() => {
    load();
  }, [load]);
  // Track the running game so opening the QAM mid-game edits that game's profile.
  useEffect(() => {
    if (!config) return;
    let cancelled = false;
    const refreshRuntime = () => {
      try {
        const runtimeGame = currentGame();
        if (cancelled) return;
        setConfig((current) => {
          if (!current) return current;
          if ((current.game?.appid || "") === (runtimeGame?.appid || "") && (current.game?.name || "") === (runtimeGame?.name || "")) return current;
          return { ...current, game: runtimeGame };
        });
      } catch (error) {
      }
    };
    const timer = window.setInterval(refreshRuntime, 2000);
    refreshRuntime();
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, [!!config]);
  usePatchTweaks({ config, field: "tweaks", snapshot: savedTweaksSnapshot, save: saveTweaks, setConfig, onError: load });

  if (!config) return <PanelSection title="CalvOS Control"><Field label={message} /></PanelSection>;

  const tabContent = (content: ReactNode) => (
    <div className="pocknix-control-tab-content">{content}</div>
  );
  // Tres pestanas y nada mas (11/11/2026): Juegos (Mesa por juego), Sistema (scheduler,
  // OLED care, calvos-doctor) y Actualizar (update + rollback). Library/Cleanup/LED siguen
  // en el repo, solo dejan de mostrarse.
  const tabs = [
    { id: "Games", title: tabIcons.Games, content: tabContent(<Games config={config} setConfig={setConfig} />) },
    { id: "System", title: tabIcons.System, content: tabContent(<System config={config} setConfig={setConfig} />) },
    { id: "Updater", title: tabIcons.Updater, content: tabContent(<Updater />) },
  ];
  return (
    <div className="pocknix-control-tabs">
      <style>{styles}</style>
      <Tabs activeTab={tab} onShowTab={setTab} tabs={tabs} />
    </div>
  );
}
