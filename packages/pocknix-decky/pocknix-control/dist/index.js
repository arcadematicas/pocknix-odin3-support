const manifest = {"name":"CalvOS Control"};
const API_VERSION = 2;
const internalAPIConnection = window.__DECKY_SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED_deckyLoaderAPIInit;
if (!internalAPIConnection) {
    throw new Error('[@decky/api]: Failed to connect to the loader as as the loader API was not initialized. This is likely a bug in Decky Loader.');
}
let api;
try {
    api = internalAPIConnection.connect(API_VERSION, manifest.name);
}
catch {
    api = internalAPIConnection.connect(1, manifest.name);
    console.warn(`[@decky/api] Requested API version ${API_VERSION} but the running loader only supports version 1. Some features may not work.`);
}
if (api._version != API_VERSION) {
    console.warn(`[@decky/api] Requested API version ${API_VERSION} but the running loader only supports version ${api._version}. Some features may not work.`);
}
const call = api.call;
const toaster = api.toaster;
const openFilePicker = api.openFilePicker;
const definePlugin = (fn) => {
    return (...args) => {
        return fn(...args);
    };
};

const getConfig = () => call("get_config");
const sendReport = (text, kind, areas) => call("send_report", text, kind, areas);
const collectReport = (text, areas) => call("collect_report", text, areas);
const setScxScheduler = (scheduler) => call("set_scx_scheduler", scheduler);
const setScxMode = (mode) => call("set_scx_mode", mode);
const saveTweaks = (data) => call("save_tweaks", data);
const patchTweaks = (appid, fields) => call("patch_tweaks", appid, fields);
const exportConfig = (appid, name, basename, allowOverwrite) => call("export_config", appid, name, basename, allowOverwrite);
const configDir = () => call("config_dir");
const readConfig = (path) => call("read_config", path);
const applyConfig = (path, sourceAppid, targetAppid, targetName) => call("apply_config", path, sourceAppid, targetAppid, targetName);
const systemStatus = () => call("system_status");
// Escritorio: sabor de Plasma que se abre al salir del modo juego (plasma |
// plasma-mobile). El switch cierra Steam, asi que la UI no debe esperar nada mas.
const desktopFlavour = () => call("desktop_flavour");
const switchToDesktop = (name) => call("switch_to_desktop", name);
const oledCareStatus = () => call("oled_care_status");
const runOledRefresher = (duration, passes) => call("run_oled_refresher", duration, passes);
const checkUpdates = () => call("check_updates");
const startUpdate = () => call("start_update");
const updateStatus = () => call("update_status");
const snapshotStatus = () => call("snapshot_status");
const startRollback = (id) => call("start_rollback", id);
const rebootSystem = () => call("reboot_system");
const makoStatus = () => call("mako_status");

/** Campos que difieren entre dos objetos planos. Una clave que desaparece se manda como null. */
function diffFields(prev, next) {
    const out = {};
    const p = prev || {};
    const n = next || {};
    for (const key of new Set([...Object.keys(p), ...Object.keys(n)])) {
        if (!(key in n)) {
            out[key] = null;
            continue;
        }
        if (JSON.stringify(p[key]) !== JSON.stringify(n[key]))
            out[key] = n[key];
    }
    return out;
}

function useDebouncedSave(options) {
    const { config, field, snapshot, save, setConfig, onError, delay = 900 } = options;
    const value = config ? config[field] : undefined;
    // Latest unsaved edit; written by the debounce timer or the unmount flush below.
    const pending = SP_REACT.useRef(null);
    const flush = SP_REACT.useCallback(async () => {
        const entry = pending.current;
        if (!entry)
            return;
        pending.current = null;
        try {
            const next = await save(entry.value);
            snapshot.current = JSON.stringify(next[field]);
            setConfig((stored) => {
                if (!stored)
                    return next;
                if (JSON.stringify(stored[field]) !== entry.serialized)
                    return stored;
                return { ...stored, [field]: next[field] };
            });
        }
        catch (error) {
            onError?.(error);
        }
    }, [save, field, snapshot, setConfig, onError]);
    const flushRef = SP_REACT.useRef(flush);
    flushRef.current = flush;
    SP_REACT.useEffect(() => {
        if (!config || !snapshot.current)
            return;
        const current = JSON.stringify(value);
        if (current === snapshot.current) {
            pending.current = null;
            return;
        }
        pending.current = { value, serialized: current };
        const timer = window.setTimeout(() => flushRef.current(), delay);
        return () => window.clearTimeout(timer);
    }, [value]);
    // QAM panels unmount the moment the menu closes, and the cleanup above clears the only
    // pending timer: without this flush, any edit made <delay ms before closing is dropped.
    SP_REACT.useEffect(() => () => void flushRef.current(), []);
}

/** Same debounce/unmount-flush lifecycle as useDebouncedSave, but sends only the fields that
 *  changed since the last acknowledged state so the QAM and the library modal don't clobber
 *  each other's edits. */
function usePatchTweaks(options) {
    const { config, field, snapshot, save: saveWhole = saveTweaks, setConfig, onError, delay } = options;
    const save = SP_REACT.useCallback(async (next) => {
        let prev;
        try {
            prev = JSON.parse(snapshot.current);
        }
        catch (error) {
            prev = { global: {}, games: {} };
        }
        const prevGames = prev?.games || {};
        const nextGames = next?.games || {};
        const ids = new Set([...Object.keys(prevGames), ...Object.keys(nextGames)]);
        // A whole game disappears (rare): a field patch can't express that, so fall back to one
        // full save rather than leaving a stale profile behind.
        if ([...ids].some((id) => !(id in nextGames)))
            return saveWhole(next);
        let result = null;
        const globalDiff = diffFields(prev?.global, next?.global);
        if (Object.keys(globalDiff).length)
            result = await patchTweaks("", globalDiff);
        for (const id of ids) {
            const gameDiff = diffFields(prevGames[id], nextGames[id]);
            if (Object.keys(gameDiff).length)
                result = await patchTweaks(id, gameDiff);
        }
        // Nothing field-level changed (e.g. only key order differs): re-read so the snapshot
        // matches what is actually stored.
        return result ?? (await getConfig());
    }, [snapshot, saveWhole]);
    useDebouncedSave({ config, field, snapshot, save, setConfig, onError, delay });
}

function Icon({ path }) {
    return (SP_JSX.jsx("svg", { style: { display: "block" }, width: "20", height: "20", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: "2", strokeLinecap: "round", strokeLinejoin: "round", children: path }));
}
const tabIcons = {
    Games: (SP_JSX.jsx(Icon, { path: SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx("line", { x1: "6", x2: "10", y1: "11", y2: "11" }), SP_JSX.jsx("line", { x1: "8", x2: "8", y1: "9", y2: "13" }), SP_JSX.jsx("line", { x1: "15", x2: "15.01", y1: "12", y2: "12" }), SP_JSX.jsx("line", { x1: "18", x2: "18.01", y1: "10", y2: "10" }), SP_JSX.jsx("path", { d: "M17.32 5H6.68a4 4 0 0 0-3.978 3.59c-.006.052-.01.101-.017.152C2.604 9.416 2 14.456 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.414-1.414A2 2 0 0 1 9.828 16h4.344a2 2 0 0 1 1.414.586L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.545-.604-6.584-.685-7.258-.007-.05-.011-.1-.017-.151A4 4 0 0 0 17.32 5z" })] }) })),
    Library: (SP_JSX.jsx(Icon, { path: SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx("rect", { width: "18", height: "18", x: "3", y: "3", rx: "2" }), SP_JSX.jsx("path", { d: "M8 12h8" }), SP_JSX.jsx("path", { d: "M12 8v8" })] }) })),
    Updater: (SP_JSX.jsx(Icon, { path: SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx("path", { d: "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" }), SP_JSX.jsx("polyline", { points: "7 10 12 15 17 10" }), SP_JSX.jsx("line", { x1: "12", x2: "12", y1: "15", y2: "3" })] }) })),
    Lighting: (SP_JSX.jsx(Icon, { path: SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx("path", { d: "M9 18h6" }), SP_JSX.jsx("path", { d: "M10 22h4" }), SP_JSX.jsx("path", { d: "M15.09 14c.18-.98.65-1.74 1.41-2.5A4.65 4.65 0 0 0 18 8 6 6 0 0 0 6 8c0 1 .23 2.23 1.5 3.5A4.61 4.61 0 0 1 8.91 14" })] }) })),
    // Chip/ajustes: sistema (potencia, batería, brillo)
    System: (SP_JSX.jsx(Icon, { path: SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx("rect", { width: "16", height: "16", x: "4", y: "4", rx: "2" }), SP_JSX.jsx("rect", { width: "6", height: "6", x: "9", y: "9", rx: "1" }), SP_JSX.jsx("path", { d: "M9 2v2" }), SP_JSX.jsx("path", { d: "M15 2v2" }), SP_JSX.jsx("path", { d: "M9 20v2" }), SP_JSX.jsx("path", { d: "M15 20v2" }), SP_JSX.jsx("path", { d: "M2 9h2" }), SP_JSX.jsx("path", { d: "M2 15h2" }), SP_JSX.jsx("path", { d: "M20 9h2" }), SP_JSX.jsx("path", { d: "M20 15h2" })] }) })),
    // Escoba: limpieza de cachés
    Cleanup: (SP_JSX.jsx(Icon, { path: SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx("path", { d: "M3 21h18" }), SP_JSX.jsx("path", { d: "M12 3v8" }), SP_JSX.jsx("path", { d: "M8 11h8l1.5 6h-11z" })] }) })),
};

