// Valve's fex-compat-tool reads STEAM_COMPAT_FEX_CONFIG at the top of the x86 launch chain,
// before our proton shim exists — a game's launch options are the only channel that reaches
// it. ARM Protons ignore the variable (wrapper FEX_APP_CONFIG path).

import type { FexProfile } from "../types";

const FEX_TOKEN = /STEAM_COMPAT_FEX_CONFIG=("[^"]*"|\S*)\s*/g;

/** "" = remove the token: "default"'s string equals Valve's own defaults exactly. */
export function fexSteamString(profileId: string | undefined, profiles: Record<string, FexProfile>): string {
  if (!profileId || profileId === "default") return "";
  return profiles[profileId]?.steam || "";
}

function getLaunchOptions(appid: string): Promise<string | null> {
  return new Promise((resolve) => {
    const apps = window.SteamClient?.Apps;
    if (!apps?.RegisterForAppDetails) return resolve(null);
    let registration: any;
    let timer: number | undefined;
    let done = false;
    const finish = (value: string | null) => {
      if (done) return;
      done = true;
      if (timer !== undefined) window.clearTimeout(timer);
      // Steam may call back before RegisterForAppDetails returns; unregister on a microtask.
      Promise.resolve().then(() => registration?.unregister?.());
      resolve(value);
    };
    timer = window.setTimeout(() => finish(null), 3000);
    try {
      registration = apps.RegisterForAppDetails(Number(appid), (details: any) => {
        finish(String(details?.strLaunchOptions ?? ""));
      });
    } catch (error) {
      finish(null);
    }
  });
}

/** Rewrites only our token, preserving the user's options; bails rather than clobber
 *  when the current value can't be read. */
export async function syncFexLaunchOption(appid: string, steam: string): Promise<void> {
  const apps = window.SteamClient?.Apps;
  if (!apps?.SetAppLaunchOptions) return;
  const current = await getLaunchOptions(appid);
  if (current === null) return;
  const stripped = current.replace(FEX_TOKEN, "").trim();
  let next: string;
  if (steam) {
    const rest = stripped.includes("%command%") ? stripped : ["%command%", stripped].filter(Boolean).join(" ");
    next = `STEAM_COMPAT_FEX_CONFIG=${steam} ${rest}`;
  } else {
    next = stripped === "%command%" ? "" : stripped;
  }
  if (next !== current.trim()) apps.SetAppLaunchOptions(Number(appid), next);
}

// MAKO Decky (Lossless Scaling frame generation) activates through a per-game launch option
// too: its wrapper exports the Vulkan-layer environment for that game only. It rides the same
// channel as the FEX token, so both edits rewrite the string in place and can coexist. The
// wrapper must sit after any KEY=VALUE assignments but before %command%, or the game runs
// unwrapped and MAKO silently does nothing.
const MAKO_WRAPPER = "/home/deck/.local/bin/mako-run";
const MAKO_TOKEN = /(?:\/home\/deck\/\.local\/bin\/mako-run|~\/\.local\/bin\/mako-run)\s*/g;
const MAKO_PRESENT = /(?:\/home\/deck\/\.local\/bin\/mako-run|~\/\.local\/bin\/mako-run)/;

/** true when the game's current launch options already run through the MAKO wrapper. */
export function makoEnabledIn(current: string): boolean {
  return MAKO_PRESENT.test(current);
}

/** Read a game's launch options; null when Steam will not report them (never clobber then). */
export function readLaunchOptions(appid: string): Promise<string | null> {
  return getLaunchOptions(appid);
}

/** Add or remove the MAKO wrapper, preserving every other token in the string. */
export async function syncMakoLaunchOption(appid: string, enabled: boolean): Promise<void> {
  const apps = window.SteamClient?.Apps;
  if (!apps?.SetAppLaunchOptions) return;
  const current = await getLaunchOptions(appid);
  if (current === null) return;
  const stripped = current.replace(MAKO_TOKEN, "").trim();
  let next: string;
  if (enabled) {
    next = stripped.includes("%command%")
      ? stripped.replace("%command%", `${MAKO_WRAPPER} %command%`)
      : [stripped, `${MAKO_WRAPPER} %command%`].filter(Boolean).join(" ");
  } else {
    next = stripped === "%command%" ? "" : stripped;
  }
  if (next !== current.trim()) apps.SetAppLaunchOptions(Number(appid), next);
}
