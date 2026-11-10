import { useCallback } from "react";
import type { Dispatch, MutableRefObject, SetStateAction } from "react";
import { getConfig, patchTweaks, saveTweaks } from "../backend";
import { diffFields } from "../lib/diffTweaks";
import type { Config, Tweaks } from "../types";
import { useDebouncedSave } from "./useDebouncedSave";

interface PatchTweaksOptions {
  config: Config | null;
  field: "tweaks";
  snapshot: MutableRefObject<string>;
  /** Whole-object write, only used when a game profile disappears entirely. */
  save?: (value: any) => Promise<Config>;
  setConfig: Dispatch<SetStateAction<Config | null>>;
  onError?: (error: unknown) => void;
  delay?: number;
}

/** Same debounce/unmount-flush lifecycle as useDebouncedSave, but sends only the fields that
 *  changed since the last acknowledged state so the QAM and the library modal don't clobber
 *  each other's edits. */
export function usePatchTweaks(options: PatchTweaksOptions) {
  const { config, field, snapshot, save: saveWhole = saveTweaks, setConfig, onError, delay } = options;
  const save = useCallback(async (next: Tweaks): Promise<Config> => {
    let prev: Tweaks;
    try {
      prev = JSON.parse(snapshot.current) as Tweaks;
    } catch (error) {
      prev = { global: {}, games: {} };
    }
    const prevGames = prev?.games || {};
    const nextGames = next?.games || {};
    const ids = new Set([...Object.keys(prevGames), ...Object.keys(nextGames)]);
    // A whole game disappears (rare): a field patch can't express that, so fall back to one
    // full save rather than leaving a stale profile behind.
    if ([...ids].some((id) => !(id in nextGames))) return saveWhole(next);

    let result: Config | null = null;
    const globalDiff = diffFields(prev?.global, next?.global);
    if (Object.keys(globalDiff).length) result = await patchTweaks("", globalDiff);
    for (const id of ids) {
      const gameDiff = diffFields(prevGames[id], nextGames[id]);
      if (Object.keys(gameDiff).length) result = await patchTweaks(id, gameDiff);
    }
    // Nothing field-level changed (e.g. only key order differs): re-read so the snapshot
    // matches what is actually stored.
    return result ?? (await getConfig());
  }, [snapshot, saveWhole]);

  useDebouncedSave({ config, field, snapshot, save, setConfig, onError, delay });
}