function gameDisplayName(game) {
    if (!game?.appid)
        return "";
    return game.name || `App ${game.appid}`;
}
// The backend lists every appmanifest in steamapps, tools included. app_type 4 = tool in
// Steam's appStore overview; this name pattern is the fallback when no overview exists.
const NON_GAME_NAME = /^(Proton[ 0-9]|Proton (Hotfix|EasyAntiCheat|BattlEye)|Steam Linux Runtime|Steamworks Common)/i;
function isGame(appid, name) {
    try {
        const overview = window.appStore?.GetAppOverviewByAppID?.(Number(appid));
        if (typeof overview?.app_type === "number")
            return overview.app_type !== 4;
    }
    catch (error) {
    }
    return !NON_GAME_NAME.test(name);
}
// Non-Steam shortcuts have no appmanifest, so only deckDesktopApps sees them. Their appids are
// unsigned and above 2^31, hence the >>> 0: some builds hand out the signed-int32 form.
function nonSteamShortcuts() {
    try {
        const ids = window.collectionStore?.deckDesktopApps?.apps;
        if (!ids?.values)
            return [];
        const shortcuts = [];
        for (const id of Array.from(ids.values())) {
            const appid = String(Number(id) >>> 0);
            if (!appid || appid === "0")
                continue;
            let name = "";
            try {
                name = window.appStore?.GetAppOverviewByAppID?.(Number(appid))?.display_name || "";
            }
            catch (error) {
            }
            shortcuts.push({ appid, name: name || `App ${appid}`, nonSteam: true });
        }
        return shortcuts;
    }
    catch (error) {
        return [];
    }
}
function availableGames(config) {
    const games = new Map();
    for (const game of config.installedGames || []) {
        if (game?.appid && isGame(String(game.appid), game.name || "")) {
            games.set(String(game.appid), { appid: String(game.appid), name: game.name || `App ${game.appid}` });
        }
    }
    for (const shortcut of nonSteamShortcuts()) {
        games.set(shortcut.appid, shortcut);
    }
    // Saved tweaks keep a game listed even when the lookups above miss it, so existing
    // per-game config can never become unreachable.
    for (const [appid, game] of Object.entries(config.tweaks?.games || {})) {
        if (game && typeof game === "object" && !games.has(String(appid))) {
            games.set(String(appid), { appid: String(appid), name: game.name || `App ${appid}`, nonSteam: Number(appid) >= 0x80000000 });
        }
    }
    return Array.from(games.values()).sort((a, b) => (a.nonSteam ? 1 : 0) - (b.nonSteam ? 1 : 0) || gameDisplayName(a).localeCompare(gameDisplayName(b)));
}
function editTargetOptions(config) {
    return [
        { data: "", label: "Default" },
        ...availableGames(config).map((game) => ({
            data: game.appid,
            label: game.nonSteam ? `${gameDisplayName(game)} · non-Steam` : gameDisplayName(game),
        })),
    ];
}
function currentGame() {
    const running = DFL.Router?.MainRunningApp || window.Router?.MainRunningApp;
    const appid = running?.appid;
    if (!appid)
        return null;
    const id = String(appid);
    let name = running?.display_name || running?.displayName || "";
    try {
        const details = window.appDetailsStore?.GetAppDetails?.(Number(id));
        name = details?.strDisplayName || details?.strName || details?.name || name;
    }
    catch (error) {
    }
    return { appid: id, name: name || `App ${id}` };
}

const styles = `
      .pocknix-control-tabs {
        height: 95%;
        width: 316px;
        position: fixed;
        margin-top: -12px;
        margin-left: -8px;
        overflow: hidden;
      }
      .pocknix-control-tabs > div > div:first-child::before {
        background: #0D141C;
        box-shadow: none;
        backdrop-filter: none;
      }
      .pocknix-control-tabs [role="tabpanel"] {
        padding-left: 0 !important;
        padding-right: 0 !important;
      }
      .pocknix-control-tabs .pocknix-control-tab-content {
        padding-bottom: 24px;
      }
      .pocknix-control-tabs .pocknix-log {
        font-family: monospace;
        font-size: 10px;
        line-height: 14px;
        word-break: break-all;
        white-space: pre-wrap;
      }
      .pocknix-control-tabs .pocknix-note {
        box-sizing: border-box;
        width: 100%;
        padding: 8px 16px 8px;
        font-size: 12px;
        line-height: 16px;
        opacity: 0.62;
        text-align: left;
        justify-content: flex-start;
        align-self: stretch;
      }
    `;

// Drives the same state as Steam's own per-game compatibility dropdown (SpecifyCompatTool +
// app details), so never store a shadow copy: the two UIs stay in sync by construction.


// Steam's tool list is only reachable through its react-query hook, which throws
// without Steam's QueryClient in context; a throwaway root under Steam's provider
// works from any tree (QAM panel, modals, import flow).
const steam = {
    hook: null,
    provider: null,
    client: null,
    createRoot: null,
};
function findSteam() {
    steam.hook || (steam.hook = DFL.findModuleExport((e) => typeof e === "function" && e.toString().includes("Failed to fetch available compat tools")));
    steam.provider || (steam.provider = DFL.findModuleExport((e) => {
        if (typeof e !== "function")
            return false;
        const src = e.toString();
        return src.length < 400 && /\.mount\(\)/.test(src) && /unmount\(\)/.test(src) && /children/.test(src);
    }));
    steam.client || (steam.client = DFL.findModuleExport((e) => e && typeof e === "object" && typeof e.getQueryCache === "function" && typeof e.invalidateQueries === "function"));
    steam.createRoot || (steam.createRoot = DFL.findModule((m) => typeof m?.createRoot === "function")?.createRoot);
    return !!(steam.hook && steam.provider && steam.client && steam.createRoot);
}
class ProbeBoundary extends SP_REACT.Component {
    constructor() {
        super(...arguments);
        this.state = { failed: false };
    }
    static getDerivedStateFromError() {
        return { failed: true };
    }
    componentDidCatch(error) {
        this.props.onError(error);
    }
    render() {
        return this.state.failed ? null : this.props.children;
    }
}
function steamCompatTools(appid) {
    return new Promise((resolve) => {
        let root = null;
        const finish = (tools) => {
            clearTimeout(timer);
            resolve(tools);
            setTimeout(() => root?.unmount(), 0);
        };
        const timer = setTimeout(() => finish([]), 10000);
        const Probe = () => {
            const [query] = steam.hook(Number(appid));
            if (query.status === "success")
                finish(fromSteam(query.data));
            else if (query.status === "error")
                finish([]);
            return null;
        };
        try {
            root = steam.createRoot(document.createElement("div"));
            root.render(SP_REACT.createElement(ProbeBoundary, { onError: () => finish([]) }, SP_REACT.createElement(steam.provider, { client: steam.client }, SP_REACT.createElement(Probe))));
        }
        catch {
            finish([]);
        }
    });
}
function fromSteam(data) {
    return (data?.tools ?? [])
        .filter((tool) => !tool.is_incompatible)
        .map((tool) => ({ name: String(tool.name ?? ""), label: String(tool.display_name || tool.name || "") }))
        .filter((tool) => tool.name);
}
async function availableCompatTools(appid) {
    const apps = window.SteamClient?.Apps;
    try {
        if (apps?.GetAvailableCompatTools) {
            const tools = await apps.GetAvailableCompatTools(Number(appid));
            if (!Array.isArray(tools))
                return [];
            return tools
                .map((tool) => ({
                name: String(tool?.strToolName ?? ""),
                label: String(tool?.strDisplayName ?? tool?.strToolName ?? ""),
            }))
                .filter((tool) => tool.name);
        }
        return findSteam() ? await steamCompatTools(appid) : [];
    }
    catch {
        return [];
    }
}
/** Live view of the game's current tool; fires again when it changes anywhere (incl. Steam's UI). */
function registerForCompatTool(appid, onChange) {
    const apps = window.SteamClient?.Apps;
    if (!apps?.RegisterForAppDetails)
        return () => { };
    const registration = apps.RegisterForAppDetails(Number(appid), (details) => {
        onChange(String(details?.strCompatToolName ?? ""));
    });
    return () => registration?.unregister?.();
}
function setCompatTool(appid, tool) {
    window.SteamClient?.Apps?.SpecifyCompatTool?.(Number(appid), tool);
}
/** Resolve an imported Proton pick against this device's tools. Unknown ARM-named tools
 *  fall back to the cachy ARM Proton; unknown x86-named ones to a Proton 11. */
