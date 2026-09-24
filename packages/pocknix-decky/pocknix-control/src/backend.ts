import { call } from "@decky/api";
import type { Config, ConfigExportResult, ConfigImportResult, ConfigPreview, LedConfig, LedSideKey, MakoStatus, OledCareStatus, SdcardInfo, ShareStatus, SnapshotStatus, Tweaks, UpdateInfo, UpdateStatus } from "./types";

export const getConfig = () => call<[], Config>("get_config");
export const setFanMode = (mode: string) => call<[string], Config>("set_fan_mode", mode);
export const setLavdMode = (mode: string) => call<[string], Config>("set_lavd_mode", mode);
export const setScxScheduler = (scheduler: string) => call<[string], Config>("set_scx_scheduler", scheduler);
export const setScxMode = (mode: string) => call<[string], Config>("set_scx_mode", mode);
export const saveTweaks = (data: Tweaks) => call<[Tweaks], Config>("save_tweaks", data);
export const exportConfig = (appid: string, name: string, basename: string, allowOverwrite: boolean) =>
  call<[string, string, string, boolean], ConfigExportResult>("export_config", appid, name, basename, allowOverwrite);
export const configDir = () => call<[], string>("config_dir");
export const readConfig = (path: string) => call<[string], ConfigPreview>("read_config", path);
export const applyConfig = (path: string, sourceAppid: string, targetAppid: string, targetName: string) =>
  call<[string, string, string, string], ConfigImportResult>("apply_config", path, sourceAppid, targetAppid, targetName);
export const setLed = (side: LedSideKey, r: number, g: number, b: number, brightness: number) =>
  call<[LedSideKey, number, number, number, number], LedConfig>("set_led", side, r, g, b, brightness);
export const setLedSideEnabled = (side: "left" | "right", enabled: boolean) =>
  call<["left" | "right", boolean], LedConfig>("set_led_side_enabled", side, enabled);
export const setLedLinked = (linked: boolean) => call<[boolean], LedConfig>("set_led_linked", linked);
export const setLedEnabled = (enabled: boolean) => call<[boolean], LedConfig>("set_led_enabled", enabled);
export const setLedSides = (sides: boolean) => call<[boolean], LedConfig>("set_led_sides", sides);
export interface CleanupItem { id: string; label: string; description: string; size: number; advanced: boolean }
export interface CleanupScan { items: CleanupItem[]; total: number; free: number; diskTotal: number }
export interface CleanupResult { freed: number; errors: string[] }
export interface BiggestEntry { path: string; size: number }

export interface SystemBattery { available: boolean; capacity?: number | null; status?: string | null; health?: string | null; cycles?: number | null; currentNow?: number | null; voltageNow?: number | null }
export interface SystemBacklight { available: boolean; value?: number; max?: number; percent?: number }
export interface SystemStatus { profile: string | null; profiles: { id: string; label: string }[]; battery: SystemBattery; backlight: SystemBacklight }

export const systemStatus = () => call<[], SystemStatus>("system_status");

export const cleanupScan = () => call<[], CleanupScan>("cleanup_scan");
export const cleanupRun = (ids: string[]) => call<[string[]], CleanupResult>("cleanup_run", ids);
export const cleanupBiggest = () => call<[], BiggestEntry[]>("cleanup_biggest");

export const oledCareStatus = () => call<[], OledCareStatus>("oled_care_status");
export const runOledRefresher = (duration?: number, passes?: number) => call<[number | undefined, number | undefined], OledCareStatus>("run_oled_refresher", duration, passes);
export const detectSdcard = () => call<[], SdcardInfo>("detect_sdcard");
export const formatSdcard = (label: string) => call<[string], SdcardInfo>("format_sdcard", label);
export const shareStatus = () => call<[], ShareStatus>("share_status");
export const setShare = (on: boolean) => call<[boolean], ShareStatus>("set_share", on);
export const installSamba = () => call<[], ShareStatus>("install_samba");
export const checkUpdates = () => call<[], UpdateInfo[]>("check_updates");
export const startUpdate = () => call<[], UpdateStatus>("start_update");
export const updateStatus = () => call<[], UpdateStatus>("update_status");
export const snapshotStatus = () => call<[], SnapshotStatus>("snapshot_status");
export const startRollback = (id: string) => call<[string], SnapshotStatus>("start_rollback", id);
export const rebootSystem = () => call<[], boolean>("reboot_system");
export const makoStatus = () => call<[], MakoStatus>("mako_status");