function resolveCompatTool(wanted, tools) {
    if (!wanted)
        return { tool: "", fallback: false };
    if (tools.some((tool) => tool.name === wanted))
        return { tool: wanted, fallback: false };
    const haystack = (tool) => `${tool.name} ${tool.label}`;
    const isArm = /arm/i.test(wanted);
    const fallback = isArm
        ? tools.find((tool) => /cachy/i.test(haystack(tool)) && !/x86/i.test(haystack(tool)))
        : tools.find((tool) => /(^|\D)11(\D|$)/.test(haystack(tool)) && !/arm|cachy/i.test(haystack(tool)));
    return { tool: fallback?.name || "", fallback: true };
}

// Valve's fex-compat-tool reads STEAM_COMPAT_FEX_CONFIG at the top of the x86 launch chain,
// before our proton shim exists — a game's launch options are the only channel that reaches
// it. ARM Protons ignore the variable (wrapper FEX_APP_CONFIG path).
const FEX_TOKEN = /STEAM_COMPAT_FEX_CONFIG=("[^"]*"|\S*)\s*/g;
/** "" = remove the token: "default"'s string equals Valve's own defaults exactly. */
function fexSteamString(profileId, profiles) {
    if (!profileId || profileId === "default")
        return "";
    return profiles[profileId]?.steam || "";
}
function getLaunchOptions(appid) {
    return new Promise((resolve) => {
        const apps = window.SteamClient?.Apps;
        if (!apps?.RegisterForAppDetails)
            return resolve(null);
        let registration;
        let timer;
        let done = false;
        const finish = (value) => {
            if (done)
                return;
            done = true;
            if (timer !== undefined)
                window.clearTimeout(timer);
            // Steam may call back before RegisterForAppDetails returns; unregister on a microtask.
            Promise.resolve().then(() => registration?.unregister?.());
            resolve(value);
        };
        timer = window.setTimeout(() => finish(null), 3000);
        try {
            registration = apps.RegisterForAppDetails(Number(appid), (details) => {
                finish(String(details?.strLaunchOptions ?? ""));
            });
        }
        catch (error) {
            finish(null);
        }
    });
}
/** Rewrites only our token, preserving the user's options; bails rather than clobber
 *  when the current value can't be read. */
async function syncFexLaunchOption(appid, steam) {
    const apps = window.SteamClient?.Apps;
    if (!apps?.SetAppLaunchOptions)
        return;
    const current = await getLaunchOptions(appid);
    if (current === null)
        return;
    const stripped = current.replace(FEX_TOKEN, "").trim();
    let next;
    if (steam) {
        const rest = stripped.includes("%command%") ? stripped : ["%command%", stripped].filter(Boolean).join(" ");
        next = `STEAM_COMPAT_FEX_CONFIG=${steam} ${rest}`;
    }
    else {
        next = stripped === "%command%" ? "" : stripped;
    }
    if (next !== current.trim())
        apps.SetAppLaunchOptions(Number(appid), next);
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
function makoEnabledIn(current) {
    return MAKO_PRESENT.test(current);
}
/** Read a game's launch options; null when Steam will not report them (never clobber then). */
function readLaunchOptions(appid) {
    return getLaunchOptions(appid);
}
/** Add or remove the MAKO wrapper, preserving every other token in the string. */
async function syncMakoLaunchOption(appid, enabled) {
    const apps = window.SteamClient?.Apps;
    if (!apps?.SetAppLaunchOptions)
        return;
    const current = await getLaunchOptions(appid);
    if (current === null)
        return;
    const stripped = current.replace(MAKO_TOKEN, "").trim();
    let next;
    if (enabled) {
        next = stripped.includes("%command%")
            ? stripped.replace("%command%", `${MAKO_WRAPPER} %command%`)
            : [stripped, `${MAKO_WRAPPER} %command%`].filter(Boolean).join(" ");
    }
    else {
        next = stripped === "%command%" ? "" : stripped;
    }
    if (next !== current.trim())
        apps.SetAppLaunchOptions(Number(appid), next);
}
// Native games have no Proton wrapper, so a per-game Mesa pick would never reach them. The
// generic wrapper reads SteamAppId -> /etc/pocknix/game-tweaks.json at launch and exports the
// chosen ICD; putting it in the launch options once is enough, and later version changes in
// the panel apply without touching Steam again. Same channel and token discipline as MAKO:
// only our token is rewritten, everything else in the string survives.
const GAME_WRAPPER = "/usr/lib/pocknix/pocknix-game-wrapper";
const GAME_WRAPPER_TOKEN = /\/usr\/lib\/pocknix\/pocknix-game-wrapper\s*/g;
/** Add or remove the native Mesa wrapper, preserving every other launch-option token. */
async function syncGameWrapperLaunchOption(appid, enabled) {
    const apps = window.SteamClient?.Apps;
    if (!apps?.SetAppLaunchOptions)
        return;
    const current = await getLaunchOptions(appid);
    if (current === null)
        return;
    const stripped = current.replace(GAME_WRAPPER_TOKEN, "").trim();
    let next;
    if (enabled) {
        next = stripped.includes("%command%")
            ? stripped.replace("%command%", `${GAME_WRAPPER} %command%`)
            : [stripped, `${GAME_WRAPPER} %command%`].filter(Boolean).join(" ");
    }
    else {
        next = stripped === "%command%" ? "" : stripped;
    }
    if (next !== current.trim())
        apps.SetAppLaunchOptions(Number(appid), next);
}

function SelectEdit({ label, value, options, onChange }) {
    const rgOptions = options.map((option) => (typeof option === "string" ? { data: option, label: option } : option));
    return (SP_JSX.jsx(DFL.PanelSectionRow, { children: label === undefined ? (SP_JSX.jsx(DFL.Dropdown, { selectedOption: value, rgOptions: rgOptions, onChange: (option) => onChange(option.data) })) : (SP_JSX.jsx(DFL.DropdownItem, { label: label, selectedOption: value, rgOptions: rgOptions, onChange: (option) => onChange(option.data) })) }));
}

// Audio buffer (PULSE_LATENCY_MSEC): absorbs FEX-mixer overruns (SFX-burst crackle) at the
// cost of audio latency — keep rhythm games on Game default. 60 measured ~10x fewer underruns.
const audioLatencyOptions = [
    { data: "", label: "Game default" },
    { data: "60", label: "60 ms" },
    { data: "90", label: "90 ms" },
    { data: "120", label: "120 ms" },
];
const lavdOptions = [
    { data: "autopilot", label: "Autopilot" },
    { data: "performance", label: "Performance" },
];
const scxSchedulerOptions = [
    { data: "auto", label: "Auto (perfil QAM)" },
    { data: "lavd", label: "LAVD (Valve)" },
    { data: "bpfland", label: "BPFLAND (handheld)" },
];
const scxModeOptions = {
    lavd: [
        { data: "autopilot", label: "Autopilot" },
        { data: "performance", label: "Performance" },
        { data: "balanced", label: "Balanced" },
        { data: "powersave", label: "Powersave" },
    ],
    bpfland: [
        { data: "default", label: "Default" },
        { data: "performance", label: "Performance" },
        { data: "powersave", label: "Powersave" },
    ],
};
// The proton wrapper resolves "big" against the board's POCKNIX_BIG_CORES mask.
const cpuPinOptions = [
    { data: "", label: "All cores" },
    { data: "big", label: "Big cores only" },
];
const globalChoice = { data: "", label: "Use global" };
function EnvVarsModal({ initial, onSave, closeModal }) {
    const [value, setValue] = SP_REACT.useState(initial);
    return (SP_JSX.jsx(DFL.ConfirmModal, { strTitle: "Environment Variables", strDescription: 'Space-separated KEY=VALUE pairs; quote values with spaces, e.g. DXVK_CONFIG="dxgi.customDeviceDesc = GTX 480". Steam launch options win over these.', strOKButtonText: "Save", onCancel: () => closeModal?.(), onOK: () => {
            onSave(value.trim());
            closeModal?.();
        }, children: SP_JSX.jsx(DFL.TextField, { label: "Variables", value: value, onChange: (event) => setValue(event.target.value) }) }));
}
function EnvVarsButton({ value, onSave }) {
    return (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", description: value ? value : "None set", onClick: () => DFL.showModal(SP_JSX.jsx(EnvVarsModal, { initial: value, onSave: onSave })), children: "Environment Variables" }) }));
}
/** Per-game scheduler overrides ("" = follow the global mode). */
function PerfFields({ values, patch }) {
    const perGameLavd = [globalChoice, ...lavdOptions];
    const lavdValue = perGameLavd.some((option) => option.data === String(values.lavdMode ?? "")) ? String(values.lavdMode ?? "") : "";
    const pinValue = cpuPinOptions.some((option) => option.data === String(values.cpuPin ?? "")) ? String(values.cpuPin ?? "") : "";
    return (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx(SelectEdit, { label: "CPU Scheduler", value: lavdValue, options: perGameLavd, onChange: (id) => patch({ lavdMode: id }) }), SP_JSX.jsx(SelectEdit, { label: "CPU Cores", value: pinValue, options: cpuPinOptions, onChange: (id) => patch({ cpuPin: id }) })] }));
}
/** The per-game tweak controls, shared by the Games tab and the library context-menu modal. */
function TweakFields({ config, appid, values, patch }) {
    // Proton pick is Steam's own per-game compat setting (see lib/compat.ts) — read live and
    // written straight back to Steam, so it mirrors the game-properties dropdown both ways.
    const [compatTools, setCompatTools] = SP_REACT.useState([]);
    const [currentTool, setCurrentTool] = SP_REACT.useState("");
    SP_REACT.useEffect(() => {
        setCompatTools([]);
        setCurrentTool("");
        if (!appid)
            return;
        let live = true;
        availableCompatTools(appid).then((tools) => {
            if (live)
                setCompatTools(tools);
        });
        const unregister = registerForCompatTool(appid, (tool) => {
            if (live)
                setCurrentTool(tool);
        });
        return () => {
            live = false;
            unregister();
        };
    }, [appid]);
    const compatOptions = [
        { data: "", label: "Steam default" },
        ...compatTools.map((tool) => ({ data: tool.name, label: tool.label })),
    ];
    const compatValue = compatOptions.some((option) => option.data === currentTool) ? currentTool : "";
    const presets = config.fexProfiles || {};
    const storedProfile = values.fexProfile;
    const fexValue = storedProfile && presets[storedProfile] ? storedProfile : "default";
    const fexOptions = Object.entries(presets).map(([id, profile]) => ({ data: id, label: profile.label }));
    const storedLatency = String(values.audioLatency ?? "");
    const audioValue = audioLatencyOptions.some((option) => option.data === storedLatency) ? storedLatency : "";
    const mesaOptions = [{ data: "", label: "System default" }, ...(config.mesaVersions || [])];
    const storedMesa = String(values.mesaVersion ?? "");
    const mesaValue = mesaOptions.some((option) => option.data === storedMesa) ? storedMesa : "";
    return (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx(SelectEdit, { label: "Proton Version", value: compatValue, options: compatOptions, onChange: (name) => {
                    setCurrentTool(String(name));
                    setCompatTool(appid, String(name));
                } }), SP_JSX.jsx(SelectEdit, { label: "FEX Preset", value: fexValue, options: fexOptions, onChange: (id) => {
                    patch({ fexProfile: id });
                    syncFexLaunchOption(appid, fexSteamString(String(id), presets));
                } }), SP_JSX.jsx(SelectEdit, { label: "Audio Buffer", value: audioValue, options: audioLatencyOptions, onChange: (id) => patch({ audioLatency: id }) }), SP_JSX.jsx(SelectEdit, { label: "Mesa Version", value: mesaValue, options: mesaOptions, onChange: (id) => patch({ mesaVersion: id }) }), SP_JSX.jsx(EnvVarsButton, { value: String(values.envVars ?? ""), onSave: (next) => patch({ envVars: next }) })] }));
}

// Sabores de escritorio instalados en la consola (backend: py_modules/desktop.py).
const SABORES = {
    plasma: "Plasma de escritorio",
    "plasma-mobile": "Plasma Mobile",
};
// Areas del informe. "logs" es la pesada: apagada por defecto para que enviar sea rapido.
const AREAS = [
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
const voltios = (uv) => (uv == null ? null : `${(uv / 1000000).toFixed(2)} V`);
const amperios = (ua) => (ua == null ? null : `${(ua / 1000000).toFixed(2)} A`);
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
function hace(ts) {
    if (!ts)
        return "todavía no";
    const s = Math.max(0, Math.floor(Date.now() / 1000) - ts);
    if (s < 60)
        return `hace ${s} s`;
    if (s < 3600)
        return `hace ${Math.floor(s / 60)} min`;
    return `hace ${Math.floor(s / 3600)} h`;
}
function System({ config, setConfig }) {
    const [status, setStatus] = SP_REACT.useState(null);
    const [error, setError] = SP_REACT.useState("");
    const [texto, setTexto] = SP_REACT.useState("");
    const [enviando, setEnviando] = SP_REACT.useState(false);
    const [informe, setInforme] = SP_REACT.useState(null);
    const [kind, setKind] = SP_REACT.useState("bug");
    const [areas, setAreas] = SP_REACT.useState(() => {
        const on = {};
        for (const [id] of AREAS)
            on[id] = id !== "logs";
        return on;
    });
    const [sabor, setSabor] = SP_REACT.useState("");
    const [cambiando, setCambiando] = SP_REACT.useState(false);
    const [fallo, setFallo] = SP_REACT.useState("");
    const [guardando, setGuardando] = SP_REACT.useState(false);
    const [guardado, setGuardado] = SP_REACT.useState(null);
    const [oled, setOled] = SP_REACT.useState(null);
    const [refresherMsg, setRefresherMsg] = SP_REACT.useState(null);
    SP_REACT.useEffect(() => {
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
    const applyMode = async (setter, mode) => {
        try {
            const next = await setter(mode);
            setConfig((current) => (current ? { ...current, lavdMode: next.lavdMode, scxScheduler: next.scxScheduler, scxMode: next.scxMode } : current));
        }
        catch (err) {
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
    const cambiarAEscritorio = async (name) => {
        setCambiando(true);
        setFallo("");
        try {
            await switchToDesktop(name);
            setSabor(name);
        }
        catch (err) {
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
        }
        catch (err) {
            setGuardado({ ok: false, error: String(err) });
        }
        finally {
            setGuardando(false);
        }
    };
    const enviarInforme = async () => {
        setEnviando(true);
        setInforme(null);
        try {
            setInforme(await sendReport(texto, kind, Object.keys(areas).filter((k) => areas[k])));
        }
        catch (err) {
            setInforme({ ok: false, error: String(err) });
        }
        finally {
            setEnviando(false);
        }
    };
    return (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsxs(DFL.PanelSection, { title: "RENDIMIENTO", children: [SP_JSX.jsx(SelectEdit, { label: "Scheduler", value: config.scxScheduler || "auto", options: scxSchedulerOptions, onChange: (mode) => applyMode(setScxScheduler, mode) }), config.scxScheduler === "auto" ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "Scheduler activo", description: config.scxEffective || "—" }) })) : (SP_JSX.jsx(SelectEdit, { label: "Scheduler Mode", value: config.scxMode, options: scxModeOptions[config.scxScheduler || ""] || lavdOptions, onChange: (mode) => applyMode(setScxMode, mode) }))] }), SP_JSX.jsxs(DFL.PanelSection, { title: "OLED CARE", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", description: "Refresco anti retenci\u00F3n (ruido a pantalla completa, ~9 s).", onClick: runRefresher, children: "Run Pixel Refresher" }) }), refresherMsg ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "", description: refresherMsg }) })) : null, SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "Autom\u00E1tico", description: oled && !oled.available
                                ? "No disponible en este equipo."
                                : oled && !oled.daemonUp
                                    ? "Daemon parado (sin estado todavía)."
                                    : oled
                                        ? `Cada ${Math.round(oled.idleSeconds / 60)} min inactivo · último: ${hace(oled.lastRefresh)} (${oled.count})`
                                        : "…" }) }), oled?.lastSkip ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u00DAltimo omitido", description: oled.lastSkip }) })) : null] }), SP_JSX.jsxs(DFL.PanelSection, { title: "BATER\u00CDA", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: b?.capacity != null ? `${b.capacity}%` : "…", description: detalle || "…" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "", description: "El perfil de potencia est\u00E1 en el men\u00FA de Steam (\u22EF \u2192 Rendimiento). El brillo, en los controles nativos." }) })] }), SP_JSX.jsxs(DFL.PanelSection, { title: "ESCRITORIO", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: sabor ? `Ahora: ${SABORES[sabor] || sabor}` : "Ahora: …", description: "El escritorio que se abre al salir del modo juego." }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Button, { onClick: () => cambiarAEscritorio("plasma"), disabled: cambiando, children: "Cambiar a Plasma (escritorio)" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Button, { onClick: () => cambiarAEscritorio("plasma-mobile"), disabled: cambiando, children: "Cambiar a Plasma Mobile" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { description: cambiando
                                ? "Cerrando el modo juego…"
                                : "Steam se cerrará y la consola abrirá el escritorio elegido." }) }), fallo ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "No se pudo cambiar", description: fallo }) })) : null] }), error ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "Error", description: error }) })) : null, SP_JSX.jsxs(DFL.PanelSection, { title: "INFORME", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { description: "Que quieres mandar:" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Button, { onClick: () => setKind("bug"), children: (kind === "bug" ? "● " : "○ ") + "Reportar un problema" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Button, { onClick: () => setKind("idea"), children: (kind === "idea" ? "● " : "○ ") + "Sugerir una mejora" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { description: "Que incluyo:" }) }), AREAS.map(([id, label, desc]) => (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: label, description: desc, checked: !!areas[id], onChange: (v) => setAreas({ ...areas, [id]: v }) }) }, id))), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.TextField, { label: "Descripcion (opcional)", value: texto, onChange: (e) => setTexto(e.target.value) }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Button, { onClick: guardarInforme, disabled: guardando || !Object.values(areas).some(Boolean), children: guardando ? "Recogiendo..." : "Guardar informe (sin enviar)" }) }), guardado ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: guardado.ok ? "Informe guardado" : "No se pudo recoger", description: guardado.ok ? (guardado.path || "") : [guardado.error, guardado.detail].filter(Boolean).join(" — ") }) })) : null, SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Button, { onClick: enviarInforme, disabled: enviando || !Object.values(areas).some(Boolean), children: enviando ? "Enviando..." : "Enviar informe" }) }), informe ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: informe.ok ? "Informe enviado" : "No se pudo enviar", description: informe.ok ? (informe.issue || "") : [informe.error, informe.detail].filter(Boolean).join(" — ") }) })) : null, SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "", description: "Se envia a nuestro GitHub (arcadematicas/calvOS-reports). El informe se redacta antes de salir: sin rutas de usuario, hostname, IP, MAC ni claves." }) })] })] }));
}

function clone(obj) {
    return JSON.parse(JSON.stringify(obj));
}

// Pestana Juegos: solo la seleccion de Mesa por juego. El scheduler vive en Sistema y el
// resto de ajustes (FEX, audio, env) se retiraron de la UI el 11/11/2026: no se usaban y
// hacian que este plugin pareciese un segundo panel de control.
function Games({ config, setConfig }) {
    const runtimeGame = config.game;
    const games = availableGames(config);
    const game = config.selectedGame || runtimeGame || null;
    const appid = game?.appid || "";
    const tweaks = config.tweaks;
    const settings = appid ? tweaks.games[appid] || {} : {};
    const perGameEnabled = !!(appid && settings.enabled === true);
    // Un juego es "nativo" cuando Steam no le asigna herramienta de compatibilidad. Solo en
    // ese caso tiene sentido meter el wrapper: a un juego de Proton le pondriamos un ICD de
    // ARM y lo dejariamos sin driver (el wrapper de Proton ya resuelve su Mesa). "known"
    // evita decidir con el valor inicial vacio antes de que Steam conteste.
    const [known, setKnown] = SP_REACT.useState(false);
    const [native, setNative] = SP_REACT.useState(false);
    SP_REACT.useEffect(() => {
        setKnown(false);
        setNative(false);
        if (!appid)
            return;
        let live = true;
        // Llamada redundante a proposito: fuerza la carga del hook de Steam y, si el callback
        // no llega, dejamos known=false y no tocamos las launch options.
        availableCompatTools(appid).catch(() => { });
        const unregister = registerForCompatTool(appid, (tool) => {
            if (!live)
                return;
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
    const patchMesa = (value) => {
        setConfig((current) => {
            if (!current || !appid)
                return current;
            const next = clone(current);
            next.tweaks.games[appid] = { ...(next.tweaks.games[appid] || {}), enabled: true, name: game?.name || "", mesaVersion: value };
            return next;
        });
        if (known && native)
            void syncGameWrapperLaunchOption(appid, value !== "");
    };
    const setPerGameEnabled = (enabled) => {
        if (!appid)
            return;
        setConfig((current) => {
            if (!current)
                return current;
            const next = clone(current);
            next.tweaks.games[appid] = { ...(next.tweaks.games[appid] || {}), enabled, name: game?.name || "" };
            return next;
        });
        if (known && native)
            void syncGameWrapperLaunchOption(appid, enabled && mesa !== "");
    };
    // "" is the explicit Default target, not "nothing selected"; store a sentinel so it does
    // not fall back to the running game in the selectedGame derivation.
    const setSelectedGame = (value) => {
        const id = String(value);
        if (!id) {
            setConfig((current) => (current ? { ...current, selectedGame: { appid: "", name: "Default" } } : current));
            return;
        }
        const saved = games.find((candidate) => candidate.appid === id);
        setConfig((current) => (current ? { ...current, selectedGame: saved || null } : current));
    };
    return (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsxs(DFL.PanelSection, { title: "JUEGO", children: [SP_JSX.jsx(SelectEdit, { label: "Game", value: appid, options: editTargetOptions(config), onChange: setSelectedGame }), appid ? (SP_JSX.jsx(DFL.ToggleField, { label: "Usar ajustes por juego", checked: perGameEnabled, onChange: setPerGameEnabled })) : null] }), !appid ? (SP_JSX.jsx(DFL.PanelSection, { title: "MESA (VULKAN)", children: SP_JSX.jsx("div", { className: "pocknix-note", children: "Elige un juego para asignarle una versi\u00F3n de Mesa." }) })) : perGameEnabled ? (SP_JSX.jsxs(DFL.PanelSection, { title: "MESA (VULKAN)", children: [SP_JSX.jsx(SelectEdit, { label: "Mesa Version", value: mesa, options: mesaOptions, onChange: patchMesa }), SP_JSX.jsx("div", { className: "pocknix-note", children: known && !native
                            ? "Este juego usa Proton: su Mesa se elige en el wrapper de Proton."
                            : "Se aplica al arrancar el juego (AppImage, .sh o binario)." })] })) : (SP_JSX.jsx(DFL.PanelSection, { title: "MESA (VULKAN)", children: SP_JSX.jsx("div", { className: "pocknix-note", children: "Activa \"Usar ajustes por juego\" para elegir la versi\u00F3n de Mesa." }) }))] }));
}

const SHOWN_UPDATES = 8;
const gib = (bytes) => (bytes / 1024 ** 3).toFixed(1);
// snapshot metadata stores ISO-8601 UTC; show local DD/MM/YYYY HH:MM
const fmtDate = (iso) => {
    const d = new Date(iso);
    if (isNaN(d.getTime()))
        return iso;
    const p = (n) => String(n).padStart(2, "0");
    return `${p(d.getDate())}-${p(d.getMonth() + 1)}-${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`;
};
function Updater() {
    const [updates, setUpdates] = SP_REACT.useState(null);
    const [checking, setChecking] = SP_REACT.useState(false);
    const [status, setStatus] = SP_REACT.useState(null);
    const [snap, setSnap] = SP_REACT.useState(null);
    const [rollingBack, setRollingBack] = SP_REACT.useState(false);
    const [rollbackDone, setRollbackDone] = SP_REACT.useState(false);
    const [error, setError] = SP_REACT.useState("");
    const [rollbackError, setRollbackError] = SP_REACT.useState("");
    const busyRef = SP_REACT.useRef(false);
    const running = !!status?.running;
    busyRef.current = checking || running || rollingBack;
    const refreshSnap = () => snapshotStatus().then(setSnap).catch(() => { });
    // Re-attach to an update that survived a QAM close (or a Steam restart).
    SP_REACT.useEffect(() => {
        let cancelled = false;
        updateStatus()
            .then((next) => {
            if (!cancelled && (next.running || next.exitCode !== null))
                setStatus(next);
        })
            .catch(() => { });
        refreshSnap();
        return () => {
            cancelled = true;
        };
    }, []);
    SP_REACT.useEffect(() => {
        if (!running)
            return;
        const timer = window.setInterval(async () => {
            try {
                const next = await updateStatus();
                setStatus(next);
                if (!next.running) {
                    if (next.exitCode === 0)
                        setUpdates([]);
                    refreshSnap(); // a finished transaction changes snapshots + reboot-required
                }
            }
            catch (err) {
                setError(String(err));
            }
        }, 2000);
        return () => window.clearInterval(timer);
    }, [running]);
    const check = async () => {
        if (busyRef.current)
            return;
        setChecking(true);
        setError("");
        try {
            setUpdates(await checkUpdates());
        }
        catch (err) {
            setError(String(err));
        }
        finally {
            setChecking(false);
        }
    };
    const start = async () => {
        if (busyRef.current)
            return;
        setError("");
        try {
            setStatus(await startUpdate());
        }
        catch (err) {
            setError(String(err));
        }
    };
    const confirmStart = () => DFL.showModal(SP_JSX.jsx(DFL.ConfirmModal, { strTitle: "Install Updates", strDescription: "Downloads and installs all available system updates. Keep the device powered; a running game may stutter. Restart after it finishes.", strOKButtonText: "Install", onOK: start }));
    const lastSnapshot = snap?.supported && snap.snapshots.length > 0 ? snap.snapshots[snap.snapshots.length - 1] : null;
    // Already rolled back onto the latest snapshot: another rollback would be a no-op,
    // so hide the button until the next update (which clears the marker + snapshots anew).
    const onLastSnapshot = !!(snap?.rolledBack && lastSnapshot && snap.rolledBack.fromSnapshot === lastSnapshot.id);
    const rollBack = async () => {
        if (busyRef.current || !lastSnapshot)
            return;
        setRollbackError("");
        setRollingBack(true);
        try {
            setSnap(await startRollback(lastSnapshot.id));
            setRollbackDone(true);
        }
        catch (err) {
            setRollbackError(String(err));
        }
        finally {
            setRollingBack(false);
        }
    };
    const confirmRollback = () => {
        if (!lastSnapshot)
            return;
        DFL.showModal(SP_JSX.jsx(DFL.ConfirmModal, { strTitle: "Roll Back Last Update", strDescription: `Restores the system to before the update of ${fmtDate(lastSnapshot.created)}` +
                (lastSnapshot.targets ? ` (${lastSnapshot.targets})` : "") +
                `. Games, saves and settings are kept.` +
                (lastSnapshot.kernel ? " The previous kernel is restored too." : "") +
                ` Reboot after it completes.`, strOKButtonText: "Roll Back", onOK: rollBack }));
    };
    const reboot = () => rebootSystem().catch((err) => setError(String(err)));
    const finished = !running && status?.exitCode !== null && status?.exitCode !== undefined;
    const summary = updates === null
        ? "Not checked yet"
        : updates.length === 0
            ? "System is up to date"
            : `${updates.length} update${updates.length === 1 ? "" : "s"} available`;
    return (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsxs(DFL.PanelSection, { title: "SYSTEM UPDATES", children: [!running ? SP_JSX.jsx(DFL.Field, { label: "Status", description: summary }) : null, !running && updates && updates.length > 0 ? (SP_JSX.jsxs("div", { className: "pocknix-note", children: [updates.slice(0, SHOWN_UPDATES).map((update) => (SP_JSX.jsx("div", { children: `${update.name} ${update.current} → ${update.latest}` }, update.name))), updates.length > SHOWN_UPDATES ? SP_JSX.jsx("div", { children: `… and ${updates.length - SHOWN_UPDATES} more` }) : null] })) : null, SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", disabled: busyRef.current, onClick: check, children: checking ? "Checking…" : "Check for Updates" }) }), !running && updates && updates.length > 0 ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", disabled: busyRef.current, onClick: confirmStart, children: "Install Updates" }) })) : null, running ? SP_JSX.jsx(DFL.Field, { label: "Updating\u2026", description: "Safe to close this menu. Do not power off." }) : null, finished ? (SP_JSX.jsx(DFL.Field, { label: status.exitCode === 0 ? "Update complete" : `Update failed (code ${status.exitCode})`, description: status.exitCode === 0 ? "Restart to finish applying updates." : "See the log below." })) : null, finished && status.exitCode === 0 ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: reboot, children: "Restart Now" }) })) : null, (running || (finished && status.exitCode !== 0)) && status?.log ? (SP_JSX.jsx("div", { className: "pocknix-note pocknix-log", children: status.log })) : null, error ? SP_JSX.jsx(DFL.Field, { label: "Error", description: error }) : null] }), snap?.supported ? (SP_JSX.jsxs(DFL.PanelSection, { title: "ROLLBACK", children: [snap.rolledBack && !rollbackDone ? (SP_JSX.jsx(DFL.Field, { label: "System was rolled back", description: `Restored from snapshot ${snap.rolledBack.fromSnapshot} (${fmtDate(snap.rolledBack.ts)}).${onLastSnapshot ? " Rollback will be available again after the next update." : ""}` })) : null, rollbackDone ? (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx(DFL.Field, { label: "Rolled back", description: "Reboot to finish switching to the restored system." }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: reboot, children: "Reboot Now" }) })] })) : onLastSnapshot ? null : lastSnapshot ? (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx(DFL.Field, { label: "Last snapshot", description: `${fmtDate(lastSnapshot.created)}${lastSnapshot.targets ? ` — ${lastSnapshot.targets}` : ""}` }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", disabled: busyRef.current, onClick: confirmRollback, children: rollingBack ? "Rolling back…" : "Roll Back Last Update" }) })] })) : (SP_JSX.jsx(DFL.Field, { label: "No snapshots yet", description: "A snapshot is taken automatically before every update." })), rollbackError ? SP_JSX.jsx(DFL.Field, { label: "Rollback error", description: rollbackError }) : null, SP_JSX.jsx(DFL.Field, { label: "Storage", description: `${gib(snap.freeBytes)} GB free${snap.lowSpace ? " — LOW: snapshots may be skipped" : ""}` })] })) : null] }));
}

function Content() {
    const [tab, setTab] = SP_REACT.useState("Games");
    const [config, setConfig] = SP_REACT.useState(null);
    const [message, setMessage] = SP_REACT.useState("Loading");
    const savedTweaksSnapshot = SP_REACT.useRef("");
    const load = SP_REACT.useCallback(async () => {
        try {
            const next = await getConfig();
            next.game = currentGame();
            next.selectedGame = next.game || null;
            savedTweaksSnapshot.current = JSON.stringify(next.tweaks);
            setConfig(next);
        }
        catch (error) {
            setMessage(String(error));
        }
    }, []);
    SP_REACT.useEffect(() => {
        load();
    }, [load]);
    // Track the running game so opening the QAM mid-game edits that game's profile.
    SP_REACT.useEffect(() => {
        if (!config)
            return;
        let cancelled = false;
        const refreshRuntime = () => {
            try {
                const runtimeGame = currentGame();
                if (cancelled)
                    return;
                setConfig((current) => {
                    if (!current)
                        return current;
                    if ((current.game?.appid || "") === (runtimeGame?.appid || "") && (current.game?.name || "") === (runtimeGame?.name || ""))
                        return current;
                    return { ...current, game: runtimeGame };
                });
            }
            catch (error) {
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
    if (!config)
        return SP_JSX.jsx(DFL.PanelSection, { title: "CalvOS Control", children: SP_JSX.jsx(DFL.Field, { label: message }) });
    const tabContent = (content) => (SP_JSX.jsx("div", { className: "pocknix-control-tab-content", children: content }));
    // Tres pestanas y nada mas (11/11/2026): Juegos (Mesa por juego), Sistema (scheduler,
    // OLED care, calvos-doctor) y Actualizar (update + rollback). Library/Cleanup/LED siguen
    // en el repo, solo dejan de mostrarse.
    const tabs = [
        { id: "Games", title: tabIcons.Games, content: tabContent(SP_JSX.jsx(Games, { config: config, setConfig: setConfig })) },
        { id: "System", title: tabIcons.System, content: tabContent(SP_JSX.jsx(System, { config: config, setConfig: setConfig })) },
        { id: "Updater", title: tabIcons.Updater, content: tabContent(SP_JSX.jsx(Updater, {})) },
    ];
    return (SP_JSX.jsxs("div", { className: "pocknix-control-tabs", children: [SP_JSX.jsx("style", { children: styles }), SP_JSX.jsx(DFL.Tabs, { activeTab: tab, onShowTab: setTab, tabs: tabs })] }));
}

function ExportNameModal({ game, base, onDone, closeModal }) {
    const [value, setValue] = SP_REACT.useState(base);
    const [busy, setBusy] = SP_REACT.useState(false);
    const overwriting = value.trim() === base;
    const submit = async () => {
        if (busy || !value.trim())
            return;
        setBusy(true);
        try {
            const result = await exportConfig(game.appid, game.name, value.trim(), true);
            onDone(result.path);
        }
        catch (error) {
            toaster.toast({ title: "Export failed", body: String(error) });
        }
        closeModal?.();
    };
    return (SP_JSX.jsx(DFL.ConfirmModal, { strTitle: "Config Already Exists", strDescription: `${base}.pocknix.json exists. Change the name to save a new config (e.g. ${base}-2 or ${base}-fast), or keep it to overwrite.`, strOKButtonText: busy ? "Saving…" : overwriting ? "Overwrite" : "Save New", bOKDisabled: busy || !value.trim(), onCancel: () => closeModal?.(), onOK: submit, children: SP_JSX.jsx(DFL.TextField, { label: "Name", value: value, disabled: busy, onChange: (event) => setValue(event.target.value) }) }));
}
function ImportModal({ path, preview, game, onDone, closeModal }) {
    const profiles = preview.games;
    const [source, setSource] = SP_REACT.useState(profiles[0]?.appid || "");
    const [busy, setBusy] = SP_REACT.useState(false);
    const from = [preview.device, preview.exported].filter(Boolean).join(", ");
    const profileOptions = profiles.map((profile) => ({ data: profile.appid, label: profile.name || profile.appid }));
    const submit = async () => {
        if (busy || !source)
            return;
        setBusy(true);
        try {
            const result = await applyConfig(path, source, game.appid, game.name);
            try {
                const cfg = await getConfig();
                const profile = result.enabled ? String(result.fexProfile || cfg.tweaks.global.fexProfile || "") : "";
                await syncFexLaunchOption(game.appid, fexSteamString(profile, cfg.fexProfiles));
            }
            catch (error) {
            }
            if (result.protonTool) {
                const tools = await availableCompatTools(game.appid);
                const resolved = resolveCompatTool(result.protonTool, tools);
                if (resolved.tool) {
                    setCompatTool(game.appid, resolved.tool);
                    if (resolved.fallback) {
                        toaster.toast({ title: "Proton fallback", body: `${result.protonTool} not available, using ${resolved.tool}` });
                    }
                }
                else {
                    toaster.toast({ title: "Proton pick skipped", body: `${result.protonTool} not available here` });
                }
            }
            toaster.toast({ title: "Config applied", body: game.name || game.appid });
        }
        catch (error) {
            toaster.toast({ title: "Import failed", body: String(error) });
        }
        closeModal?.();
        onDone();
    };
    return (SP_JSX.jsx(DFL.ConfirmModal, { strTitle: "Import Game Config", strDescription: (from ? `Exported from ${from}. ` : "") + `Settings for ${game.name || game.appid} will be overwritten.`, strOKButtonText: busy ? "Applying…" : "Apply", bOKDisabled: busy || !source, onCancel: () => closeModal?.(), onOK: submit, children: profiles.length > 1 ? (SP_JSX.jsx(SelectEdit, { label: "Profile", value: source, options: profileOptions, onChange: (id) => setSource(String(id)) })) : (SP_JSX.jsxs("div", { className: "pocknix-note", children: ["Profile: ", profiles[0]?.name || profiles[0]?.appid] })) }));
}
/** Per-game config export/import; rendered only when a game's per-game settings are enabled. */
function ConfigSection({ game, reload }) {
    const doExport = async () => {
        try {
            const result = await exportConfig(game.appid, game.name || "", "", false);
            if (result.exists) {
                DFL.showModal(SP_JSX.jsx(ExportNameModal, { game: { appid: game.appid, name: game.name || "" }, base: result.base, onDone: (path) => toaster.toast({ title: "Game config exported", body: path }) }));
                return;
            }
            toaster.toast({ title: "Game config exported", body: result.path });
        }
        catch (error) {
            toaster.toast({ title: "Export failed", body: String(error) });
        }
    };
    const doImport = async () => {
        let path = "";
        try {
            const dir = await configDir().catch(() => "/home/deck");
            // 0 = FileSelectionType.FILE (same const-enum note as AddGame).
            const picked = await openFilePicker(0, dir, true, true);
            path = picked?.path || "";
        }
        catch (error) {
            return; // picker closed without a selection
        }
        if (!path)
            return;
        try {
            const preview = await readConfig(path);
            DFL.showModal(SP_JSX.jsx(ImportModal, { path: path, preview: preview, game: game, onDone: reload }));
        }
        catch (error) {
            toaster.toast({ title: "Import failed", body: String(error) });
        }
    };
    return (SP_JSX.jsxs(DFL.PanelSection, { title: "CONFIG", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: doExport, children: "Export Game Config" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: doImport, children: "Import Game Config" }) }), SP_JSX.jsx("div", { className: "pocknix-note", children: "Per-game tweaks and Proton pick; defaults stay local" })] }));
}

/** Per-game MAKO (Lossless Scaling frame generation) switch.
 *
 *  MAKO keeps no config blob of its own here: it activates entirely through the game's launch
 *  options, which Steam owns. The switch therefore reads the string back instead of holding a
 *  shadow copy the two UIs could disagree about. It stays hidden until the wrapper exists, so
 *  it is never offered on a device where the Renderer was not installed.
 */
function MakoToggle({ appid }) {
    const [installed, setInstalled] = SP_REACT.useState(false);
    const [on, setOn] = SP_REACT.useState(false);
    SP_REACT.useEffect(() => {
        let cancelled = false;
        setInstalled(false);
        setOn(false);
        makoStatus()
            .then((status) => {
            if (!cancelled)
                setInstalled(status.installed);
        })
            .catch(() => { });
        readLaunchOptions(appid)
            .then((options) => {
            if (!cancelled)
                setOn(options ? makoEnabledIn(options) : false);
        })
            .catch(() => { });
        return () => {
            cancelled = true;
        };
    }, [appid]);
    if (!installed)
        return null;
    return (SP_JSX.jsx(DFL.ToggleField, { label: "MAKO (Lossless Scaling frame gen)", checked: on, onChange: (next) => {
            setOn(next);
            // Steam owns the string, so roll the toggle back if the write is refused.
            syncMakoLaunchOption(appid, next).catch(() => setOn(!next));
        } }));
}

/** Standalone per-game settings, opened from the library context menu. Saves on each change
 *  (no QAM debounce lifecycle here; the modal has an explicit close). */
function GameSettingsModal({ appid, name, closeModal }) {
    const [config, setConfig] = SP_REACT.useState(null);
    SP_REACT.useEffect(() => {
        getConfig()
            .then(setConfig)
            .catch(() => closeModal?.());
    }, []);
    if (!config)
        return SP_JSX.jsx(DFL.ModalRoot, { closeModal: closeModal, children: "Loading\u2026" });
    const gameSettings = config.tweaks.games[appid] || {};
    const enabled = gameSettings.enabled === true;
    const values = enabled ? { ...config.tweaks.global, ...gameSettings } : config.tweaks.global;
    const update = (mutate) => {
        const next = clone(config);
        mutate(next);
        setConfig(next);
        const globalDiff = diffFields(config.tweaks.global, next.tweaks.global);
        const gameDiff = diffFields(config.tweaks.games[appid], next.tweaks.games[appid]);
        // The modal only edits `games[appid]`; `global` is sent too in case it ever changes, so a
        // whole-object write can't clobber the QAM's edits (and vice versa).
        const sendGlobal = Object.keys(globalDiff).length ? patchTweaks("", globalDiff) : Promise.resolve(null);
        sendGlobal
            .then(() => patchTweaks(appid, gameDiff))
            .then((returned) => {
            setConfig((current) => {
                if (!current || JSON.stringify(current.tweaks) !== JSON.stringify(next.tweaks))
                    return current;
                return { ...current, ...returned };
            });
        })
            .catch(() => { });
    };
    const patch = (fields) => update((next) => {
        const existing = next.tweaks.games[appid] || {};
        next.tweaks.games[appid] = { ...existing, enabled: true, name, ...fields };
    });
    return (SP_JSX.jsxs(DFL.ModalRoot, { closeModal: closeModal, children: [SP_JSX.jsx("div", { style: { fontWeight: 600, marginBottom: "8px" }, children: name || `App ${appid}` }), SP_JSX.jsx(MakoToggle, { appid: appid }), SP_JSX.jsx(DFL.ToggleField, { label: "Use Per-Game Settings", checked: enabled, onChange: (on) => {
                    update((next) => {
                        next.tweaks.games[appid] = { ...(next.tweaks.games[appid] || {}), enabled: on, name };
                    });
                    const profile = on ? String(gameSettings.fexProfile ?? config.tweaks.global.fexProfile ?? "") : "";
                    syncFexLaunchOption(appid, fexSteamString(profile, config.fexProfiles));
                } }), enabled ? (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx(PerfFields, { values: values, patch: patch }), SP_JSX.jsx(TweakFields, { config: config, appid: appid, values: values, patch: patch }), SP_JSX.jsx(ConfigSection, { game: { appid, name }, reload: () => getConfig().then(setConfig).catch(() => { }) })] })) : null] }));
}

// LibraryContextMenu is not a module export, so it is reached by classname marker ->
// `navigator:` wrapper -> fake-render, whose element type is the real class.
// Steam UI internals are unversioned: every step is guarded so a shape change costs the
// menu item, never the plugin.
function patchLibraryContextMenu() {
    try {
        const menuModule = DFL.findModuleChild((mod) => {
            if (typeof mod !== "object" || !mod)
                return undefined;
            for (const prop in mod) {
                try {
                    if (mod[prop]?.toString?.()?.includes("().LibraryContextMenu"))
                        return mod;
                }
                catch (error) { }
            }
            return undefined;
        });
        if (!menuModule)
            return () => { };
        const wrapper = Object.values(menuModule).find((member) => {
            try {
                return typeof member === "function" && member?.toString?.()?.includes("navigator:");
            }
            catch (error) {
                return false;
            }
        });
        if (!wrapper)
            return () => { };
        const LibraryContextMenu = DFL.fakeRenderComponent(wrapper)?.type;
        if (!LibraryContextMenu?.prototype?.BuildManageSubmenu)
            return () => { };
        // The builder returns either a plain item array or an element with children.
        const patch = DFL.afterPatch(LibraryContextMenu.prototype, "BuildManageSubmenu", function (_args, ret) {
            try {
                const overview = this.props?.overview;
                const appid = overview?.appid;
                if (!appid)
                    return ret;
                const children = Array.isArray(ret) ? ret : ret?.props?.children;
                if (!Array.isArray(children))
                    return ret;
                if (children.some((child) => child?.key === "pocknix-settings"))
                    return ret;
                children.push(SP_JSX.jsx(DFL.MenuItem, { onSelected: () => DFL.showModal(SP_JSX.jsx(GameSettingsModal, { appid: String(appid), name: String(overview?.display_name ?? "") })), children: "CalvOS Settings" }, "pocknix-settings"));
            }
            catch (error) { }
            return ret;
        });
        return () => patch.unpatch();
    }
    catch (error) {
        return () => { };
    }
}

/**
 * PESTAÑA PROPIA EN EL QAM (independiente del menú de Decky).
 *
 * POR QUE EXISTE
 *   El cliente de Steam del 13/10/2026 partió el CSS del QAM: el `TitleView` del menú de
 *   Decky busca `staticClasses.Title`, ya no existe, lanza
 *       TypeError: Cannot read properties of undefined (reading 'Title')
 *   y la pestaña de Decky deja de renderizarse. Un plugin normal (`definePlugin({content})`)
 *   vive DENTRO de esa pestaña -> queda INACCESIBLE (le pasó a PocknixControl).
 *
 *   Solución (la misma que usa el plugin "Panel de Control" de Hooandee): registrarnos en la
 *   tabla de pestañas del QAM (`window.__TABS_HOOK_INSTANCE`, la misma que usa Decky) con
 *   NUESTRO propio título. Así nuestros ajustes salen siempre en el QAM, aunque el menú de
 *   Decky esté roto.
 *
 *   ⚠️ `staticClasses?.Title` con optional chaining: si Steam vuelve a cambiar el CSS, el
 *   className queda `undefined` (la pestaña sigue saliendo), en vez de lanzar un TypeError
 *   que impediría el registro. Es exactamente el fallo de hoy, así que no lo quitamos.
 *
 *   Si el hook no existe (versión de Decky distinta) NO se rompe nada: se avisa por consola
 *   y el plugin sigue funcionando con su pestaña normal de Decky.
 */
const TAB_ID = 0x504b43; // "PKC"
const OWNER = "pocknix-control";
function tabsHook() {
    try {
        const hook = window.__TABS_HOOK_INSTANCE;
        if (!hook ||
            !Array.isArray(hook.tabs) ||
            typeof hook.add !== "function" ||
            typeof hook.removeById !== "function") {
            return null;
        }
        return hook;
    }
    catch {
        return null;
    }
}
function ownedTabs(hook) {
    return hook.tabs.filter((tab) => tab && tab.id === TAB_ID && tab.__pkcOwner === OWNER);
}
/** Registra (o re-registra) nuestra pestaña. Devuelve true si quedó registrada. */
function registerQamTab(content, icon) {
    try {
        const hook = tabsHook();
        if (!hook)
            return false;
        // Quita SOLO la nuestra (idempotente); no toca las de otros plugins.
        for (const _tab of ownedTabs(hook)) {
            try {
                hook.removeById(TAB_ID);
            }
            catch {
                /* ignore */
            }
        }
        const staticClasses = DFL?.staticClasses;
        hook.add({
            id: TAB_ID,
            title: SP_JSX.jsx("div", { className: staticClasses?.Title, children: "CalvOS Control" }),
            content,
            icon,
            __pkcOwner: OWNER,
        });
        return hook.tabs.some((tab) => tab?.id === TAB_ID);
    }
    catch (e) {
        console.warn("[PocknixControl] pestaña propia del QAM no disponible:", e);
        return false;
    }
}
/** Quita nuestra pestaña (al descargar el plugin). */
function unregisterQamTab() {
    try {
        const hook = tabsHook();
        if (!hook)
            return;
        for (const _tab of ownedTabs(hook)) {
            try {
                hook.removeById(TAB_ID);
            }
            catch {
                /* ignore */
            }
        }
    }
    catch {
        /* ignore */
    }
}
/**
 * Al cargar el plugin el hook puede no existir todavía, y además Decky **recrea** el
 * `TabsHook` en algunos momentos (`window.__TABS_HOOK_INSTANCE?.deinit(); ... = this`), con
 * lo que nuestra pestaña se pierde. Por eso no basta con registrar una vez: un vigilante
 * comprueba cada 2 s que siga estando y la vuelve a añadir si falta.
 * Devuelve una función para pararlo.
 */
function startQamTabWatchdog(content, icon) {
    let cancelled = false;
    const tick = () => {
        if (cancelled)
            return;
        try {
            const hook = tabsHook();
            if (!hook)
                return; // Decky aún no tiene el hook: se reintenta en el siguiente tick
            const present = hook.tabs.some((tab) => tab && tab.id === TAB_ID && tab.__pkcOwner === OWNER);
            if (present)
                return;
            if (registerQamTab(content, icon)) {
                console.log("[PocknixControl] pestaña propia del QAM (re)registrada");
            }
        }
        catch {
            /* nunca romper el plugin por esto */
        }
    };
    tick();
    const interval = window.setInterval(tick, 2000);
    return () => {
        cancelled = true;
        window.clearInterval(interval);
    };
}

const tabIcon = SP_JSX.jsx("div", { style: { fontWeight: 700 }, children: "P" });
var index = definePlugin(() => {
    const unpatchContextMenu = patchLibraryContextMenu();
    // Pestaña PROPIA en el QAM: Steam (13/10/2026) rompió el menú de Decky y la pestaña
    // normal de los plugins quedó inaccesible. Si el hook no está, no pasa nada: se usa la
    // de Decky como siempre.
    const stopQamWatchdog = startQamTabWatchdog(SP_JSX.jsx(Content, {}), tabIcon);
    return {
        name: "CalvOS Control",
        content: SP_JSX.jsx(Content, {}),
        icon: tabIcon,
        alwaysRender: true,
        onDismount() {
            stopQamWatchdog();
            unregisterQamTab();
            unpatchContextMenu();
        },
    };
});

export { index as default };
//# sourceMappingURL=index.js.map
