// Decky Loader will pass this api in, it's versioned to allow for backwards compatibility.
// @ts-ignore

// Prevents it from being duplicated in output.
const manifest = {"name":"MAKO - Frame Generation","author":"Eugenio Segala","flags":[],"api_version":1,"publish":{"tags":["installer","vulkan","mako","framegen","lossless-scaling","scaling","steam-machine"],"description":"MAKO brings Lossless Scaling frame generation and Vulkan-powered spatial scaling to Steam Deck, Steam Machine, and SteamOS gaming.","image":"https://raw.githubusercontent.com/eugeniosegala/MAKO/refs/heads/main/plugin/assets/mako-logo.webp"}};
const API_VERSION = 2;
const internalAPIConnection = window.__DECKY_SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED_deckyLoaderAPIInit;
// Initialize
if (!internalAPIConnection) {
    throw new Error('[@decky/api]: Failed to connect to the loader as as the loader API was not initialized. This is likely a bug in Decky Loader.');
}
// Version 1 throws on version mismatch so we have to account for that here.
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
const callable = api.callable;
const toaster = api.toaster;
const definePlugin = (fn) => {
    return (...args) => {
        // TODO: Maybe wrap this
        return fn(...args);
    };
};

var DefaultContext = {
  color: undefined,
  size: undefined,
  className: undefined,
  style: undefined,
  attr: undefined
};
var IconContext = SP_REACT.createContext && /*#__PURE__*/SP_REACT.createContext(DefaultContext);

var _excluded = ["attr", "size", "title"];
function _objectWithoutProperties(source, excluded) { if (source == null) return {}; var target = _objectWithoutPropertiesLoose(source, excluded); var key, i; if (Object.getOwnPropertySymbols) { var sourceSymbolKeys = Object.getOwnPropertySymbols(source); for (i = 0; i < sourceSymbolKeys.length; i++) { key = sourceSymbolKeys[i]; if (excluded.indexOf(key) >= 0) continue; if (!Object.prototype.propertyIsEnumerable.call(source, key)) continue; target[key] = source[key]; } } return target; }
function _objectWithoutPropertiesLoose(source, excluded) { if (source == null) return {}; var target = {}; for (var key in source) { if (Object.prototype.hasOwnProperty.call(source, key)) { if (excluded.indexOf(key) >= 0) continue; target[key] = source[key]; } } return target; }
function _extends() { _extends = Object.assign ? Object.assign.bind() : function (target) { for (var i = 1; i < arguments.length; i++) { var source = arguments[i]; for (var key in source) { if (Object.prototype.hasOwnProperty.call(source, key)) { target[key] = source[key]; } } } return target; }; return _extends.apply(this, arguments); }
function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), !0).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(obj, key, value) { key = _toPropertyKey(key); if (key in obj) { Object.defineProperty(obj, key, { value: value, enumerable: true, configurable: true, writable: true }); } else { obj[key] = value; } return obj; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == typeof i ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != typeof t || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r || "default"); if ("object" != typeof i) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
function Tree2Element(tree) {
  return tree && tree.map((node, i) => /*#__PURE__*/SP_REACT.createElement(node.tag, _objectSpread({
    key: i
  }, node.attr), Tree2Element(node.child)));
}
function GenIcon(data) {
  return props => /*#__PURE__*/SP_REACT.createElement(IconBase, _extends({
    attr: _objectSpread({}, data.attr)
  }, props), Tree2Element(data.child));
}
function IconBase(props) {
  var elem = conf => {
    var {
        attr,
        size,
        title
      } = props,
      svgProps = _objectWithoutProperties(props, _excluded);
    var computedSize = size || conf.size || "1em";
    var className;
    if (conf.className) className = conf.className;
    if (props.className) className = (className ? className + " " : "") + props.className;
    return /*#__PURE__*/SP_REACT.createElement("svg", _extends({
      stroke: "currentColor",
      fill: "currentColor",
      strokeWidth: "0"
    }, conf.attr, attr, svgProps, {
      className: className,
      style: _objectSpread(_objectSpread({
        color: props.color || conf.color
      }, conf.style), props.style),
      height: computedSize,
      width: computedSize,
      xmlns: "http://www.w3.org/2000/svg"
    }), title && /*#__PURE__*/SP_REACT.createElement("title", null, title), props.children);
  };
  return IconContext !== undefined ? /*#__PURE__*/SP_REACT.createElement(IconContext.Consumer, null, conf => elem(conf)) : elem(DefaultContext);
}

// THIS FILE IS AUTO GENERATED
function GiSharkFin (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 512 512"},"child":[{"tag":"path","attr":{"d":"M349.603 42.768c-31.36-1.053-234.946 205.685-280.595 309.828 26.998-7.923 58.257-15.23 82.4-13.004 22.594 2.083 40.82 15.274 57.844 26.603 17.023 11.33 32.575 20.703 48.654 20.416 16.378-.29 32.196-11.74 49.502-24.862 17.306-13.122 36.175-27.944 60.272-27.812 6.093.033 12.397.946 18.79 2.505-56.174-100.224-21.42-289.766-36.062-293.598-.255-.04-.523-.065-.805-.074zm21.586 312.37c-24.097-.13-42.966 14.69-60.272 27.813-17.306 13.123-33.124 24.573-49.502 24.864-16.08.287-31.63-9.086-48.654-20.416-17.023-11.33-35.25-24.52-57.844-26.603-25.39-2.34-58.66 5.86-86.557 14.234-27.895 8.372-50.07 17.28-50.07 17.28l6.706 16.702s21.492-8.624 48.54-16.743c27.047-8.12 60-15.37 79.73-13.55 16.277 1.5 32.278 12.186 49.523 23.663 17.244 11.476 36 23.838 58.946 23.43 24.043-.43 42.793-15.428 60.057-28.518 17.264-13.09 32.97-24.245 49.3-24.156 17.393.094 46.024 13.347 68.952 27.23 22.928 13.882 40.662 27.745 40.662 27.745l11.09-14.176s-18.476-14.464-42.43-28.967c-23.954-14.504-52.877-29.696-78.178-29.834zm1.91 41.12c-24.097-.132-42.966 14.69-60.272 27.812-17.306 13.122-33.124 24.572-49.502 24.864-16.08.286-31.63-9.087-48.654-20.416-17.023-11.33-35.25-24.52-57.844-26.604-25.39-2.34-58.66 5.86-86.557 14.234-27.895 8.374-50.07 17.28-50.07 17.28l6.708 16.703s21.49-8.623 48.537-16.74c27.048-8.12 60.002-15.37 79.73-13.552 16.28 1.5 32.28 12.187 49.524 23.664 17.244 11.477 36 23.84 58.946 23.43 24.044-.43 42.795-15.427 60.06-28.518 17.263-13.09 32.966-24.245 49.296-24.156 17.394.095 46.025 13.348 68.953 27.23 22.928 13.883 40.662 27.748 40.662 27.748l11.092-14.177s-18.476-14.464-42.43-28.968c-23.955-14.504-52.88-29.696-78.18-29.834z"},"child":[]}]})(props);
}

// src/config/generatedConfigSchema.ts
// Stable cross-language profile contract
const DEFAULT_PROFILE_NAME = "mako";
const MAKO_WRAPPER_RELATIVE_PATH = ".local/bin/mako-run";
const PER_GAME_WRAPPER_FLATPAK_APP_IDS = [
    "com.heroicgameslauncher.hgl",
    "net.lutris.Lutris",
];
const PROFILE_KIND_DEFAULT = "default";
const PROFILE_KIND_GAME = "game";
// Ordered Flatpak runtime contract generated from shared_config.py
const SUPPORTED_FLATPAK_RUNTIMES = [
    { version: "23.08", statusField: "installed_23_08", i18nKey: "FLATPAK_RUNTIME_VERSION" },
    { version: "24.08", statusField: "installed_24_08", i18nKey: "FLATPAK_RUNTIME_VERSION" },
    { version: "25.08", statusField: "installed_25_08", i18nKey: "FLATPAK_RUNTIME_VERSION" },
];
// Shared backend validation and Decky UI limits
const BASE_FPS_CAP_MIN = 0;
const BASE_FPS_CAP_UI_MAX = 120;
const TARGET_FPS_MIN = 30;
const TARGET_FPS_MAX = 240;
const ADAPTIVE_MAX_MULTIPLIER_MIN = 2;
const ADAPTIVE_MAX_MULTIPLIER_MAX = 5;
const ADAPTIVE_MINIMUM_BASE_FPS = 10;
const DYNAMIC_CADENCE_PROBE_INTERVAL_SECONDS_VALUES = [
    0.1,
    0.2,
    0.25,
    0.5,
    0.75,
    1.0,
    1.5,
    2.0,
    3.0,
];
const FLOW_SCALE_MIN = 0.25;
const FLOW_SCALE_MAX = 1.0;
const SCALING_FACTOR_MIN = 1.0;
const SCALING_FACTOR_MAX = 2.0;
const SCALING_METHOD_NATIVE = "native";
const SCALING_METHOD_MAKO = "mako";
const SCALING_METHOD_LS1 = "ls1";
const SCALING_METHOD_LS1_PERFORMANCE = "ls1-performance";
const SCALING_SHARPNESS_MIN = 0.0;
const SCALING_SHARPNESS_MAX = 1.0;
const ULTRA_PERFORMANCE_FLOW_SCALE = 0.75;
const FIXED_MULTIPLIER_UI_MIN = 2;
const FIXED_MULTIPLIER_UI_MAX = 5;
const FRAME_GENERATION_REFRESH_THRESHOLD_MAX = 240;
const FRAME_GENERATION_REFRESH_THRESHOLD_UI_MIN = 30;
const FRAME_GENERATION_REFRESH_THRESHOLD_PRESET = 60;
// Stable persisted values for the optional post-process Vulkan layer
const EXTERNAL_VULKAN_LAYER_NONE = "";
const EXTERNAL_VULKAN_LAYER_MANGOHUD = "mangohud";
const EXTERNAL_VULKAN_LAYER_VKBASALT = "vkbasalt";
// Configuration field type enum - matches Python
var ConfigFieldType;
(function (ConfigFieldType) {
    ConfigFieldType["BOOLEAN"] = "boolean";
    ConfigFieldType["INTEGER"] = "integer";
    ConfigFieldType["FLOAT"] = "float";
    ConfigFieldType["STRING"] = "string";
})(ConfigFieldType || (ConfigFieldType = {}));
// Field name constants for type-safe access
const DLL = "dll";
const ALLOW_FP16 = "allow_fp16";
const SCALING_ENABLED = "scaling_enabled";
const SCALING_METHOD = "scaling_method";
const SCALING_FACTOR = "scaling_factor";
const SCALING_SUPERSAMPLING = "scaling_supersampling";
const SCALING_SHARPNESS = "scaling_sharpness";
const FRAME_GENERATION_ENABLED = "frame_generation_enabled";
const FRAME_GENERATION_REFRESH_THRESHOLD = "frame_generation_refresh_threshold";
const MULTIPLIER = "multiplier";
const TARGET_FPS = "target_fps";
const ADAPTIVE_MAX_MULTIPLIER = "adaptive_max_multiplier";
const ADAPTIVE_STABLE_CADENCE = "adaptive_stable_cadence";
const DYNAMIC_CADENCE_PROBE_INTERVAL_SECONDS = "dynamic_cadence_probe_interval_seconds";
const ULTRA_PERFORMANCE = "ultra_performance";
const FLOW_SCALE = "flow_scale";
const PERFORMANCE_MODE = "performance_mode";
const ACTIVE_IN = "active_in";
const GPU = "gpu";
const DISABLE_MAKO = "disable_mako";
const GAMESCOPE_WSI_COMPATIBILITY = "gamescope_wsi_compatibility";
const SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY = "swapchain_image_count_compatibility";
const EXTERNAL_VULKAN_LAYER = "external_vulkan_layer";
const DISABLE_STEAMDECK_MODE = "disable_steamdeck_mode";
const ENABLE_ZINK = "enable_zink";
const FORCE_ALSA_AUDIO = "force_alsa_audio";
function getDefaults() {
    return {
        dll: "",
        allow_fp16: true,
        scaling_enabled: false,
        scaling_method: "ls1",
        scaling_factor: 1.5,
        scaling_supersampling: false,
        scaling_sharpness: 0.8,
        frame_generation_enabled: true,
        frame_generation_refresh_threshold: 0,
        base_fps_cap: 0,
        multiplier: 2,
        adaptive: false,
        adaptive_auto_base_fps_cap: true,
        target_fps: 90,
        adaptive_max_multiplier: 3,
        adaptive_stable_cadence: true,
        dynamic_cadence_recovery: false,
        dynamic_cadence_probe_interval_seconds: 2.0,
        ultra_performance: false,
        flow_scale: 0.9,
        performance_mode: false,
        pacing: "none",
        active_in: "",
        gpu: "",
        disable_mako: false,
        disable_hdr_exposure: true,
        gamescope_wsi_compatibility: false,
        swapchain_image_count_compatibility: false,
        external_vulkan_layer: "",
        disable_steamdeck_mode: false,
        enable_zink: false,
        force_alsa_audio: false,
    };
}

// The backend RPC replaces this pre-load fallback with the actual Decky home.
const DEFAULT_MAKO_WRAPPER_PATH = `/home/deck/${MAKO_WRAPPER_RELATIVE_PATH}`;
const DEFAULT_STEAM_LAUNCH_OPTION = `${DEFAULT_MAKO_WRAPPER_PATH} %command%`;

function configFailureResult(error) {
    return { success: false, config: null, message: "", error };
}
function profilesFailureResult(error) {
    return {
        success: false,
        profiles: null,
        current_profile: null,
        profile_details: null,
        message: "",
        error,
    };
}
function profileFailureResult(error, fields = {}) {
    return { success: false, message: "", error, ...fields };
}
// API functions
const installMako = callable("install_mako");
const uninstallMako = callable("uninstall_mako");
const checkMakoInstalled = callable("check_mako_installed");
const checkLosslessScalingDll = callable("check_lossless_scaling_dll");
const checkScalingModel = callable("check_scaling_model");
const getDllStats = callable("get_dll_stats");
const getMakoConfig = callable("get_mako_config");
const getProfileConfig = callable("get_profile_config");
const getRuntimeStatus = callable("get_runtime_status");
callable("get_config_schema");
const getLaunchOption = callable("get_launch_option");
const getConfigFileContent = callable("get_config_file_content");
const getLaunchScriptContent = callable("get_launch_script_content");
const checkFgmodDirectory = callable("check_fgmod_directory");
// Flatpak management API functions
const checkFlatpakExtensionStatus = callable("check_flatpak_extension_status");
const installFlatpakExtension = callable("install_flatpak_extension");
const uninstallFlatpakExtension = callable("uninstall_flatpak_extension");
const getFlatpakApps = callable("get_flatpak_apps");
const setFlatpakAppOverride = callable("set_flatpak_app_override");
const removeFlatpakAppOverride = callable("remove_flatpak_app_override");
// Updated config function using object-based configuration (single source of truth)
const updateMakoConfig = callable("update_mako_config");
// Object-based configuration helper
const updateMakoConfigFromObject = async (config) => {
    return updateMakoConfig(config);
};
// Self-updater API functions
// Profile management API functions
const getProfiles = callable("get_profiles");
callable("create_profile");
const deleteProfile = callable("delete_profile");
const renameProfile = callable("rename_profile");
const captureGameProfile = callable("capture_game_profile");
const setCurrentProfile = callable("set_current_profile");
const syncCurrentProfile = callable("sync_current_profile");
const updateProfileConfig = callable("update_profile_config");
const updateProfileConfigFields = callable("update_profile_config_fields");

const MAKO_INSTALL_COMPLETION_DURATION_MS = 3000;
const CLIPBOARD_SUCCESS_DURATION_MS = 3000;
const RUNTIME_STATUS_POLL_INTERVAL_MS = 1500;
const SCALING_MODEL_POLL_INTERVAL_MS = 30000;
const SCALING_MODEL_DEBOUNCE_MS = 500;

function scalingInactiveReason(status, profileName) {
    if (!status.success)
        return null;
    const context = status.contexts.find((candidate) => !candidate.spatial_scaling.activation_supported &&
        candidate.requested.scaling_enabled &&
        candidate.requested.scaling_method !== "native" &&
        (!profileName ||
            candidate.requested.name === profileName ||
            candidate.applied.name === profileName));
    return context
        ? context.spatial_scaling.inactive_reason ||
            "gamescope-wsi-surface-unproven"
        : null;
}
const EMPTY_RUNTIME_SCALING_UI_STATE = {
    hasContext: false,
    phase: "inactive",
    frameGenerationActive: false,
    frameGenerationEnabled: false,
    frameGenerationMode: "off",
    frameGenerationAdaptiveStyle: null,
    frameGenerationTargetFps: null,
    frameGenerationMultiplier: null,
    frameGenerationPending: false,
    scalingActive: false,
    scalingEnabled: false,
    scalingActivationSupported: null,
    scalingPending: false,
    inactiveReason: null,
    constraintReason: null,
    requestedFactor: 1,
    nonSupersamplingFactorCeiling: null,
    sourceWidth: 0,
    sourceHeight: 0,
    presentationWidth: 0,
    presentationHeight: 0,
    gamescopeTargetWidth: 0,
    gamescopeTargetHeight: 0,
    requestedMethod: "native",
    activeMethod: "native",
    effectiveFactor: 1,
    pipeline: "inactive",
    supersamplingActive: false,
    fallbackReason: null,
};
function newestContext(contexts, predicate) {
    return contexts.find(predicate);
}
function runtimeScalingUiState(status, profileName) {
    if (!status.success) {
        return { ...EMPTY_RUNTIME_SCALING_UI_STATE };
    }
    const contexts = status.contexts.filter((candidate) => !profileName ||
        candidate.requested.name === profileName ||
        candidate.applied.name === profileName);
    const ceilings = contexts
        .map((candidate) => candidate.spatial_scaling.non_supersampling_factor_ceiling)
        .filter((value) => value !== null && value >= 1);
    const frameContext = newestContext(contexts, (candidate) => candidate.role === "frame-generation");
    const scalingRequestedContext = newestContext(contexts, (candidate) => candidate.requested.scaling_enabled);
    const spatialContext = newestContext(contexts, (candidate) => candidate.spatial_scaling.active) ??
        scalingRequestedContext ??
        newestContext(contexts, (candidate) => candidate.role === "spatial-scaling");
    const appliedFrameProfile = frameContext?.applied;
    const frameGenerationEnabled = Boolean(appliedFrameProfile?.frame_generation_enabled);
    const frameGenerationMode = !frameGenerationEnabled
        ? "off"
        : appliedFrameProfile?.adaptive
            ? "adaptive"
            : "fixed";
    return {
        hasContext: contexts.length > 0,
        phase: contexts.length > 0 ? status.phase : "inactive",
        frameGenerationActive: Boolean(frameContext?.frame_generation_active),
        frameGenerationEnabled,
        frameGenerationMode,
        frameGenerationAdaptiveStyle: appliedFrameProfile?.adaptive
            ? appliedFrameProfile.adaptive_auto_base_fps_cap
                ? "steady"
                : "fractional"
            : null,
        frameGenerationTargetFps: appliedFrameProfile?.adaptive
            ? appliedFrameProfile.target_fps
            : null,
        frameGenerationMultiplier: frameGenerationEnabled
            ? appliedFrameProfile?.adaptive
                ? appliedFrameProfile.adaptive_max_multiplier
                : (appliedFrameProfile?.multiplier ?? null)
            : null,
        frameGenerationPending: Boolean(frameContext &&
            (frameContext.pending.frame_generation_private ||
                frameContext.pending.process_restart)),
        scalingActive: Boolean(spatialContext?.spatial_scaling.active),
        scalingEnabled: Boolean(scalingRequestedContext?.requested.scaling_enabled),
        scalingActivationSupported: spatialContext
            ? spatialContext.spatial_scaling.activation_supported
            : null,
        scalingPending: Boolean(spatialContext &&
            (spatialContext.pending.spatial_private ||
                spatialContext.pending.swapchain_recreation ||
                spatialContext.pending.process_restart)),
        inactiveReason: spatialContext?.spatial_scaling.inactive_reason ??
            scalingInactiveReason(status, profileName),
        constraintReason: spatialContext?.spatial_scaling.constraint_reason ?? null,
        requestedFactor: spatialContext?.requested.scaling_factor ??
            scalingRequestedContext?.requested.scaling_factor ??
            1,
        nonSupersamplingFactorCeiling: ceilings.length > 0 ? Math.min(...ceilings) : null,
        sourceWidth: spatialContext?.spatial_scaling.source_width ?? 0,
        sourceHeight: spatialContext?.spatial_scaling.source_height ?? 0,
        presentationWidth: spatialContext?.spatial_scaling.presentation_width ?? 0,
        presentationHeight: spatialContext?.spatial_scaling.presentation_height ?? 0,
        gamescopeTargetWidth: spatialContext?.spatial_scaling.gamescope_target_width ?? 0,
        gamescopeTargetHeight: spatialContext?.spatial_scaling.gamescope_target_height ?? 0,
        requestedMethod: spatialContext?.spatial_scaling.requested_method ?? "native",
        activeMethod: spatialContext?.spatial_scaling.active_method ?? "native",
        effectiveFactor: spatialContext?.spatial_scaling.effective_factor ?? 1,
        pipeline: spatialContext?.spatial_scaling.pipeline ?? "inactive",
        supersamplingActive: Boolean(spatialContext?.spatial_scaling.supersampling_active),
        fallbackReason: spatialContext?.spatial_scaling.fallback_reason ?? null,
    };
}

var es = {
	CONTENT_SCALING: "Escalado",
	SCALING_ENABLED: "Activar escalado (Reiniciar)",
	EXPERIMENTAL_LABEL: "Experimental",
	SCALING_ENABLED_DESC: "Actívalo antes de iniciar el juego. Si está desactivado, el escalado se desactiva por completo. Admite modelos de Lossless Scaling y MAKO Scaler.",
	SCALING_ENABLED_WARNING: "Deja el escalado desactivado cuando no lo necesites, ya que consume recursos. Usarlo junto con la generación de cuadros puede afectar al rendimiento; prueba diferentes ajustes de rendimiento o una resolución más baja en el juego.",
	SCALING_RUNTIME_SURFACE_UNSUPPORTED: "This running surface does not support MAKO scaling. Quality Supersampling, Scale Factor, and Sharpness are locked until a supported surface is detected. Frame Generation remains available.",
	SCALING_METHOD: "Método de escalado",
	SCALING_METHOD_DESC: "Elige el modelo de escalado. Puedes cambiarlo mientras el juego está en ejecución.",
	SCALING_LS1_ACTIVE_FALLBACK: "LS1 is unavailable for this game. MAKO Scaler is active. Your LS1 selection is preserved.",
	SCALING_LS1_UNAVAILABLE: "The selected LS1 model could not be loaded during the availability check. MAKO Scaler is used automatically if LS1 cannot load. Your LS1 selection is preserved.",
	SCALING_METHOD_COMPARISON_TIP: "Cómo funciona el escalado:\n1. En Steam, establece la resolución del juego en la resolución máxima de tu pantalla (Steam Deck: 1280 × 800; Steam Machine: 3840 × 2160).\n2. En el juego, elige una resolución menor, como 480p, 720p o más.\n3. Usa un factor de escala para ampliar la imagen. 2x duplica tu resolución.\n\nReducir la resolución del juego y volver a escalarla puede mejorar mucho el rendimiento, con una compensación en la calidad de imagen.",
	SCALING_METHOD_NATIVE: "Resolución nativa",
	SCALING_METHOD_MAKO: "MAKO Scaler",
	SCALING_METHOD_LS1: "LS1 Quality",
	SCALING_METHOD_LS1_PERFORMANCE: "LS1 Performance",
	SCALING_FACTOR: "Factor de escala",
	SCALING_FACTOR_DESC: "Define la relación entre el tamaño de salida y el de entrada para todos los métodos. Con una salida de tamaño fijo, los valores altos reducen la resolución de origen. Si el juego controla el tamaño de la ventana, reduce primero la resolución dentro del juego; los factores altos amplían la salida de MAKO y pueden aumentar el uso de GPU.",
	SCALING_FACTOR_LIMIT_SUFFIX: "límite de pantalla",
	SCALING_FACTOR_DEVICE_LIMIT: "Límite actual de pantalla: {factor}x. Se conserva el valor guardado de {saved}x; activa Supermuestreo de calidad para usarlo.",
	SCALING_FACTOR_NO_HEADROOM: "Esta resolución ya ocupa toda la pantalla. Reduce la resolución del juego o activa Supermuestreo de calidad.",
	SCALING_SUPERSAMPLING: "Supermuestreo de calidad",
	SCALING_SUPERSAMPLING_DESC: "Permite superar un límite de salida de Gamescope para reducir la imagen con mayor calidad, aumentando el uso de GPU y memoria. No cambia el escalado en otras superficies del escritorio.",
	SCALING_SUPERSAMPLING_WARNING: "El supermuestreo está activado. Cuando se aplica un límite de salida de Gamescope, MAKO puede superarlo para obtener una imagen reducida más nítida.",
	SCALING_SHARPNESS: "Nitidez del escalado",
	SCALING_SHARPNESS_DESC: "En MAKO, aplica este multiplicador del 0 al 100 % a su base de nitidez 3x. En LS1 selecciona una de cinco variantes de nitidez aprendidas.",
	CONTENT_FPS_MULTIPLIER: "Generación de cuadros",
	CONTENT_PERFORMANCE_SETTINGS: "Configuración de rendimiento",
	CONTENT_ADVANCED_DETAILS: "Detalles avanzados",
	CONTENT_FLATPAK_SETUP: "Configuración de Flatpak",
	CONFIG_SECTION_TITLE: "Configuración avanzada de renderizado",
	CONFIG_WORKAROUNDS_TITLE: "Configuración de compatibilidad",
	CONFIG_FLOW_SCALE: "Escala de flujo",
	CONFIG_FLOW_SCALE_DESC: "Controla la resolución interna de estimación de movimiento usada solo para la generación de cuadros. Los valores bajos reducen la carga de la GPU y los altos priorizan la calidad.",
	CONFIG_BASE_FPS_CAP: "Límite de FPS base",
	CONFIG_BASE_FPS_CAP_OFF: "Desactivado",
	CONFIG_BASE_FPS_CAP_DESC: "Limita los cuadros reales de la aplicación antes de la generación. Funciona con DirectX, OpenGL mediante Zink y Vulkan.",
	CONFIG_BASE_FPS_CAP_STEADY_RELATION: "Controlado por Límite base estable ({fps} FPS). El valor manual permanece guardado.",
	CONFIG_BASE_FPS_CAP_RECOVERY_RELATION: "Cambiar este límite desactiva la Recuperación de cadencia dinámica.",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD: "Desactivar automáticamente la generación según la frecuencia",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD_DESC: "Pausa la generación de cuadros cuando Gamescope confirma que la pantalla actual está en el umbral o por debajo, y reanuda el modo seleccionado por encima. No actúa si no hay datos de frecuencia.",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD: "Umbral de frecuencia de actualización",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD_DESC: "Elija la frecuencia más alta a la que la generación de cuadros debe permanecer pausada.",
	CONFIG_ULTRA_PERFORMANCE: "Rendimiento ultra (Reiniciar)",
	CONFIG_ULTRA_PERFORMANCE_DESC: "Reduce la carga de la GPU de MAKO en dispositivos de bajo consumo. Usa una escala de flujo del 75 %, el modelo de FG ligero, FP16 cuando es compatible y LS1 Performance cuando el escalado está habilitado. Sacrifica calidad de imagen para mejorar el rendimiento de las funciones activas de MAKO.",
	CONFIG_ULTRA_PERFORMANCE_WARNING: "Activar o desactivar Ultra Performance requiere reiniciar el juego. Los demás controles de perfil compatibles siguen disponibles después del inicio.",
	CONFIG_PERFORMANCE_MODE: "Modelo de FG ligero",
	CONFIG_PERFORMANCE_MODE_DESC: "Reduce la carga de la GPU con un modelo de generación de cuadros más ligero a costa de más imágenes fantasma. Rendimiento ultra la mantiene activada.",
	CONFIG_DISABLE_STEAMDECK_MODE: "Desactivar el modo Steam Deck (Reiniciar)",
	CONFIG_DISABLE_STEAMDECK_MODE_DESC: "Desactiva el modo Steam Deck. Desbloquea opciones ocultas en algunos juegos.",
	CONFIG_ENABLE_ZINK: "Activar Zink para juegos OpenGL (Reiniciar)",
	CONFIG_ENABLE_ZINK_DESC: "Usa la implementación de OpenGL basada en Vulkan para juegos OpenGL. Puede provocar bloqueos o congelaciones en algunos juegos.",
	CONFIG_FORCE_ALSA_AUDIO: "Forzar audio ALSA (Reiniciar)",
	CONFIG_FORCE_ALSA_AUDIO_DESC: "Puede mejorar la compatibilidad con modos como Zink y reducir cortes de audio o sonidos fuertes repentinos. Desactívelo para restaurar los valores de audio normales.",
	CONFIG_EXTERNAL_TOOLS_TITLE: "Herramientas externas",
	CONFIG_ENABLE_MANGOHUD: "Activar MangoHud (Reiniciar)",
	CONFIG_ENABLE_MANGOHUD_DESC: "Usa MangoHud instalado en el sistema y su configuración existente. Consulte la guía avanzada para definir variables de entorno por juego.",
	CONFIG_ENABLE_VKBASALT: "Activar vkBasalt (Reiniciar)",
	CONFIG_ENABLE_VKBASALT_DESC: "Déjelo desactivado salvo que esté probando vkBasalt con este juego. Usa una capa vkBasalt instalada en el sistema para este perfil. Las pruebas iniciales se limitan a juegos Vulkan nativos de 64 bits o Proton iniciados directamente por Steam en SteamOS.",
	INSTALL_INSTALLING: "Instalando MAKO Renderer...",
	INSTALL_UNINSTALLING: "Eliminando MAKO Renderer...",
	FLATPAK_MODAL_TITLE: "Extensiones de Flatpak",
	FLATPAK_RUNTIME_INSTALLER: "Instalador de extensiones de entorno",
	FLATPAK_RUNTIME_VERSION: "Entorno {version}",
	FLATPAK_INSTALLED: "Instalado",
	FLATPAK_NOT_INSTALLED: "No instalado",
	FLATPAK_UNINSTALL_TITLE: "Desinstalar extensión de entorno",
	FLATPAK_UNINSTALL_CONFIRM_PREFIX: "¿Seguro que desea desinstalar el entorno",
	FLATPAK_UNINSTALL_CONFIRM_SUFFIX: "seleccionado?",
	FLATPAK_UNINSTALL_BTN: "Desinstalar",
	FLATPAK_INSTALL_BTN: "Instalar",
	FLATPAK_UPDATE_BTN: "Actualizar",
	FLATPAK_INSTALLING_BTN: "Instalando...",
	FLATPAK_UNINSTALLING_BTN: "Desinstalando...",
	FLATPAK_UPDATING_BTN: "Actualizando...",
	FLATPAK_APPS_TITLE: "Aplicaciones Flatpak",
	FLATPAK_NO_APPS: "No se encontraron aplicaciones Flatpak",
	FLATPAK_NO_APPS_DESC: "No hay aplicaciones Flatpak instaladas actualmente",
	FLATPAK_STATUS_CONFIGURED: "Preparada",
	FLATPAK_STATUS_PARTIAL: "Parcial",
	FLATPAK_STATUS_NO_OVERRIDES: "Sin ajustes",
	FLATPAK_ERROR: "Error",
	FLATPAK_ERROR_STATUS: "No se pudo comprobar el estado de la extensión",
	FLATPAK_ERROR_APPS: "No se pudieron cargar las aplicaciones Flatpak",
	FLATPAK_STEAM_CONFIG_TITLE: "Referencia para accesos directos manuales de Steam",
	FLATPAK_STEAM_CONFIG_HEADER: "Ejemplo de destino (no configura Steam)",
	FLATPAK_STEAM_CONFIG_DESC: "Use esto solo para un acceso directo de Steam añadido manualmente cuyo Destino original sea /usr/bin/flatpak. Prepare primero la aplicación Flatpak arriba y mantenga Iniciar en y Opciones de lanzamiento sin cambios. Heroic, Lutris y EmuDeck tienen pasos propios en la guía de lanzadores.",
	FLATPAK_IMPORTANT_LABEL: "IMPORTANTE:",
	FLATPAK_STEAM_CONFIG_IMPORTANT: "Sustituya solo DESTINO. No pegue esto en OPCIONES DE LANZAMIENTO.",
	FLATPAK_PER_GAME_APP_DESC: "{app_id} - {status}. Active MAKO por juego usando {wrapper_path}. Consulte el campo correcto en la guía de lanzadores.",
	FLATPAK_DIRECT_APP_DESC: "{app_id} - {status}. La preparación se aplica a toda esta aplicación Flatpak. Consulte la guía de lanzadores para EmuDeck y los accesos directos de Steam.",
	FLATPAK_STEP_WRAPPER_PATH: "Contenedor instalado en este dispositivo:",
	FLATPAK_STEP_FINAL: "Destino para un acceso directo que originalmente usaba \"/usr/bin/flatpak\":",
	FLATPAK_OPEN_README: "Abrir guía de lanzadores",
	FLATPAK_CLOSE: "Cerrar",
	ADVANCED_DETAILS_LOADING: "Cargando información...",
	ADVANCED_DETAILS_ERROR_PREFIX: "Error:",
	ADVANCED_DETAILS_DLL_PATH: "Ruta de la DLL",
	ADVANCED_DETAILS_LIBRARY: "Biblioteca de Lossless Scaling",
	ADVANCED_DETAILS_NOT_AVAILABLE: "No disponible",
	ADVANCED_DETAILS_DLL_HASH: "Hash SHA256 de la DLL",
	ADVANCED_DETAILS_DETECTION_SOURCE: "Origen de detección",
	ADVANCED_DETAILS_LAUNCH_SCRIPT: "Script de inicio",
	ADVANCED_DETAILS_SCRIPT_NOT_FOUND_PREFIX: "No se encontró el script:",
	ADVANCED_DETAILS_PATH_PREFIX: "Ruta:",
	ADVANCED_DETAILS_NO_CONTENT: "Sin contenido",
	ADVANCED_DETAILS_CONFIG_FILE: "Archivo de configuración",
	ADVANCED_DETAILS_CONFIG_NOT_FOUND_PREFIX: "No se encontró la configuración:",
	ADVANCED_DETAILS_CLOSE: "Cerrar",
	WELCOME_TITLE: "¡Hola desde el equipo de MAKO!",
	WELCOME_TIPS_COLLAPSE: "Ocultar consejos",
	WELCOME_TIPS_EXPAND: "Mostrar consejos",
	WELCOME_LIVE_UPDATES: "Muchos ajustes se aplican en tiempo real.",
	WELCOME_RESTART_REQUIRED: "Las opciones marcadas como «Reiniciar» requieren reiniciar el juego.",
	WELCOME_PERFORMANCE_NOTE: "Los cambios en la resolución y el escalado del juego pueden afectar al rendimiento.",
	WELCOME_CLEAN_SESSION_PREFIX: "Si algo ",
	WELCOME_CLEAN_SESSION_WRONG: "no se ve o no se siente bien",
	WELCOME_CLEAN_SESSION_AFTER: " después de ",
	WELCOME_CLEAN_SESSION_CHANGES: "varios cambios",
	WELCOME_CLEAN_SESSION_RESTART_SEPARATOR: ", ",
	WELCOME_CLEAN_SESSION_RESTART: "reinicie el juego para comenzar una sesión nueva y limpia.",
	WELCOME_ENJOY: "Cada juego es diferente. Encuentre los ajustes que mejor le funcionen y disfrute jugando. MAKO sigue mejorando con cada versión, ¡así que esté atento a la página de lanzamientos!",
	PROFILE_CAPTURE_READY: "MAKO selecciona automáticamente los perfiles guardados. Si este juego es nuevo, guárdelo abajo; reinicie el juego tras cambiar opciones que requieran reinicio.",
	PROFILE_HELP: "Inicie un juego y guarde su proceso una vez. MAKO selecciona automáticamente los perfiles guardados; fuera de un juego, el desplegable solo elige qué perfil editar.",
	PROFILE_SECTION_TITLE: "Perfiles de juego / proceso",
	PROFILE_DEFAULT: "Predeterminado",
	PROFILE_SAVED_LABEL: "Perfil guardado",
	PROFILE_GAME_SAVED: "Perfil de juego guardado",
	PROFILE_GAME_SAVE_FAILED: "No se pudo guardar el perfil del juego",
	PROFILE_SAVE_RUNNING: "Guardar perfil para {game}",
	PROFILE_DETAIL_DEFAULT: "Abra un juego para guardar su perfil",
	PROFILE_DETAIL_GAME: "Juego guardado",
	PROFILE_DETAIL_PROCESS: "Proceso guardado",
	PROFILE_STEAM_APP_ID: "ID de aplicación de Steam: {app_id}",
	PROFILE_PROCESSES: "Procesos: {processes}",
	PROFILE_PROCESSES_EMPTY: "Procesos: introduzca uno en Procesos coincidentes abajo",
	PROFILE_MANAGE_WHEN_IDLE: "Cierre el juego en ejecución para renombrar o eliminar perfiles.",
	PROFILE_NAME_LABEL: "Nombre",
	PROFILE_CANCEL_BTN: "Cancelar",
	PROFILE_RENAME_TITLE: "Renombrar perfil",
	PROFILE_RENAME_DESC_PREFIX: "Elija un nombre reconocible para este perfil de juego o proceso.",
	PROFILE_RENAME_BTN: "Renombrar",
	PROFILE_CANNOT_DELETE_TITLE: "No se puede eliminar el perfil predeterminado",
	PROFILE_CANNOT_DELETE_MSG: "El perfil predeterminado no se puede eliminar",
	PROFILE_DELETE_TITLE: "Eliminar perfil de juego / proceso",
	PROFILE_DELETE_CONFIRM: "¿Eliminar \"{profile}\" y todos sus ajustes guardados?",
	PROFILE_DELETE_BTN: "Eliminar",
	PROFILE_CANNOT_RENAME_TITLE: "No se puede renombrar el perfil predeterminado",
	PROFILE_CANNOT_RENAME_MSG: "El perfil predeterminado no se puede renombrar",
	USAGE_TITLE: "Instrucciones de uso",
	USAGE_DESC: "Copie la opción de lanzamiento en las opciones del juego de Steam para activar MAKO Renderer con generación de cuadros, escalado o ambas funciones.",
	CLIPBOARD_COPIED: "Copiado al portapapeles",
	CLIPBOARD_COPYING: "Copiando...",
	CLIPBOARD_COPY_LAUNCH: "Copiar opción de lanzamiento",
	CLIPBOARD_MAKO_FGMOD: "MAKO + DeckyFG",
	CONTENT_RUNNING: "en ejecución.",
	CONTENT_ENGINE_UPDATE_REQUIRED: "Se requiere actualizar MAKO Renderer",
	CONTENT_ENGINE_INSTALLED: "Instalado:",
	CONTENT_ENGINE_NOT_RECORDED: "no registrado",
	CONTENT_ENGINE_EXPECTS: "Este complemento espera:",
	CONTENT_ENGINE_BUNDLED_VERSION: "la versión incluida",
	CONTENT_ENGINE_PREDATES_TRACKING: "La carga instalada es anterior al seguimiento de versiones.",
	CONTENT_ENGINE_UPDATE_DESC: "Reinstale MAKO Renderer para aplicar la versión incluida en este complemento. Después, actualice las extensiones de entorno correspondientes a las aplicaciones Flatpak preparadas.",
	CONTENT_UPDATE_RENDERER: "Actualizar MAKO Renderer",
	CONTENT_UPDATING_RENDERER: "Actualizando MAKO Renderer...",
	MULTIPLIER_TITLE: "Multiplicador de FPS fijo",
	MULTIPLIER_DESC: "Configura el modo Fijo entre 2x y 5x. Puede rendir mejor que Adaptativo en algunos juegos, sobre todo con ritmo irregular. 5x tiene un coste alto para pantallas de alta frecuencia. Prueba ambos en cada juego. Con Recuperación de cadencia dinámica, es un límite frente a la frecuencia confirmada de Gamescope; Adaptativo gestiona su propio multiplicador.",
	MULTIPLIER_ADAPTIVE_RELATION: "No disponible mientras la Generación de cuadros adaptativa esté activada.",
	ADAPTIVE_TITLE: "Generación de cuadros adaptativa",
	ADAPTIVE_DESC: "Ajusta la generación de cuadros para alcanzar los FPS objetivo. El límite base estable es el valor predeterminado para un ritmo más uniforme. Activa Adaptativo fraccional para conservar más cuadros reales y pruébalo en cada juego.",
	FRACTIONAL_ADAPTIVE_PRESET: "Adaptativo fraccionario",
	FRACTIONAL_ADAPTIVE_PRESET_DESC: "Combina proporciones de generación para alcanzar objetivos como 60 FPS reales → 90 FPS mostrados. Conserva más cuadros reales y puede reducir la latencia de entrada y las imágenes fantasma, pero puede sentirse menos fluido en algunos juegos.",
	FRACTIONAL_ADAPTIVE_PRESET_RELATION: "No se puede combinar con el Límite base estable. Cambiar esta opción también desactiva la Recuperación de cadencia dinámica.",
	ADAPTIVE_TARGET_FPS: "FPS objetivo",
	ADAPTIVE_TARGET_FPS_DESC: "FPS mostrados deseados. Adaptativo fraccionario puede combinar relaciones para alcanzarlos; el límite base estable limita los FPS reales a la mitad del objetivo.",
	ADAPTIVE_AUTO_BASE_FPS_CAP: "Límite base estable",
	ADAPTIVE_AUTO_BASE_FPS_CAP_DESC: "El modo Adaptativo predeterminado. Limita los FPS reales a la mitad del objetivo para una cadencia uniforme. Ventajas: ritmo normalmente más suave. Inconvenientes: menos cuadros reales y posiblemente más latencia de entrada e imágenes fantasma.",
	ADAPTIVE_AUTO_BASE_FPS_CAP_RELATION: "Sustituye al Límite de FPS base. No se puede combinar con Adaptativo fraccionario ni con Recuperación de cadencia dinámica.",
	ADAPTIVE_MAX_MULTIPLIER: "Multiplicador adaptativo máximo",
	ADAPTIVE_MAX_MULTIPLIER_DESC: "Límite de interpolación. 3x es equilibrado; 2x suele ofrecer la mejor imagen, 4x da más margen para alcanzar el objetivo y 5x es para pantallas de alta frecuencia de actualización con una reserva considerable de GPU y memoria. Pruébelo en cada juego.",
	ADAPTIVE_SMOOTH_CADENCE: "Cadencia suave",
	ADAPTIVE_SMOOTH_CADENCE_DESC: "Usa una cadencia de interpolación constante validada. Puede suavizar el movimiento mostrado, pero reducir la cadencia de cuadros reales y aumentar la latencia de entrada. Activado de forma predeterminada; desactívelo si el juego responde mejor sin él.",
	DYNAMIC_CADENCE_RECOVERY: "Recuperación de cadencia dinámica",
	DYNAMIC_CADENCE_RECOVERY_DESC: "Ayuda a juegos y emuladores que cambian entre frecuencias nativas, como 30 FPS durante el juego y 60 FPS en los menús. Comprueba periódicamente los cambios y recupera la cadencia correcta, pero cada comprobación puede afectar brevemente al ritmo. Actívela solo en los juegos afectados.",
	DYNAMIC_CADENCE_RECOVERY_RELATION: "Al activar esta opción se desactivan el Límite base estable y el Límite de FPS base. Cambiar cualquiera de ellos más adelante desactiva la Recuperación.",
	DYNAMIC_CADENCE_PROBE_INTERVAL: "Intervalo de sondeo de cadencia",
	DYNAMIC_CADENCE_PROBE_INTERVAL_DESC: "Frecuencia con la que Recuperación comprueba la tasa nativa. 0,1 segundos es una opción agresiva y puede provocar tirones breves frecuentes; 2 segundos es el valor predeterminado y 3 segundos comprueba con la menor frecuencia. Pruébelo en cada juego.",
	ADAPTIVE_VALUE: "Adaptativo",
	CONFIG_DLL_PATH: "Ruta de Lossless.dll (Reiniciar)",
	CONFIG_DLL_PATH_DESC: "Ruta completa opcional a Lossless.dll. Déjela vacía para usar la detección automática de MAKO Renderer. Reinicie el juego después de cambiarla.",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH: "Desactivar MAKO Renderer en el próximo inicio",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH_DESC: "Solo para solucionar problemas. Impide que MAKO Renderer se cargue la próxima vez que se inicie el juego. Use Generación de cuadros arriba para activar o desactivar la síntesis.",
	CONFIG_DISABLE_HDR_EXPOSURE: "Desactivar HDR",
	CONFIG_DISABLE_HDR_EXPOSURE_DESC: "HDR no está disponible en esta versión. Este ajuste obligatorio mantiene activa la ruta SDR estable.",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY: "Gamescope WSI (Reiniciar)",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_DESC: "Puede reducir artefactos de movimiento coloreados o pixelados en algunos juegos mediante la ruta de presentación de Gamescope. El escalado lo activa automáticamente. En perfiles solo con generación de cuadros, actívelo únicamente para los juegos afectados.",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_WARNING: "Esta ruta de compatibilidad se limita a lanzamientos de host de 64 bits compatibles. Déjela desactivada cuando el juego no la necesite, ya que puede afectar al rendimiento.",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY: "Imágenes de intercambio del juego (Reiniciar)",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_DESC: "Puede corregir juegos que no se inician con la generación de cuadros al conservar el mínimo de imágenes de intercambio solicitado por el juego. Actívelo solo para los juegos afectados.",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_WARNING: "Los cuadros generados pueden omitirse cuando el compositor no tiene una imagen libre, lo que puede reducir la fluidez o el rendimiento bajo presión.",
	FRAME_GENERATION_ENABLED: "Generación de cuadros",
	FRAME_GENERATION_ENABLED_DESC: "Déjela activada para usar la generación fija o adaptativa. Al desactivarla, ningún modo genera cuadros; los ajustes permanecen guardados.",
	FRAME_GENERATION_ENABLED_WARNING: "Mantenga esta opción activada si desea generar cuadros.",
	CONFIG_ALLOW_FP16: "Permitir FP16 (Reiniciar)",
	CONFIG_ALLOW_FP16_DESC: "Ajuste global del renderizador: se aplica a todos los perfiles y no puede cambiarse por juego. Mejora el rendimiento en AMD; desactívelo para GPU NVIDIA antiguas. Reinicie el juego después de cambiarlo.",
	CONFIG_GPU: "GPU (Reiniciar)",
	CONFIG_GPU_DESC: "Nombre de GPU, ID proveedor:dispositivo o ID de bus PCI opcional. Reinicie el juego después de cambiarlo.",
	CONFIG_ACTIVE_IN: "Procesos coincidentes",
	CONFIG_ACTIVE_IN_DESC: "Nombres de ejecutables o procesos separados por comas. La captura del juego en ejecución los completa automáticamente; edítelos solo si un lanzador o emulador necesita un alias de proceso adicional.",
	CONFIG_MANUAL_OVERRIDES_TITLE: "Ajustes manuales",
	INSTALL_REMOVE_RENDERER: "Eliminar MAKO Renderer",
	INSTALL_RENDERER: "Instalar MAKO Renderer",
	FLATPAK_EXTENSION_UPDATED: "Extensión Flatpak actualizada",
	FLATPAK_EXTENSION_FAILED: "Falló la extensión Flatpak",
	FLATPAK_EXTENSION_ACTION_FAILED: "No se pudo",
	FLATPAK_RUNTIME_EXTENSION_UPDATED: "extensión de entorno actualizada",
	FLATPAK_RUNTIME_EXTENSION: "extensión de entorno",
	FLATPAK_APPLICATION_UPDATED: "Aplicación Flatpak actualizada",
	FLATPAK_UPDATED: "actualizada",
	FLATPAK_PREPARE_APPLICATION: "Preparar una aplicación",
	FLATPAK_PREPARE_APPLICATION_DESC: "Instale la extensión de entorno correspondiente y prepare la aplicación. Heroic y Lutris necesitan un wrapper por juego; los emuladores se preparan para toda la aplicación. Consulte la guía de lanzadores.",
	FLATPAK_INSTALL_ACTION: "instalar",
	FLATPAK_UNINSTALL_ACTION: "desinstalar",
	FLATPAK_APPLICATION_ACTION_FAILED: "No se pudo actualizar",
	PROFILE_UNKNOWN_ERROR: "Error desconocido",
	PROFILE_LOAD_FAILED: "No se pudieron cargar los perfiles",
	PROFILE_LOAD_ERROR: "Error al cargar los perfiles",
	PROFILE_SWITCHED: "Perfil cambiado",
	PROFILE_SWITCHED_DESC: "Perfil cambiado a:",
	PROFILE_SWITCH_FAILED: "No se pudo cambiar de perfil",
	PROFILE_SWITCH_ERROR: "Error al cambiar de perfil",
	PROFILE_DELETED: "Perfil eliminado",
	PROFILE_DELETED_DESC: "Perfil eliminado:",
	PROFILE_DELETE_FAILED: "No se pudo eliminar el perfil",
	PROFILE_DELETE_ERROR: "Error al eliminar el perfil",
	PROFILE_RENAMED: "Perfil renombrado",
	PROFILE_RENAMED_DESC: "Perfil renombrado a:",
	PROFILE_RENAME_FAILED: "No se pudo renombrar el perfil",
	PROFILE_RENAME_ERROR: "Error al renombrar el perfil",
	PROFILE_UPDATE_CONFIG_FAILED: "No se pudo actualizar la configuración del perfil",
	PROFILE_UPDATE_CONFIG_ERROR: "Error al actualizar la configuración del perfil",
	USAGE_MAKO_CONFIG_NOTE: "Este comando aplica MAKO solo al juego que inicie con él.",
	USAGE_ISOLATION_NOTE: "No combine MAKO con otra herramienta de generación de cuadros o escalado para el mismo juego.",
	ADVANCED_DETAILS_FAILED_LOAD_DATA: "No se pudieron cargar los datos",
	ADVANCED_DETAILS_FAILED_DLL_STATS: "No se pudieron obtener las estadísticas de la DLL",
	STATUS_ENGINE_INSTALLED: "MAKO Renderer instalado",
	STATUS_ENGINE_NOT_INSTALLED: "MAKO Renderer no instalado",
	STATUS_ENGINE_INSTALLING: "Instalando MAKO Renderer...",
	STATUS_ENGINE_UPDATING: "Actualizando MAKO Renderer...",
	STATUS_ENGINE_REMOVING: "Eliminando MAKO Renderer...",
	STATUS_ENGINE_REMOVED: "¡MAKO Renderer se eliminó correctamente!",
	STATUS_INSTALL_FAILED: "Error de instalación:",
	STATUS_UNINSTALL_FAILED: "Error de desinstalación:",
	STATUS_LOSSLESS_INSTALLED: "Lossless Scaling instalado",
	STATUS_LOSSLESS_NOT_INSTALLED: "Lossless Scaling no está instalado — es necesario para la generación de fotogramas y LS1; MAKO Scaler sigue disponible",
	TOAST_INSTALL_COMPLETE: "Instalación completada",
	TOAST_INSTALL_COMPLETE_DESC: "Se recomienda reiniciar el dispositivo.",
	TOAST_INSTALL_FAILED: "Error de instalación",
	TOAST_UNKNOWN_ERROR: "Se produjo un error desconocido",
	TOAST_UNINSTALL_COMPLETE: "MAKO Renderer eliminado",
	TOAST_UNINSTALL_COMPLETE_DESC: "Se eliminaron los archivos de MAKO Renderer",
	TOAST_UNINSTALL_FAILED: "Error de desinstalación",
	TOAST_CONFIG_UPDATE_FAILED: "Error de actualización",
	TOAST_CONFIG_UPDATE_FAILED_DESC: "No se pudo actualizar la configuración",
	TOAST_CLIPBOARD_SUCCESS: "¡Copiado al portapapeles!",
	TOAST_CLIPBOARD_SUCCESS_DESC: "Opción de lanzamiento lista para pegar",
	TOAST_CLIPBOARD_FAILED: "Error al copiar",
	TOAST_CLIPBOARD_FAILED_DESC: "No se pudo copiar al portapapeles",
	FEATURE_UPSCALING_TAB: "Upscaling",
	LIVE_STATUS_TITLE: "Live Status",
	LIVE_STATUS_CONNECTED: "MAKO is active",
	LIVE_STATUS_WAITING: "Waiting for MAKO",
	LIVE_STATUS_WAITING_DESC: "Live status is unavailable, but MAKO may still be active. Some games and emulators may not report live metrics. Check Frame Generation or Scaling manually.",
	LIVE_STATUS_FG_INACTIVE: "On in settings, but not currently generating frames.",
	LIVE_STATUS_OFF: "Off",
	LIVE_STATUS_SCALING_INACTIVE: "On in settings, but the game image is not being upscaled.",
	LIVE_STATUS_SCALING_MEMORY_LIMIT: "The requested render resolution exceeds this GPU's memory safety limit. Lower the in-game resolution.",
	LIVE_STATUS_SCALING_MEMORY_CONSTRAINED: "Requested {requested}×; limited to {effective}× by this GPU's memory safety limit.",
	LIVE_STATUS_SCALING_NO_HEADROOM: "This input already fills the display target. Lower the in-game resolution or enable Quality Supersampling.",
	LIVE_STATUS_PENDING: "A saved change is still applying or needs a restart.",
	LIVE_STATUS_SUPERSAMPLING: "Quality Supersampling active.",
	LIVE_STATUS_SCALING_FALLBACK: "You selected {requested}; MAKO is using {active} instead.",
	LIVE_STATUS_MODE: "Mode",
	LIVE_STATUS_FIXED_VALUE: "Fixed",
	LIVE_STATUS_ADAPTIVE_STYLE: "Style",
	LIVE_STATUS_STEADY_VALUE: "Steady",
	LIVE_STATUS_FRACTIONAL_VALUE: "Fractional",
	LIVE_STATUS_TARGET: "Target",
	LIVE_STATUS_MAX_MULTIPLIER: "Max factor",
	LIVE_STATUS_MULTIPLIER: "Factor",
	LIVE_STATUS_MODEL: "Model",
	LIVE_STATUS_NATIVE: "Native",
	LIVE_STATUS_LS1_PERFORMANCE: "LS1 Perf",
	LIVE_STATUS_ORIGINAL_RESOLUTION: "Input",
	LIVE_STATUS_RENDER_RESOLUTION: "Render",
	LIVE_STATUS_DISPLAY_RESOLUTION: "Display",
	LIVE_STATUS_SCALED_RESOLUTION: "Output",
	LIVE_STATUS_SCALING_UNAVAILABLE: "Unavailable for this running surface."
};
var ja = {
	CONTENT_SCALING: "スケーリング",
	SCALING_ENABLED: "スケーリングを有効化（再起動）",
	EXPERIMENTAL_LABEL: "実験的",
	SCALING_ENABLED_DESC: "ゲームを起動する前に有効にしてください。無効にすると、スケーリングは完全に無効になります。Lossless Scaling のモデルと MAKO Scaler に対応します。",
	SCALING_ENABLED_WARNING: "スケーリングが不要な場合は、リソースを消費するためオフにしてください。フレーム生成と併用するとパフォーマンスに影響する場合があります。別のパフォーマンス設定や低いゲーム内解像度を試してください。",
	SCALING_RUNTIME_SURFACE_UNSUPPORTED: "This running surface does not support MAKO scaling. Quality Supersampling, Scale Factor, and Sharpness are locked until a supported surface is detected. Frame Generation remains available.",
	SCALING_METHOD: "スケーリング方式",
	SCALING_METHOD_DESC: "スケーリングモデルを選択します。ゲームの実行中でも変更できます。",
	SCALING_LS1_ACTIVE_FALLBACK: "LS1 is unavailable for this game. MAKO Scaler is active. Your LS1 selection is preserved.",
	SCALING_LS1_UNAVAILABLE: "The selected LS1 model could not be loaded during the availability check. MAKO Scaler is used automatically if LS1 cannot load. Your LS1 selection is preserved.",
	SCALING_METHOD_COMPARISON_TIP: "スケーリングの仕組み:\n1. Steam でゲーム解像度をディスプレイの最大解像度に設定します（Steam Deck: 1280 × 800、Steam Machine: 3840 × 2160）。\n2. ゲーム内では 480p、720p、またはそれ以上の低い解像度を選びます。\n3. スケール係数で画像を拡大します。2x で解像度が 2 倍になります。\n\nゲームの描画解像度を下げて再び拡大すると、画質とのトレードオフはありますが、パフォーマンスを大きく改善できます。",
	SCALING_METHOD_NATIVE: "ネイティブ解像度",
	SCALING_METHOD_MAKO: "MAKO Scaler",
	SCALING_METHOD_LS1: "LS1 Quality",
	SCALING_METHOD_LS1_PERFORMANCE: "LS1 Performance",
	SCALING_FACTOR: "スケール倍率",
	SCALING_FACTOR_DESC: "すべての方式について、出力と入力のサイズ比を設定します。出力サイズが固定されている場合、値を高くすると元の解像度が下がります。ゲームがウィンドウサイズを制御する場合は、先にゲーム内の解像度を下げてください。倍率を高くすると MAKO の出力が大きくなり、GPU 負荷が増えることがあります。",
	SCALING_FACTOR_LIMIT_SUFFIX: "ディスプレイ上限",
	SCALING_FACTOR_DEVICE_LIMIT: "現在のディスプレイ上限: {factor}x。保存済みの {saved}x は維持されます。使用するには品質スーパーサンプリングを有効にしてください。",
	SCALING_FACTOR_NO_HEADROOM: "この解像度はすでにディスプレイ全体を使用しています。ゲーム内解像度を下げるか、品質スーパーサンプリングを有効にしてください。",
	SCALING_SUPERSAMPLING: "品質スーパーサンプリング",
	SCALING_SUPERSAMPLING_DESC: "Gamescope の出力上限を超えて高品質なダウンサンプリングを行えるようにします。GPU とメモリの使用量が増加します。他のデスクトップサーフェスでのスケーリングには影響しません。",
	SCALING_SUPERSAMPLING_WARNING: "スーパーサンプリングが有効です。Gamescope の出力上限が適用される場合、MAKO はそれを超えて描画し、より鮮明なダウンサンプリング画像を生成できます。",
	SCALING_SHARPNESS: "スケーリングのシャープネス",
	SCALING_SHARPNESS_DESC: "MAKO では、この 0～100% の倍率を 3 倍のシャープニング基準に適用します。LS1 では学習済みの5段階のシャープネスから選択します。",
	CONTENT_FPS_MULTIPLIER: "フレーム生成",
	CONTENT_PERFORMANCE_SETTINGS: "パフォーマンス設定",
	CONTENT_ADVANCED_DETAILS: "詳細情報",
	CONTENT_FLATPAK_SETUP: "Flatpak設定",
	CONFIG_SECTION_TITLE: "高度なレンダリング設定",
	CONFIG_WORKAROUNDS_TITLE: "互換性設定",
	CONFIG_FLOW_SCALE: "フロースケール",
	CONFIG_FLOW_SCALE_DESC: "フレーム生成でのみ使用する内部モーション推定解像度を調整します。低い値は GPU 負荷を減らし、高い値は画質を優先します。",
	CONFIG_BASE_FPS_CAP: "基本FPS上限",
	CONFIG_BASE_FPS_CAP_OFF: "オフ",
	CONFIG_BASE_FPS_CAP_DESC: "フレーム生成前の実フレームレートを制限します。DirectX、Zink 経由の OpenGL、Vulkan に対応します。",
	CONFIG_BASE_FPS_CAP_STEADY_RELATION: "安定ベース FPS 制限（{fps} FPS）によって制御されています。手動値は保存されたままです。",
	CONFIG_BASE_FPS_CAP_RECOVERY_RELATION: "この上限を変更すると、動的ケイデンス回復がオフになります。",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD: "リフレッシュレートに応じてフレーム生成を自動無効化",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD_DESC: "Gamescope が現在のディスプレイをしきい値以下と確認した場合にフレーム生成を一時停止し、しきい値を超えると選択したモードを再開します。リフレッシュレート情報がない場合は動作しません。",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD: "リフレッシュレートしきい値",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD_DESC: "フレーム生成を一時停止する最大リフレッシュレートを選択します。",
	CONFIG_ULTRA_PERFORMANCE: "ウルトラパフォーマンス（再起動）",
	CONFIG_ULTRA_PERFORMANCE_DESC: "低消費電力デバイスで MAKO の GPU 負荷を軽減します。フロースケール 75%、軽量 FG モデル、対応環境では FP16、スケーリング有効時は LS1 Performance を使用します。有効な MAKO 機能全体で、画質と引き換えにパフォーマンスを高めます。",
	CONFIG_ULTRA_PERFORMANCE_WARNING: "Ultra Performance のオン／オフ切り替えにはゲームの再起動が必要です。その他の互換性のあるプロファイル設定は起動後も利用できます。",
	CONFIG_PERFORMANCE_MODE: "軽量 FG モデル",
	CONFIG_PERFORMANCE_MODE_DESC: "軽量なフレーム生成モデルで GPU 負荷を下げますが、ゴーストが増えます。ウルトラパフォーマンスでは常に有効です。",
	CONFIG_DISABLE_STEAMDECK_MODE: "Steam Deckモードを無効化（再起動）",
	CONFIG_DISABLE_STEAMDECK_MODE_DESC: "Steam Deck モードを無効化します。一部ゲームの隠し設定を解放します。",
	CONFIG_ENABLE_ZINK: "OpenGLゲーム用Zinkを有効化（再起動）",
	CONFIG_ENABLE_ZINK_DESC: "OpenGL ゲームに Vulkan ベースの OpenGL 実装を使用します。一部のゲームでクラッシュやフリーズが発生する場合があります。",
	CONFIG_FORCE_ALSA_AUDIO: "ALSA オーディオを強制（再起動）",
	CONFIG_FORCE_ALSA_AUDIO_DESC: "Zink などのモードとの互換性を向上させ、音声の途切れや突然の大音量を抑えられる場合があります。無効にすると通常の音声設定に戻ります。",
	CONFIG_EXTERNAL_TOOLS_TITLE: "外部ツール",
	CONFIG_ENABLE_MANGOHUD: "MangoHud を有効化（再起動）",
	CONFIG_ENABLE_MANGOHUD_DESC: "ホストにインストールされた MangoHud と既存の MangoHud 設定を使用します。ゲーム別の環境変数オーバーライドについてはエキスパートガイドを参照してください。",
	CONFIG_ENABLE_VKBASALT: "vkBasalt を有効化（再起動）",
	CONFIG_ENABLE_VKBASALT_DESC: "このゲームで vkBasalt をテストする場合を除き、オフのままにしてください。このプロファイルでホストにインストールされた vkBasalt レイヤーを使用します。最初のテスト対象は、SteamOS 上で Steam から直接起動する 64 ビットのネイティブ Vulkan または Proton ゲームです。",
	INSTALL_INSTALLING: "MAKO Renderer をインストール中...",
	INSTALL_UNINSTALLING: "MAKO Renderer を削除中...",
	FLATPAK_MODAL_TITLE: "Flatpak拡張",
	FLATPAK_RUNTIME_INSTALLER: "ランタイム拡張インストーラー",
	FLATPAK_RUNTIME_VERSION: "ランタイム {version}",
	FLATPAK_INSTALLED: "インストール済み",
	FLATPAK_NOT_INSTALLED: "未インストール",
	FLATPAK_UNINSTALL_TITLE: "ランタイム拡張をアンインストール",
	FLATPAK_UNINSTALL_CONFIRM_PREFIX: "本当に",
	FLATPAK_UNINSTALL_CONFIRM_SUFFIX: "ランタイム拡張をアンインストールしますか？",
	FLATPAK_UNINSTALL_BTN: "アンインストール",
	FLATPAK_INSTALL_BTN: "インストール",
	FLATPAK_UPDATE_BTN: "更新",
	FLATPAK_INSTALLING_BTN: "インストール中...",
	FLATPAK_UNINSTALLING_BTN: "アンインストール中...",
	FLATPAK_UPDATING_BTN: "更新中...",
	FLATPAK_APPS_TITLE: "Flatpakアプリケーション",
	FLATPAK_NO_APPS: "Flatpakアプリなし",
	FLATPAK_NO_APPS_DESC: "現在インストールされているFlatpakアプリケーションはありません",
	FLATPAK_STATUS_CONFIGURED: "準備済み",
	FLATPAK_STATUS_PARTIAL: "部分設定",
	FLATPAK_STATUS_NO_OVERRIDES: "オーバーライドなし",
	FLATPAK_ERROR: "エラー",
	FLATPAK_ERROR_STATUS: "拡張ステータスの確認に失敗しました",
	FLATPAK_ERROR_APPS: "Flatpakアプリケーションの読み込みに失敗しました",
	FLATPAK_STEAM_CONFIG_TITLE: "手動 Steam ショートカットの参照",
	FLATPAK_STEAM_CONFIG_HEADER: "ターゲット例（Steam は自動設定されません）",
	FLATPAK_STEAM_CONFIG_DESC: "元のリンク先が /usr/bin/flatpak の、手動で追加した Steam ショートカットにのみ使用してください。先に上で Flatpak アプリを準備し、作業フォルダーと起動オプションは変更しないでください。Heroic、Lutris、EmuDeck にはランチャー設定ガイドに個別の手順があります。",
	FLATPAK_IMPORTANT_LABEL: "重要:",
	FLATPAK_STEAM_CONFIG_IMPORTANT: "TARGET のみを置き換えてください。Launch Options には貼り付けないでください。",
	FLATPAK_PER_GAME_APP_DESC: "{app_id} - {status}。{wrapper_path} を使ってゲームごとに MAKO を有効にします。入力欄はランチャー設定ガイドで確認してください。",
	FLATPAK_DIRECT_APP_DESC: "{app_id} - {status}。準備はこの Flatpak アプリ全体に適用されます。EmuDeck と Steam ショートカットの手順はランチャー設定ガイドをご覧ください。",
	FLATPAK_STEP_WRAPPER_PATH: "このデバイスにインストールされたラッパー:",
	FLATPAK_STEP_FINAL: "元のターゲットが \"/usr/bin/flatpak\" のショートカット用ターゲット:",
	FLATPAK_OPEN_README: "ランチャー設定ガイドを開く",
	FLATPAK_CLOSE: "閉じる",
	ADVANCED_DETAILS_LOADING: "情報を読み込み中...",
	ADVANCED_DETAILS_ERROR_PREFIX: "エラー:",
	ADVANCED_DETAILS_DLL_PATH: "DLLパス",
	ADVANCED_DETAILS_LIBRARY: "Lossless Scaling ライブラリ",
	ADVANCED_DETAILS_NOT_AVAILABLE: "利用不可",
	ADVANCED_DETAILS_DLL_HASH: "DLL SHA256ハッシュ",
	ADVANCED_DETAILS_DETECTION_SOURCE: "検出ソース",
	ADVANCED_DETAILS_LAUNCH_SCRIPT: "起動スクリプト",
	ADVANCED_DETAILS_SCRIPT_NOT_FOUND_PREFIX: "スクリプトが見つかりません:",
	ADVANCED_DETAILS_PATH_PREFIX: "パス:",
	ADVANCED_DETAILS_NO_CONTENT: "コンテンツなし",
	ADVANCED_DETAILS_CONFIG_FILE: "設定ファイル",
	ADVANCED_DETAILS_CONFIG_NOT_FOUND_PREFIX: "設定が見つかりません:",
	ADVANCED_DETAILS_CLOSE: "閉じる",
	WELCOME_TITLE: "MAKO チームからこんにちは！",
	WELCOME_TIPS_COLLAPSE: "ヒントを隠す",
	WELCOME_TIPS_EXPAND: "ヒントを表示",
	WELCOME_LIVE_UPDATES: "多くの設定はリアルタイムで反映されます。",
	WELCOME_RESTART_REQUIRED: "「再起動」と表示された項目はゲームの再起動が必要です。",
	WELCOME_PERFORMANCE_NOTE: "ゲームの解像度やスケーリングの変更はパフォーマンスに影響する場合があります。",
	WELCOME_CLEAN_SESSION_PREFIX: "もし",
	WELCOME_CLEAN_SESSION_WRONG: "表示や操作感に違和感がある",
	WELCOME_CLEAN_SESSION_AFTER: "場合は、",
	WELCOME_CLEAN_SESSION_CHANGES: "何度か変更した後",
	WELCOME_CLEAN_SESSION_RESTART_SEPARATOR: "、",
	WELCOME_CLEAN_SESSION_RESTART: "ゲームを再起動して新しいクリーンなセッションでお試しください。",
	WELCOME_ENJOY: "ゲームごとに最適な設定は異なります。自分に合う設定を見つけてゲームをお楽しみください。MAKO はリリースごとに改善を続けているので、リリースページもご確認ください！",
	PROFILE_CAPTURE_READY: "保存済みプロファイルは MAKO が自動的に選択します。新しいゲームの場合は下で保存してください。再起動が必要な設定を変更した後はゲームを再起動してください。",
	PROFILE_HELP: "ゲームを起動して、そのプロセスを一度保存します。MAKO は保存済みプロファイルを自動選択します。ゲーム外では、ドロップダウンは編集するプロファイルだけを選びます。",
	PROFILE_SECTION_TITLE: "ゲーム / プロセス プロファイル",
	PROFILE_DEFAULT: "デフォルト",
	PROFILE_SAVED_LABEL: "保存済みプロファイル",
	PROFILE_GAME_SAVED: "ゲームプロファイルを保存しました",
	PROFILE_GAME_SAVE_FAILED: "ゲームプロファイルを保存できませんでした",
	PROFILE_SAVE_RUNNING: "{game} のプロファイルを保存",
	PROFILE_DETAIL_DEFAULT: "ゲームを開いてプロフィールを保存してください",
	PROFILE_DETAIL_GAME: "保存済みゲーム",
	PROFILE_DETAIL_PROCESS: "保存済みプロセス",
	PROFILE_STEAM_APP_ID: "Steam アプリ ID: {app_id}",
	PROFILE_PROCESSES: "プロセス: {processes}",
	PROFILE_PROCESSES_EMPTY: "プロセス: 下の「一致するプロセス」に入力してください",
	PROFILE_MANAGE_WHEN_IDLE: "実行中のゲームを終了すると、プロファイルの名前変更や削除ができます。",
	PROFILE_NAME_LABEL: "名前",
	PROFILE_CANCEL_BTN: "キャンセル",
	PROFILE_RENAME_TITLE: "プロファイルの名前を変更",
	PROFILE_RENAME_DESC_PREFIX: "このゲームまたはプロセスプロファイルの分かりやすい名前を選択してください。",
	PROFILE_RENAME_BTN: "名前変更",
	PROFILE_CANNOT_DELETE_TITLE: "デフォルトプロファイルは削除できません",
	PROFILE_CANNOT_DELETE_MSG: "デフォルトプロファイルは削除できません",
	PROFILE_DELETE_TITLE: "ゲーム / プロセス プロファイルを削除",
	PROFILE_DELETE_CONFIRM: "「{profile}」と保存済み設定をすべて削除しますか？",
	PROFILE_DELETE_BTN: "削除",
	PROFILE_CANNOT_RENAME_TITLE: "デフォルトプロファイルの名前は変更できません",
	PROFILE_CANNOT_RENAME_MSG: "デフォルトプロファイルの名前は変更できません",
	USAGE_TITLE: "使用方法",
	USAGE_DESC: "Steam ゲームの起動オプションにコピーした内容を貼り付け、フレーム生成、スケーリング、または両方で MAKO Renderer を有効にします。",
	CLIPBOARD_COPIED: "クリップボードにコピーしました",
	CLIPBOARD_COPYING: "コピー中...",
	CLIPBOARD_COPY_LAUNCH: "起動オプションをコピー",
	CLIPBOARD_MAKO_FGMOD: "MAKO + DeckyFG",
	CONTENT_RUNNING: "実行中。",
	CONTENT_ENGINE_UPDATE_REQUIRED: "MAKO Renderer の更新が必要です",
	CONTENT_ENGINE_INSTALLED: "インストール済み:",
	CONTENT_ENGINE_NOT_RECORDED: "記録なし",
	CONTENT_ENGINE_EXPECTS: "このプラグインが必要とするバージョン:",
	CONTENT_ENGINE_BUNDLED_VERSION: "同梱バージョン",
	CONTENT_ENGINE_PREDATES_TRACKING: "インストール済みのペイロードはバージョン追跡より前のものです。",
	CONTENT_ENGINE_UPDATE_DESC: "MAKO Renderer を再インストールして、このプラグインに同梱されたバージョンを適用してください。その後、準備済み Flatpak アプリに対応するランタイム拡張を更新してください。",
	CONTENT_UPDATE_RENDERER: "MAKO Renderer を更新",
	CONTENT_UPDATING_RENDERER: "MAKO Renderer を更新中...",
	MULTIPLIER_TITLE: "固定 FPS 倍率",
	MULTIPLIER_DESC: "固定モードを 2x～5x に設定します。フレームペーシングが不安定なゲームでは固定がアダプティブより高性能な場合があります。5x は高リフレッシュレート向けの高負荷設定です。ゲームごとに両方を試してください。動的ケイデンス回復では確認済み Gamescope リフレッシュレートに対する上限となり、アダプティブは独自の倍率を管理します。",
	MULTIPLIER_ADAPTIVE_RELATION: "アダプティブ フレーム生成が有効な間は使用できません。",
	ADAPTIVE_TITLE: "アダプティブ フレーム生成",
	ADAPTIVE_DESC: "目標 FPS に近づくようフレーム生成を調整します。より滑らかなペーシングのため、安定ベース上限が既定です。実フレームを増やすには小数アダプティブを有効にし、ゲームごとに試してください。",
	FRACTIONAL_ADAPTIVE_PRESET: "小数倍率 Adaptive",
	FRACTIONAL_ADAPTIVE_PRESET_DESC: "生成倍率を組み合わせ、実 FPS 60 → 表示 FPS 90 のような目標を目指します。実フレームを多く保ち、入力遅延とゴーストを減らせる場合がありますが、一部のゲームでは滑らかさが落ちることがあります。",
	FRACTIONAL_ADAPTIVE_PRESET_RELATION: "安定ベース FPS 制限とは同時に使用できません。この設定を変更すると、動的ケイデンス回復もオフになります。",
	ADAPTIVE_TARGET_FPS: "目標FPS",
	ADAPTIVE_TARGET_FPS_DESC: "希望する表示 FPS です。小数倍率 Adaptive は倍率を組み合わせて目標を目指し、安定ベース FPS 制限は実 FPS を目標の半分に制限します。",
	ADAPTIVE_AUTO_BASE_FPS_CAP: "安定ベース FPS 制限",
	ADAPTIVE_AUTO_BASE_FPS_CAP_DESC: "Adaptive の既定モードです。実 FPS を目標の半分に制限し、均一なフレーム間隔を保ちます。利点: 通常はより滑らかなペーシングになります。欠点: 実フレームが減り、入力遅延とゴーストが増える可能性があります。",
	ADAPTIVE_AUTO_BASE_FPS_CAP_RELATION: "ベース FPS 制限を上書きします。小数倍率 Adaptive または動的ケイデンス回復とは同時に使用できません。",
	ADAPTIVE_MAX_MULTIPLIER: "アダプティブ最大倍率",
	ADAPTIVE_MAX_MULTIPLIER_DESC: "補間の上限です。3x はバランス型、2x は通常もっとも良い画質、4x は目標に到達する余裕を増やし、5x は十分な GPU とメモリの余裕がある高リフレッシュレートディスプレイ向けです。ゲームごとに確認してください。",
	ADAPTIVE_SMOOTH_CADENCE: "スムーズ ケイデンス",
	ADAPTIVE_SMOOTH_CADENCE_DESC: "検証済みの一定補間ケイデンスを使用します。表示上の動きがより滑らかになる場合がありますが、実フレームのケイデンスを下げ、入力遅延を増やす可能性があります。既定で有効です。ゲームの応答性がオフの方が良いと感じる場合は無効にしてください。",
	DYNAMIC_CADENCE_RECOVERY: "動的ケイデンス回復",
	DYNAMIC_CADENCE_RECOVERY_DESC: "ゲーム中 30 FPS、メニュー 60 FPS のようにネイティブレートが切り替わるゲームやエミュレーターを支援します。定期的にレートの変化を確認して正しいケイデンスを回復しますが、確認のたびにペーシングへ短く影響する場合があります。必要なゲームでのみ有効にしてください。",
	DYNAMIC_CADENCE_RECOVERY_RELATION: "オンにすると、安定ベース FPS 制限とベース FPS 制限が無効になります。後でいずれかを変更すると、回復がオフになります。",
	DYNAMIC_CADENCE_PROBE_INTERVAL: "ケイデンスプローブ間隔",
	DYNAMIC_CADENCE_PROBE_INTERVAL_DESC: "回復機能がネイティブフレームレートを確認する間隔です。0.1秒は積極的な設定で、短いペーシングの引っかかりが頻発する可能性があります。2秒が既定値で、3秒は確認頻度が最も低くなります。ゲームごとにテストしてください。",
	ADAPTIVE_VALUE: "アダプティブ",
	CONFIG_DLL_PATH: "Lossless.dll のパス（再起動）",
	CONFIG_DLL_PATH_DESC: "Lossless.dll の完全パス（任意）。空欄にすると MAKO Renderer の自動検出を使用します。変更後はゲームを再起動してください。",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH: "次回の起動時に MAKO Renderer を無効化",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH_DESC: "トラブルシューティング専用です。次回ゲーム起動時に MAKO Renderer を読み込ませません。フレーム合成をオン/オフするには、上のフレーム生成を使用してください。",
	CONFIG_DISABLE_HDR_EXPOSURE: "HDR を無効化",
	CONFIG_DISABLE_HDR_EXPOSURE_DESC: "HDR はこのリリースでは利用できません。この必須設定は安定した SDR パスを維持します。",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY: "Gamescope WSI（再起動）",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_DESC: "Gamescope の表示経路を使用することで、一部のゲームで色付きまたはピクセル状のモーションアーティファクトを軽減できる場合があります。スケーリングでは自動的に有効になります。フレーム生成のみのプロファイルでは、影響を受けるゲームにだけ有効にしてください。",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_WARNING: "この互換性経路は、対応する 64 ビットのホスト起動に限定されています。ゲームで不要な場合は、パフォーマンスに影響する可能性があるためオフにしてください。",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY: "ゲームのスワップチェーン画像（再起動）",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_DESC: "ゲームが要求したスワップチェーン画像の最小数を維持することで、フレーム生成を有効にすると起動しないゲームを修正できる場合があります。影響を受けるゲームでのみ有効にしてください。",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_WARNING: "コンポジターに空き画像がない場合は生成フレームがスキップされ、高負荷時の滑らかさやパフォーマンスが低下することがあります。",
	FRAME_GENERATION_ENABLED: "フレーム生成",
	FRAME_GENERATION_ENABLED_DESC: "固定またはアダプティブのフレーム生成を使うにはオンのままにしてください。オフにすると、どちらのモードでもフレーム生成を行いません。設定は保持されます。",
	FRAME_GENERATION_ENABLED_WARNING: "フレーム生成を使う場合は、オンのままにしてください。",
	CONFIG_ALLOW_FP16: "FP16 を許可（再起動）",
	CONFIG_ALLOW_FP16_DESC: "グローバルなレンダラー設定です。すべてのプロファイルに適用され、ゲームごとに変更できません。AMD では性能が向上する場合があります。古い NVIDIA GPU では無効にしてください。変更後はゲームを再起動してください。",
	CONFIG_GPU: "GPU（再起動）",
	CONFIG_GPU_DESC: "任意の GPU 名、vendor:device ID、または PCI バス ID。変更後はゲームを再起動してください。",
	CONFIG_ACTIVE_IN: "一致するプロセス",
	CONFIG_ACTIVE_IN_DESC: "実行ファイルまたはプロセス名をカンマで区切ります。実行中ゲームの取得で自動入力されます。ランチャーやエミュレーターに追加のプロセス別名が必要な場合のみ編集してください。",
	CONFIG_MANUAL_OVERRIDES_TITLE: "手動オーバーライド",
	INSTALL_REMOVE_RENDERER: "MAKO Renderer を削除",
	INSTALL_RENDERER: "MAKO Renderer をインストール",
	FLATPAK_EXTENSION_UPDATED: "Flatpak 拡張を更新しました",
	FLATPAK_EXTENSION_FAILED: "Flatpak 拡張の操作に失敗しました",
	FLATPAK_EXTENSION_ACTION_FAILED: "操作できませんでした:",
	FLATPAK_RUNTIME_EXTENSION_UPDATED: "ランタイム拡張を更新しました",
	FLATPAK_RUNTIME_EXTENSION: "ランタイム拡張",
	FLATPAK_APPLICATION_UPDATED: "Flatpak アプリケーションを更新しました",
	FLATPAK_UPDATED: "更新しました",
	FLATPAK_PREPARE_APPLICATION: "アプリケーションを準備",
	FLATPAK_PREPARE_APPLICATION_DESC: "対応するランタイム拡張をインストールし、アプリを準備してください。Heroic と Lutris はゲームごとにラッパーを設定し、エミュレーターはアプリ全体を準備します。手順はランチャー設定ガイドをご覧ください。",
	FLATPAK_INSTALL_ACTION: "インストール",
	FLATPAK_UNINSTALL_ACTION: "アンインストール",
	FLATPAK_APPLICATION_ACTION_FAILED: "更新できませんでした:",
	PROFILE_UNKNOWN_ERROR: "不明なエラー",
	PROFILE_LOAD_FAILED: "プロファイルの読み込みに失敗しました",
	PROFILE_LOAD_ERROR: "プロファイルの読み込み中にエラーが発生しました",
	PROFILE_SWITCHED: "プロファイルを切り替えました",
	PROFILE_SWITCHED_DESC: "切り替え先:",
	PROFILE_SWITCH_FAILED: "プロファイルの切り替えに失敗しました",
	PROFILE_SWITCH_ERROR: "プロファイル切り替え中にエラーが発生しました",
	PROFILE_DELETED: "プロファイルを削除しました",
	PROFILE_DELETED_DESC: "削除したプロファイル:",
	PROFILE_DELETE_FAILED: "プロファイルの削除に失敗しました",
	PROFILE_DELETE_ERROR: "プロファイル削除中にエラーが発生しました",
	PROFILE_RENAMED: "プロファイル名を変更しました",
	PROFILE_RENAMED_DESC: "変更後のプロファイル名:",
	PROFILE_RENAME_FAILED: "プロファイル名の変更に失敗しました",
	PROFILE_RENAME_ERROR: "プロファイル名変更中にエラーが発生しました",
	PROFILE_UPDATE_CONFIG_FAILED: "プロファイル設定の更新に失敗しました",
	PROFILE_UPDATE_CONFIG_ERROR: "プロファイル設定の更新中にエラーが発生しました",
	USAGE_MAKO_CONFIG_NOTE: "このコマンドで起動したゲームにのみ MAKO が適用されます。",
	USAGE_ISOLATION_NOTE: "同じゲームで MAKO と別のフレーム生成またはスケーリングツールを併用しないでください。",
	ADVANCED_DETAILS_FAILED_LOAD_DATA: "データの読み込みに失敗しました",
	ADVANCED_DETAILS_FAILED_DLL_STATS: "DLL 情報の取得に失敗しました",
	STATUS_ENGINE_INSTALLED: "MAKO Renderer をインストールしました",
	STATUS_ENGINE_NOT_INSTALLED: "MAKO Renderer は未インストールです",
	STATUS_ENGINE_INSTALLING: "MAKO Renderer をインストール中...",
	STATUS_ENGINE_UPDATING: "MAKO Renderer を更新中...",
	STATUS_ENGINE_REMOVING: "MAKO Renderer を削除中...",
	STATUS_ENGINE_REMOVED: "MAKO Renderer を削除しました！",
	STATUS_INSTALL_FAILED: "インストールに失敗しました:",
	STATUS_UNINSTALL_FAILED: "アンインストールに失敗しました:",
	STATUS_LOSSLESS_INSTALLED: "Lossless Scaling はインストール済みです",
	STATUS_LOSSLESS_NOT_INSTALLED: "Lossless Scaling は未インストールです — フレーム生成と LS1 に必要です。MAKO Scaler は引き続き利用できます",
	TOAST_INSTALL_COMPLETE: "インストール完了",
	TOAST_INSTALL_COMPLETE_DESC: "デバイスを再起動することをおすすめします。",
	TOAST_INSTALL_FAILED: "インストールに失敗しました",
	TOAST_UNKNOWN_ERROR: "不明なエラーが発生しました",
	TOAST_UNINSTALL_COMPLETE: "MAKO Renderer を削除しました",
	TOAST_UNINSTALL_COMPLETE_DESC: "MAKO Renderer のファイルを削除しました",
	TOAST_UNINSTALL_FAILED: "アンインストールに失敗しました",
	TOAST_CONFIG_UPDATE_FAILED: "更新に失敗しました",
	TOAST_CONFIG_UPDATE_FAILED_DESC: "設定の更新に失敗しました",
	TOAST_CLIPBOARD_SUCCESS: "クリップボードにコピーしました！",
	TOAST_CLIPBOARD_SUCCESS_DESC: "起動オプションを貼り付けられます",
	TOAST_CLIPBOARD_FAILED: "コピーに失敗しました",
	TOAST_CLIPBOARD_FAILED_DESC: "クリップボードにコピーできませんでした",
	FEATURE_UPSCALING_TAB: "Upscaling",
	LIVE_STATUS_TITLE: "Live Status",
	LIVE_STATUS_CONNECTED: "MAKO is active",
	LIVE_STATUS_WAITING: "Waiting for MAKO",
	LIVE_STATUS_WAITING_DESC: "Live status is unavailable, but MAKO may still be active. Some games and emulators may not report live metrics. Check Frame Generation or Scaling manually.",
	LIVE_STATUS_FG_INACTIVE: "On in settings, but not currently generating frames.",
	LIVE_STATUS_OFF: "Off",
	LIVE_STATUS_SCALING_INACTIVE: "On in settings, but the game image is not being upscaled.",
	LIVE_STATUS_SCALING_MEMORY_LIMIT: "The requested render resolution exceeds this GPU's memory safety limit. Lower the in-game resolution.",
	LIVE_STATUS_SCALING_MEMORY_CONSTRAINED: "Requested {requested}×; limited to {effective}× by this GPU's memory safety limit.",
	LIVE_STATUS_SCALING_NO_HEADROOM: "This input already fills the display target. Lower the in-game resolution or enable Quality Supersampling.",
	LIVE_STATUS_PENDING: "A saved change is still applying or needs a restart.",
	LIVE_STATUS_SUPERSAMPLING: "Quality Supersampling active.",
	LIVE_STATUS_SCALING_FALLBACK: "You selected {requested}; MAKO is using {active} instead.",
	LIVE_STATUS_MODE: "Mode",
	LIVE_STATUS_FIXED_VALUE: "Fixed",
	LIVE_STATUS_ADAPTIVE_STYLE: "Style",
	LIVE_STATUS_STEADY_VALUE: "Steady",
	LIVE_STATUS_FRACTIONAL_VALUE: "Fractional",
	LIVE_STATUS_TARGET: "Target",
	LIVE_STATUS_MAX_MULTIPLIER: "Max factor",
	LIVE_STATUS_MULTIPLIER: "Factor",
	LIVE_STATUS_MODEL: "Model",
	LIVE_STATUS_NATIVE: "Native",
	LIVE_STATUS_LS1_PERFORMANCE: "LS1 Perf",
	LIVE_STATUS_ORIGINAL_RESOLUTION: "Input",
	LIVE_STATUS_RENDER_RESOLUTION: "Render",
	LIVE_STATUS_DISPLAY_RESOLUTION: "Display",
	LIVE_STATUS_SCALED_RESOLUTION: "Output",
	LIVE_STATUS_SCALING_UNAVAILABLE: "Unavailable for this running surface."
};
var ko = {
	CONTENT_SCALING: "스케일링",
	SCALING_ENABLED: "스케일링 활성화 (재시작)",
	EXPERIMENTAL_LABEL: "실험적",
	SCALING_ENABLED_DESC: "게임을 시작하기 전에 활성화하세요. 끄면 스케일링이 완전히 비활성화됩니다. Lossless Scaling 모델과 MAKO Scaler를 지원합니다.",
	SCALING_ENABLED_WARNING: "스케일링은 리소스를 사용하므로 필요하지 않을 때는 꺼 두세요. 프레임 생성과 함께 사용하면 성능에 영향을 줄 수 있습니다. 다른 성능 설정이나 더 낮은 게임 내 해상도를 사용해 보세요.",
	SCALING_RUNTIME_SURFACE_UNSUPPORTED: "This running surface does not support MAKO scaling. Quality Supersampling, Scale Factor, and Sharpness are locked until a supported surface is detected. Frame Generation remains available.",
	SCALING_METHOD: "스케일링 방식",
	SCALING_METHOD_DESC: "스케일링 모델을 선택합니다. 게임 실행 중에도 변경할 수 있습니다.",
	SCALING_LS1_ACTIVE_FALLBACK: "LS1 is unavailable for this game. MAKO Scaler is active. Your LS1 selection is preserved.",
	SCALING_LS1_UNAVAILABLE: "The selected LS1 model could not be loaded during the availability check. MAKO Scaler is used automatically if LS1 cannot load. Your LS1 selection is preserved.",
	SCALING_METHOD_COMPARISON_TIP: "스케일링 작동 방식:\n1. Steam에서 게임 해상도를 디스플레이의 최대 해상도로 설정하세요(Steam Deck: 1280 × 800, Steam Machine: 3840 × 2160).\n2. 게임에서는 480p, 720p 또는 그 이상의 낮은 해상도를 선택하세요.\n3. 스케일 팩터로 이미지를 확대하세요. 2x는 해상도를 두 배로 만듭니다.\n\n게임의 렌더링 해상도를 낮춘 뒤 다시 확대하면 화질의 절충은 있지만 성능을 크게 향상할 수 있습니다.",
	SCALING_METHOD_NATIVE: "네이티브 해상도",
	SCALING_METHOD_MAKO: "MAKO Scaler",
	SCALING_METHOD_LS1: "LS1 Quality",
	SCALING_METHOD_LS1_PERFORMANCE: "LS1 Performance",
	SCALING_FACTOR: "스케일 배율",
	SCALING_FACTOR_DESC: "모든 방식의 출력 대 입력 크기 비율을 설정합니다. 출력 크기가 고정되어 있으면 값이 높을수록 원본 해상도가 낮아집니다. 게임이 창 크기를 제어하는 경우 먼저 게임 내 해상도를 낮추세요. 배율을 높이면 MAKO의 출력 크기가 커져 GPU 부하가 증가할 수 있습니다.",
	SCALING_FACTOR_LIMIT_SUFFIX: "디스플레이 제한",
	SCALING_FACTOR_DEVICE_LIMIT: "현재 디스플레이 제한: {factor}x. 저장된 {saved}x 값은 유지됩니다. 사용하려면 품질 슈퍼샘플링을 켜세요.",
	SCALING_FACTOR_NO_HEADROOM: "이 해상도는 이미 디스플레이를 채우고 있습니다. 게임 내 해상도를 낮추거나 품질 슈퍼샘플링을 켜세요.",
	SCALING_SUPERSAMPLING: "품질 슈퍼샘플링",
	SCALING_SUPERSAMPLING_DESC: "Gamescope 출력 제한을 초과하여 더 높은 품질로 다운샘플링할 수 있게 하며, GPU와 메모리 사용량이 증가합니다. 다른 데스크톱 표면의 스케일링에는 영향을 주지 않습니다.",
	SCALING_SUPERSAMPLING_WARNING: "슈퍼샘플링이 활성화되었습니다. Gamescope 출력 제한이 적용되는 경우 MAKO가 이를 초과하여 더 선명한 다운샘플링 이미지를 만들 수 있습니다.",
	SCALING_SHARPNESS: "스케일링 선명도",
	SCALING_SHARPNESS_DESC: "MAKO에서는 이 0~100% 배율을 3배 선명도 기준에 적용합니다. LS1에서는 학습된 다섯 가지 선명도 변형 중 하나를 선택합니다.",
	CONTENT_FPS_MULTIPLIER: "프레임 생성",
	CONTENT_PERFORMANCE_SETTINGS: "성능 설정",
	CONTENT_ADVANCED_DETAILS: "상세 정보",
	CONTENT_FLATPAK_SETUP: "Flatpak 설정",
	CONFIG_SECTION_TITLE: "고급 렌더링 설정",
	CONFIG_WORKAROUNDS_TITLE: "호환성 설정",
	CONFIG_FLOW_SCALE: "흐름 배율",
	CONFIG_FLOW_SCALE_DESC: "프레임 생성에만 사용되는 내부 모션 추정 해상도를 조절합니다. 낮은 값은 GPU 부하를 줄이고 높은 값은 화질을 우선합니다.",
	CONFIG_BASE_FPS_CAP: "기본 FPS 상한",
	CONFIG_BASE_FPS_CAP_OFF: "끄기",
	CONFIG_BASE_FPS_CAP_DESC: "프레임 생성 전에 실제 애플리케이션 프레임을 제한합니다. DirectX, Zink 기반 OpenGL 및 Vulkan에서 작동합니다.",
	CONFIG_BASE_FPS_CAP_STEADY_RELATION: "안정적 기본 FPS 제한({fps} FPS)이 제어합니다. 수동 값은 저장된 상태로 유지됩니다.",
	CONFIG_BASE_FPS_CAP_RECOVERY_RELATION: "이 제한을 변경하면 동적 케이던스 복구가 꺼집니다.",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD: "주사율에 따라 프레임 생성 자동 비활성화",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD_DESC: "Gamescope가 현재 디스플레이의 주사율이 임계값 이하임을 확인하면 프레임 생성을 일시 중지하고, 임계값을 넘으면 선택한 모드를 다시 시작합니다. 주사율 정보가 없으면 작동하지 않습니다.",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD: "주사율 임계값",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD_DESC: "프레임 생성을 일시 중지할 최대 주사율을 선택합니다.",
	CONFIG_ULTRA_PERFORMANCE: "울트라 성능 (재시작)",
	CONFIG_ULTRA_PERFORMANCE_DESC: "저전력 기기에서 MAKO의 GPU 부하를 줄입니다. 흐름 배율 75%, 경량 FG 모델, 지원되는 경우 FP16, 스케일링이 활성화되면 LS1 Performance를 사용합니다. 활성화된 MAKO 기능 전반에서 화질과 성능을 맞바꿉니다.",
	CONFIG_ULTRA_PERFORMANCE_WARNING: "Ultra Performance를 켜거나 끄려면 게임을 다시 시작해야 합니다. 그 밖의 호환되는 프로필 설정은 시작 후에도 사용할 수 있습니다.",
	CONFIG_PERFORMANCE_MODE: "경량 FG 모델",
	CONFIG_PERFORMANCE_MODE_DESC: "더 가벼운 프레임 생성 모델로 GPU 작업을 줄이지만 고스팅이 늘어납니다. 울트라 성능에서는 항상 활성화됩니다.",
	CONFIG_DISABLE_STEAMDECK_MODE: "Steam Deck 모드 비활성화 (재시작)",
	CONFIG_DISABLE_STEAMDECK_MODE_DESC: "Steam Deck 모드를 비활성화합니다. 일부 게임의 숨겨진 설정을 해제합니다.",
	CONFIG_ENABLE_ZINK: "OpenGL 게임에 Zink 활성화 (재시작)",
	CONFIG_ENABLE_ZINK_DESC: "OpenGL 게임에 Vulkan 기반 OpenGL 구현을 사용합니다. 일부 게임에서 크래시나 멈춤이 발생할 수 있습니다.",
	CONFIG_FORCE_ALSA_AUDIO: "ALSA 오디오 강제 사용 (재시작)",
	CONFIG_FORCE_ALSA_AUDIO_DESC: "Zink 같은 모드와의 호환성을 개선하고 오디오 끊김이나 갑작스러운 큰 소리를 줄일 수 있습니다. 비활성화하면 기본 오디오 설정으로 돌아갑니다.",
	CONFIG_EXTERNAL_TOOLS_TITLE: "외부 도구",
	CONFIG_ENABLE_MANGOHUD: "MangoHud 활성화 (재시작)",
	CONFIG_ENABLE_MANGOHUD_DESC: "호스트에 설치된 MangoHud와 기존 MangoHud 설정을 사용합니다. 게임별 환경 변수 재정의는 전문가 가이드를 참조하세요.",
	CONFIG_ENABLE_VKBASALT: "vkBasalt 활성화 (재시작)",
	CONFIG_ENABLE_VKBASALT_DESC: "이 게임에서 vkBasalt를 테스트하는 경우가 아니면 꺼 두세요. 이 프로필에서 호스트에 설치된 vkBasalt 레이어를 사용합니다. 초기 테스트 경로는 SteamOS에서 Steam으로 직접 실행하는 64비트 네이티브 Vulkan 또는 Proton 게임으로 제한됩니다.",
	INSTALL_INSTALLING: "MAKO Renderer 설치 중...",
	INSTALL_UNINSTALLING: "MAKO Renderer 제거 중...",
	FLATPAK_MODAL_TITLE: "Flatpak 확장",
	FLATPAK_RUNTIME_INSTALLER: "런타임 확장 설치",
	FLATPAK_RUNTIME_VERSION: "런타임 {version}",
	FLATPAK_INSTALLED: "설치됨",
	FLATPAK_NOT_INSTALLED: "설치 안 됨",
	FLATPAK_UNINSTALL_TITLE: "런타임 확장 제거",
	FLATPAK_UNINSTALL_CONFIRM_PREFIX: "정말로",
	FLATPAK_UNINSTALL_CONFIRM_SUFFIX: "런타임 확장을 제거하시겠습니까?",
	FLATPAK_UNINSTALL_BTN: "제거",
	FLATPAK_INSTALL_BTN: "설치",
	FLATPAK_UPDATE_BTN: "업데이트",
	FLATPAK_INSTALLING_BTN: "설치 중...",
	FLATPAK_UNINSTALLING_BTN: "제거 중...",
	FLATPAK_UPDATING_BTN: "업데이트 중...",
	FLATPAK_APPS_TITLE: "Flatpak 애플리케이션",
	FLATPAK_NO_APPS: "Flatpak 앱 없음",
	FLATPAK_NO_APPS_DESC: "현재 설치된 Flatpak 애플리케이션이 없습니다",
	FLATPAK_STATUS_CONFIGURED: "준비됨",
	FLATPAK_STATUS_PARTIAL: "부분 설정",
	FLATPAK_STATUS_NO_OVERRIDES: "오버라이드 없음",
	FLATPAK_ERROR: "오류",
	FLATPAK_ERROR_STATUS: "확장 상태 확인 실패",
	FLATPAK_ERROR_APPS: "Flatpak 애플리케이션 로드 실패",
	FLATPAK_STEAM_CONFIG_TITLE: "수동 Steam 바로가기 참고",
	FLATPAK_STEAM_CONFIG_HEADER: "대상 예시 (Steam을 자동 설정하지 않음)",
	FLATPAK_STEAM_CONFIG_DESC: "원래 대상이 /usr/bin/flatpak인 수동 추가 Steam 바로가기에만 사용하세요. 먼저 위에서 Flatpak 앱을 준비하고 시작 위치와 시작 옵션은 그대로 두세요. Heroic, Lutris, EmuDeck은 런처 설정 가이드에 별도 단계가 있습니다.",
	FLATPAK_IMPORTANT_LABEL: "중요:",
	FLATPAK_STEAM_CONFIG_IMPORTANT: "TARGET만 바꾸세요. 실행 옵션에 붙여 넣지 마세요.",
	FLATPAK_PER_GAME_APP_DESC: "{app_id} - {status}. {wrapper_path}를 사용해 게임별로 MAKO를 활성화하세요. 올바른 입력란은 런처 설정 가이드를 확인하세요.",
	FLATPAK_DIRECT_APP_DESC: "{app_id} - {status}. 준비는 이 Flatpak 앱 전체에 적용됩니다. EmuDeck과 Steam 바로가기는 런처 설정 가이드를 따르세요.",
	FLATPAK_STEP_WRAPPER_PATH: "이 장치에 설치된 래퍼:",
	FLATPAK_STEP_FINAL: "원래 \"/usr/bin/flatpak\"을 사용한 바로가기의 대상:",
	FLATPAK_OPEN_README: "런처 설정 가이드 열기",
	FLATPAK_CLOSE: "닫기",
	ADVANCED_DETAILS_LOADING: "정보 불러오는 중...",
	ADVANCED_DETAILS_ERROR_PREFIX: "오류:",
	ADVANCED_DETAILS_DLL_PATH: "DLL 경로",
	ADVANCED_DETAILS_LIBRARY: "Lossless Scaling 라이브러리",
	ADVANCED_DETAILS_NOT_AVAILABLE: "사용 불가",
	ADVANCED_DETAILS_DLL_HASH: "DLL SHA256 해시",
	ADVANCED_DETAILS_DETECTION_SOURCE: "감지 소스",
	ADVANCED_DETAILS_LAUNCH_SCRIPT: "실행 스크립트",
	ADVANCED_DETAILS_SCRIPT_NOT_FOUND_PREFIX: "스크립트 없음:",
	ADVANCED_DETAILS_PATH_PREFIX: "경로:",
	ADVANCED_DETAILS_NO_CONTENT: "내용 없음",
	ADVANCED_DETAILS_CONFIG_FILE: "설정 파일",
	ADVANCED_DETAILS_CONFIG_NOT_FOUND_PREFIX: "설정 없음:",
	ADVANCED_DETAILS_CLOSE: "닫기",
	WELCOME_TITLE: "MAKO 팀에서 인사드립니다!",
	WELCOME_TIPS_COLLAPSE: "팁 숨기기",
	WELCOME_TIPS_EXPAND: "팁 표시",
	WELCOME_LIVE_UPDATES: "많은 설정은 실시간으로 적용됩니다.",
	WELCOME_RESTART_REQUIRED: "'재시작'이라고 표시된 옵션은 게임을 다시 시작해야 합니다.",
	WELCOME_PERFORMANCE_NOTE: "게임 해상도와 스케일링 변경은 성능에 영향을 줄 수 있습니다.",
	WELCOME_CLEAN_SESSION_PREFIX: "만약 ",
	WELCOME_CLEAN_SESSION_WRONG: "화면이나 플레이 감각에 문제가 있다면",
	WELCOME_CLEAN_SESSION_AFTER: ", ",
	WELCOME_CLEAN_SESSION_CHANGES: "여러 설정을 바꾼 뒤",
	WELCOME_CLEAN_SESSION_RESTART_SEPARATOR: " ",
	WELCOME_CLEAN_SESSION_RESTART: "게임을 다시 시작해 깨끗한 새 세션에서 확인하세요.",
	WELCOME_ENJOY: "게임마다 최적의 설정은 다릅니다. 자신에게 맞는 설정을 찾아 즐겁게 플레이하세요. MAKO는 릴리스마다 계속 개선되고 있으니 릴리스 페이지도 확인해 주세요!",
	PROFILE_CAPTURE_READY: "저장된 프로필은 MAKO가 자동으로 선택합니다. 새로운 게임이라면 아래에서 저장하세요. 재시작 전용 설정을 바꾼 뒤에는 게임을 다시 시작하세요.",
	PROFILE_HELP: "게임을 실행하고 프로세스를 한 번 저장하세요. MAKO는 저장된 프로필을 자동으로 선택합니다. 게임 밖에서는 드롭다운이 편집할 프로필만 선택합니다.",
	PROFILE_SECTION_TITLE: "게임 / 프로세스 프로필",
	PROFILE_DEFAULT: "기본",
	PROFILE_SAVED_LABEL: "저장된 프로필",
	PROFILE_GAME_SAVED: "게임 프로필 저장됨",
	PROFILE_GAME_SAVE_FAILED: "게임 프로필을 저장할 수 없음",
	PROFILE_SAVE_RUNNING: "{game} 프로필 저장",
	PROFILE_DETAIL_DEFAULT: "게임을 열어 프로필을 저장하세요",
	PROFILE_DETAIL_GAME: "저장된 게임",
	PROFILE_DETAIL_PROCESS: "저장된 프로세스",
	PROFILE_STEAM_APP_ID: "Steam 앱 ID: {app_id}",
	PROFILE_PROCESSES: "프로세스: {processes}",
	PROFILE_PROCESSES_EMPTY: "프로세스: 아래의 일치하는 프로세스에 입력하세요",
	PROFILE_MANAGE_WHEN_IDLE: "실행 중인 게임을 종료하면 프로필 이름을 변경하거나 삭제할 수 있습니다.",
	PROFILE_NAME_LABEL: "이름",
	PROFILE_CANCEL_BTN: "취소",
	PROFILE_RENAME_TITLE: "프로필 이름 변경",
	PROFILE_RENAME_DESC_PREFIX: "이 게임 또는 프로세스 프로필의 알아보기 쉬운 이름을 선택하세요.",
	PROFILE_RENAME_BTN: "이름 변경",
	PROFILE_CANNOT_DELETE_TITLE: "기본 프로필 삭제 불가",
	PROFILE_CANNOT_DELETE_MSG: "기본 프로필은 삭제할 수 없습니다",
	PROFILE_DELETE_TITLE: "게임 / 프로세스 프로필 삭제",
	PROFILE_DELETE_CONFIRM: "\"{profile}\" 및 저장된 설정을 모두 삭제할까요?",
	PROFILE_DELETE_BTN: "삭제",
	PROFILE_CANNOT_RENAME_TITLE: "기본 프로필 이름 변경 불가",
	PROFILE_CANNOT_RENAME_MSG: "기본 프로필의 이름은 변경할 수 없습니다",
	USAGE_TITLE: "사용 방법",
	USAGE_DESC: "복사한 실행 옵션을 Steam 게임의 실행 옵션에 붙여넣어 프레임 생성, 스케일링 또는 두 기능 모두에 MAKO Renderer를 활성화하세요.",
	CLIPBOARD_COPIED: "클립보드에 복사됨",
	CLIPBOARD_COPYING: "복사 중...",
	CLIPBOARD_COPY_LAUNCH: "실행 옵션 복사",
	CLIPBOARD_MAKO_FGMOD: "MAKO + DeckyFG",
	CONTENT_RUNNING: "실행 중입니다.",
	CONTENT_ENGINE_UPDATE_REQUIRED: "MAKO Renderer 업데이트 필요",
	CONTENT_ENGINE_INSTALLED: "설치됨:",
	CONTENT_ENGINE_NOT_RECORDED: "기록되지 않음",
	CONTENT_ENGINE_EXPECTS: "이 플러그인에서 필요한 버전:",
	CONTENT_ENGINE_BUNDLED_VERSION: "번들 버전",
	CONTENT_ENGINE_PREDATES_TRACKING: "설치된 페이로드는 버전 추적 이전의 것입니다.",
	CONTENT_ENGINE_UPDATE_DESC: "MAKO Renderer를 다시 설치하여 이 플러그인에 포함된 버전을 적용하세요. 그런 다음 준비된 Flatpak 앱에 맞는 런타임 확장을 업데이트하세요.",
	CONTENT_UPDATE_RENDERER: "MAKO Renderer 업데이트",
	CONTENT_UPDATING_RENDERER: "MAKO Renderer 업데이트 중...",
	MULTIPLIER_TITLE: "고정 FPS 배율",
	MULTIPLIER_DESC: "고정 모드를 2x~5x로 설정합니다. 프레임 페이싱이 불안정한 일부 게임에서는 고정 모드가 적응형보다 나을 수 있습니다. 5x는 고주사율 화면을 위한 고비용 옵션입니다. 게임마다 둘 다 시험하세요. 동적 케이던스 복구에서는 확인된 Gamescope 주사율에 대한 상한이며 적응형은 자체 배율을 관리합니다.",
	MULTIPLIER_ADAPTIVE_RELATION: "적응형 프레임 생성이 활성화된 동안에는 사용할 수 없습니다.",
	ADAPTIVE_TITLE: "적응형 프레임 생성",
	ADAPTIVE_DESC: "목표 FPS에 도달하도록 프레임 생성을 조정합니다. 더 부드러운 페이싱을 위해 안정적인 기본 제한이 기본값입니다. 실제 프레임을 더 유지하려면 분수 적응형을 켜고 게임마다 시험하세요.",
	FRACTIONAL_ADAPTIVE_PRESET: "소수 배율 적응형",
	FRACTIONAL_ADAPTIVE_PRESET_DESC: "생성 비율을 혼합해 실제 60 FPS → 표시 90 FPS와 같은 목표에 맞춥니다. 실제 프레임을 더 유지하고 입력 지연과 고스팅을 줄일 수 있지만, 일부 게임에서는 덜 부드럽게 느껴질 수 있습니다.",
	FRACTIONAL_ADAPTIVE_PRESET_RELATION: "안정적 기본 FPS 제한과 함께 사용할 수 없습니다. 이 옵션을 변경하면 동적 케이던스 복구도 꺼집니다.",
	ADAPTIVE_TARGET_FPS: "목표 FPS",
	ADAPTIVE_TARGET_FPS_DESC: "원하는 표시 FPS입니다. 소수 배율 적응형은 배율을 섞어 목표에 도달하며, 안정적 기본 FPS 제한은 실제 FPS를 목표의 절반으로 제한합니다.",
	ADAPTIVE_AUTO_BASE_FPS_CAP: "안정적 기본 FPS 제한",
	ADAPTIVE_AUTO_BASE_FPS_CAP_DESC: "기본 적응형 모드입니다. 실제 FPS를 목표의 절반으로 제한하여 고른 프레임 간격을 유지합니다. 장점: 일반적으로 페이싱이 더 부드럽습니다. 단점: 실제 프레임이 줄고 입력 지연과 고스팅이 늘 수 있습니다.",
	ADAPTIVE_AUTO_BASE_FPS_CAP_RELATION: "기본 FPS 제한을 재정의합니다. 소수 배율 적응형 또는 동적 케이던스 복구와 함께 사용할 수 없습니다.",
	ADAPTIVE_MAX_MULTIPLIER: "최대 적응형 배율",
	ADAPTIVE_MAX_MULTIPLIER_DESC: "보간 상한입니다. 3x는 균형형이고, 2x는 보통 가장 좋은 화질을 제공하며, 4x는 목표 달성 여유를 높이고, 5x는 충분한 GPU 및 메모리 여유가 있는 고주사율 디스플레이용입니다. 게임별로 테스트하세요.",
	ADAPTIVE_SMOOTH_CADENCE: "부드러운 케이던스",
	ADAPTIVE_SMOOTH_CADENCE_DESC: "검증된 일정 보간 케이던스를 사용합니다. 화면의 움직임이 더 부드럽게 보일 수 있지만 실제 프레임 케이던스를 낮추고 입력 지연을 늘릴 수 있습니다. 기본값은 활성화이며, 끈 상태에서 게임 반응성이 더 좋다고 느껴지면 비활성화하세요.",
	DYNAMIC_CADENCE_RECOVERY: "동적 케이던스 복구",
	DYNAMIC_CADENCE_RECOVERY_DESC: "게임 중 30 FPS, 메뉴 60 FPS처럼 네이티브 프레임률이 바뀌는 게임과 에뮬레이터를 지원합니다. 주기적으로 변화를 확인해 올바른 케이던스를 복구하지만, 확인할 때마다 페이싱에 잠시 영향이 있을 수 있습니다. 필요한 게임에서만 사용하세요.",
	DYNAMIC_CADENCE_RECOVERY_RELATION: "이 옵션을 켜면 안정적 기본 FPS 제한과 기본 FPS 제한이 꺼집니다. 나중에 어느 쪽이든 변경하면 복구가 꺼집니다.",
	DYNAMIC_CADENCE_PROBE_INTERVAL: "케이던스 검사 간격",
	DYNAMIC_CADENCE_PROBE_INTERVAL_DESC: "복구 기능이 기본 프레임 속도를 확인하는 간격입니다. 0.1초는 공격적인 옵션으로 짧은 페이싱 끊김이 자주 발생할 수 있습니다. 2초가 기본값이며 3초는 가장 드물게 확인합니다. 게임별로 테스트하세요.",
	ADAPTIVE_VALUE: "적응형",
	CONFIG_DLL_PATH: "Lossless.dll 경로 (재시작)",
	CONFIG_DLL_PATH_DESC: "Lossless.dll의 전체 경로입니다. 비워 두면 MAKO Renderer 자동 검색을 사용합니다. 변경 후 게임을 다시 시작하세요.",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH: "다음 실행 시 MAKO Renderer 비활성화",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH_DESC: "문제 해결 전용입니다. 다음에 게임을 시작할 때 MAKO Renderer가 로드되지 않게 합니다. 합성을 켜거나 끄려면 위의 프레임 생성을 사용하세요.",
	CONFIG_DISABLE_HDR_EXPOSURE: "HDR 비활성화",
	CONFIG_DISABLE_HDR_EXPOSURE_DESC: "HDR은 이 릴리스에서 사용할 수 없습니다. 이 필수 설정은 안정적인 SDR 경로를 유지합니다.",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY: "Gamescope WSI (재시작)",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_DESC: "Gamescope 표시 경로를 사용하여 일부 게임의 색상 또는 픽셀 형태 모션 아티팩트를 줄일 수 있습니다. 스케일링에서는 자동으로 활성화됩니다. 프레임 생성 전용 프로필에서는 영향을 받는 게임에만 활성화하세요.",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_WARNING: "이 호환성 경로는 지원되는 64비트 호스트 실행으로 제한됩니다. 성능에 영향을 줄 수 있으므로 게임에 필요하지 않으면 꺼 두세요.",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY: "게임 스왑체인 이미지 (재시작)",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_DESC: "게임이 요청한 최소 스왑체인 이미지 수를 유지하여 프레임 생성 사용 시 시작되지 않는 게임을 해결할 수 있습니다. 영향을 받는 게임에서만 활성화하세요.",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_WARNING: "컴포지터에 여유 이미지가 없으면 생성 프레임을 건너뛸 수 있으며, 부하가 높을 때 부드러움이나 성능이 저하될 수 있습니다.",
	FRAME_GENERATION_ENABLED: "프레임 생성",
	FRAME_GENERATION_ENABLED_DESC: "고정 또는 적응형 프레임 생성을 사용하려면 켜 둡니다. 끄면 두 모드 모두 프레임을 생성하지 않으며 설정은 유지됩니다.",
	FRAME_GENERATION_ENABLED_WARNING: "프레임 생성을 사용하려면 이 설정을 켜 두세요.",
	CONFIG_ALLOW_FP16: "FP16 허용 (재시작)",
	CONFIG_ALLOW_FP16_DESC: "전역 렌더러 설정입니다. 모든 프로필에 적용되며 게임별로 변경할 수 없습니다. AMD에서 성능을 향상할 수 있습니다. 오래된 NVIDIA GPU에서는 비활성화하세요. 변경 후 게임을 다시 시작하세요.",
	CONFIG_GPU: "GPU (재시작)",
	CONFIG_GPU_DESC: "선택적 GPU 이름, vendor:device ID 또는 PCI 버스 ID입니다. 변경 후 게임을 다시 시작하세요.",
	CONFIG_ACTIVE_IN: "일치하는 프로세스",
	CONFIG_ACTIVE_IN_DESC: "실행 파일 또는 프로세스 이름을 쉼표로 구분합니다. 실행 중 게임 캡처가 자동으로 채웁니다. 런처나 에뮬레이터에 추가 프로세스 별칭이 필요한 경우에만 편집하세요.",
	CONFIG_MANUAL_OVERRIDES_TITLE: "수동 재정의",
	INSTALL_REMOVE_RENDERER: "MAKO Renderer 제거",
	INSTALL_RENDERER: "MAKO Renderer 설치",
	FLATPAK_EXTENSION_UPDATED: "Flatpak 확장을 업데이트했습니다",
	FLATPAK_EXTENSION_FAILED: "Flatpak 확장 작업에 실패했습니다",
	FLATPAK_EXTENSION_ACTION_FAILED: "실행할 수 없습니다:",
	FLATPAK_RUNTIME_EXTENSION_UPDATED: "런타임 확장을 업데이트했습니다",
	FLATPAK_RUNTIME_EXTENSION: "런타임 확장",
	FLATPAK_APPLICATION_UPDATED: "Flatpak 애플리케이션을 업데이트했습니다",
	FLATPAK_UPDATED: "업데이트됨",
	FLATPAK_PREPARE_APPLICATION: "애플리케이션 준비",
	FLATPAK_PREPARE_APPLICATION_DESC: "해당 런타임 확장을 설치한 다음 앱을 준비하세요. Heroic과 Lutris에는 게임별 래퍼가 필요하며, 에뮬레이터는 앱 전체에 적용됩니다. 단계는 런처 설정 가이드를 확인하세요.",
	FLATPAK_INSTALL_ACTION: "설치",
	FLATPAK_UNINSTALL_ACTION: "제거",
	FLATPAK_APPLICATION_ACTION_FAILED: "업데이트할 수 없습니다:",
	PROFILE_UNKNOWN_ERROR: "알 수 없는 오류",
	PROFILE_LOAD_FAILED: "프로필을 불러오지 못했습니다",
	PROFILE_LOAD_ERROR: "프로필을 불러오는 중 오류가 발생했습니다",
	PROFILE_SWITCHED: "프로필을 전환했습니다",
	PROFILE_SWITCHED_DESC: "전환한 프로필:",
	PROFILE_SWITCH_FAILED: "프로필 전환에 실패했습니다",
	PROFILE_SWITCH_ERROR: "프로필 전환 중 오류가 발생했습니다",
	PROFILE_DELETED: "프로필을 삭제했습니다",
	PROFILE_DELETED_DESC: "삭제한 프로필:",
	PROFILE_DELETE_FAILED: "프로필 삭제에 실패했습니다",
	PROFILE_DELETE_ERROR: "프로필 삭제 중 오류가 발생했습니다",
	PROFILE_RENAMED: "프로필 이름을 변경했습니다",
	PROFILE_RENAMED_DESC: "변경한 프로필 이름:",
	PROFILE_RENAME_FAILED: "프로필 이름 변경에 실패했습니다",
	PROFILE_RENAME_ERROR: "프로필 이름 변경 중 오류가 발생했습니다",
	PROFILE_UPDATE_CONFIG_FAILED: "프로필 설정 업데이트에 실패했습니다",
	PROFILE_UPDATE_CONFIG_ERROR: "프로필 설정 업데이트 중 오류가 발생했습니다",
	USAGE_MAKO_CONFIG_NOTE: "이 명령으로 실행한 게임에만 MAKO가 적용됩니다.",
	USAGE_ISOLATION_NOTE: "같은 게임에서 MAKO를 다른 프레임 생성 또는 스케일링 도구와 함께 사용하지 마세요.",
	ADVANCED_DETAILS_FAILED_LOAD_DATA: "데이터를 불러오지 못했습니다",
	ADVANCED_DETAILS_FAILED_DLL_STATS: "DLL 정보를 가져오지 못했습니다",
	STATUS_ENGINE_INSTALLED: "MAKO Renderer가 설치되었습니다",
	STATUS_ENGINE_NOT_INSTALLED: "MAKO Renderer가 설치되지 않았습니다",
	STATUS_ENGINE_INSTALLING: "MAKO Renderer 설치 중...",
	STATUS_ENGINE_UPDATING: "MAKO Renderer 업데이트 중...",
	STATUS_ENGINE_REMOVING: "MAKO Renderer 제거 중...",
	STATUS_ENGINE_REMOVED: "MAKO Renderer를 제거했습니다!",
	STATUS_INSTALL_FAILED: "설치 실패:",
	STATUS_UNINSTALL_FAILED: "제거 실패:",
	STATUS_LOSSLESS_INSTALLED: "Lossless Scaling이 설치되었습니다",
	STATUS_LOSSLESS_NOT_INSTALLED: "Lossless Scaling이 설치되지 않았습니다 — 프레임 생성 및 LS1에 필요합니다. MAKO Scaler는 계속 사용할 수 있습니다",
	TOAST_INSTALL_COMPLETE: "설치 완료",
	TOAST_INSTALL_COMPLETE_DESC: "기기를 다시 시작하는 것이 좋습니다.",
	TOAST_INSTALL_FAILED: "설치 실패",
	TOAST_UNKNOWN_ERROR: "알 수 없는 오류가 발생했습니다",
	TOAST_UNINSTALL_COMPLETE: "MAKO Renderer 제거됨",
	TOAST_UNINSTALL_COMPLETE_DESC: "MAKO Renderer 파일을 제거했습니다",
	TOAST_UNINSTALL_FAILED: "제거 실패",
	TOAST_CONFIG_UPDATE_FAILED: "업데이트 실패",
	TOAST_CONFIG_UPDATE_FAILED_DESC: "설정 업데이트에 실패했습니다",
	TOAST_CLIPBOARD_SUCCESS: "클립보드에 복사했습니다!",
	TOAST_CLIPBOARD_SUCCESS_DESC: "실행 옵션을 붙여넣을 수 있습니다",
	TOAST_CLIPBOARD_FAILED: "복사 실패",
	TOAST_CLIPBOARD_FAILED_DESC: "클립보드에 복사할 수 없습니다",
	FEATURE_UPSCALING_TAB: "Upscaling",
	LIVE_STATUS_TITLE: "Live Status",
	LIVE_STATUS_CONNECTED: "MAKO is active",
	LIVE_STATUS_WAITING: "Waiting for MAKO",
	LIVE_STATUS_WAITING_DESC: "Live status is unavailable, but MAKO may still be active. Some games and emulators may not report live metrics. Check Frame Generation or Scaling manually.",
	LIVE_STATUS_FG_INACTIVE: "On in settings, but not currently generating frames.",
	LIVE_STATUS_OFF: "Off",
	LIVE_STATUS_SCALING_INACTIVE: "On in settings, but the game image is not being upscaled.",
	LIVE_STATUS_SCALING_MEMORY_LIMIT: "The requested render resolution exceeds this GPU's memory safety limit. Lower the in-game resolution.",
	LIVE_STATUS_SCALING_MEMORY_CONSTRAINED: "Requested {requested}×; limited to {effective}× by this GPU's memory safety limit.",
	LIVE_STATUS_SCALING_NO_HEADROOM: "This input already fills the display target. Lower the in-game resolution or enable Quality Supersampling.",
	LIVE_STATUS_PENDING: "A saved change is still applying or needs a restart.",
	LIVE_STATUS_SUPERSAMPLING: "Quality Supersampling active.",
	LIVE_STATUS_SCALING_FALLBACK: "You selected {requested}; MAKO is using {active} instead.",
	LIVE_STATUS_MODE: "Mode",
	LIVE_STATUS_FIXED_VALUE: "Fixed",
	LIVE_STATUS_ADAPTIVE_STYLE: "Style",
	LIVE_STATUS_STEADY_VALUE: "Steady",
	LIVE_STATUS_FRACTIONAL_VALUE: "Fractional",
	LIVE_STATUS_TARGET: "Target",
	LIVE_STATUS_MAX_MULTIPLIER: "Max factor",
	LIVE_STATUS_MULTIPLIER: "Factor",
	LIVE_STATUS_MODEL: "Model",
	LIVE_STATUS_NATIVE: "Native",
	LIVE_STATUS_LS1_PERFORMANCE: "LS1 Perf",
	LIVE_STATUS_ORIGINAL_RESOLUTION: "Input",
	LIVE_STATUS_RENDER_RESOLUTION: "Render",
	LIVE_STATUS_DISPLAY_RESOLUTION: "Display",
	LIVE_STATUS_SCALED_RESOLUTION: "Output",
	LIVE_STATUS_SCALING_UNAVAILABLE: "Unavailable for this running surface."
};
var language_metadata = {
	en: {
		name: "English"
	},
	"pt-BR": {
		name: "Português (Brasil)"
	},
	"pt-PT": {
		name: "Português (Portugal)"
	},
	es: {
		name: "Español"
	},
	ko: {
		name: "한국어"
	},
	ja: {
		name: "日本語"
	},
	uk: {
		name: "Українська"
	},
	zh: {
		name: "简体中文"
	}
};
var steam_language_map = {
	english: "en",
	brazilian: "pt-BR",
	portuguese: "pt-PT",
	spanish: "es",
	latam: "es",
	korean: "ko",
	koreana: "ko",
	japanese: "ja",
	schinese: "zh",
	tchinese: "zh",
	ukrainian: "uk"
};
var template = {
	CONTENT_SCALING: "Spatial Settings",
	SCALING_ENABLED: "Enable Scaling (Restart)",
	EXPERIMENTAL_LABEL: "Experimental",
	SCALING_ENABLED_DESC: "Enable before starting the game. When off, scaling is fully disabled. Supports Lossless Scaling models and MAKO Scaler.",
	SCALING_ENABLED_WARNING: "Leave Scaling off when you do not need it, as it consumes resources. Using it with Frame Generation may affect performance; try different performance settings or a lower in-game resolution.",
	SCALING_RUNTIME_SURFACE_UNSUPPORTED: "This running surface does not support MAKO scaling. Quality Supersampling, Scale Factor, and Sharpness are locked until a supported surface is detected. Frame Generation remains available.",
	SCALING_METHOD: "Scaling Method",
	SCALING_METHOD_DESC: "Choose the scaling model. You can change it while the game is running.",
	SCALING_LS1_ACTIVE_FALLBACK: "LS1 is unavailable for this game. MAKO Scaler is active. Your LS1 selection is preserved.",
	SCALING_LS1_UNAVAILABLE: "The selected LS1 model could not be loaded during the availability check. MAKO Scaler is used automatically if LS1 cannot load. Your LS1 selection is preserved.",
	SCALING_METHOD_COMPARISON_TIP: "How scaling works:\n1. In Steam, set Game Resolution to your display's maximum resolution (Steam Deck: 1280 × 800; Steam Machine: 3840 × 2160).\n2. In the game, choose a lower resolution, such as 480p, 720p, or more.\n3. Use a Scale Factor to enlarge the image. 2x doubles your resolution.\n\nReducing the resolution of the game and scaling it back can substantially increase performance, with an image-quality trade-off.",
	SCALING_METHOD_NATIVE: "Native Resolution",
	SCALING_METHOD_MAKO: "MAKO Scaler",
	SCALING_METHOD_LS1: "LS1 Quality",
	SCALING_METHOD_LS1_PERFORMANCE: "LS1 Performance",
	SCALING_FACTOR: "Scale Factor",
	SCALING_FACTOR_DESC: "Sets the output-to-input size ratio for every method. With a fixed output size, higher values lower the source resolution. When the game controls the window size, lower its resolution in the game first; higher factors enlarge MAKO's output and can increase GPU cost.",
	SCALING_FACTOR_LIMIT_SUFFIX: "display limit",
	SCALING_FACTOR_DEVICE_LIMIT: "Current display limit: {factor}x. Your saved {saved}x value is preserved; enable Quality Supersampling to use it.",
	SCALING_FACTOR_NO_HEADROOM: "This resolution already fills the display. Lower the in-game resolution or enable Quality Supersampling.",
	SCALING_SUPERSAMPLING: "Quality Supersampling",
	SCALING_SUPERSAMPLING_DESC: "Allows exceeding a Gamescope output limit for higher-quality downsampling, increasing GPU and memory use. Does not change scaling on other desktop surfaces.",
	SCALING_SUPERSAMPLING_WARNING: "Supersampling is enabled. Where a Gamescope output limit applies, MAKO may exceed it for a sharper downsampled image.",
	SCALING_SHARPNESS: "Scaling Sharpness",
	SCALING_SHARPNESS_DESC: "For MAKO, applies this 0–100% multiplier to its 3x sharpening baseline. For LS1, selects one of five learned sharpness variants.",
	CONTENT_FPS_MULTIPLIER: "Frame Generation",
	CONTENT_PERFORMANCE_SETTINGS: "Performance Settings",
	CONTENT_ADVANCED_DETAILS: "Advanced Details",
	CONTENT_FLATPAK_SETUP: "Flatpak Setup",
	CONFIG_SECTION_TITLE: "Advanced Rendering Settings",
	CONFIG_WORKAROUNDS_TITLE: "Compatibility Settings",
	CONFIG_FLOW_SCALE: "Flow Scale",
	CONFIG_FLOW_SCALE_DESC: "Controls the internal motion-estimation resolution used only for Frame Generation. Lower values reduce GPU work; higher values favour quality.",
	CONFIG_BASE_FPS_CAP: "Base FPS Cap",
	CONFIG_BASE_FPS_CAP_OFF: "Off",
	CONFIG_BASE_FPS_CAP_DESC: "Caps real application frames before frame generation. Works with DirectX, OpenGL through Zink, and Vulkan.",
	CONFIG_BASE_FPS_CAP_STEADY_RELATION: "Controlled by Steady Base Cap ({fps} FPS). Your manual value remains saved.",
	CONFIG_BASE_FPS_CAP_RECOVERY_RELATION: "Changing this cap turns Dynamic Cadence Recovery off.",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD: "Auto-disable Frame Generation by Refresh Rate",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD_DESC: "Pauses frame generation when Gamescope confirms the current display is at or below the threshold, then resumes your selected mode above it. Does nothing when refresh feedback is unavailable.",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD: "Refresh Rate Threshold",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD_DESC: "Choose the highest refresh rate where frame generation should remain paused.",
	CONFIG_ULTRA_PERFORMANCE: "Ultra Performance (Restart)",
	CONFIG_ULTRA_PERFORMANCE_DESC: "Reduces MAKO's GPU workload on low-power devices. Uses 75% Flow Scale, the Lighter FG Model, FP16 when supported, and LS1 Performance when Scaling is enabled. Trades image quality for performance across the active MAKO features.",
	CONFIG_ULTRA_PERFORMANCE_WARNING: "Turning Ultra Performance on or off requires a game restart. Other compatible profile controls remain available after startup.",
	CONFIG_PERFORMANCE_MODE: "Lighter FG Model",
	CONFIG_PERFORMANCE_MODE_DESC: "Reduces GPU work by using a lighter frame-generation model at the cost of more ghosting. Ultra Performance locks this on.",
	CONFIG_DISABLE_STEAMDECK_MODE: "Disable Steam Deck Mode (Restart)",
	CONFIG_DISABLE_STEAMDECK_MODE_DESC: "Disables Steam Deck mode. Unlocks hidden settings in some games.",
	CONFIG_ENABLE_ZINK: "Enable Zink for OpenGL Games (Restart)",
	CONFIG_ENABLE_ZINK_DESC: "Uses the Vulkan-based OpenGL implementation for OpenGL games. May cause crashes or freezes in some games.",
	CONFIG_FORCE_ALSA_AUDIO: "Force ALSA Audio (Restart)",
	CONFIG_FORCE_ALSA_AUDIO_DESC: "May improve compatibility with modes such as Zink and reduce audio stuttering or sudden loud sounds. Disable to restore normal audio defaults.",
	CONFIG_EXTERNAL_TOOLS_TITLE: "External Tools",
	CONFIG_ENABLE_MANGOHUD: "Enable MangoHud (Restart)",
	CONFIG_ENABLE_MANGOHUD_DESC: "Uses the host-installed MangoHud and your existing MangoHud configuration. See the expert guide for per-game environment overrides.",
	CONFIG_ENABLE_VKBASALT: "Enable vkBasalt (Restart)",
	CONFIG_ENABLE_VKBASALT_DESC: "Keep it off unless you are testing vkBasalt with this game. Uses a host-installed vkBasalt layer for this profile. The initial test lane is limited to 64-bit native Vulkan or Proton games launched directly by Steam on SteamOS.",
	INSTALL_INSTALLING: "Installing MAKO Renderer...",
	INSTALL_UNINSTALLING: "Removing MAKO Renderer...",
	FLATPAK_MODAL_TITLE: "Flatpak Extensions",
	FLATPAK_RUNTIME_INSTALLER: "Runtime Extension Installer",
	FLATPAK_RUNTIME_VERSION: "Runtime {version}",
	FLATPAK_INSTALLED: "Installed",
	FLATPAK_NOT_INSTALLED: "Not installed",
	FLATPAK_UNINSTALL_TITLE: "Uninstall Runtime Extension",
	FLATPAK_UNINSTALL_CONFIRM_PREFIX: "Are you sure you want to uninstall the",
	FLATPAK_UNINSTALL_CONFIRM_SUFFIX: "runtime extension?",
	FLATPAK_UNINSTALL_BTN: "Uninstall",
	FLATPAK_INSTALL_BTN: "Install",
	FLATPAK_UPDATE_BTN: "Update",
	FLATPAK_INSTALLING_BTN: "Installing...",
	FLATPAK_UNINSTALLING_BTN: "Uninstalling...",
	FLATPAK_UPDATING_BTN: "Updating...",
	FLATPAK_APPS_TITLE: "Flatpak Applications",
	FLATPAK_NO_APPS: "No Flatpak Apps Found",
	FLATPAK_NO_APPS_DESC: "No Flatpak applications are currently installed",
	FLATPAK_STATUS_CONFIGURED: "Prepared",
	FLATPAK_STATUS_PARTIAL: "Partial",
	FLATPAK_STATUS_NO_OVERRIDES: "No overrides",
	FLATPAK_ERROR: "Error",
	FLATPAK_ERROR_STATUS: "Failed to check extension status",
	FLATPAK_ERROR_APPS: "Failed to load Flatpak applications",
	FLATPAK_STEAM_CONFIG_TITLE: "Manual Steam shortcut reference",
	FLATPAK_STEAM_CONFIG_HEADER: "Target example (does not configure Steam)",
	FLATPAK_STEAM_CONFIG_DESC: "Use this only for a manually added Steam shortcut whose original Target is /usr/bin/flatpak. Prepare that Flatpak application above first, then leave Start In and Launch Options unchanged. Heroic, Lutris, and EmuDeck have separate steps in the launcher setup guide.",
	FLATPAK_IMPORTANT_LABEL: "IMPORTANT:",
	FLATPAK_STEAM_CONFIG_IMPORTANT: "Replace TARGET only. Do not paste this into Launch Options.",
	FLATPAK_PER_GAME_APP_DESC: "{app_id} - {status}. Enable MAKO per game using {wrapper_path}. See the launcher setup guide for the correct field.",
	FLATPAK_DIRECT_APP_DESC: "{app_id} - {status}. Preparation applies to this entire Flatpak app. Follow the launcher setup guide for EmuDeck and Steam shortcuts.",
	FLATPAK_STEP_WRAPPER_PATH: "Wrapper installed on this device:",
	FLATPAK_STEP_FINAL: "Target for a shortcut that originally used \"/usr/bin/flatpak\":",
	FLATPAK_OPEN_README: "Open launcher setup guide",
	FLATPAK_CLOSE: "Close",
	ADVANCED_DETAILS_LOADING: "Loading information...",
	ADVANCED_DETAILS_ERROR_PREFIX: "Error:",
	ADVANCED_DETAILS_DLL_PATH: "DLL Path",
	ADVANCED_DETAILS_LIBRARY: "Lossless Scaling Library",
	ADVANCED_DETAILS_NOT_AVAILABLE: "Not available",
	ADVANCED_DETAILS_DLL_HASH: "DLL SHA256 Hash",
	ADVANCED_DETAILS_DETECTION_SOURCE: "Detection Source",
	ADVANCED_DETAILS_LAUNCH_SCRIPT: "Launch Script",
	ADVANCED_DETAILS_SCRIPT_NOT_FOUND_PREFIX: "Script not found:",
	ADVANCED_DETAILS_PATH_PREFIX: "Path:",
	ADVANCED_DETAILS_NO_CONTENT: "No content",
	ADVANCED_DETAILS_CONFIG_FILE: "Configuration File",
	ADVANCED_DETAILS_CONFIG_NOT_FOUND_PREFIX: "Config not found:",
	ADVANCED_DETAILS_CLOSE: "Close",
	WELCOME_TITLE: "Hello from the MAKO Team!",
	WELCOME_TIPS_COLLAPSE: "Hide tips",
	WELCOME_TIPS_EXPAND: "Show tips",
	WELCOME_LIVE_UPDATES: "Many settings apply live.",
	WELCOME_RESTART_REQUIRED: "Options marked Restart require a game restart.",
	WELCOME_PERFORMANCE_NOTE: "Game resolution and scaling changes can affect performance.",
	WELCOME_CLEAN_SESSION_PREFIX: "If anything ",
	WELCOME_CLEAN_SESSION_WRONG: "looks or feels wrong",
	WELCOME_CLEAN_SESSION_AFTER: " after ",
	WELCOME_CLEAN_SESSION_CHANGES: "several changes",
	WELCOME_CLEAN_SESSION_RESTART_SEPARATOR: ", ",
	WELCOME_CLEAN_SESSION_RESTART: "restart the game for a clean new session.",
	WELCOME_ENJOY: "Every game is different. Find the best settings that work for you and enjoy playing. MAKO keeps improving with every release, so keep an eye on the release page!",
	PROFILE_CAPTURE_READY: "MAKO selects saved profiles automatically. If this game is new, save it below; restart the game after changing restart-only settings.",
	PROFILE_HELP: "Start a game and save its process once. MAKO selects saved profiles automatically; outside a game, the dropdown only chooses which profile to edit.",
	PROFILE_SECTION_TITLE: "Game / Process Profiles",
	PROFILE_DEFAULT: "Default",
	PROFILE_SAVED_LABEL: "Saved profile",
	PROFILE_GAME_SAVED: "Game profile saved",
	PROFILE_GAME_SAVE_FAILED: "Could not save game profile",
	PROFILE_SAVE_RUNNING: "Save profile for {game}",
	PROFILE_DETAIL_DEFAULT: "Open a game to save its profile",
	PROFILE_DETAIL_GAME: "Saved game",
	PROFILE_DETAIL_PROCESS: "Saved process",
	PROFILE_STEAM_APP_ID: "Steam app ID: {app_id}",
	PROFILE_PROCESSES: "Processes: {processes}",
	PROFILE_PROCESSES_EMPTY: "Processes: enter one in Matched Processes below",
	PROFILE_MANAGE_WHEN_IDLE: "Close the running game to rename or delete profiles.",
	PROFILE_NAME_LABEL: "Name",
	PROFILE_CANCEL_BTN: "Cancel",
	PROFILE_RENAME_TITLE: "Rename Profile",
	PROFILE_RENAME_DESC_PREFIX: "Choose a friendly name for this game or process profile.",
	PROFILE_RENAME_BTN: "Rename",
	PROFILE_CANNOT_DELETE_TITLE: "Cannot delete default profile",
	PROFILE_CANNOT_DELETE_MSG: "The default profile cannot be deleted",
	PROFILE_DELETE_TITLE: "Delete Game / Process Profile",
	PROFILE_DELETE_CONFIRM: "Delete \"{profile}\" and all of its saved settings?",
	PROFILE_DELETE_BTN: "Delete",
	PROFILE_CANNOT_RENAME_TITLE: "Cannot rename default profile",
	PROFILE_CANNOT_RENAME_MSG: "The default profile cannot be renamed",
	USAGE_TITLE: "Usage Instructions",
	USAGE_DESC: "Copy the launch option into your Steam game's launch options to enable MAKO Renderer for frame generation, scaling, or both.",
	CLIPBOARD_COPIED: "Copied to clipboard",
	CLIPBOARD_COPYING: "Copying...",
	CLIPBOARD_COPY_LAUNCH: "Copy Launch Option",
	CLIPBOARD_MAKO_FGMOD: "MAKO + DeckyFG",
	CONTENT_RUNNING: "running.",
	CONTENT_ENGINE_UPDATE_REQUIRED: "MAKO Renderer update required",
	CONTENT_ENGINE_INSTALLED: "Installed:",
	CONTENT_ENGINE_NOT_RECORDED: "not recorded",
	CONTENT_ENGINE_EXPECTS: "This plugin expects:",
	CONTENT_ENGINE_BUNDLED_VERSION: "the bundled version",
	CONTENT_ENGINE_PREDATES_TRACKING: "The installed payload predates version tracking.",
	CONTENT_ENGINE_UPDATE_DESC: "Reinstall MAKO Renderer to apply the version bundled with this plugin. Then update the matching runtime extensions for prepared Flatpak apps.",
	CONTENT_UPDATE_RENDERER: "Update MAKO Renderer",
	CONTENT_UPDATING_RENDERER: "Updating MAKO Renderer...",
	MULTIPLIER_TITLE: "Fixed FPS Multiplier",
	MULTIPLIER_DESC: "Sets Fixed mode to 2x–5x. Fixed may perform better than Adaptive in some games, especially when frame pacing is uneven or unstable. 5x is a high-cost option for high-refresh displays. Test both per game. With Dynamic Cadence Recovery, this is a ceiling against confirmed Gamescope refresh; Adaptive manages its own multiplier.",
	MULTIPLIER_ADAPTIVE_RELATION: "Unavailable while Adaptive Frame Generation is enabled.",
	ADAPTIVE_TITLE: "Adaptive Frame Generation",
	ADAPTIVE_DESC: "Adjusts frame generation to reach Target FPS. The steady base cap is the default for smoother pacing. Enable Fractional Adaptive to keep more real frames, but test it per game.",
	FRACTIONAL_ADAPTIVE_PRESET: "Fractional Adaptive",
	FRACTIONAL_ADAPTIVE_PRESET_DESC: "Mixes generation ratios to reach targets such as 60 real FPS → 90 displayed FPS. It keeps more real frames and may reduce input lag and ghosting, but can feel less smooth in some games.",
	FRACTIONAL_ADAPTIVE_PRESET_RELATION: "Cannot be combined with Steady Base Cap. Changing it also turns Dynamic Cadence Recovery off.",
	ADAPTIVE_TARGET_FPS: "Target FPS",
	ADAPTIVE_TARGET_FPS_DESC: "Desired displayed FPS. Fractional Adaptive may mix ratios to reach it; Steady Base Cap starts at half the target and can align a validated lower integer rung.",
	ADAPTIVE_AUTO_BASE_FPS_CAP: "Steady Base Cap",
	ADAPTIVE_AUTO_BASE_FPS_CAP_DESC: "The default Adaptive mode. Starts at half the target; with Smooth Cadence it can align a validated 3x–5x rung. Pros: usually smoother pacing. Cons: fewer real frames and potentially more input lag and ghosting.",
	ADAPTIVE_AUTO_BASE_FPS_CAP_RELATION: "Overrides Base FPS Cap. Cannot be combined with Fractional Adaptive or Dynamic Cadence Recovery.",
	ADAPTIVE_MAX_MULTIPLIER: "Maximum Adaptive Multiplier",
	ADAPTIVE_MAX_MULTIPLIER_DESC: "Interpolation ceiling. 3x is balanced; 2x usually looks best, 4x gives more headroom, and 5x is for high-refresh displays with substantial GPU and memory headroom. Test per game.",
	ADAPTIVE_SMOOTH_CADENCE: "Smooth Cadence",
	ADAPTIVE_SMOOTH_CADENCE_DESC: "Uses a validated constant interpolation cadence. With Steady Base Cap, it can align proven 3x–5x demand to an exact target rung. It can make motion smoother, but may lower real-frame cadence and increase input lag. Enabled by default; disable it if a game feels more responsive without it.",
	DYNAMIC_CADENCE_RECOVERY: "Dynamic Cadence Recovery",
	DYNAMIC_CADENCE_RECOVERY_DESC: "Helps games and emulators that switch native rates, such as 30 FPS gameplay and 60 FPS menus. It periodically checks for a rate change and recovers the correct cadence, but each check can briefly affect pacing. Enable it only for affected games.",
	DYNAMIC_CADENCE_RECOVERY_RELATION: "Turning this on disables Steady Base Cap and Base FPS Cap. Changing either cap later turns Recovery off.",
	DYNAMIC_CADENCE_PROBE_INTERVAL: "Cadence Probe Interval",
	DYNAMIC_CADENCE_PROBE_INTERVAL_DESC: "How often Recovery tests the native frame rate. 0.1 seconds is aggressive and may cause frequent brief pacing hitches; 2 seconds is the default, while 3 seconds checks least often. Test per game.",
	ADAPTIVE_VALUE: "Adaptive",
	CONFIG_DLL_PATH: "Lossless.dll Path (Restart)",
	CONFIG_DLL_PATH_DESC: "Optional full path to Lossless.dll. Leave blank to use MAKO Renderer automatic discovery.",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH: "Disable MAKO Renderer on Next Launch",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH_DESC: "Troubleshooting only. Stops MAKO Renderer loading the next time the game starts. Use Frame Generation above to switch synthesis on or off.",
	CONFIG_DISABLE_HDR_EXPOSURE: "Disable HDR",
	CONFIG_DISABLE_HDR_EXPOSURE_DESC: "HDR is unavailable in this release. This required setting keeps the stable SDR path active.",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY: "Gamescope WSI (Restart)",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_DESC: "May reduce coloured or pixelated motion artifacts in some games by using Gamescope's presentation path. Scaling enables it automatically. For FG-only profiles, enable it only for affected games.",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_WARNING: "This compatibility path is limited to supported 64-bit host launches. Leave it off when the game does not need it, as it may impact performance.",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY: "Game Swapchain Images (Restart)",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_DESC: "Can fix games that fail to start with Frame Generation by preserving the game's requested swapchain image minimum. Enable it only for affected games.",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_WARNING: "Generated frames may be skipped when the compositor has no spare image, which can reduce smoothness or performance under pressure.",
	FRAME_GENERATION_ENABLED: "Frame Generation",
	FRAME_GENERATION_ENABLED_DESC: "Leave it on to use Fixed or Adaptive Frame Generation. When off, neither mode generates frames; your settings stay saved.",
	FRAME_GENERATION_ENABLED_WARNING: "Keep this on if you want frame generation.",
	CONFIG_ALLOW_FP16: "Allow FP16 (Restart)",
	CONFIG_ALLOW_FP16_DESC: "Global renderer setting: applies to all profiles and cannot be changed per game. Improves performance on AMD; disable for older NVIDIA GPUs. Restart the game after changing it.",
	CONFIG_GPU: "GPU (Restart)",
	CONFIG_GPU_DESC: "Optional GPU name, vendor:device ID, or PCI bus ID. Restart the game after changing it.",
	CONFIG_ACTIVE_IN: "Matched Processes",
	CONFIG_ACTIVE_IN_DESC: "Executable or process names separated by commas. Running-game capture fills these automatically; edit them only when a launcher or emulator needs an additional process alias.",
	CONFIG_MANUAL_OVERRIDES_TITLE: "Manual Overrides",
	INSTALL_REMOVE_RENDERER: "Remove MAKO Renderer",
	INSTALL_RENDERER: "Install MAKO Renderer",
	FLATPAK_EXTENSION_UPDATED: "Flatpak extension updated",
	FLATPAK_EXTENSION_FAILED: "Flatpak extension failed",
	FLATPAK_EXTENSION_ACTION_FAILED: "Could not",
	FLATPAK_RUNTIME_EXTENSION_UPDATED: "runtime extension updated",
	FLATPAK_RUNTIME_EXTENSION: "runtime extension",
	FLATPAK_APPLICATION_UPDATED: "Flatpak application updated",
	FLATPAK_UPDATED: "updated",
	FLATPAK_PREPARE_APPLICATION: "Prepare an application",
	FLATPAK_PREPARE_APPLICATION_DESC: "Install the matching runtime extension, then prepare the app. Heroic and Lutris need a per-game wrapper; emulators are prepared app-wide. Open the launcher setup guide for steps.",
	FLATPAK_INSTALL_ACTION: "install",
	FLATPAK_UNINSTALL_ACTION: "uninstall",
	FLATPAK_APPLICATION_ACTION_FAILED: "Could not update",
	PROFILE_UNKNOWN_ERROR: "Unknown error",
	PROFILE_LOAD_FAILED: "Failed to load profiles",
	PROFILE_LOAD_ERROR: "Error loading profiles",
	PROFILE_SWITCHED: "Profile switched",
	PROFILE_SWITCHED_DESC: "Switched to profile:",
	PROFILE_SWITCH_FAILED: "Failed to switch profile",
	PROFILE_SWITCH_ERROR: "Error switching profile",
	PROFILE_DELETED: "Profile deleted",
	PROFILE_DELETED_DESC: "Deleted profile:",
	PROFILE_DELETE_FAILED: "Failed to delete profile",
	PROFILE_DELETE_ERROR: "Error deleting profile",
	PROFILE_RENAMED: "Profile renamed",
	PROFILE_RENAMED_DESC: "Renamed profile to:",
	PROFILE_RENAME_FAILED: "Failed to rename profile",
	PROFILE_RENAME_ERROR: "Error renaming profile",
	PROFILE_UPDATE_CONFIG_FAILED: "Failed to update profile config",
	PROFILE_UPDATE_CONFIG_ERROR: "Error updating profile config",
	USAGE_MAKO_CONFIG_NOTE: "This command applies MAKO only to the game you launch with it.",
	USAGE_ISOLATION_NOTE: "Do not combine MAKO with another frame-generation or scaling tool for the same game.",
	ADVANCED_DETAILS_FAILED_LOAD_DATA: "Failed to load data",
	ADVANCED_DETAILS_FAILED_DLL_STATS: "Failed to get DLL stats",
	STATUS_ENGINE_INSTALLED: "MAKO Renderer installed",
	STATUS_ENGINE_NOT_INSTALLED: "MAKO Renderer not installed",
	STATUS_ENGINE_INSTALLING: "Installing MAKO Renderer...",
	STATUS_ENGINE_UPDATING: "Updating MAKO Renderer...",
	STATUS_ENGINE_REMOVING: "Removing MAKO Renderer...",
	STATUS_ENGINE_REMOVED: "MAKO Renderer removed successfully!",
	STATUS_INSTALL_FAILED: "Installation failed:",
	STATUS_UNINSTALL_FAILED: "Uninstallation failed:",
	STATUS_LOSSLESS_INSTALLED: "Lossless Scaling installed",
	STATUS_LOSSLESS_NOT_INSTALLED: "Lossless Scaling not installed — required for Frame Generation and LS1; MAKO Scaler remains available",
	TOAST_INSTALL_COMPLETE: "Installation Complete",
	TOAST_INSTALL_COMPLETE_DESC: "Restarting your device is recommended.",
	TOAST_INSTALL_FAILED: "Installation Failed",
	TOAST_UNKNOWN_ERROR: "Unknown error occurred",
	TOAST_UNINSTALL_COMPLETE: "MAKO Renderer Removed",
	TOAST_UNINSTALL_COMPLETE_DESC: "MAKO Renderer files have been removed",
	TOAST_UNINSTALL_FAILED: "Uninstallation Failed",
	TOAST_CONFIG_UPDATE_FAILED: "Update Failed",
	TOAST_CONFIG_UPDATE_FAILED_DESC: "Failed to update configuration",
	TOAST_CLIPBOARD_SUCCESS: "Copied to Clipboard!",
	TOAST_CLIPBOARD_SUCCESS_DESC: "Launch option ready to paste",
	TOAST_CLIPBOARD_FAILED: "Copy Failed",
	TOAST_CLIPBOARD_FAILED_DESC: "Unable to copy to clipboard",
	FEATURE_UPSCALING_TAB: "Upscaling",
	LIVE_STATUS_TITLE: "Live Status",
	LIVE_STATUS_CONNECTED: "MAKO is active",
	LIVE_STATUS_WAITING: "Waiting for MAKO",
	LIVE_STATUS_WAITING_DESC: "Live status is unavailable, but MAKO may still be active. Some games and emulators may not report live metrics. Check Frame Generation or Scaling manually.",
	LIVE_STATUS_FG_INACTIVE: "On in settings, but not currently generating frames.",
	LIVE_STATUS_OFF: "Off",
	LIVE_STATUS_SCALING_INACTIVE: "On in settings, but the game image is not being upscaled.",
	LIVE_STATUS_SCALING_MEMORY_LIMIT: "The requested render resolution exceeds this GPU's memory safety limit. Lower the in-game resolution.",
	LIVE_STATUS_SCALING_MEMORY_CONSTRAINED: "Requested {requested}×; limited to {effective}× by this GPU's memory safety limit.",
	LIVE_STATUS_SCALING_NO_HEADROOM: "This input already fills the display target. Lower the in-game resolution or enable Quality Supersampling.",
	LIVE_STATUS_PENDING: "A saved change is still applying or needs a restart.",
	LIVE_STATUS_SUPERSAMPLING: "Quality Supersampling active.",
	LIVE_STATUS_SCALING_FALLBACK: "You selected {requested}; MAKO is using {active} instead.",
	LIVE_STATUS_MODE: "Mode",
	LIVE_STATUS_FIXED_VALUE: "Fixed",
	LIVE_STATUS_ADAPTIVE_STYLE: "Style",
	LIVE_STATUS_STEADY_VALUE: "Steady",
	LIVE_STATUS_FRACTIONAL_VALUE: "Fractional",
	LIVE_STATUS_TARGET: "Target",
	LIVE_STATUS_MAX_MULTIPLIER: "Max factor",
	LIVE_STATUS_MULTIPLIER: "Factor",
	LIVE_STATUS_MODEL: "Model",
	LIVE_STATUS_NATIVE: "Native",
	LIVE_STATUS_LS1_PERFORMANCE: "LS1 Perf",
	LIVE_STATUS_ORIGINAL_RESOLUTION: "Input",
	LIVE_STATUS_RENDER_RESOLUTION: "Render",
	LIVE_STATUS_DISPLAY_RESOLUTION: "Display",
	LIVE_STATUS_SCALED_RESOLUTION: "Output",
	LIVE_STATUS_SCALING_UNAVAILABLE: "Unavailable for this running surface."
};
var uk = {
	CONTENT_SCALING: "Масштабування",
	SCALING_ENABLED: "Увімкнути масштабування (перезапуск)",
	EXPERIMENTAL_LABEL: "Експериментально",
	SCALING_ENABLED_DESC: "Увімкніть перед запуском гри. Якщо вимкнено, масштабування повністю вимикається. Підтримує моделі Lossless Scaling і MAKO Scaler.",
	SCALING_ENABLED_WARNING: "Залишайте масштабування вимкненим, коли воно не потрібне, оскільки воно споживає ресурси. Використання разом із генерацією кадрів може впливати на продуктивність; спробуйте інші налаштування продуктивності або нижчу роздільну здатність у грі.",
	SCALING_RUNTIME_SURFACE_UNSUPPORTED: "This running surface does not support MAKO scaling. Quality Supersampling, Scale Factor, and Sharpness are locked until a supported surface is detected. Frame Generation remains available.",
	SCALING_METHOD: "Метод масштабування",
	SCALING_METHOD_DESC: "Виберіть модель масштабування. Її можна змінювати під час роботи гри.",
	SCALING_LS1_ACTIVE_FALLBACK: "LS1 is unavailable for this game. MAKO Scaler is active. Your LS1 selection is preserved.",
	SCALING_LS1_UNAVAILABLE: "The selected LS1 model could not be loaded during the availability check. MAKO Scaler is used automatically if LS1 cannot load. Your LS1 selection is preserved.",
	SCALING_METHOD_COMPARISON_TIP: "Як працює масштабування:\n1. У Steam установіть роздільну здатність гри на максимальну роздільну здатність дисплея (Steam Deck: 1280 × 800; Steam Machine: 3840 × 2160).\n2. У грі виберіть нижчу роздільну здатність, наприклад 480p, 720p або більше.\n3. Використайте коефіцієнт масштабування, щоб збільшити зображення. 2x подвоює роздільну здатність.\n\nЗменшення роздільної здатності гри з подальшим масштабуванням може значно підвищити продуктивність, але з компромісом у якості зображення.",
	SCALING_METHOD_NATIVE: "Нативна роздільна здатність",
	SCALING_METHOD_MAKO: "MAKO Scaler",
	SCALING_METHOD_LS1: "LS1 Quality",
	SCALING_METHOD_LS1_PERFORMANCE: "LS1 Performance",
	SCALING_FACTOR: "Коефіцієнт масштабування",
	SCALING_FACTOR_DESC: "Визначає співвідношення розміру вихідного та вхідного зображень для всіх методів. За фіксованого розміру виведення вищі значення знижують роздільну здатність джерела. Якщо гра керує розміром вікна, спочатку знизьте роздільну здатність у самій грі; вищі коефіцієнти збільшують зображення на виході MAKO та можуть підвищити навантаження на GPU.",
	SCALING_FACTOR_LIMIT_SUFFIX: "межа дисплея",
	SCALING_FACTOR_DEVICE_LIMIT: "Поточна межа дисплея: {factor}x. Збережене значення {saved}x не змінено; увімкніть Якісний суперсемплінг, щоб використати його.",
	SCALING_FACTOR_NO_HEADROOM: "Ця роздільна здатність уже заповнює дисплей. Зменште роздільну здатність у грі або ввімкніть Якісний суперсемплінг.",
	SCALING_SUPERSAMPLING: "Якісний суперсемплінг",
	SCALING_SUPERSAMPLING_DESC: "Дозволяє перевищувати обмеження розміру виведення Gamescope для якіснішого зменшення зображення, збільшуючи використання GPU та пам’яті. Не змінює масштабування на інших поверхнях стільниці.",
	SCALING_SUPERSAMPLING_WARNING: "Суперсемплінг увімкнено. Якщо діє обмеження розміру виведення Gamescope, MAKO може перевищити його для чіткішого зменшеного зображення.",
	SCALING_SHARPNESS: "Різкість масштабування",
	SCALING_SHARPNESS_DESC: "Для MAKO цей множник 0–100% застосовується до базової різкості 3x. Для LS1 він обирає один із п’яти навчених варіантів різкості.",
	CONTENT_FPS_MULTIPLIER: "Генерація кадрів",
	CONTENT_PERFORMANCE_SETTINGS: "Налаштування продуктивності",
	CONTENT_ADVANCED_DETAILS: "Докладна інформація",
	CONTENT_FLATPAK_SETUP: "Налаштування Flatpak",
	CONFIG_SECTION_TITLE: "Розширені налаштування рендерингу",
	CONFIG_WORKAROUNDS_TITLE: "Налаштування сумісності",
	CONFIG_FLOW_SCALE: "Масштаб оптичного потоку",
	CONFIG_FLOW_SCALE_DESC: "Керує внутрішньою роздільною здатністю оцінки руху лише для генерації кадрів. Менші значення знижують навантаження на GPU, більші надають пріоритет якості.",
	CONFIG_BASE_FPS_CAP: "Базовий ліміт FPS",
	CONFIG_BASE_FPS_CAP_OFF: "Вимк.",
	CONFIG_BASE_FPS_CAP_DESC: "Обмежує реальні кадри застосунку до генерації кадрів. Працює з DirectX, OpenGL через Zink і Vulkan.",
	CONFIG_BASE_FPS_CAP_STEADY_RELATION: "Керується стабільним базовим лімітом FPS ({fps} FPS). Ручне значення залишається збереженим.",
	CONFIG_BASE_FPS_CAP_RECOVERY_RELATION: "Зміна цього ліміту вимикає відновлення динамічного ритму кадрів.",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD: "Автоматично вимикати генерацію кадрів за частотою оновлення",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD_DESC: "Призупиняє генерацію кадрів, коли Gamescope підтверджує, що поточна частота оновлення дисплея не перевищує поріг, і відновлює вибраний режим вище нього. Нічого не робить, коли зворотний зв’язок про частоту оновлення недоступний.",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD: "Поріг частоти оновлення",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD_DESC: "Виберіть найвищу частоту оновлення, за якої генерація кадрів має залишатися призупиненою.",
	CONFIG_ULTRA_PERFORMANCE: "Ультрапродуктивність (перезапуск)",
	CONFIG_ULTRA_PERFORMANCE_DESC: "Зменшує навантаження MAKO на GPU малопотужних пристроїв. Використовує масштаб оптичного потоку 75%, легшу модель FG, FP16 за підтримки та LS1 Performance, коли масштабування увімкнено. Обмінює якість зображення на продуктивність активних функцій MAKO.",
	CONFIG_ULTRA_PERFORMANCE_WARNING: "Увімкнення або вимкнення Ultra Performance потребує перезапуску гри. Інші сумісні параметри профілю залишаються доступними після запуску.",
	CONFIG_PERFORMANCE_MODE: "Легша модель FG",
	CONFIG_PERFORMANCE_MODE_DESC: "Зменшує роботу GPU завдяки легшій моделі генерації кадрів ціною більшої кількості шлейфів. Ультрапродуктивність фіксує її увімкненою.",
	CONFIG_DISABLE_STEAMDECK_MODE: "Вимкнути режим Steam Deck (перезапуск)",
	CONFIG_DISABLE_STEAMDECK_MODE_DESC: "Вимикає режим Steam Deck. У деяких іграх це відкриває приховані налаштування.",
	CONFIG_ENABLE_ZINK: "Увімкнути Zink для ігор OpenGL (перезапуск)",
	CONFIG_ENABLE_ZINK_DESC: "Використовує реалізацію OpenGL поверх Vulkan для ігор OpenGL. У деяких іграх можливі збої або зависання.",
	CONFIG_FORCE_ALSA_AUDIO: "Примусово використовувати ALSA (перезапуск)",
	CONFIG_FORCE_ALSA_AUDIO_DESC: "Може покращити сумісність із режимами на кшталт Zink і зменшити заїкання звуку або раптові гучні звуки. Вимкніть, щоб повернути звичайні налаштування аудіо.",
	CONFIG_EXTERNAL_TOOLS_TITLE: "Зовнішні інструменти",
	CONFIG_ENABLE_MANGOHUD: "Увімкнути MangoHud (перезапуск)",
	CONFIG_ENABLE_MANGOHUD_DESC: "Використовує встановлений у системі MangoHud і вашу наявну конфігурацію MangoHud. Перевизначення змінних середовища для окремих ігор описані в посібнику для досвідчених користувачів.",
	CONFIG_ENABLE_VKBASALT: "Увімкнути vkBasalt (перезапуск)",
	CONFIG_ENABLE_VKBASALT_DESC: "Не вмикайте, якщо не тестуєте vkBasalt у цій грі. Використовує встановлений у системі шар vkBasalt для цього профілю. Початкове тестування обмежене 64-бітними нативними Vulkan-іграми або Proton-іграми, запущеними безпосередньо через Steam у SteamOS.",
	INSTALL_INSTALLING: "Встановлення MAKO Renderer...",
	INSTALL_UNINSTALLING: "Видалення MAKO Renderer...",
	FLATPAK_MODAL_TITLE: "Розширення Flatpak",
	FLATPAK_RUNTIME_INSTALLER: "Інсталятор розширень середовища виконання",
	FLATPAK_RUNTIME_VERSION: "Середовище виконання {version}",
	FLATPAK_INSTALLED: "Встановлено",
	FLATPAK_NOT_INSTALLED: "Не встановлено",
	FLATPAK_UNINSTALL_TITLE: "Видалити розширення середовища виконання",
	FLATPAK_UNINSTALL_CONFIRM_PREFIX: "Видалити розширення середовища виконання версії",
	FLATPAK_UNINSTALL_CONFIRM_SUFFIX: "— ви впевнені?",
	FLATPAK_UNINSTALL_BTN: "Видалити",
	FLATPAK_INSTALL_BTN: "Встановити",
	FLATPAK_UPDATE_BTN: "Оновити",
	FLATPAK_INSTALLING_BTN: "Встановлення...",
	FLATPAK_UNINSTALLING_BTN: "Видалення...",
	FLATPAK_UPDATING_BTN: "Оновлення...",
	FLATPAK_APPS_TITLE: "Застосунки Flatpak",
	FLATPAK_NO_APPS: "Застосунки Flatpak не знайдено",
	FLATPAK_NO_APPS_DESC: "Зараз застосунки Flatpak не встановлені",
	FLATPAK_STATUS_CONFIGURED: "Підготовлено",
	FLATPAK_STATUS_PARTIAL: "Частково",
	FLATPAK_STATUS_NO_OVERRIDES: "Без перевизначень",
	FLATPAK_ERROR: "Помилка",
	FLATPAK_ERROR_STATUS: "Не вдалося перевірити стан розширення",
	FLATPAK_ERROR_APPS: "Не вдалося завантажити список застосунків Flatpak",
	FLATPAK_STEAM_CONFIG_TITLE: "Необов’язкові ярлики Flatpak у Steam",
	FLATPAK_STEAM_CONFIG_HEADER: "Налаштування ярликів Flatpak у Steam",
	FLATPAK_STEAM_CONFIG_DESC: "Використовуйте лише для доданого вручну ярлика Steam, початкове поле «Ціль» якого містить /usr/bin/flatpak. Спочатку підготуйте застосунок Flatpak вище та залиште «Робочу теку» й «Параметри запуску» без змін. Heroic, Lutris і EmuDeck мають окремі кроки в посібнику з налаштування лаунчерів.",
	FLATPAK_IMPORTANT_LABEL: "ВАЖЛИВО:",
	FLATPAK_STEAM_CONFIG_IMPORTANT: "Вкажіть це в TARGET (НЕ В ПАРАМЕТРАХ ЗАПУСКУ)",
	FLATPAK_PER_GAME_APP_DESC: "{app_id} - {status}. Увімкніть MAKO для окремої гри за допомогою {wrapper_path}. Потрібне поле вказано в посібнику з налаштування лаунчерів.",
	FLATPAK_DIRECT_APP_DESC: "{app_id} - {status}. Підготовка діє для всього цього застосунку Flatpak. Для EmuDeck і ярликів Steam дотримуйтеся посібника з налаштування лаунчерів.",
	FLATPAK_STEP_WRAPPER_PATH: "Шлях до обгортки (Wrapper) на цьому пристрої:",
	FLATPAK_STEP_FINAL: "Кінцевий результат має виглядати так:",
	FLATPAK_OPEN_README: "Відкрити посібник із налаштування лаунчерів",
	FLATPAK_CLOSE: "Закрити",
	ADVANCED_DETAILS_LOADING: "Завантаження інформації...",
	ADVANCED_DETAILS_ERROR_PREFIX: "Помилка:",
	ADVANCED_DETAILS_DLL_PATH: "Шлях до DLL",
	ADVANCED_DETAILS_LIBRARY: "Бібліотека Lossless Scaling",
	ADVANCED_DETAILS_NOT_AVAILABLE: "Недоступно",
	ADVANCED_DETAILS_DLL_HASH: "SHA256-хеш DLL",
	ADVANCED_DETAILS_DETECTION_SOURCE: "Джерело виявлення",
	ADVANCED_DETAILS_LAUNCH_SCRIPT: "Скрипт запуску",
	ADVANCED_DETAILS_SCRIPT_NOT_FOUND_PREFIX: "Скрипт не знайдено:",
	ADVANCED_DETAILS_PATH_PREFIX: "Шлях:",
	ADVANCED_DETAILS_NO_CONTENT: "Немає вмісту",
	ADVANCED_DETAILS_CONFIG_FILE: "Файл конфігурації",
	ADVANCED_DETAILS_CONFIG_NOT_FOUND_PREFIX: "Конфігурацію не знайдено:",
	ADVANCED_DETAILS_CLOSE: "Закрити",
	WELCOME_TITLE: "Вітаємо від команди MAKO!",
	WELCOME_TIPS_COLLAPSE: "Сховати поради",
	WELCOME_TIPS_EXPAND: "Показати поради",
	WELCOME_LIVE_UPDATES: "Багато налаштувань застосовуються наживо.",
	WELCOME_RESTART_REQUIRED: "Параметри з позначкою «Перезапуск» потребують перезапуску гри.",
	WELCOME_PERFORMANCE_NOTE: "Зміни роздільної здатності та масштабування гри можуть впливати на продуктивність.",
	WELCOME_CLEAN_SESSION_PREFIX: "Якщо щось ",
	WELCOME_CLEAN_SESSION_WRONG: "виглядає або відчувається не так",
	WELCOME_CLEAN_SESSION_AFTER: " після ",
	WELCOME_CLEAN_SESSION_CHANGES: "кількох змін",
	WELCOME_CLEAN_SESSION_RESTART_SEPARATOR: ", ",
	WELCOME_CLEAN_SESSION_RESTART: "перезапустіть гру для нового чистого сеансу.",
	WELCOME_ENJOY: "Кожна гра відрізняється. Знайдіть налаштування, які найкраще підходять вам, і насолоджуйтеся грою. MAKO вдосконалюється з кожним випуском, тож стежте за сторінкою випусків!",
	PROFILE_CAPTURE_READY: "MAKO автоматично вибирає збережені профілі. Якщо ця гра нова, збережіть її нижче; після зміни налаштувань, що потребують перезапуску, перезапустіть гру.",
	PROFILE_HELP: "Запустіть гру й один раз збережіть її процес. MAKO автоматично вибирає збережені профілі; поза грою випадаючий список лише визначає профіль для редагування.",
	PROFILE_SECTION_TITLE: "Профілі ігор / процесів",
	PROFILE_DEFAULT: "За замовчуванням",
	PROFILE_SAVED_LABEL: "Збережений профіль",
	PROFILE_GAME_SAVED: "Профіль гри збережено",
	PROFILE_GAME_SAVE_FAILED: "Не вдалося зберегти профіль гри",
	PROFILE_SAVE_RUNNING: "Зберегти профіль для {game}",
	PROFILE_DETAIL_DEFAULT: "Відкрийте гру, щоб зберегти її профіль",
	PROFILE_DETAIL_GAME: "Збережена гра",
	PROFILE_DETAIL_PROCESS: "Збережений процес",
	PROFILE_STEAM_APP_ID: "Steam App ID: {app_id}",
	PROFILE_PROCESSES: "Процеси: {processes}",
	PROFILE_PROCESSES_EMPTY: "Процеси: вкажіть один нижче в полі «Процеси, що відповідають профілю»",
	PROFILE_MANAGE_WHEN_IDLE: "Закрийте запущену гру, щоб перейменовувати або видаляти профілі.",
	PROFILE_NAME_LABEL: "Назва",
	PROFILE_CANCEL_BTN: "Скасувати",
	PROFILE_RENAME_TITLE: "Перейменувати профіль",
	PROFILE_RENAME_DESC_PREFIX: "Виберіть зрозумілу назву для профілю цієї гри або процесу.",
	PROFILE_RENAME_BTN: "Перейменувати",
	PROFILE_CANNOT_DELETE_TITLE: "Не можна видалити профіль за замовчуванням",
	PROFILE_CANNOT_DELETE_MSG: "Профіль за замовчуванням видалити не можна",
	PROFILE_DELETE_TITLE: "Видалити профіль гри / процесу",
	PROFILE_DELETE_CONFIRM: "Видалити «{profile}» і всі збережені для нього налаштування?",
	PROFILE_DELETE_BTN: "Видалити",
	PROFILE_CANNOT_RENAME_TITLE: "Не можна перейменувати профіль за замовчуванням",
	PROFILE_CANNOT_RENAME_MSG: "Профіль за замовчуванням перейменувати не можна",
	USAGE_TITLE: "Як користуватися",
	USAGE_DESC: "Вставте скопійований параметр у параметри запуску гри в Steam, щоб увімкнути MAKO Renderer для генерації кадрів, масштабування або обох функцій.",
	CLIPBOARD_COPIED: "Скопійовано в буфер обміну",
	CLIPBOARD_COPYING: "Копіювання...",
	CLIPBOARD_COPY_LAUNCH: "Копіювати параметр запуску",
	CLIPBOARD_MAKO_FGMOD: "MAKO + DeckyFG",
	CONTENT_RUNNING: "запущено.",
	CONTENT_ENGINE_UPDATE_REQUIRED: "Потрібне оновлення MAKO Renderer",
	CONTENT_ENGINE_INSTALLED: "Встановлено:",
	CONTENT_ENGINE_NOT_RECORDED: "версію не записано",
	CONTENT_ENGINE_EXPECTS: "Цьому плагіну потрібна версія:",
	CONTENT_ENGINE_BUNDLED_VERSION: "вбудована версія",
	CONTENT_ENGINE_PREDATES_TRACKING: "Встановлений пакет створено до появи відстеження версій.",
	CONTENT_ENGINE_UPDATE_DESC: "Перевстановіть MAKO Renderer, щоб застосувати версію з цього плагіна. Потім оновіть відповідні розширення середовища виконання для підготовлених застосунків Flatpak.",
	CONTENT_UPDATE_RENDERER: "Оновити MAKO Renderer",
	CONTENT_UPDATING_RENDERER: "Оновлення MAKO Renderer...",
	MULTIPLIER_TITLE: "Фіксований множник FPS",
	MULTIPLIER_DESC: "Установлює фіксований режим від 2x до 5x. У деяких іграх він може працювати краще за адаптивний, особливо за нерівного ритму. 5x — ресурсомістка опція для дисплеїв із високою частотою. Перевіряйте обидва режими для кожної гри. З відновленням динамічного ритму це межа за підтвердженою частотою Gamescope; адаптивний режим керує власним множником.",
	MULTIPLIER_ADAPTIVE_RELATION: "Недоступно, поки ввімкнено адаптивну генерацію кадрів.",
	ADAPTIVE_TITLE: "Адаптивна генерація кадрів",
	ADAPTIVE_DESC: "Налаштовує генерацію кадрів для досягнення цільового FPS. Стабільне базове обмеження є типовим для плавнішого ритму. Увімкніть дробовий адаптивний режим, щоб зберегти більше справжніх кадрів, але перевіряйте його для кожної гри.",
	FRACTIONAL_ADAPTIVE_PRESET: "Адаптивний режим із дробовим множником (пресет)",
	FRACTIONAL_ADAPTIVE_PRESET_DESC: "Поєднує коефіцієнти генерації, щоб досягати цілей на кшталт 60 реальних FPS → 90 відображуваних FPS. Зберігає більше реальних кадрів і може зменшити затримку введення та кількість шлейфів, але в деяких іграх може бути менш плавним.",
	FRACTIONAL_ADAPTIVE_PRESET_RELATION: "Не можна поєднувати зі стабільним базовим лімітом FPS. Зміна цього параметра також вимикає відновлення динамічного ритму кадрів.",
	ADAPTIVE_TARGET_FPS: "Цільовий FPS",
	ADAPTIVE_TARGET_FPS_DESC: "Бажаний відображуваний FPS. Адаптивний режим із дробовим множником може поєднувати коефіцієнти для його досягнення; стабільний базовий ліміт FPS обмежує реальний FPS половиною цільового.",
	ADAPTIVE_AUTO_BASE_FPS_CAP: "Стабільний базовий ліміт FPS",
	ADAPTIVE_AUTO_BASE_FPS_CAP_DESC: "Стандартний адаптивний режим. Обмежує реальний FPS половиною цільового для рівномірного ритму кадрів. Перевага: зазвичай плавніше виведення. Недолік: менше реальних кадрів і потенційно більша затримка введення та більше шлейфів.",
	ADAPTIVE_AUTO_BASE_FPS_CAP_RELATION: "Перевизначає базовий ліміт FPS. Не можна поєднувати з адаптивним режимом із дробовим множником або відновленням динамічного ритму кадрів.",
	ADAPTIVE_MAX_MULTIPLIER: "Максимальний адаптивний множник",
	ADAPTIVE_MAX_MULTIPLIER_DESC: "Максимальний коефіцієнт інтерполяції. 3x — збалансований варіант; 2x зазвичай дає найкращу якість, 4x залишає більше запасу для досягнення цілі, а 5x призначений для дисплеїв із високою частотою оновлення за наявності значного запасу GPU та пам’яті. Перевіряйте окремо для кожної гри.",
	ADAPTIVE_SMOOTH_CADENCE: "Рівномірний ритм кадрів",
	ADAPTIVE_SMOOTH_CADENCE_DESC: "Використовує перевірений постійний ритм інтерполяції. Рух на екрані може виглядати плавніше, але частота реальних кадрів може знизитися, а затримка введення — зрости. Увімкнено за замовчуванням; вимкніть, якщо без цього гра відчувається чутливішою.",
	DYNAMIC_CADENCE_RECOVERY: "Відновлення динамічного ритму кадрів",
	DYNAMIC_CADENCE_RECOVERY_DESC: "Допомагає іграм та емуляторам, у яких змінюється власна частота кадрів, наприклад 30 FPS у грі та 60 FPS у меню. Періодично перевіряє зміну й відновлює правильний ритм кадрів, але кожна перевірка може коротко вплинути на плавність. Увімкніть лише для відповідних ігор.",
	DYNAMIC_CADENCE_RECOVERY_RELATION: "Увімкнення цього параметра вимикає стабільний базовий ліміт FPS і базовий ліміт FPS. Подальша зміна будь-якого з них вимикає відновлення.",
	DYNAMIC_CADENCE_PROBE_INTERVAL: "Інтервал перевірки ритму кадрів",
	DYNAMIC_CADENCE_PROBE_INTERVAL_DESC: "Як часто відновлення перевіряє власну частоту кадрів. 0,1 секунди — агресивний варіант, який може спричиняти часті короткі збої ритму; 2 секунди — типове значення, а 3 секунди перевіряють найрідше. Перевіряйте в кожній грі.",
	ADAPTIVE_VALUE: "Адаптив.",
	CONFIG_DLL_PATH: "Шлях до Lossless.dll (перезапуск)",
	CONFIG_DLL_PATH_DESC: "Необов’язковий повний шлях до Lossless.dll. Залиште порожнім, щоб MAKO Renderer виконав автоматичний пошук. Після зміни перезапустіть гру.",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH: "Вимкнути MAKO Renderer під час наступного запуску",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH_DESC: "Лише для діагностики. Не дає MAKO Renderer завантажитися під час наступного запуску гри. Щоб увімкнути або вимкнути синтез, використовуйте перемикач «Генерація кадрів» вище.",
	CONFIG_DISABLE_HDR_EXPOSURE: "Вимкнути HDR",
	CONFIG_DISABLE_HDR_EXPOSURE_DESC: "HDR у цьому випуску недоступний. Це обов’язкове налаштування зберігає стабільний шлях SDR.",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY: "Gamescope WSI (перезапуск)",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_DESC: "Може зменшити кольорові або піксельні артефакти руху в деяких іграх завдяки шляху презентації Gamescope. Масштабування вмикає його автоматично. У профілях лише з генерацією кадрів вмикайте його тільки для ігор із такими артефактами.",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_WARNING: "Цей шлях сумісності обмежений підтримуваними 64-бітними запусками на хості. Залишайте його вимкненим, коли він не потрібен грі, оскільки він може вплинути на продуктивність.",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY: "Зображення swapchain гри (перезапуск)",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_DESC: "Може виправити ігри, які не запускаються з генерацією кадрів, зберігаючи запитаний грою мінімум зображень swapchain. Вмикайте лише для проблемних ігор.",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_WARNING: "Згенеровані кадри можуть пропускатися, коли композитору бракує вільного зображення, що може знизити плавність або продуктивність під навантаженням.",
	FRAME_GENERATION_ENABLED: "Генерація кадрів",
	FRAME_GENERATION_ENABLED_DESC: "Залиште увімкненим для фіксованої або адаптивної генерації кадрів. Якщо вимкнути, жоден режим не генеруватиме кадри, але налаштування збережуться.",
	FRAME_GENERATION_ENABLED_WARNING: "Залиште увімкненим, якщо хочете використовувати генерацію кадрів.",
	CONFIG_ALLOW_FP16: "Дозволити FP16 (перезапуск)",
	CONFIG_ALLOW_FP16_DESC: "Підвищує продуктивність на AMD; вимкніть для старіших GPU NVIDIA. Після зміни перезапустіть гру.",
	CONFIG_GPU: "GPU (перезапуск)",
	CONFIG_GPU_DESC: "Необов’язково: назва GPU, ID vendor:device або PCI Bus ID. Після зміни перезапустіть гру.",
	CONFIG_ACTIVE_IN: "Процеси, що відповідають профілю",
	CONFIG_ACTIVE_IN_DESC: "Назви виконуваних файлів або процесів через кому. Захоплення запущеної гри заповнює їх автоматично; редагуйте лише тоді, коли лаунчеру або емулятору потрібен додатковий псевдонім процесу.",
	CONFIG_MANUAL_OVERRIDES_TITLE: "Ручні перевизначення",
	INSTALL_REMOVE_RENDERER: "Видалити MAKO Renderer",
	INSTALL_RENDERER: "Встановити MAKO Renderer",
	FLATPAK_EXTENSION_UPDATED: "Розширення Flatpak оновлено",
	FLATPAK_EXTENSION_FAILED: "Помилка розширення Flatpak",
	FLATPAK_EXTENSION_ACTION_FAILED: "Не вдалося",
	FLATPAK_RUNTIME_EXTENSION_UPDATED: "розширення середовища виконання оновлено",
	FLATPAK_RUNTIME_EXTENSION: "розширення середовища виконання",
	FLATPAK_APPLICATION_UPDATED: "Застосунок Flatpak оновлено",
	FLATPAK_UPDATED: "оновлено",
	FLATPAK_PREPARE_APPLICATION: "Підготувати застосунок",
	FLATPAK_PREPARE_APPLICATION_DESC: "Установіть відповідне розширення середовища виконання, а потім підготуйте застосунок. Heroic і Lutris потребують обгортки для кожної гри; емулятори готуються для всього застосунку. Кроки наведено в посібнику з налаштування лаунчерів.",
	FLATPAK_INSTALL_ACTION: "встановити",
	FLATPAK_UNINSTALL_ACTION: "видалити",
	FLATPAK_APPLICATION_ACTION_FAILED: "Не вдалося оновити",
	PROFILE_UNKNOWN_ERROR: "Невідома помилка",
	PROFILE_LOAD_FAILED: "Не вдалося завантажити профілі",
	PROFILE_LOAD_ERROR: "Помилка завантаження профілів",
	PROFILE_SWITCHED: "Профіль перемкнено",
	PROFILE_SWITCHED_DESC: "Вибрано профіль:",
	PROFILE_SWITCH_FAILED: "Не вдалося перемкнути профіль",
	PROFILE_SWITCH_ERROR: "Помилка перемикання профілю",
	PROFILE_DELETED: "Профіль видалено",
	PROFILE_DELETED_DESC: "Видалено профіль:",
	PROFILE_DELETE_FAILED: "Не вдалося видалити профіль",
	PROFILE_DELETE_ERROR: "Помилка видалення профілю",
	PROFILE_RENAMED: "Профіль перейменовано",
	PROFILE_RENAMED_DESC: "Нова назва профілю:",
	PROFILE_RENAME_FAILED: "Не вдалося перейменувати профіль",
	PROFILE_RENAME_ERROR: "Помилка перейменування профілю",
	PROFILE_UPDATE_CONFIG_FAILED: "Не вдалося оновити налаштування профілю",
	PROFILE_UPDATE_CONFIG_ERROR: "Помилка оновлення налаштувань профілю",
	USAGE_MAKO_CONFIG_NOTE: "Ця команда застосовує MAKO лише до гри, запущеної через неї.",
	USAGE_ISOLATION_NOTE: "Не поєднуйте MAKO з іншим інструментом генерації кадрів або масштабування в одній грі.",
	ADVANCED_DETAILS_FAILED_LOAD_DATA: "Не вдалося завантажити дані",
	ADVANCED_DETAILS_FAILED_DLL_STATS: "Не вдалося отримати відомості про DLL",
	STATUS_ENGINE_INSTALLED: "MAKO Renderer встановлено",
	STATUS_ENGINE_NOT_INSTALLED: "MAKO Renderer не встановлено",
	STATUS_ENGINE_INSTALLING: "Встановлення MAKO Renderer...",
	STATUS_ENGINE_UPDATING: "Оновлення MAKO Renderer...",
	STATUS_ENGINE_REMOVING: "Видалення MAKO Renderer...",
	STATUS_ENGINE_REMOVED: "MAKO Renderer успішно видалено!",
	STATUS_INSTALL_FAILED: "Помилка встановлення:",
	STATUS_UNINSTALL_FAILED: "Помилка видалення:",
	STATUS_LOSSLESS_INSTALLED: "Lossless Scaling встановлено",
	STATUS_LOSSLESS_NOT_INSTALLED: "Lossless Scaling не встановлено — він потрібен для генерації кадрів і LS1; MAKO Scaler залишається доступним",
	TOAST_INSTALL_COMPLETE: "Встановлення завершено",
	TOAST_INSTALL_COMPLETE_DESC: "Рекомендується перезапустити пристрій.",
	TOAST_INSTALL_FAILED: "Помилка встановлення",
	TOAST_UNKNOWN_ERROR: "Сталася невідома помилка",
	TOAST_UNINSTALL_COMPLETE: "MAKO Renderer видалено",
	TOAST_UNINSTALL_COMPLETE_DESC: "Файли MAKO Renderer видалено",
	TOAST_UNINSTALL_FAILED: "Помилка видалення",
	TOAST_CONFIG_UPDATE_FAILED: "Помилка оновлення",
	TOAST_CONFIG_UPDATE_FAILED_DESC: "Не вдалося оновити конфігурацію",
	TOAST_CLIPBOARD_SUCCESS: "Скопійовано в буфер обміну!",
	TOAST_CLIPBOARD_SUCCESS_DESC: "Параметр запуску готовий до вставлення",
	TOAST_CLIPBOARD_FAILED: "Помилка копіювання",
	TOAST_CLIPBOARD_FAILED_DESC: "Не вдалося скопіювати в буфер обміну",
	FEATURE_UPSCALING_TAB: "Upscaling",
	LIVE_STATUS_TITLE: "Live Status",
	LIVE_STATUS_CONNECTED: "MAKO is active",
	LIVE_STATUS_WAITING: "Waiting for MAKO",
	LIVE_STATUS_WAITING_DESC: "Live status is unavailable, but MAKO may still be active. Some games and emulators may not report live metrics. Check Frame Generation or Scaling manually.",
	LIVE_STATUS_FG_INACTIVE: "On in settings, but not currently generating frames.",
	LIVE_STATUS_OFF: "Off",
	LIVE_STATUS_SCALING_INACTIVE: "On in settings, but the game image is not being upscaled.",
	LIVE_STATUS_SCALING_MEMORY_LIMIT: "The requested render resolution exceeds this GPU's memory safety limit. Lower the in-game resolution.",
	LIVE_STATUS_SCALING_MEMORY_CONSTRAINED: "Requested {requested}×; limited to {effective}× by this GPU's memory safety limit.",
	LIVE_STATUS_SCALING_NO_HEADROOM: "This input already fills the display target. Lower the in-game resolution or enable Quality Supersampling.",
	LIVE_STATUS_PENDING: "A saved change is still applying or needs a restart.",
	LIVE_STATUS_SUPERSAMPLING: "Quality Supersampling active.",
	LIVE_STATUS_SCALING_FALLBACK: "You selected {requested}; MAKO is using {active} instead.",
	LIVE_STATUS_MODE: "Mode",
	LIVE_STATUS_FIXED_VALUE: "Fixed",
	LIVE_STATUS_ADAPTIVE_STYLE: "Style",
	LIVE_STATUS_STEADY_VALUE: "Steady",
	LIVE_STATUS_FRACTIONAL_VALUE: "Fractional",
	LIVE_STATUS_TARGET: "Target",
	LIVE_STATUS_MAX_MULTIPLIER: "Max factor",
	LIVE_STATUS_MULTIPLIER: "Factor",
	LIVE_STATUS_MODEL: "Model",
	LIVE_STATUS_NATIVE: "Native",
	LIVE_STATUS_LS1_PERFORMANCE: "LS1 Perf",
	LIVE_STATUS_ORIGINAL_RESOLUTION: "Input",
	LIVE_STATUS_RENDER_RESOLUTION: "Render",
	LIVE_STATUS_DISPLAY_RESOLUTION: "Display",
	LIVE_STATUS_SCALED_RESOLUTION: "Output",
	LIVE_STATUS_SCALING_UNAVAILABLE: "Unavailable for this running surface."
};
var zh = {
	CONTENT_SCALING: "图像缩放",
	SCALING_ENABLED: "启用缩放（重启）",
	EXPERIMENTAL_LABEL: "实验性",
	SCALING_ENABLED_DESC: "请在启动游戏前启用。关闭后，缩放将完全停用。支持 Lossless Scaling 模型和 MAKO Scaler。",
	SCALING_ENABLED_WARNING: "不需要缩放时请将其关闭，因为它会占用资源。与帧生成同时使用可能会影响性能；请尝试不同的性能设置或降低游戏内分辨率。",
	SCALING_RUNTIME_SURFACE_UNSUPPORTED: "This running surface does not support MAKO scaling. Quality Supersampling, Scale Factor, and Sharpness are locked until a supported surface is detected. Frame Generation remains available.",
	SCALING_METHOD: "缩放方法",
	SCALING_METHOD_DESC: "选择缩放模型。可在游戏运行时更改。",
	SCALING_LS1_ACTIVE_FALLBACK: "LS1 is unavailable for this game. MAKO Scaler is active. Your LS1 selection is preserved.",
	SCALING_LS1_UNAVAILABLE: "The selected LS1 model could not be loaded during the availability check. MAKO Scaler is used automatically if LS1 cannot load. Your LS1 selection is preserved.",
	SCALING_METHOD_COMPARISON_TIP: "缩放如何工作：\n1. 在 Steam 中，将游戏分辨率设为显示器的最高分辨率（Steam Deck：1280 × 800；Steam Machine：3840 × 2160）。\n2. 在游戏内选择较低分辨率，例如 480p、720p 或更高。\n3. 使用缩放系数放大画面。2x 会让分辨率翻倍。\n\n降低游戏渲染分辨率后再进行缩放可以显著提升性能，但会牺牲一些图像质量。",
	SCALING_METHOD_NATIVE: "原生分辨率",
	SCALING_METHOD_MAKO: "MAKO Scaler",
	SCALING_METHOD_LS1: "LS1 Quality",
	SCALING_METHOD_LS1_PERFORMANCE: "LS1 Performance",
	SCALING_FACTOR: "缩放倍率",
	SCALING_FACTOR_DESC: "设置所有方法的输出与输入尺寸比率。输出尺寸固定时，数值越高，源分辨率越低。如果游戏控制窗口尺寸，请先在游戏中降低分辨率；更高的倍率会增大 MAKO 的输出尺寸，并可能增加 GPU 负载。",
	SCALING_FACTOR_LIMIT_SUFFIX: "显示上限",
	SCALING_FACTOR_DEVICE_LIMIT: "当前显示上限：{factor}x。已保存的 {saved}x 值会保留；启用质量超级采样即可使用。",
	SCALING_FACTOR_NO_HEADROOM: "此分辨率已填满显示器。请降低游戏内分辨率或启用质量超级采样。",
	SCALING_SUPERSAMPLING: "质量超级采样",
	SCALING_SUPERSAMPLING_DESC: "允许超出 Gamescope 的输出尺寸限制，以获得更高质量的下采样效果，但会增加 GPU 和内存使用量。不会改变其他桌面表面的缩放行为。",
	SCALING_SUPERSAMPLING_WARNING: "已启用超采样。如果存在 Gamescope 输出尺寸限制，MAKO 可以超出该限制，以获得更清晰的下采样图像。",
	SCALING_SHARPNESS: "缩放锐度",
	SCALING_SHARPNESS_DESC: "对于 MAKO，此 0–100% 倍率会应用于其 3 倍锐化基准。对于 LS1，它从五个训练好的锐度变体中选择。",
	CONTENT_FPS_MULTIPLIER: "帧生成",
	CONTENT_PERFORMANCE_SETTINGS: "性能设置",
	CONTENT_ADVANCED_DETAILS: "高级详情",
	CONTENT_FLATPAK_SETUP: "Flatpak 设置",
	CONFIG_SECTION_TITLE: "高级渲染设置",
	CONFIG_WORKAROUNDS_TITLE: "兼容性设置",
	CONFIG_FLOW_SCALE: "光流缩放",
	CONFIG_FLOW_SCALE_DESC: "调整仅用于帧生成的内部运动估计分辨率。较低的值可减少 GPU 负载，较高的值更注重画质。",
	CONFIG_BASE_FPS_CAP: "基础 FPS 上限",
	CONFIG_BASE_FPS_CAP_OFF: "关闭",
	CONFIG_BASE_FPS_CAP_DESC: "在帧生成前限制应用的真实帧率。支持 DirectX、通过 Zink 运行的 OpenGL 和 Vulkan。",
	CONFIG_BASE_FPS_CAP_STEADY_RELATION: "由稳定基础 FPS 上限（{fps} FPS）控制。手动设置值仍会保留。",
	CONFIG_BASE_FPS_CAP_RECOVERY_RELATION: "更改此上限会关闭动态节奏恢复。",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD: "按刷新率自动禁用帧生成",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD_DESC: "当 Gamescope 确认当前显示器的刷新率等于或低于阈值时暂停帧生成，超过阈值后恢复所选模式。无法获取刷新率信息时不会执行任何操作。",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD: "刷新率阈值",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD_DESC: "选择帧生成应保持暂停的最高刷新率。",
	CONFIG_ULTRA_PERFORMANCE: "极致性能（重启）",
	CONFIG_ULTRA_PERFORMANCE_DESC: "降低 MAKO 在低功耗设备上的 GPU 负载。它使用 75% 光流缩放、轻量帧生成模型、受支持时的 FP16，并在启用缩放时使用 LS1 Performance。以画质换取所有已启用 MAKO 功能的性能。",
	CONFIG_ULTRA_PERFORMANCE_WARNING: "开启或关闭 Ultra Performance 需要重启游戏。其他兼容的配置文件控件在启动后仍可使用。",
	CONFIG_PERFORMANCE_MODE: "轻量帧生成模型",
	CONFIG_PERFORMANCE_MODE_DESC: "使用更轻量的帧生成模型来减少 GPU 工作，但会增加重影。极致性能会强制启用此选项。",
	CONFIG_DISABLE_STEAMDECK_MODE: "禁用 Steam Deck 模式（重启）",
	CONFIG_DISABLE_STEAMDECK_MODE_DESC: "禁用 Steam Deck 模式，可解锁部分游戏中的隐藏设置。",
	CONFIG_ENABLE_ZINK: "为 OpenGL 游戏启用 Zink（重启）",
	CONFIG_ENABLE_ZINK_DESC: "让 OpenGL 游戏使用基于 Vulkan 的 OpenGL 实现。可能导致部分游戏崩溃或卡死。",
	CONFIG_FORCE_ALSA_AUDIO: "强制使用 ALSA 音频（重启）",
	CONFIG_FORCE_ALSA_AUDIO_DESC: "可能改善与 Zink 等模式的兼容性，并减少音频卡顿或突然出现的巨响。关闭后将恢复常规音频默认设置。",
	CONFIG_EXTERNAL_TOOLS_TITLE: "外部工具",
	CONFIG_ENABLE_MANGOHUD: "启用 MangoHud（重启）",
	CONFIG_ENABLE_MANGOHUD_DESC: "使用主机上安装的 MangoHud 和现有 MangoHud 配置。每个游戏的环境变量覆盖方法请参阅专家指南。",
	CONFIG_ENABLE_VKBASALT: "启用 vkBasalt（重启）",
	CONFIG_ENABLE_VKBASALT_DESC: "除非要在此游戏中测试 vkBasalt，否则请保持关闭。为此配置文件使用主机上安装的 vkBasalt 层。初始测试范围仅限于在 SteamOS 上由 Steam 直接启动的 64 位原生 Vulkan 或 Proton 游戏。",
	INSTALL_INSTALLING: "正在安装 MAKO Renderer...",
	INSTALL_UNINSTALLING: "正在移除 MAKO Renderer...",
	FLATPAK_MODAL_TITLE: "Flatpak 扩展",
	FLATPAK_RUNTIME_INSTALLER: "运行时扩展安装器",
	FLATPAK_RUNTIME_VERSION: "运行时 {version}",
	FLATPAK_INSTALLED: "已安装",
	FLATPAK_NOT_INSTALLED: "未安装",
	FLATPAK_UNINSTALL_TITLE: "卸载运行时扩展",
	FLATPAK_UNINSTALL_CONFIRM_PREFIX: "确定要卸载",
	FLATPAK_UNINSTALL_CONFIRM_SUFFIX: "运行时扩展吗？",
	FLATPAK_UNINSTALL_BTN: "卸载",
	FLATPAK_INSTALL_BTN: "安装",
	FLATPAK_UPDATE_BTN: "更新",
	FLATPAK_INSTALLING_BTN: "正在安装...",
	FLATPAK_UNINSTALLING_BTN: "正在卸载...",
	FLATPAK_UPDATING_BTN: "正在更新...",
	FLATPAK_APPS_TITLE: "Flatpak 应用",
	FLATPAK_NO_APPS: "未找到 Flatpak 应用",
	FLATPAK_NO_APPS_DESC: "当前没有安装任何 Flatpak 应用",
	FLATPAK_STATUS_CONFIGURED: "已准备",
	FLATPAK_STATUS_PARTIAL: "部分完成",
	FLATPAK_STATUS_NO_OVERRIDES: "无覆盖设置",
	FLATPAK_ERROR: "错误",
	FLATPAK_ERROR_STATUS: "无法检查扩展状态",
	FLATPAK_ERROR_APPS: "无法加载 Flatpak 应用",
	FLATPAK_STEAM_CONFIG_TITLE: "手动 Steam 快捷方式参考",
	FLATPAK_STEAM_CONFIG_HEADER: "目标示例（不会自动配置 Steam）",
	FLATPAK_STEAM_CONFIG_DESC: "仅用于手动添加且原始目标为 /usr/bin/flatpak 的 Steam 快捷方式。先在上方准备该 Flatpak 应用，再保持起始位置和启动选项不变。Heroic、Lutris 和 EmuDeck 在启动器设置指南中有各自的步骤。",
	FLATPAK_IMPORTANT_LABEL: "重要：",
	FLATPAK_STEAM_CONFIG_IMPORTANT: "只替换“目标”。不要将此内容粘贴到“启动选项”中。",
	FLATPAK_PER_GAME_APP_DESC: "{app_id} - {status}。使用 {wrapper_path} 为每个游戏启用 MAKO。请查看启动器设置指南以确认应填写的字段。",
	FLATPAK_DIRECT_APP_DESC: "{app_id} - {status}。准备对整个 Flatpak 应用生效。EmuDeck 和 Steam 快捷方式的步骤请参阅启动器设置指南。",
	FLATPAK_STEP_WRAPPER_PATH: "此设备上安装的包装器：",
	FLATPAK_STEP_FINAL: "原来使用 \"/usr/bin/flatpak\" 的快捷方式目标：",
	FLATPAK_OPEN_README: "打开启动器设置指南",
	FLATPAK_CLOSE: "关闭",
	ADVANCED_DETAILS_LOADING: "正在加载信息...",
	ADVANCED_DETAILS_ERROR_PREFIX: "错误：",
	ADVANCED_DETAILS_DLL_PATH: "DLL 路径",
	ADVANCED_DETAILS_LIBRARY: "Lossless Scaling 库",
	ADVANCED_DETAILS_NOT_AVAILABLE: "不可用",
	ADVANCED_DETAILS_DLL_HASH: "DLL SHA256 哈希",
	ADVANCED_DETAILS_DETECTION_SOURCE: "检测来源",
	ADVANCED_DETAILS_LAUNCH_SCRIPT: "启动脚本",
	ADVANCED_DETAILS_SCRIPT_NOT_FOUND_PREFIX: "未找到脚本：",
	ADVANCED_DETAILS_PATH_PREFIX: "路径：",
	ADVANCED_DETAILS_NO_CONTENT: "无内容",
	ADVANCED_DETAILS_CONFIG_FILE: "配置文件",
	ADVANCED_DETAILS_CONFIG_NOT_FOUND_PREFIX: "未找到配置：",
	ADVANCED_DETAILS_CLOSE: "关闭",
	WELCOME_TITLE: "MAKO 团队向你问好！",
	WELCOME_TIPS_COLLAPSE: "隐藏提示",
	WELCOME_TIPS_EXPAND: "显示提示",
	WELCOME_LIVE_UPDATES: "许多设置可实时生效。",
	WELCOME_RESTART_REQUIRED: "标有“重启”的选项需要重启游戏。",
	WELCOME_PERFORMANCE_NOTE: "更改游戏分辨率和缩放可能会影响性能。",
	WELCOME_CLEAN_SESSION_PREFIX: "如果",
	WELCOME_CLEAN_SESSION_WRONG: "画面或操作感觉异常",
	WELCOME_CLEAN_SESSION_AFTER: "，尤其是在",
	WELCOME_CLEAN_SESSION_CHANGES: "多次调整",
	WELCOME_CLEAN_SESSION_RESTART_SEPARATOR: "后",
	WELCOME_CLEAN_SESSION_RESTART: "，请重启游戏，以全新干净的会话重新开始。",
	WELCOME_ENJOY: "每款游戏都不一样。找到最适合你的设置，尽情游玩。MAKO 会在每个版本中持续改进，请关注发布页面！",
	PROFILE_CAPTURE_READY: "MAKO 会自动选择已保存的配置文件。如果这是新游戏，请在下方保存；更改仅在重启后生效的设置后，请重启游戏。",
	PROFILE_HELP: "启动游戏并保存一次其进程。MAKO 会自动选择已保存的配置文件；游戏未运行时，下拉菜单仅用于选择要编辑的配置文件。",
	PROFILE_SECTION_TITLE: "游戏 / 进程配置文件",
	PROFILE_DEFAULT: "默认",
	PROFILE_SAVED_LABEL: "已保存的配置文件",
	PROFILE_GAME_SAVED: "游戏配置文件已保存",
	PROFILE_GAME_SAVE_FAILED: "无法保存游戏配置文件",
	PROFILE_SAVE_RUNNING: "为 {game} 保存配置文件",
	PROFILE_DETAIL_DEFAULT: "打开游戏以保存其配置文件",
	PROFILE_DETAIL_GAME: "已保存的游戏",
	PROFILE_DETAIL_PROCESS: "已保存的进程",
	PROFILE_STEAM_APP_ID: "Steam 应用 ID：{app_id}",
	PROFILE_PROCESSES: "进程：{processes}",
	PROFILE_PROCESSES_EMPTY: "进程：请在下方“匹配的进程”中输入",
	PROFILE_MANAGE_WHEN_IDLE: "关闭正在运行的游戏后才能重命名或删除配置文件。",
	PROFILE_NAME_LABEL: "名称",
	PROFILE_CANCEL_BTN: "取消",
	PROFILE_RENAME_TITLE: "重命名配置文件",
	PROFILE_RENAME_DESC_PREFIX: "为此游戏或进程配置文件选择一个易于识别的名称。",
	PROFILE_RENAME_BTN: "重命名",
	PROFILE_CANNOT_DELETE_TITLE: "无法删除默认配置文件",
	PROFILE_CANNOT_DELETE_MSG: "不能删除默认配置文件",
	PROFILE_DELETE_TITLE: "删除游戏 / 进程配置文件",
	PROFILE_DELETE_CONFIRM: "要删除“{profile}”及其所有已保存设置吗？",
	PROFILE_DELETE_BTN: "删除",
	PROFILE_CANNOT_RENAME_TITLE: "无法重命名默认配置文件",
	PROFILE_CANNOT_RENAME_MSG: "不能重命名默认配置文件",
	USAGE_TITLE: "使用说明",
	USAGE_DESC: "将复制的启动选项粘贴到 Steam 游戏的启动选项中，以启用 MAKO Renderer 的帧生成、图像缩放或两者。",
	CLIPBOARD_COPIED: "已复制到剪贴板",
	CLIPBOARD_COPYING: "正在复制...",
	CLIPBOARD_COPY_LAUNCH: "复制启动选项",
	CLIPBOARD_MAKO_FGMOD: "MAKO + DeckyFG",
	CONTENT_RUNNING: "正在运行。",
	CONTENT_ENGINE_UPDATE_REQUIRED: "需要更新 MAKO Renderer",
	CONTENT_ENGINE_INSTALLED: "已安装：",
	CONTENT_ENGINE_NOT_RECORDED: "未记录",
	CONTENT_ENGINE_EXPECTS: "此插件需要：",
	CONTENT_ENGINE_BUNDLED_VERSION: "随附版本",
	CONTENT_ENGINE_PREDATES_TRACKING: "已安装的内容早于版本跟踪功能。",
	CONTENT_ENGINE_UPDATE_DESC: "重新安装 MAKO Renderer，以应用此插件附带的版本。然后为已准备的 Flatpak 应用更新匹配的运行时扩展。",
	CONTENT_UPDATE_RENDERER: "更新 MAKO Renderer",
	CONTENT_UPDATING_RENDERER: "正在更新 MAKO Renderer...",
	MULTIPLIER_TITLE: "固定 FPS 倍率",
	MULTIPLIER_DESC: "将固定模式设为 2x–5x。在帧节奏不均或不稳定的游戏中，固定模式可能优于自适应模式。5x 是面向高刷新率显示器的高开销选项，请逐个游戏测试。启用动态节奏恢复后，它会成为相对于已确认 Gamescope 刷新率的上限；自适应模式管理自己的倍率。",
	MULTIPLIER_ADAPTIVE_RELATION: "启用自适应帧生成时不可用。",
	ADAPTIVE_TITLE: "自适应帧生成",
	ADAPTIVE_DESC: "调整帧生成以达到目标 FPS。稳定基础帧率上限是获得更平滑节奏的默认设置。启用分数自适应可保留更多真实帧，但请逐个游戏测试。",
	FRACTIONAL_ADAPTIVE_PRESET: "小数倍率自适应",
	FRACTIONAL_ADAPTIVE_PRESET_DESC: "混合生成倍率以达到诸如 60 实际 FPS → 90 显示 FPS 的目标。可保留更多真实帧并可能降低输入延迟和重影，但在某些游戏中可能不够流畅。",
	FRACTIONAL_ADAPTIVE_PRESET_RELATION: "不能与稳定基础 FPS 上限同时使用。更改此选项也会关闭动态节奏恢复。",
	ADAPTIVE_TARGET_FPS: "目标 FPS",
	ADAPTIVE_TARGET_FPS_DESC: "期望的显示 FPS。分数自适应会混合倍率来达到目标；稳定基础 FPS 上限会把真实 FPS 限制为目标值的一半。",
	ADAPTIVE_AUTO_BASE_FPS_CAP: "稳定基础 FPS 上限",
	ADAPTIVE_AUTO_BASE_FPS_CAP_DESC: "默认的自适应模式。将真实 FPS 限制为目标值的一半，以保持均匀的帧节奏。优点：帧节奏通常更流畅。缺点：真实帧更少，并可能增加输入延迟和重影。",
	ADAPTIVE_AUTO_BASE_FPS_CAP_RELATION: "会覆盖基础 FPS 上限。不能与小数倍率自适应或动态节奏恢复同时使用。",
	ADAPTIVE_MAX_MULTIPLIER: "最大自适应倍率",
	ADAPTIVE_MAX_MULTIPLIER_DESC: "插帧上限。3x 较为均衡；2x 通常画面最佳，4x 为达到目标提供更多余量，而 5x 适用于具有充足 GPU 和内存余量的高刷新率显示器。请针对每个游戏进行测试。",
	ADAPTIVE_SMOOTH_CADENCE: "平滑节奏",
	ADAPTIVE_SMOOTH_CADENCE_DESC: "使用经过验证的固定插帧节奏。它可以使显示运动更平滑，但可能降低真实帧节奏并增加输入延迟。默认启用；如果关闭后游戏响应更快，请将其禁用。",
	DYNAMIC_CADENCE_RECOVERY: "动态节奏恢复",
	DYNAMIC_CADENCE_RECOVERY_DESC: "帮助原生帧率会切换的游戏和模拟器，例如游戏中 30 FPS、菜单中 60 FPS。它会定期检查变化并恢复正确的帧节奏，但每次检查都可能短暂影响帧节奏。只应在受影响的游戏中启用。",
	DYNAMIC_CADENCE_RECOVERY_RELATION: "启用此选项会关闭稳定基础 FPS 上限和基础 FPS 上限。之后更改任一上限都会关闭恢复功能。",
	DYNAMIC_CADENCE_PROBE_INTERVAL: "节奏探测间隔",
	DYNAMIC_CADENCE_PROBE_INTERVAL_DESC: "设置恢复功能检查原生帧率的频率。0.1 秒是激进选项，可能频繁造成短暂节奏卡顿；2 秒是默认值，3 秒的检查频率最低。请针对每个游戏测试。",
	ADAPTIVE_VALUE: "自适应",
	CONFIG_DLL_PATH: "Lossless.dll 路径（重启）",
	CONFIG_DLL_PATH_DESC: "Lossless.dll 的可选完整路径。留空则使用 MAKO Renderer 自动查找。更改后请重启游戏。",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH: "下次启动时禁用 MAKO Renderer",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH_DESC: "仅用于故障排查。下次启动游戏时阻止 MAKO Renderer 加载。要开启或关闭帧合成，请使用上方的“帧生成”。",
	CONFIG_DISABLE_HDR_EXPOSURE: "禁用 HDR",
	CONFIG_DISABLE_HDR_EXPOSURE_DESC: "此版本不支持 HDR。此必需设置会保持稳定的 SDR 路径启用。",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY: "Gamescope WSI（重启）",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_DESC: "通过使用 Gamescope 显示路径，它可能会减少某些游戏中的彩色或像素化运动伪影。启用缩放时会自动启用此功能。对于仅使用帧生成的配置文件，请只为受影响的游戏启用。",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_WARNING: "此兼容路径仅限受支持的 64 位主机启动方式。游戏不需要时请将其关闭，因为它可能影响性能。",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY: "游戏交换链图像（重启）",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_DESC: "保留游戏请求的交换链最小图像数，可能修复启用帧生成后无法启动的游戏。仅对受影响的游戏启用。",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_WARNING: "当合成器没有可用图像时，生成帧可能会被跳过，从而在压力下降低流畅度或性能。",
	FRAME_GENERATION_ENABLED: "帧生成",
	FRAME_GENERATION_ENABLED_DESC: "保持启用即可使用固定或自适应帧生成。关闭后，两种模式均不会生成帧，但设置会保留。",
	FRAME_GENERATION_ENABLED_WARNING: "如果要使用帧生成，请保持此选项开启。",
	CONFIG_ALLOW_FP16: "允许 FP16（重启）",
	CONFIG_ALLOW_FP16_DESC: "这是全局渲染器设置：适用于所有配置文件，不能按游戏更改。可提升 AMD GPU 的性能；较旧的 NVIDIA GPU 请禁用。更改后请重启游戏。",
	CONFIG_GPU: "GPU（重启）",
	CONFIG_GPU_DESC: "可选的 GPU 名称、厂商:设备 ID 或 PCI 总线 ID。更改后请重启游戏。",
	CONFIG_ACTIVE_IN: "匹配的进程",
	CONFIG_ACTIVE_IN_DESC: "用逗号分隔的可执行文件名或进程名。运行中游戏的捕获功能会自动填写；仅当启动器或模拟器需要额外的进程别名时才进行编辑。",
	CONFIG_MANUAL_OVERRIDES_TITLE: "手动覆盖",
	INSTALL_REMOVE_RENDERER: "移除 MAKO Renderer",
	INSTALL_RENDERER: "安装 MAKO Renderer",
	FLATPAK_EXTENSION_UPDATED: "Flatpak 扩展已更新",
	FLATPAK_EXTENSION_FAILED: "Flatpak 扩展操作失败",
	FLATPAK_EXTENSION_ACTION_FAILED: "无法",
	FLATPAK_RUNTIME_EXTENSION_UPDATED: "运行时扩展已更新",
	FLATPAK_RUNTIME_EXTENSION: "运行时扩展",
	FLATPAK_APPLICATION_UPDATED: "Flatpak 应用已更新",
	FLATPAK_UPDATED: "已更新",
	FLATPAK_PREPARE_APPLICATION: "准备应用",
	FLATPAK_PREPARE_APPLICATION_DESC: "安装匹配的运行时扩展，然后准备应用。Heroic 和 Lutris 需要为每个游戏设置包装器；模拟器的准备对整个应用生效。具体步骤请查看启动器设置指南。",
	FLATPAK_INSTALL_ACTION: "安装",
	FLATPAK_UNINSTALL_ACTION: "卸载",
	FLATPAK_APPLICATION_ACTION_FAILED: "无法更新",
	PROFILE_UNKNOWN_ERROR: "未知错误",
	PROFILE_LOAD_FAILED: "无法加载配置文件",
	PROFILE_LOAD_ERROR: "加载配置文件时出错",
	PROFILE_SWITCHED: "配置文件已切换",
	PROFILE_SWITCHED_DESC: "已切换到配置文件：",
	PROFILE_SWITCH_FAILED: "无法切换配置文件",
	PROFILE_SWITCH_ERROR: "切换配置文件时出错",
	PROFILE_DELETED: "配置文件已删除",
	PROFILE_DELETED_DESC: "已删除配置文件：",
	PROFILE_DELETE_FAILED: "无法删除配置文件",
	PROFILE_DELETE_ERROR: "删除配置文件时出错",
	PROFILE_RENAMED: "配置文件已重命名",
	PROFILE_RENAMED_DESC: "已重命名为：",
	PROFILE_RENAME_FAILED: "无法重命名配置文件",
	PROFILE_RENAME_ERROR: "重命名配置文件时出错",
	PROFILE_UPDATE_CONFIG_FAILED: "无法更新配置文件设置",
	PROFILE_UPDATE_CONFIG_ERROR: "更新配置文件设置时出错",
	USAGE_MAKO_CONFIG_NOTE: "此命令只会将 MAKO 应用于通过它启动的游戏。",
	USAGE_ISOLATION_NOTE: "请勿在同一游戏中同时使用 MAKO 与其他帧生成或图像缩放工具。",
	ADVANCED_DETAILS_FAILED_LOAD_DATA: "无法加载数据",
	ADVANCED_DETAILS_FAILED_DLL_STATS: "无法获取 DLL 信息",
	STATUS_ENGINE_INSTALLED: "MAKO Renderer 已安装",
	STATUS_ENGINE_NOT_INSTALLED: "MAKO Renderer 未安装",
	STATUS_ENGINE_INSTALLING: "正在安装 MAKO Renderer...",
	STATUS_ENGINE_UPDATING: "正在更新 MAKO Renderer...",
	STATUS_ENGINE_REMOVING: "正在移除 MAKO Renderer...",
	STATUS_ENGINE_REMOVED: "MAKO Renderer 已成功移除！",
	STATUS_INSTALL_FAILED: "安装失败：",
	STATUS_UNINSTALL_FAILED: "卸载失败：",
	STATUS_LOSSLESS_INSTALLED: "Lossless Scaling 已安装",
	STATUS_LOSSLESS_NOT_INSTALLED: "Lossless Scaling 未安装 — 帧生成和 LS1 需要它；MAKO Scaler 仍然可用",
	TOAST_INSTALL_COMPLETE: "安装完成",
	TOAST_INSTALL_COMPLETE_DESC: "建议重新启动设备。",
	TOAST_INSTALL_FAILED: "安装失败",
	TOAST_UNKNOWN_ERROR: "发生未知错误",
	TOAST_UNINSTALL_COMPLETE: "MAKO Renderer 已移除",
	TOAST_UNINSTALL_COMPLETE_DESC: "MAKO Renderer 文件已移除",
	TOAST_UNINSTALL_FAILED: "卸载失败",
	TOAST_CONFIG_UPDATE_FAILED: "更新失败",
	TOAST_CONFIG_UPDATE_FAILED_DESC: "无法更新配置",
	TOAST_CLIPBOARD_SUCCESS: "已复制到剪贴板！",
	TOAST_CLIPBOARD_SUCCESS_DESC: "启动选项已可粘贴",
	TOAST_CLIPBOARD_FAILED: "复制失败",
	TOAST_CLIPBOARD_FAILED_DESC: "无法复制到剪贴板",
	FEATURE_UPSCALING_TAB: "Upscaling",
	LIVE_STATUS_TITLE: "Live Status",
	LIVE_STATUS_CONNECTED: "MAKO is active",
	LIVE_STATUS_WAITING: "Waiting for MAKO",
	LIVE_STATUS_WAITING_DESC: "Live status is unavailable, but MAKO may still be active. Some games and emulators may not report live metrics. Check Frame Generation or Scaling manually.",
	LIVE_STATUS_FG_INACTIVE: "On in settings, but not currently generating frames.",
	LIVE_STATUS_OFF: "Off",
	LIVE_STATUS_SCALING_INACTIVE: "On in settings, but the game image is not being upscaled.",
	LIVE_STATUS_SCALING_MEMORY_LIMIT: "The requested render resolution exceeds this GPU's memory safety limit. Lower the in-game resolution.",
	LIVE_STATUS_SCALING_MEMORY_CONSTRAINED: "Requested {requested}×; limited to {effective}× by this GPU's memory safety limit.",
	LIVE_STATUS_SCALING_NO_HEADROOM: "This input already fills the display target. Lower the in-game resolution or enable Quality Supersampling.",
	LIVE_STATUS_PENDING: "A saved change is still applying or needs a restart.",
	LIVE_STATUS_SUPERSAMPLING: "Quality Supersampling active.",
	LIVE_STATUS_SCALING_FALLBACK: "You selected {requested}; MAKO is using {active} instead.",
	LIVE_STATUS_MODE: "Mode",
	LIVE_STATUS_FIXED_VALUE: "Fixed",
	LIVE_STATUS_ADAPTIVE_STYLE: "Style",
	LIVE_STATUS_STEADY_VALUE: "Steady",
	LIVE_STATUS_FRACTIONAL_VALUE: "Fractional",
	LIVE_STATUS_TARGET: "Target",
	LIVE_STATUS_MAX_MULTIPLIER: "Max factor",
	LIVE_STATUS_MULTIPLIER: "Factor",
	LIVE_STATUS_MODEL: "Model",
	LIVE_STATUS_NATIVE: "Native",
	LIVE_STATUS_LS1_PERFORMANCE: "LS1 Perf",
	LIVE_STATUS_ORIGINAL_RESOLUTION: "Input",
	LIVE_STATUS_RENDER_RESOLUTION: "Render",
	LIVE_STATUS_DISPLAY_RESOLUTION: "Display",
	LIVE_STATUS_SCALED_RESOLUTION: "Output",
	LIVE_STATUS_SCALING_UNAVAILABLE: "Unavailable for this running surface."
};
var languageBundle = {
	es: es,
	ja: ja,
	ko: ko,
	language_metadata: language_metadata,
	"pt-BR": {
	CONTENT_SCALING: "Redimensionamento",
	SCALING_ENABLED: "Ativar redimensionamento (Reiniciar)",
	EXPERIMENTAL_LABEL: "Experimental",
	SCALING_ENABLED_DESC: "Ative antes de iniciar o jogo. Quando desativado, o redimensionamento fica completamente desativado. Oferece suporte aos modelos do Lossless Scaling e ao MAKO Scaler.",
	SCALING_ENABLED_WARNING: "Deixe o redimensionamento desativado quando não precisar dele, pois ele consome recursos. Usá-lo com a geração de quadros pode afetar o desempenho; experimente diferentes configurações de desempenho ou uma resolução mais baixa no jogo.",
	SCALING_RUNTIME_SURFACE_UNSUPPORTED: "This running surface does not support MAKO scaling. Quality Supersampling, Scale Factor, and Sharpness are locked until a supported surface is detected. Frame Generation remains available.",
	SCALING_METHOD: "Método de redimensionamento",
	SCALING_METHOD_DESC: "Escolha o modelo de redimensionamento. Você pode alterá-lo enquanto o jogo está em execução.",
	SCALING_LS1_ACTIVE_FALLBACK: "LS1 is unavailable for this game. MAKO Scaler is active. Your LS1 selection is preserved.",
	SCALING_LS1_UNAVAILABLE: "The selected LS1 model could not be loaded during the availability check. MAKO Scaler is used automatically if LS1 cannot load. Your LS1 selection is preserved.",
	SCALING_METHOD_COMPARISON_TIP: "Como a escala funciona:\n1. No Steam, defina a resolução do jogo para a resolução máxima da tela (Steam Deck: 1280 × 800; Steam Machine: 3840 × 2160).\n2. No jogo, escolha uma resolução menor, como 480p, 720p ou mais.\n3. Use um fator de escala para ampliar a imagem. 2x dobra a resolução.\n\nReduzir a resolução do jogo e ampliá-la novamente pode melhorar muito o desempenho, com uma troca na qualidade da imagem.",
	SCALING_METHOD_NATIVE: "Resolução nativa",
	SCALING_METHOD_MAKO: "MAKO Scaler",
	SCALING_METHOD_LS1: "LS1 Quality",
	SCALING_METHOD_LS1_PERFORMANCE: "LS1 Performance",
	SCALING_FACTOR: "Fator de escala",
	SCALING_FACTOR_DESC: "Define a proporção entre o tamanho de saída e o de entrada para todos os métodos. Com uma saída de tamanho fixo, valores maiores reduzem a resolução de origem. Quando o jogo controla o tamanho da janela, reduza a resolução no próprio jogo primeiro; fatores maiores ampliam a saída do MAKO e podem aumentar o uso da GPU.",
	SCALING_FACTOR_LIMIT_SUFFIX: "limite da tela",
	SCALING_FACTOR_DEVICE_LIMIT: "Limite atual da tela: {factor}x. O valor salvo de {saved}x é preservado; ative Superamostragem de qualidade para usá-lo.",
	SCALING_FACTOR_NO_HEADROOM: "Esta resolução já preenche a tela. Reduza a resolução no jogo ou ative a Superamostragem de qualidade.",
	SCALING_SUPERSAMPLING: "Superamostragem de qualidade",
	SCALING_SUPERSAMPLING_DESC: "Permite ultrapassar um limite de saída do Gamescope para reduzir a imagem com mais qualidade, aumentando o uso de GPU e memória. Não altera o escalonamento em outras superfícies da área de trabalho.",
	SCALING_SUPERSAMPLING_WARNING: "A superamostragem está ativada. Quando há um limite de saída do Gamescope, o MAKO pode ultrapassá-lo para obter uma imagem reduzida mais nítida.",
	SCALING_SHARPNESS: "Nitidez do redimensionamento",
	SCALING_SHARPNESS_DESC: "No MAKO, aplica este multiplicador de 0 a 100% à sua base de nitidez 3x. No LS1, seleciona uma de cinco variantes de nitidez aprendidas.",
	CONTENT_FPS_MULTIPLIER: "Geração de quadros",
	CONTENT_PERFORMANCE_SETTINGS: "Configurações de desempenho",
	CONTENT_ADVANCED_DETAILS: "Detalhes avançados",
	CONTENT_FLATPAK_SETUP: "Configuração do Flatpak",
	CONFIG_SECTION_TITLE: "Configurações avançadas de renderização",
	CONFIG_WORKAROUNDS_TITLE: "Configurações de compatibilidade",
	CONFIG_FLOW_SCALE: "Escala de fluxo",
	CONFIG_FLOW_SCALE_DESC: "Controla a resolução interna de estimativa de movimento usada apenas pela geração de quadros. Valores menores reduzem o trabalho da GPU e valores maiores priorizam a qualidade.",
	CONFIG_BASE_FPS_CAP: "Limite de FPS base",
	CONFIG_BASE_FPS_CAP_OFF: "Desativado",
	CONFIG_BASE_FPS_CAP_DESC: "Limita os quadros reais do aplicativo antes da geração de quadros. Funciona com DirectX, OpenGL por meio do Zink e Vulkan.",
	CONFIG_BASE_FPS_CAP_STEADY_RELATION: "Controlado pelo Limite base estável ({fps} FPS). O valor manual continua salvo.",
	CONFIG_BASE_FPS_CAP_RECOVERY_RELATION: "Alterar este limite desativa a Recuperação de cadência dinâmica.",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD: "Desativar automaticamente pela taxa de atualização",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD_DESC: "Pausa a geração de quadros quando o Gamescope confirma que a tela atual está no limite ou abaixo dele e retoma o modo selecionado acima do limite. Não faz nada quando a taxa de atualização não está disponível.",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD: "Limite da taxa de atualização",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD_DESC: "Escolha a maior taxa de atualização em que a geração de quadros deve permanecer pausada.",
	CONFIG_ULTRA_PERFORMANCE: "Desempenho ultra (Reiniciar)",
	CONFIG_ULTRA_PERFORMANCE_DESC: "Reduz a carga da GPU do MAKO em dispositivos de baixo consumo. Usa escala de fluxo de 75%, o modelo de FG mais leve, FP16 quando houver suporte e LS1 Performance quando a escala estiver ativada. Troca qualidade de imagem por desempenho nos recursos ativos do MAKO.",
	CONFIG_ULTRA_PERFORMANCE_WARNING: "Ativar ou desativar o Ultra Performance requer reiniciar o jogo. Outros controles de perfil compatíveis continuam disponíveis após a inicialização.",
	CONFIG_PERFORMANCE_MODE: "Modelo de FG mais leve",
	CONFIG_PERFORMANCE_MODE_DESC: "Reduz o trabalho da GPU usando um modelo de geração de quadros mais leve ao custo de mais fantasmas. Desempenho ultra mantém esta opção ativada.",
	CONFIG_DISABLE_STEAMDECK_MODE: "Desativar o modo Steam Deck (Reiniciar)",
	CONFIG_DISABLE_STEAMDECK_MODE_DESC: "Desativa o modo Steam Deck. Desbloqueia configurações ocultas em alguns jogos.",
	CONFIG_ENABLE_ZINK: "Ativar o Zink para jogos OpenGL (Reiniciar)",
	CONFIG_ENABLE_ZINK_DESC: "Usa a implementação de OpenGL baseada em Vulkan para jogos OpenGL. Pode causar travamentos ou congelamentos em alguns jogos.",
	CONFIG_FORCE_ALSA_AUDIO: "Forçar áudio ALSA (Reiniciar)",
	CONFIG_FORCE_ALSA_AUDIO_DESC: "Pode melhorar a compatibilidade com modos como o Zink e reduzir falhas de áudio ou sons altos repentinos. Desative para restaurar os padrões normais de áudio.",
	CONFIG_EXTERNAL_TOOLS_TITLE: "Ferramentas externas",
	CONFIG_ENABLE_MANGOHUD: "Ativar o MangoHud (Reiniciar)",
	CONFIG_ENABLE_MANGOHUD_DESC: "Usa o MangoHud instalado no sistema e sua configuração existente. Consulte o guia avançado para substituições de ambiente por jogo.",
	CONFIG_ENABLE_VKBASALT: "Ativar o vkBasalt (Reiniciar)",
	CONFIG_ENABLE_VKBASALT_DESC: "Deixe desativado, a menos que esteja testando o vkBasalt com este jogo. Usa uma camada vkBasalt instalada no sistema para este perfil. Os testes iniciais se limitam a jogos Vulkan nativos de 64 bits ou Proton iniciados diretamente pelo Steam no SteamOS.",
	INSTALL_INSTALLING: "Instalando o MAKO Renderer...",
	INSTALL_UNINSTALLING: "Removendo o MAKO Renderer...",
	FLATPAK_MODAL_TITLE: "Extensões Flatpak",
	FLATPAK_RUNTIME_INSTALLER: "Instalador de extensões de ambiente",
	FLATPAK_RUNTIME_VERSION: "Ambiente {version}",
	FLATPAK_INSTALLED: "Instalado",
	FLATPAK_NOT_INSTALLED: "Não instalado",
	FLATPAK_UNINSTALL_TITLE: "Desinstalar extensão de ambiente",
	FLATPAK_UNINSTALL_CONFIRM_PREFIX: "Tem certeza de que deseja desinstalar o ambiente",
	FLATPAK_UNINSTALL_CONFIRM_SUFFIX: "selecionado?",
	FLATPAK_UNINSTALL_BTN: "Desinstalar",
	FLATPAK_INSTALL_BTN: "Instalar",
	FLATPAK_UPDATE_BTN: "Atualizar",
	FLATPAK_INSTALLING_BTN: "Instalando...",
	FLATPAK_UNINSTALLING_BTN: "Desinstalando...",
	FLATPAK_UPDATING_BTN: "Atualizando...",
	FLATPAK_APPS_TITLE: "Aplicativos Flatpak",
	FLATPAK_NO_APPS: "Nenhum aplicativo Flatpak encontrado",
	FLATPAK_NO_APPS_DESC: "Nenhum aplicativo Flatpak está instalado no momento",
	FLATPAK_STATUS_CONFIGURED: "Preparado",
	FLATPAK_STATUS_PARTIAL: "Parcial",
	FLATPAK_STATUS_NO_OVERRIDES: "Sem substituições",
	FLATPAK_ERROR: "Erro",
	FLATPAK_ERROR_STATUS: "Falha ao verificar o status da extensão",
	FLATPAK_ERROR_APPS: "Falha ao carregar os aplicativos Flatpak",
	FLATPAK_STEAM_CONFIG_TITLE: "Referência para atalhos manuais do Steam",
	FLATPAK_STEAM_CONFIG_HEADER: "Exemplo de destino (não configura o Steam)",
	FLATPAK_STEAM_CONFIG_DESC: "Use apenas para um atalho do Steam adicionado manualmente cujo Destino original seja /usr/bin/flatpak. Prepare o aplicativo Flatpak acima primeiro e mantenha Iniciar em e Opções de inicialização inalterados. Heroic, Lutris e EmuDeck têm etapas próprias no guia de inicializadores.",
	FLATPAK_IMPORTANT_LABEL: "IMPORTANTE:",
	FLATPAK_STEAM_CONFIG_IMPORTANT: "Substitua somente o DESTINO. Não cole isto nas Opções de inicialização.",
	FLATPAK_PER_GAME_APP_DESC: "{app_id} - {status}. Ative o MAKO por jogo usando {wrapper_path}. Consulte o campo correto no guia de inicializadores.",
	FLATPAK_DIRECT_APP_DESC: "{app_id} - {status}. A preparação se aplica a todo este aplicativo Flatpak. Siga o guia de inicializadores para EmuDeck e atalhos do Steam.",
	FLATPAK_STEP_WRAPPER_PATH: "Wrapper instalado neste dispositivo:",
	FLATPAK_STEP_FINAL: "Destino para um atalho que originalmente usava \"/usr/bin/flatpak\":",
	FLATPAK_OPEN_README: "Abrir guia de inicializadores",
	FLATPAK_CLOSE: "Fechar",
	ADVANCED_DETAILS_LOADING: "Carregando informações...",
	ADVANCED_DETAILS_ERROR_PREFIX: "Erro:",
	ADVANCED_DETAILS_DLL_PATH: "Caminho da DLL",
	ADVANCED_DETAILS_LIBRARY: "Biblioteca do Lossless Scaling",
	ADVANCED_DETAILS_NOT_AVAILABLE: "Não disponível",
	ADVANCED_DETAILS_DLL_HASH: "Hash SHA256 da DLL",
	ADVANCED_DETAILS_DETECTION_SOURCE: "Origem da detecção",
	ADVANCED_DETAILS_LAUNCH_SCRIPT: "Script de inicialização",
	ADVANCED_DETAILS_SCRIPT_NOT_FOUND_PREFIX: "Script não encontrado:",
	ADVANCED_DETAILS_PATH_PREFIX: "Caminho:",
	ADVANCED_DETAILS_NO_CONTENT: "Sem conteúdo",
	ADVANCED_DETAILS_CONFIG_FILE: "Arquivo de configuração",
	ADVANCED_DETAILS_CONFIG_NOT_FOUND_PREFIX: "Configuração não encontrada:",
	ADVANCED_DETAILS_CLOSE: "Fechar",
	WELCOME_TITLE: "Olá da equipe MAKO!",
	WELCOME_TIPS_COLLAPSE: "Ocultar dicas",
	WELCOME_TIPS_EXPAND: "Mostrar dicas",
	WELCOME_LIVE_UPDATES: "Muitas configurações são aplicadas em tempo real.",
	WELCOME_RESTART_REQUIRED: "As opções marcadas como “Reiniciar” exigem que o jogo seja reiniciado.",
	WELCOME_PERFORMANCE_NOTE: "Alterações na resolução e no redimensionamento do jogo podem afetar o desempenho.",
	WELCOME_CLEAN_SESSION_PREFIX: "Se algo ",
	WELCOME_CLEAN_SESSION_WRONG: "parecer errado",
	WELCOME_CLEAN_SESSION_AFTER: " após ",
	WELCOME_CLEAN_SESSION_CHANGES: "várias mudanças",
	WELCOME_CLEAN_SESSION_RESTART_SEPARATOR: ", ",
	WELCOME_CLEAN_SESSION_RESTART: "reinicie o jogo para começar uma sessão nova e limpa.",
	WELCOME_ENJOY: "Cada jogo é diferente. Encontre as configurações ideais para você e aproveite. O MAKO continua melhorando a cada versão, então fique de olho na página de lançamentos!",
	PROFILE_CAPTURE_READY: "O MAKO seleciona perfis salvos automaticamente. Se este jogo for novo, salve-o abaixo; reinicie o jogo após alterar configurações que exigem reinício.",
	PROFILE_HELP: "Inicie um jogo e salve o processo uma vez. O MAKO seleciona os perfis salvos automaticamente; fora de um jogo, a lista apenas escolhe qual perfil editar.",
	PROFILE_SECTION_TITLE: "Perfis de jogo / processo",
	PROFILE_DEFAULT: "Padrão",
	PROFILE_SAVED_LABEL: "Perfil salvo",
	PROFILE_GAME_SAVED: "Perfil do jogo salvo",
	PROFILE_GAME_SAVE_FAILED: "Não foi possível salvar o perfil do jogo",
	PROFILE_SAVE_RUNNING: "Salvar perfil para {game}",
	PROFILE_DETAIL_DEFAULT: "Abra um jogo para salvar seu perfil",
	PROFILE_DETAIL_GAME: "Jogo salvo",
	PROFILE_DETAIL_PROCESS: "Processo salvo",
	PROFILE_STEAM_APP_ID: "ID do aplicativo Steam: {app_id}",
	PROFILE_PROCESSES: "Processos: {processes}",
	PROFILE_PROCESSES_EMPTY: "Processos: insira um em Processos correspondentes abaixo",
	PROFILE_MANAGE_WHEN_IDLE: "Feche o jogo em execução para renomear ou excluir perfis.",
	PROFILE_NAME_LABEL: "Nome",
	PROFILE_CANCEL_BTN: "Cancelar",
	PROFILE_RENAME_TITLE: "Renomear perfil",
	PROFILE_RENAME_DESC_PREFIX: "Escolha um nome amigável para este perfil de jogo ou processo.",
	PROFILE_RENAME_BTN: "Renomear",
	PROFILE_CANNOT_DELETE_TITLE: "Não é possível excluir o perfil padrão",
	PROFILE_CANNOT_DELETE_MSG: "O perfil padrão não pode ser excluído",
	PROFILE_DELETE_TITLE: "Excluir perfil de jogo / processo",
	PROFILE_DELETE_CONFIRM: "Excluir \"{profile}\" e todas as configurações salvas?",
	PROFILE_DELETE_BTN: "Excluir",
	PROFILE_CANNOT_RENAME_TITLE: "Não é possível renomear o perfil padrão",
	PROFILE_CANNOT_RENAME_MSG: "O perfil padrão não pode ser renomeado",
	USAGE_TITLE: "Instruções de uso",
	USAGE_DESC: "Cole a opção copiada nas opções de inicialização do jogo no Steam para ativar o MAKO Renderer com geração de quadros, redimensionamento ou ambos.",
	CLIPBOARD_COPIED: "Copiado para a área de transferência",
	CLIPBOARD_COPYING: "Copiando...",
	CLIPBOARD_COPY_LAUNCH: "Copiar opção de inicialização",
	CLIPBOARD_MAKO_FGMOD: "MAKO + DeckyFG",
	CONTENT_RUNNING: "em execução.",
	CONTENT_ENGINE_UPDATE_REQUIRED: "Atualização do MAKO Renderer necessária",
	CONTENT_ENGINE_INSTALLED: "Instalado:",
	CONTENT_ENGINE_NOT_RECORDED: "não registrado",
	CONTENT_ENGINE_EXPECTS: "Este plugin espera:",
	CONTENT_ENGINE_BUNDLED_VERSION: "a versão incluída",
	CONTENT_ENGINE_PREDATES_TRACKING: "A carga instalada é anterior ao rastreamento de versões.",
	CONTENT_ENGINE_UPDATE_DESC: "Reinstale o MAKO Renderer para aplicar a versão incluída neste plugin. Depois, atualize as extensões de ambiente correspondentes aos aplicativos Flatpak preparados.",
	CONTENT_UPDATE_RENDERER: "Atualizar o MAKO Renderer",
	CONTENT_UPDATING_RENDERER: "Atualizando o MAKO Renderer...",
	MULTIPLIER_TITLE: "Multiplicador de FPS fixo",
	MULTIPLIER_DESC: "Define o modo Fixo de 2x a 5x. O Fixo pode render melhor que o Adaptativo em alguns jogos, especialmente com ritmo irregular. 5x tem alto custo e é voltado a telas de alta atualização. Teste ambos por jogo. Com a Recuperação de cadência dinâmica, este valor é um limite diante da atualização confirmada do Gamescope; o Adaptativo gerencia seu próprio multiplicador.",
	MULTIPLIER_ADAPTIVE_RELATION: "Indisponível enquanto a Geração de quadros adaptativa estiver ativada.",
	ADAPTIVE_TITLE: "Geração de quadros adaptativa",
	ADAPTIVE_DESC: "Ajusta a geração de quadros para alcançar o FPS alvo. O limite base estável é o padrão para um ritmo mais suave. Ative o Adaptativo fracionário para manter mais quadros reais, mas teste por jogo.",
	FRACTIONAL_ADAPTIVE_PRESET: "Adaptativo fracionário",
	FRACTIONAL_ADAPTIVE_PRESET_DESC: "Combina proporções de geração para atingir metas como 60 FPS reais → 90 FPS exibidos. Mantém mais quadros reais e pode reduzir a latência de entrada e os fantasmas, mas pode parecer menos suave em alguns jogos.",
	FRACTIONAL_ADAPTIVE_PRESET_RELATION: "Não pode ser combinado com o Limite base estável. Alterar esta opção também desativa a Recuperação de cadência dinâmica.",
	ADAPTIVE_TARGET_FPS: "FPS alvo",
	ADAPTIVE_TARGET_FPS_DESC: "FPS exibido desejado. O Adaptativo fracionário pode combinar proporções para alcançá-lo; o limite base estável limita o FPS real à metade do alvo.",
	ADAPTIVE_AUTO_BASE_FPS_CAP: "Limite base estável",
	ADAPTIVE_AUTO_BASE_FPS_CAP_DESC: "O modo Adaptativo padrão. Limita o FPS real à metade do alvo para uma cadência uniforme. Vantagens: ritmo geralmente mais suave. Desvantagens: menos quadros reais e possivelmente mais latência de entrada e fantasmas.",
	ADAPTIVE_AUTO_BASE_FPS_CAP_RELATION: "Substitui o Limite de FPS base. Não pode ser combinado com o Adaptativo fracionário ou a Recuperação de cadência dinâmica.",
	ADAPTIVE_MAX_MULTIPLIER: "Multiplicador adaptativo máximo",
	ADAPTIVE_MAX_MULTIPLIER_DESC: "Limite de interpolação. 3x é equilibrado; 2x geralmente tem a melhor aparência, 4x oferece mais margem para alcançar o alvo e 5x destina-se a telas de alta taxa de atualização com bastante folga de GPU e memória. Teste em cada jogo.",
	ADAPTIVE_SMOOTH_CADENCE: "Cadência suave",
	ADAPTIVE_SMOOTH_CADENCE_DESC: "Usa uma cadência de interpolação constante validada. Pode tornar o movimento exibido mais suave, mas reduzir a cadência de quadros reais e aumentar a latência de entrada. Ativada por padrão; desative se o jogo parecer mais responsivo sem ela.",
	DYNAMIC_CADENCE_RECOVERY: "Recuperação de cadência dinâmica",
	DYNAMIC_CADENCE_RECOVERY_DESC: "Ajuda jogos e emuladores que alternam taxas nativas, como 30 FPS durante o jogo e 60 FPS nos menus. Verifica periodicamente a mudança e recupera a cadência correta, mas cada verificação pode afetar brevemente o ritmo. Ative apenas nos jogos afetados.",
	DYNAMIC_CADENCE_RECOVERY_RELATION: "Ativar esta opção desativa o Limite base estável e o Limite de FPS base. Alterar qualquer um deles depois desativa a Recuperação.",
	DYNAMIC_CADENCE_PROBE_INTERVAL: "Intervalo de verificação da cadência",
	DYNAMIC_CADENCE_PROBE_INTERVAL_DESC: "Define com que frequência a Recuperação testa a taxa nativa. 0,1 segundo é uma opção agressiva e pode causar breves engasgos de ritmo frequentes; 2 segundos é o padrão e 3 segundos faz verificações com a menor frequência. Teste em cada jogo.",
	ADAPTIVE_VALUE: "Adaptativo",
	CONFIG_DLL_PATH: "Caminho do Lossless.dll (Reiniciar)",
	CONFIG_DLL_PATH_DESC: "Caminho completo opcional para Lossless.dll. Deixe em branco para usar a detecção automática do MAKO Renderer. Reinicie o jogo após alterar.",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH: "Desativar o MAKO Renderer na próxima inicialização",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH_DESC: "Somente para solução de problemas. Impede o carregamento do MAKO Renderer na próxima vez que o jogo iniciar. Use Geração de quadros acima para ativar ou desativar a síntese.",
	CONFIG_DISABLE_HDR_EXPOSURE: "Desativar HDR",
	CONFIG_DISABLE_HDR_EXPOSURE_DESC: "HDR não está disponível nesta versão. Esta configuração obrigatória mantém o caminho SDR estável ativo.",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY: "Gamescope WSI (Reiniciar)",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_DESC: "Pode reduzir artefatos de movimento coloridos ou pixelados em alguns jogos usando o caminho de apresentação do Gamescope. O redimensionamento o ativa automaticamente. Em perfis somente com geração de quadros, ative-o apenas nos jogos afetados.",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_WARNING: "Este caminho de compatibilidade é limitado a inicializações de host de 64 bits compatíveis. Deixe-o desativado quando o jogo não precisar dele, pois pode afetar o desempenho.",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY: "Imagens de swapchain do jogo (Reiniciar)",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_DESC: "Pode corrigir jogos que não iniciam com a geração de quadros ao preservar o mínimo de imagens de swapchain solicitado pelo jogo. Ative apenas nos jogos afetados.",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_WARNING: "Quadros gerados podem ser ignorados quando o compositor não tem uma imagem livre, o que pode reduzir a fluidez ou o desempenho sob pressão.",
	FRAME_GENERATION_ENABLED: "Geração de quadros",
	FRAME_GENERATION_ENABLED_DESC: "Deixe ativada para usar a geração Fixa ou Adaptativa. Quando desativada, nenhum modo gera quadros; suas configurações permanecem salvas.",
	FRAME_GENERATION_ENABLED_WARNING: "Mantenha esta opção ativada se quiser gerar quadros.",
	CONFIG_ALLOW_FP16: "Permitir FP16 (Reiniciar)",
	CONFIG_ALLOW_FP16_DESC: "Configuração global do renderizador: aplica-se a todos os perfis e não pode ser alterada por jogo. Melhora o desempenho em AMD; desative para GPUs NVIDIA mais antigas. Reinicie o jogo após alterar.",
	CONFIG_GPU: "GPU (Reiniciar)",
	CONFIG_GPU_DESC: "Nome opcional da GPU, ID fornecedor:dispositivo ou ID do barramento PCI. Reinicie o jogo após a alteração.",
	CONFIG_ACTIVE_IN: "Processos correspondentes",
	CONFIG_ACTIVE_IN_DESC: "Nomes de executáveis ou processos separados por vírgulas. A captura do jogo em execução os preenche automaticamente; edite somente quando um inicializador ou emulador precisar de um alias de processo adicional.",
	CONFIG_MANUAL_OVERRIDES_TITLE: "Substituições manuais",
	INSTALL_REMOVE_RENDERER: "Remover o MAKO Renderer",
	INSTALL_RENDERER: "Instalar o MAKO Renderer",
	FLATPAK_EXTENSION_UPDATED: "Extensão Flatpak atualizada",
	FLATPAK_EXTENSION_FAILED: "Falha na extensão Flatpak",
	FLATPAK_EXTENSION_ACTION_FAILED: "Não foi possível",
	FLATPAK_RUNTIME_EXTENSION_UPDATED: "extensão de ambiente atualizada",
	FLATPAK_RUNTIME_EXTENSION: "extensão de ambiente",
	FLATPAK_APPLICATION_UPDATED: "Aplicativo Flatpak atualizado",
	FLATPAK_UPDATED: "atualizado",
	FLATPAK_PREPARE_APPLICATION: "Preparar um aplicativo",
	FLATPAK_PREPARE_APPLICATION_DESC: "Instale a extensão de ambiente correspondente e prepare o aplicativo. Heroic e Lutris precisam de um wrapper por jogo; os emuladores são preparados para todo o aplicativo. Consulte o guia de inicializadores.",
	FLATPAK_INSTALL_ACTION: "instalar",
	FLATPAK_UNINSTALL_ACTION: "desinstalar",
	FLATPAK_APPLICATION_ACTION_FAILED: "Não foi possível atualizar",
	PROFILE_UNKNOWN_ERROR: "Erro desconhecido",
	PROFILE_LOAD_FAILED: "Falha ao carregar os perfis",
	PROFILE_LOAD_ERROR: "Erro ao carregar os perfis",
	PROFILE_SWITCHED: "Perfil alterado",
	PROFILE_SWITCHED_DESC: "Perfil alterado para:",
	PROFILE_SWITCH_FAILED: "Falha ao alterar o perfil",
	PROFILE_SWITCH_ERROR: "Erro ao alterar o perfil",
	PROFILE_DELETED: "Perfil excluído",
	PROFILE_DELETED_DESC: "Perfil excluído:",
	PROFILE_DELETE_FAILED: "Falha ao excluir o perfil",
	PROFILE_DELETE_ERROR: "Erro ao excluir o perfil",
	PROFILE_RENAMED: "Perfil renomeado",
	PROFILE_RENAMED_DESC: "Perfil renomeado para:",
	PROFILE_RENAME_FAILED: "Falha ao renomear o perfil",
	PROFILE_RENAME_ERROR: "Erro ao renomear o perfil",
	PROFILE_UPDATE_CONFIG_FAILED: "Falha ao atualizar a configuração do perfil",
	PROFILE_UPDATE_CONFIG_ERROR: "Erro ao atualizar a configuração do perfil",
	USAGE_MAKO_CONFIG_NOTE: "Este comando aplica o MAKO apenas ao jogo iniciado com ele.",
	USAGE_ISOLATION_NOTE: "Não combine o MAKO com outra ferramenta de geração de quadros ou redimensionamento no mesmo jogo.",
	ADVANCED_DETAILS_FAILED_LOAD_DATA: "Falha ao carregar os dados",
	ADVANCED_DETAILS_FAILED_DLL_STATS: "Falha ao obter estatísticas da DLL",
	STATUS_ENGINE_INSTALLED: "MAKO Renderer instalado",
	STATUS_ENGINE_NOT_INSTALLED: "MAKO Renderer não instalado",
	STATUS_ENGINE_INSTALLING: "Instalando o MAKO Renderer...",
	STATUS_ENGINE_UPDATING: "Atualizando o MAKO Renderer...",
	STATUS_ENGINE_REMOVING: "Removendo o MAKO Renderer...",
	STATUS_ENGINE_REMOVED: "MAKO Renderer removido com sucesso!",
	STATUS_INSTALL_FAILED: "Falha na instalação:",
	STATUS_UNINSTALL_FAILED: "Falha na desinstalação:",
	STATUS_LOSSLESS_INSTALLED: "Lossless Scaling instalado",
	STATUS_LOSSLESS_NOT_INSTALLED: "Lossless Scaling não instalado — necessário para geração de quadros e LS1; o MAKO Scaler continua disponível",
	TOAST_INSTALL_COMPLETE: "Instalação concluída",
	TOAST_INSTALL_COMPLETE_DESC: "É recomendável reiniciar o dispositivo.",
	TOAST_INSTALL_FAILED: "Falha na instalação",
	TOAST_UNKNOWN_ERROR: "Ocorreu um erro desconhecido",
	TOAST_UNINSTALL_COMPLETE: "MAKO Renderer removido",
	TOAST_UNINSTALL_COMPLETE_DESC: "Os arquivos do MAKO Renderer foram removidos",
	TOAST_UNINSTALL_FAILED: "Falha na desinstalação",
	TOAST_CONFIG_UPDATE_FAILED: "Falha na atualização",
	TOAST_CONFIG_UPDATE_FAILED_DESC: "Falha ao atualizar a configuração",
	TOAST_CLIPBOARD_SUCCESS: "Copiado para a área de transferência!",
	TOAST_CLIPBOARD_SUCCESS_DESC: "Opção de inicialização pronta para colar",
	TOAST_CLIPBOARD_FAILED: "Falha ao copiar",
	TOAST_CLIPBOARD_FAILED_DESC: "Não foi possível copiar para a área de transferência",
	FEATURE_UPSCALING_TAB: "Upscaling",
	LIVE_STATUS_TITLE: "Live Status",
	LIVE_STATUS_CONNECTED: "MAKO is active",
	LIVE_STATUS_WAITING: "Waiting for MAKO",
	LIVE_STATUS_WAITING_DESC: "Live status is unavailable, but MAKO may still be active. Some games and emulators may not report live metrics. Check Frame Generation or Scaling manually.",
	LIVE_STATUS_FG_INACTIVE: "On in settings, but not currently generating frames.",
	LIVE_STATUS_OFF: "Off",
	LIVE_STATUS_SCALING_INACTIVE: "On in settings, but the game image is not being upscaled.",
	LIVE_STATUS_SCALING_MEMORY_LIMIT: "The requested render resolution exceeds this GPU's memory safety limit. Lower the in-game resolution.",
	LIVE_STATUS_SCALING_MEMORY_CONSTRAINED: "Requested {requested}×; limited to {effective}× by this GPU's memory safety limit.",
	LIVE_STATUS_SCALING_NO_HEADROOM: "This input already fills the display target. Lower the in-game resolution or enable Quality Supersampling.",
	LIVE_STATUS_PENDING: "A saved change is still applying or needs a restart.",
	LIVE_STATUS_SUPERSAMPLING: "Quality Supersampling active.",
	LIVE_STATUS_SCALING_FALLBACK: "You selected {requested}; MAKO is using {active} instead.",
	LIVE_STATUS_MODE: "Mode",
	LIVE_STATUS_FIXED_VALUE: "Fixed",
	LIVE_STATUS_ADAPTIVE_STYLE: "Style",
	LIVE_STATUS_STEADY_VALUE: "Steady",
	LIVE_STATUS_FRACTIONAL_VALUE: "Fractional",
	LIVE_STATUS_TARGET: "Target",
	LIVE_STATUS_MAX_MULTIPLIER: "Max factor",
	LIVE_STATUS_MULTIPLIER: "Factor",
	LIVE_STATUS_MODEL: "Model",
	LIVE_STATUS_NATIVE: "Native",
	LIVE_STATUS_LS1_PERFORMANCE: "LS1 Perf",
	LIVE_STATUS_ORIGINAL_RESOLUTION: "Input",
	LIVE_STATUS_RENDER_RESOLUTION: "Render",
	LIVE_STATUS_DISPLAY_RESOLUTION: "Display",
	LIVE_STATUS_SCALED_RESOLUTION: "Output",
	LIVE_STATUS_SCALING_UNAVAILABLE: "Unavailable for this running surface."
},
	"pt-PT": {
	CONTENT_SCALING: "Redimensionamento",
	SCALING_ENABLED: "Ativar redimensionamento (Reiniciar)",
	EXPERIMENTAL_LABEL: "Experimental",
	SCALING_ENABLED_DESC: "Ative antes de iniciar o jogo. Quando está desativado, o redimensionamento fica totalmente desativado. Suporta os modelos do Lossless Scaling e o MAKO Scaler.",
	SCALING_ENABLED_WARNING: "Deixe o redimensionamento desativado quando não precisar dele, pois consome recursos. Usá-lo com a geração de fotogramas pode afetar o desempenho; experimente diferentes definições de desempenho ou uma resolução mais baixa no jogo.",
	SCALING_RUNTIME_SURFACE_UNSUPPORTED: "This running surface does not support MAKO scaling. Quality Supersampling, Scale Factor, and Sharpness are locked until a supported surface is detected. Frame Generation remains available.",
	SCALING_METHOD: "Método de redimensionamento",
	SCALING_METHOD_DESC: "Escolha o modelo de redimensionamento. Pode alterá-lo enquanto o jogo está em execução.",
	SCALING_LS1_ACTIVE_FALLBACK: "LS1 is unavailable for this game. MAKO Scaler is active. Your LS1 selection is preserved.",
	SCALING_LS1_UNAVAILABLE: "The selected LS1 model could not be loaded during the availability check. MAKO Scaler is used automatically if LS1 cannot load. Your LS1 selection is preserved.",
	SCALING_METHOD_COMPARISON_TIP: "Como funciona o redimensionamento:\n1. No Steam, defina a resolução do jogo para a resolução máxima do ecrã (Steam Deck: 1280 × 800; Steam Machine: 3840 × 2160).\n2. No jogo, escolha uma resolução mais baixa, como 480p, 720p ou mais.\n3. Utilize um fator de redimensionamento para ampliar a imagem. 2x duplica a resolução.\n\nReduzir a resolução do jogo e ampliá-la novamente pode melhorar muito o desempenho, com uma contrapartida na qualidade de imagem.",
	SCALING_METHOD_NATIVE: "Resolução nativa",
	SCALING_METHOD_MAKO: "MAKO Scaler",
	SCALING_METHOD_LS1: "LS1 Quality",
	SCALING_METHOD_LS1_PERFORMANCE: "LS1 Performance",
	SCALING_FACTOR: "Fator de escala",
	SCALING_FACTOR_DESC: "Define a proporção entre o tamanho de saída e o de entrada para todos os métodos. Com uma saída de tamanho fixo, valores mais altos reduzem a resolução de origem. Quando o jogo controla o tamanho da janela, reduza primeiro a resolução no próprio jogo; fatores mais altos ampliam a saída do MAKO e podem aumentar a utilização da GPU.",
	SCALING_FACTOR_LIMIT_SUFFIX: "limite do ecrã",
	SCALING_FACTOR_DEVICE_LIMIT: "Limite atual do ecrã: {factor}x. O valor guardado de {saved}x é preservado; ative a Superamostragem de qualidade para o utilizar.",
	SCALING_FACTOR_NO_HEADROOM: "Esta resolução já preenche o ecrã. Reduza a resolução no jogo ou ative a Superamostragem de qualidade.",
	SCALING_SUPERSAMPLING: "Superamostragem de qualidade",
	SCALING_SUPERSAMPLING_DESC: "Permite ultrapassar um limite de saída do Gamescope para reduzir a imagem com mais qualidade, aumentando a utilização de GPU e memória. Não altera o escalonamento noutras superfícies do ambiente de trabalho.",
	SCALING_SUPERSAMPLING_WARNING: "A superamostragem está ativada. Quando existe um limite de saída do Gamescope, o MAKO pode ultrapassá-lo para obter uma imagem reduzida mais nítida.",
	SCALING_SHARPNESS: "Nitidez do redimensionamento",
	SCALING_SHARPNESS_DESC: "No MAKO, aplica este multiplicador de 0 a 100% à sua base de nitidez 3x. No LS1, seleciona uma de cinco variantes de nitidez aprendidas.",
	CONTENT_FPS_MULTIPLIER: "Geração de fotogramas",
	CONTENT_PERFORMANCE_SETTINGS: "Definições de desempenho",
	CONTENT_ADVANCED_DETAILS: "Detalhes avançados",
	CONTENT_FLATPAK_SETUP: "Configuração do Flatpak",
	CONFIG_SECTION_TITLE: "Definições avançadas de renderização",
	CONFIG_WORKAROUNDS_TITLE: "Definições de compatibilidade",
	CONFIG_FLOW_SCALE: "Escala de fluxo",
	CONFIG_FLOW_SCALE_DESC: "Controla a resolução interna de estimação de movimento usada apenas pela geração de fotogramas. Valores mais baixos reduzem o trabalho da GPU e valores mais altos favorecem a qualidade.",
	CONFIG_BASE_FPS_CAP: "Limite de FPS base",
	CONFIG_BASE_FPS_CAP_OFF: "Desativado",
	CONFIG_BASE_FPS_CAP_DESC: "Limita os fotogramas reais da aplicação antes da geração de fotogramas. Funciona com DirectX, OpenGL através do Zink e Vulkan.",
	CONFIG_BASE_FPS_CAP_STEADY_RELATION: "Controlado pelo Limite base estável ({fps} FPS). O valor manual permanece guardado.",
	CONFIG_BASE_FPS_CAP_RECOVERY_RELATION: "Alterar este limite desativa a Recuperação de cadência dinâmica.",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD: "Desativar automaticamente pela taxa de atualização",
	CONFIG_FRAME_GENERATION_REFRESH_GUARD_DESC: "Pausa a geração de fotogramas quando o Gamescope confirma que o ecrã atual está no limite ou abaixo dele e retoma o modo selecionado acima do limite. Não faz nada quando a taxa de atualização não está disponível.",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD: "Limite da taxa de atualização",
	CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD_DESC: "Escolha a taxa de atualização mais alta em que a geração de fotogramas deve permanecer pausada.",
	CONFIG_ULTRA_PERFORMANCE: "Desempenho ultra (Reiniciar)",
	CONFIG_ULTRA_PERFORMANCE_DESC: "Reduz a carga da GPU do MAKO em dispositivos de baixo consumo. Utiliza uma escala de fluxo de 75%, o modelo de FG mais leve, FP16 quando suportado e LS1 Performance quando o redimensionamento está ativado. Troca qualidade de imagem por desempenho nas funcionalidades ativas do MAKO.",
	CONFIG_ULTRA_PERFORMANCE_WARNING: "Ativar ou desativar o Ultra Performance requer reiniciar o jogo. Os outros controlos de perfil compatíveis continuam disponíveis após o arranque.",
	CONFIG_PERFORMANCE_MODE: "Modelo de FG mais leve",
	CONFIG_PERFORMANCE_MODE_DESC: "Reduz o trabalho da GPU com um modelo de geração de fotogramas mais leve à custa de mais imagens fantasma. Desempenho ultra mantém esta opção ativa.",
	CONFIG_DISABLE_STEAMDECK_MODE: "Desativar o modo Steam Deck (Reiniciar)",
	CONFIG_DISABLE_STEAMDECK_MODE_DESC: "Desativa o modo Steam Deck. Desbloqueia definições ocultas em alguns jogos.",
	CONFIG_ENABLE_ZINK: "Ativar o Zink para jogos OpenGL (Reiniciar)",
	CONFIG_ENABLE_ZINK_DESC: "Utiliza a implementação de OpenGL baseada em Vulkan para jogos OpenGL. Pode causar falhas ou bloqueios em alguns jogos.",
	CONFIG_FORCE_ALSA_AUDIO: "Forçar áudio ALSA (Reiniciar)",
	CONFIG_FORCE_ALSA_AUDIO_DESC: "Pode melhorar a compatibilidade com modos como o Zink e reduzir falhas de áudio ou sons altos repentinos. Desative para restaurar as predefinições normais de áudio.",
	CONFIG_EXTERNAL_TOOLS_TITLE: "Ferramentas externas",
	CONFIG_ENABLE_MANGOHUD: "Ativar o MangoHud (Reiniciar)",
	CONFIG_ENABLE_MANGOHUD_DESC: "Utiliza o MangoHud instalado no sistema e a sua configuração existente. Consulte o guia avançado para substituições de ambiente por jogo.",
	CONFIG_ENABLE_VKBASALT: "Ativar o vkBasalt (Reiniciar)",
	CONFIG_ENABLE_VKBASALT_DESC: "Mantenha-o desativado, exceto se estiver a testar o vkBasalt com este jogo. Utiliza uma camada vkBasalt instalada no sistema para este perfil. Os testes iniciais limitam-se a jogos Vulkan nativos de 64 bits ou Proton iniciados diretamente pelo Steam no SteamOS.",
	INSTALL_INSTALLING: "A instalar o MAKO Renderer...",
	INSTALL_UNINSTALLING: "A remover o MAKO Renderer...",
	FLATPAK_MODAL_TITLE: "Extensões Flatpak",
	FLATPAK_RUNTIME_INSTALLER: "Instalador de extensões de ambiente",
	FLATPAK_RUNTIME_VERSION: "Ambiente {version}",
	FLATPAK_INSTALLED: "Instalado",
	FLATPAK_NOT_INSTALLED: "Não instalado",
	FLATPAK_UNINSTALL_TITLE: "Desinstalar extensão de ambiente",
	FLATPAK_UNINSTALL_CONFIRM_PREFIX: "Tem a certeza de que pretende desinstalar o ambiente",
	FLATPAK_UNINSTALL_CONFIRM_SUFFIX: "selecionado?",
	FLATPAK_UNINSTALL_BTN: "Desinstalar",
	FLATPAK_INSTALL_BTN: "Instalar",
	FLATPAK_UPDATE_BTN: "Atualizar",
	FLATPAK_INSTALLING_BTN: "A instalar...",
	FLATPAK_UNINSTALLING_BTN: "A desinstalar...",
	FLATPAK_UPDATING_BTN: "A atualizar...",
	FLATPAK_APPS_TITLE: "Aplicações Flatpak",
	FLATPAK_NO_APPS: "Nenhuma aplicação Flatpak encontrada",
	FLATPAK_NO_APPS_DESC: "Não existem aplicações Flatpak instaladas neste momento",
	FLATPAK_STATUS_CONFIGURED: "Preparada",
	FLATPAK_STATUS_PARTIAL: "Parcial",
	FLATPAK_STATUS_NO_OVERRIDES: "Sem substituições",
	FLATPAK_ERROR: "Erro",
	FLATPAK_ERROR_STATUS: "Falha ao verificar o estado da extensão",
	FLATPAK_ERROR_APPS: "Falha ao carregar as aplicações Flatpak",
	FLATPAK_STEAM_CONFIG_TITLE: "Referência para atalhos manuais do Steam",
	FLATPAK_STEAM_CONFIG_HEADER: "Exemplo de destino (não configura o Steam)",
	FLATPAK_STEAM_CONFIG_DESC: "Use apenas para um atalho do Steam adicionado manualmente cujo Destino original seja /usr/bin/flatpak. Prepare primeiro a aplicação Flatpak acima e mantenha Iniciar em e Opções de arranque inalterados. Heroic, Lutris e EmuDeck têm passos próprios no guia de lançadores.",
	FLATPAK_IMPORTANT_LABEL: "IMPORTANTE:",
	FLATPAK_STEAM_CONFIG_IMPORTANT: "Substitua apenas o DESTINO. Não cole isto nas Opções de arranque.",
	FLATPAK_PER_GAME_APP_DESC: "{app_id} - {status}. Ative o MAKO por jogo usando {wrapper_path}. Consulte o campo correto no guia de lançadores.",
	FLATPAK_DIRECT_APP_DESC: "{app_id} - {status}. A preparação aplica-se a toda esta aplicação Flatpak. Siga o guia de lançadores para EmuDeck e atalhos do Steam.",
	FLATPAK_STEP_WRAPPER_PATH: "Wrapper instalado neste dispositivo:",
	FLATPAK_STEP_FINAL: "Destino para um atalho que originalmente utilizava \"/usr/bin/flatpak\":",
	FLATPAK_OPEN_README: "Abrir guia de lançadores",
	FLATPAK_CLOSE: "Fechar",
	ADVANCED_DETAILS_LOADING: "A carregar informações...",
	ADVANCED_DETAILS_ERROR_PREFIX: "Erro:",
	ADVANCED_DETAILS_DLL_PATH: "Caminho da DLL",
	ADVANCED_DETAILS_LIBRARY: "Biblioteca do Lossless Scaling",
	ADVANCED_DETAILS_NOT_AVAILABLE: "Não disponível",
	ADVANCED_DETAILS_DLL_HASH: "Hash SHA256 da DLL",
	ADVANCED_DETAILS_DETECTION_SOURCE: "Origem da deteção",
	ADVANCED_DETAILS_LAUNCH_SCRIPT: "Script de arranque",
	ADVANCED_DETAILS_SCRIPT_NOT_FOUND_PREFIX: "Script não encontrado:",
	ADVANCED_DETAILS_PATH_PREFIX: "Caminho:",
	ADVANCED_DETAILS_NO_CONTENT: "Sem conteúdo",
	ADVANCED_DETAILS_CONFIG_FILE: "Ficheiro de configuração",
	ADVANCED_DETAILS_CONFIG_NOT_FOUND_PREFIX: "Configuração não encontrada:",
	ADVANCED_DETAILS_CLOSE: "Fechar",
	WELCOME_TITLE: "Olá da equipa MAKO!",
	WELCOME_TIPS_COLLAPSE: "Ocultar dicas",
	WELCOME_TIPS_EXPAND: "Mostrar dicas",
	WELCOME_LIVE_UPDATES: "Muitas definições são aplicadas em tempo real.",
	WELCOME_RESTART_REQUIRED: "As opções assinaladas com «Reiniciar» exigem o reinício do jogo.",
	WELCOME_PERFORMANCE_NOTE: "Alterações à resolução e ao redimensionamento do jogo podem afetar o desempenho.",
	WELCOME_CLEAN_SESSION_PREFIX: "Se algo ",
	WELCOME_CLEAN_SESSION_WRONG: "parecer errado",
	WELCOME_CLEAN_SESSION_AFTER: " após ",
	WELCOME_CLEAN_SESSION_CHANGES: "várias mudanças",
	WELCOME_CLEAN_SESSION_RESTART_SEPARATOR: ", ",
	WELCOME_CLEAN_SESSION_RESTART: "reinicie o jogo para começar uma sessão nova e limpa.",
	WELCOME_ENJOY: "Cada jogo é diferente. Encontre as definições que funcionam melhor para si e divirta-se. O MAKO continua a melhorar em cada versão, por isso fique atento à página de lançamentos!",
	PROFILE_CAPTURE_READY: "O MAKO seleciona automaticamente os perfis guardados. Se este jogo for novo, guarde-o abaixo; reinicie o jogo após alterar definições que exijam reinício.",
	PROFILE_HELP: "Inicie um jogo e guarde o respetivo processo uma vez. O MAKO seleciona automaticamente os perfis guardados; fora de um jogo, a lista apenas escolhe o perfil a editar.",
	PROFILE_SECTION_TITLE: "Perfis de jogo / processo",
	PROFILE_DEFAULT: "Predefinido",
	PROFILE_SAVED_LABEL: "Perfil guardado",
	PROFILE_GAME_SAVED: "Perfil do jogo guardado",
	PROFILE_GAME_SAVE_FAILED: "Não foi possível guardar o perfil do jogo",
	PROFILE_SAVE_RUNNING: "Guardar perfil para {game}",
	PROFILE_DETAIL_DEFAULT: "Abra um jogo para guardar o respetivo perfil",
	PROFILE_DETAIL_GAME: "Jogo guardado",
	PROFILE_DETAIL_PROCESS: "Processo guardado",
	PROFILE_STEAM_APP_ID: "ID da aplicação Steam: {app_id}",
	PROFILE_PROCESSES: "Processos: {processes}",
	PROFILE_PROCESSES_EMPTY: "Processos: introduza um em Processos correspondentes abaixo",
	PROFILE_MANAGE_WHEN_IDLE: "Feche o jogo em execução para mudar o nome ou eliminar perfis.",
	PROFILE_NAME_LABEL: "Nome",
	PROFILE_CANCEL_BTN: "Cancelar",
	PROFILE_RENAME_TITLE: "Mudar o nome do perfil",
	PROFILE_RENAME_DESC_PREFIX: "Escolha um nome reconhecível para este perfil de jogo ou processo.",
	PROFILE_RENAME_BTN: "Mudar o nome",
	PROFILE_CANNOT_DELETE_TITLE: "Não é possível eliminar o perfil predefinido",
	PROFILE_CANNOT_DELETE_MSG: "O perfil predefinido não pode ser eliminado",
	PROFILE_DELETE_TITLE: "Eliminar perfil de jogo / processo",
	PROFILE_DELETE_CONFIRM: "Eliminar \"{profile}\" e todas as definições guardadas?",
	PROFILE_DELETE_BTN: "Eliminar",
	PROFILE_CANNOT_RENAME_TITLE: "Não é possível mudar o nome do perfil predefinido",
	PROFILE_CANNOT_RENAME_MSG: "Não é possível mudar o nome do perfil predefinido",
	USAGE_TITLE: "Instruções de utilização",
	USAGE_DESC: "Cole a opção copiada nas opções de arranque do jogo no Steam para ativar o MAKO Renderer com geração de fotogramas, redimensionamento ou ambos.",
	CLIPBOARD_COPIED: "Copiado para a área de transferência",
	CLIPBOARD_COPYING: "A copiar...",
	CLIPBOARD_COPY_LAUNCH: "Copiar opção de arranque",
	CLIPBOARD_MAKO_FGMOD: "MAKO + DeckyFG",
	CONTENT_RUNNING: "em execução.",
	CONTENT_ENGINE_UPDATE_REQUIRED: "É necessário atualizar o MAKO Renderer",
	CONTENT_ENGINE_INSTALLED: "Instalado:",
	CONTENT_ENGINE_NOT_RECORDED: "não registado",
	CONTENT_ENGINE_EXPECTS: "Este plugin espera:",
	CONTENT_ENGINE_BUNDLED_VERSION: "a versão incluída",
	CONTENT_ENGINE_PREDATES_TRACKING: "A carga instalada é anterior ao registo de versões.",
	CONTENT_ENGINE_UPDATE_DESC: "Reinstale o MAKO Renderer para aplicar a versão incluída neste plugin. Depois, atualize as extensões de ambiente correspondentes às aplicações Flatpak preparadas.",
	CONTENT_UPDATE_RENDERER: "Atualizar o MAKO Renderer",
	CONTENT_UPDATING_RENDERER: "A atualizar o MAKO Renderer...",
	MULTIPLIER_TITLE: "Multiplicador de FPS fixo",
	MULTIPLIER_DESC: "Define o modo Fixo entre 2x e 5x. O Fixo pode ter melhor desempenho do que o Adaptativo em alguns jogos, sobretudo com ritmo irregular. 5x tem um custo elevado para ecrãs de alta atualização. Teste ambos por jogo. Com a Recuperação de cadência dinâmica, este valor é um limite face à atualização confirmada do Gamescope; o Adaptativo gere o seu próprio multiplicador.",
	MULTIPLIER_ADAPTIVE_RELATION: "Indisponível enquanto a Geração de fotogramas adaptativa estiver ativa.",
	ADAPTIVE_TITLE: "Geração de fotogramas adaptativa",
	ADAPTIVE_DESC: "Ajusta a geração de fotogramas para atingir os FPS alvo. O limite base estável é a predefinição para um ritmo mais suave. Ative o Adaptativo fracionário para manter mais fotogramas reais, mas teste por jogo.",
	FRACTIONAL_ADAPTIVE_PRESET: "Adaptativo fracionário",
	FRACTIONAL_ADAPTIVE_PRESET_DESC: "Combina proporções de geração para atingir objetivos como 60 FPS reais → 90 FPS apresentados. Mantém mais fotogramas reais e pode reduzir a latência de entrada e as imagens fantasma, mas pode parecer menos suave em alguns jogos.",
	FRACTIONAL_ADAPTIVE_PRESET_RELATION: "Não pode ser combinado com o Limite base estável. Alterar esta opção também desativa a Recuperação de cadência dinâmica.",
	ADAPTIVE_TARGET_FPS: "FPS alvo",
	ADAPTIVE_TARGET_FPS_DESC: "FPS apresentados pretendidos. O Adaptativo fracionário pode combinar proporções para os alcançar; o limite base estável limita os FPS reais a metade do alvo.",
	ADAPTIVE_AUTO_BASE_FPS_CAP: "Limite base estável",
	ADAPTIVE_AUTO_BASE_FPS_CAP_DESC: "O modo Adaptativo predefinido. Limita os FPS reais a metade do alvo para uma cadência uniforme. Vantagens: ritmo geralmente mais suave. Desvantagens: menos fotogramas reais e possivelmente mais latência de entrada e imagens fantasma.",
	ADAPTIVE_AUTO_BASE_FPS_CAP_RELATION: "Substitui o Limite de FPS base. Não pode ser combinado com o Adaptativo fracionário ou a Recuperação de cadência dinâmica.",
	ADAPTIVE_MAX_MULTIPLIER: "Multiplicador adaptativo máximo",
	ADAPTIVE_MAX_MULTIPLIER_DESC: "Limite de interpolação. 3x é equilibrado; 2x costuma ter o melhor aspeto, 4x oferece mais margem para alcançar o alvo e 5x destina-se a ecrãs de elevada taxa de atualização com bastante margem de GPU e memória. Teste em cada jogo.",
	ADAPTIVE_SMOOTH_CADENCE: "Cadência suave",
	ADAPTIVE_SMOOTH_CADENCE_DESC: "Utiliza uma cadência de interpolação constante validada. Pode tornar o movimento apresentado mais suave, mas reduzir a cadência de fotogramas reais e aumentar a latência de entrada. Ativada por predefinição; desative-a se o jogo parecer mais reativo sem ela.",
	DYNAMIC_CADENCE_RECOVERY: "Recuperação de cadência dinâmica",
	DYNAMIC_CADENCE_RECOVERY_DESC: "Ajuda jogos e emuladores que alternam taxas nativas, como 30 FPS no jogo e 60 FPS nos menus. Verifica periodicamente a alteração e recupera a cadência correta, mas cada verificação pode afetar brevemente o ritmo. Ative apenas nos jogos afetados.",
	DYNAMIC_CADENCE_RECOVERY_RELATION: "Ativar esta opção desativa o Limite base estável e o Limite de FPS base. Alterar qualquer um deles mais tarde desativa a Recuperação.",
	DYNAMIC_CADENCE_PROBE_INTERVAL: "Intervalo de verificação da cadência",
	DYNAMIC_CADENCE_PROBE_INTERVAL_DESC: "Define a frequência com que a Recuperação testa a taxa nativa. 0,1 segundo é uma opção agressiva e pode causar breves falhas de ritmo frequentes; 2 segundos é o valor predefinido e 3 segundos faz verificações com a menor frequência. Teste em cada jogo.",
	ADAPTIVE_VALUE: "Adaptativo",
	CONFIG_DLL_PATH: "Caminho do Lossless.dll (Reiniciar)",
	CONFIG_DLL_PATH_DESC: "Caminho completo opcional para Lossless.dll. Deixe em branco para utilizar a deteção automática do MAKO Renderer. Reinicie o jogo após alterar.",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH: "Desativar o MAKO Renderer no próximo arranque",
	CONFIG_DISABLE_MAKO_NEXT_LAUNCH_DESC: "Apenas para resolução de problemas. Impede o carregamento do MAKO Renderer na próxima vez que o jogo iniciar. Utilize Geração de fotogramas acima para ativar ou desativar a síntese.",
	CONFIG_DISABLE_HDR_EXPOSURE: "Desativar HDR",
	CONFIG_DISABLE_HDR_EXPOSURE_DESC: "O HDR não está disponível nesta versão. Esta definição obrigatória mantém ativo o caminho SDR estável.",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY: "Gamescope WSI (Reiniciar)",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_DESC: "Pode reduzir artefactos de movimento coloridos ou pixelizados em alguns jogos através do caminho de apresentação do Gamescope. O redimensionamento ativa-o automaticamente. Em perfis apenas com geração de fotogramas, ative-o somente nos jogos afetados.",
	CONFIG_GAMESCOPE_WSI_COMPATIBILITY_WARNING: "Este caminho de compatibilidade é limitado a arranques de host de 64 bits compatíveis. Deixe-o desativado quando o jogo não precisar dele, pois pode afetar o desempenho.",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY: "Imagens de swapchain do jogo (Reiniciar)",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_DESC: "Pode corrigir jogos que não iniciam com a geração de fotogramas ao preservar o mínimo de imagens de swapchain pedido pelo jogo. Ative apenas nos jogos afetados.",
	CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_WARNING: "Os fotogramas gerados podem ser ignorados quando o compositor não tem uma imagem livre, o que pode reduzir a fluidez ou o desempenho sob pressão.",
	FRAME_GENERATION_ENABLED: "Geração de fotogramas",
	FRAME_GENERATION_ENABLED_DESC: "Deixe ativada para utilizar a geração Fixa ou Adaptativa. Quando desativada, nenhum modo gera fotogramas; as definições permanecem guardadas.",
	FRAME_GENERATION_ENABLED_WARNING: "Mantenha esta opção ativada se pretender gerar fotogramas.",
	CONFIG_ALLOW_FP16: "Permitir FP16 (Reiniciar)",
	CONFIG_ALLOW_FP16_DESC: "Definição global do renderizador: aplica-se a todos os perfis e não pode ser alterada por jogo. Melhora o desempenho em AMD; desative para GPUs NVIDIA mais antigas. Reinicie o jogo após alterar.",
	CONFIG_GPU: "GPU (Reiniciar)",
	CONFIG_GPU_DESC: "Nome opcional da GPU, ID fornecedor:dispositivo ou ID do barramento PCI. Reinicie o jogo após a alteração.",
	CONFIG_ACTIVE_IN: "Processos correspondentes",
	CONFIG_ACTIVE_IN_DESC: "Nomes de executáveis ou processos separados por vírgulas. A captura do jogo em execução preenche-os automaticamente; edite-os apenas quando um iniciador ou emulador precisar de um alias de processo adicional.",
	CONFIG_MANUAL_OVERRIDES_TITLE: "Substituições manuais",
	INSTALL_REMOVE_RENDERER: "Remover o MAKO Renderer",
	INSTALL_RENDERER: "Instalar o MAKO Renderer",
	FLATPAK_EXTENSION_UPDATED: "Extensão Flatpak atualizada",
	FLATPAK_EXTENSION_FAILED: "Falha na extensão Flatpak",
	FLATPAK_EXTENSION_ACTION_FAILED: "Não foi possível",
	FLATPAK_RUNTIME_EXTENSION_UPDATED: "extensão de ambiente atualizada",
	FLATPAK_RUNTIME_EXTENSION: "extensão de ambiente",
	FLATPAK_APPLICATION_UPDATED: "Aplicação Flatpak atualizada",
	FLATPAK_UPDATED: "atualizada",
	FLATPAK_PREPARE_APPLICATION: "Preparar uma aplicação",
	FLATPAK_PREPARE_APPLICATION_DESC: "Instale a extensão de ambiente correspondente e prepare a aplicação. Heroic e Lutris precisam de um wrapper por jogo; os emuladores são preparados para toda a aplicação. Consulte o guia de lançadores.",
	FLATPAK_INSTALL_ACTION: "instalar",
	FLATPAK_UNINSTALL_ACTION: "desinstalar",
	FLATPAK_APPLICATION_ACTION_FAILED: "Não foi possível atualizar",
	PROFILE_UNKNOWN_ERROR: "Erro desconhecido",
	PROFILE_LOAD_FAILED: "Falha ao carregar os perfis",
	PROFILE_LOAD_ERROR: "Erro ao carregar os perfis",
	PROFILE_SWITCHED: "Perfil alterado",
	PROFILE_SWITCHED_DESC: "Perfil alterado para:",
	PROFILE_SWITCH_FAILED: "Falha ao alterar o perfil",
	PROFILE_SWITCH_ERROR: "Erro ao alterar o perfil",
	PROFILE_DELETED: "Perfil eliminado",
	PROFILE_DELETED_DESC: "Perfil eliminado:",
	PROFILE_DELETE_FAILED: "Falha ao eliminar o perfil",
	PROFILE_DELETE_ERROR: "Erro ao eliminar o perfil",
	PROFILE_RENAMED: "Nome do perfil alterado",
	PROFILE_RENAMED_DESC: "Nome do perfil alterado para:",
	PROFILE_RENAME_FAILED: "Falha ao mudar o nome do perfil",
	PROFILE_RENAME_ERROR: "Erro ao mudar o nome do perfil",
	PROFILE_UPDATE_CONFIG_FAILED: "Falha ao atualizar a configuração do perfil",
	PROFILE_UPDATE_CONFIG_ERROR: "Erro ao atualizar a configuração do perfil",
	USAGE_MAKO_CONFIG_NOTE: "Este comando aplica o MAKO apenas ao jogo iniciado com ele.",
	USAGE_ISOLATION_NOTE: "Não combine o MAKO com outra ferramenta de geração de fotogramas ou redimensionamento no mesmo jogo.",
	ADVANCED_DETAILS_FAILED_LOAD_DATA: "Falha ao carregar os dados",
	ADVANCED_DETAILS_FAILED_DLL_STATS: "Falha ao obter estatísticas da DLL",
	STATUS_ENGINE_INSTALLED: "MAKO Renderer instalado",
	STATUS_ENGINE_NOT_INSTALLED: "MAKO Renderer não instalado",
	STATUS_ENGINE_INSTALLING: "A instalar o MAKO Renderer...",
	STATUS_ENGINE_UPDATING: "A atualizar o MAKO Renderer...",
	STATUS_ENGINE_REMOVING: "A remover o MAKO Renderer...",
	STATUS_ENGINE_REMOVED: "MAKO Renderer removido com sucesso!",
	STATUS_INSTALL_FAILED: "Falha na instalação:",
	STATUS_UNINSTALL_FAILED: "Falha na desinstalação:",
	STATUS_LOSSLESS_INSTALLED: "Lossless Scaling instalado",
	STATUS_LOSSLESS_NOT_INSTALLED: "Lossless Scaling não instalado — necessário para geração de fotogramas e LS1; o MAKO Scaler continua disponível",
	TOAST_INSTALL_COMPLETE: "Instalação concluída",
	TOAST_INSTALL_COMPLETE_DESC: "Recomenda-se reiniciar o dispositivo.",
	TOAST_INSTALL_FAILED: "Falha na instalação",
	TOAST_UNKNOWN_ERROR: "Ocorreu um erro desconhecido",
	TOAST_UNINSTALL_COMPLETE: "MAKO Renderer removido",
	TOAST_UNINSTALL_COMPLETE_DESC: "Os ficheiros do MAKO Renderer foram removidos",
	TOAST_UNINSTALL_FAILED: "Falha na desinstalação",
	TOAST_CONFIG_UPDATE_FAILED: "Falha na atualização",
	TOAST_CONFIG_UPDATE_FAILED_DESC: "Falha ao atualizar a configuração",
	TOAST_CLIPBOARD_SUCCESS: "Copiado para a área de transferência!",
	TOAST_CLIPBOARD_SUCCESS_DESC: "Opção de arranque pronta para colar",
	TOAST_CLIPBOARD_FAILED: "Falha ao copiar",
	TOAST_CLIPBOARD_FAILED_DESC: "Não foi possível copiar para a área de transferência",
	FEATURE_UPSCALING_TAB: "Upscaling",
	LIVE_STATUS_TITLE: "Live Status",
	LIVE_STATUS_CONNECTED: "MAKO is active",
	LIVE_STATUS_WAITING: "Waiting for MAKO",
	LIVE_STATUS_WAITING_DESC: "Live status is unavailable, but MAKO may still be active. Some games and emulators may not report live metrics. Check Frame Generation or Scaling manually.",
	LIVE_STATUS_FG_INACTIVE: "On in settings, but not currently generating frames.",
	LIVE_STATUS_OFF: "Off",
	LIVE_STATUS_SCALING_INACTIVE: "On in settings, but the game image is not being upscaled.",
	LIVE_STATUS_SCALING_MEMORY_LIMIT: "The requested render resolution exceeds this GPU's memory safety limit. Lower the in-game resolution.",
	LIVE_STATUS_SCALING_MEMORY_CONSTRAINED: "Requested {requested}×; limited to {effective}× by this GPU's memory safety limit.",
	LIVE_STATUS_SCALING_NO_HEADROOM: "This input already fills the display target. Lower the in-game resolution or enable Quality Supersampling.",
	LIVE_STATUS_PENDING: "A saved change is still applying or needs a restart.",
	LIVE_STATUS_SUPERSAMPLING: "Quality Supersampling active.",
	LIVE_STATUS_SCALING_FALLBACK: "You selected {requested}; MAKO is using {active} instead.",
	LIVE_STATUS_MODE: "Mode",
	LIVE_STATUS_FIXED_VALUE: "Fixed",
	LIVE_STATUS_ADAPTIVE_STYLE: "Style",
	LIVE_STATUS_STEADY_VALUE: "Steady",
	LIVE_STATUS_FRACTIONAL_VALUE: "Fractional",
	LIVE_STATUS_TARGET: "Target",
	LIVE_STATUS_MAX_MULTIPLIER: "Max factor",
	LIVE_STATUS_MULTIPLIER: "Factor",
	LIVE_STATUS_MODEL: "Model",
	LIVE_STATUS_NATIVE: "Native",
	LIVE_STATUS_LS1_PERFORMANCE: "LS1 Perf",
	LIVE_STATUS_ORIGINAL_RESOLUTION: "Input",
	LIVE_STATUS_RENDER_RESOLUTION: "Render",
	LIVE_STATUS_DISPLAY_RESOLUTION: "Display",
	LIVE_STATUS_SCALED_RESOLUTION: "Output",
	LIVE_STATUS_SCALING_UNAVAILABLE: "Unavailable for this running surface."
},
	steam_language_map: steam_language_map,
	template: template,
	uk: uk,
	zh: zh
};

// Generated from defaults/i18n by the normal frontend build.
const steamLanguageMap = languageBundle.steam_language_map;
const languageMetadata = languageBundle.language_metadata;
const translationSets = languageBundle;
const canonicalLanguageCodes = new Map(Object.keys(languageMetadata).map((language) => [language.toLowerCase(), language]));
const normalizeLanguage = (language) => {
    const normalized = (language || "en").trim().toLowerCase().replace(/_/g, "-");
    const mapped = steamLanguageMap[normalized] ?? normalized;
    // Steam has used both language names (such as `schinese`) and standard
    // locale identifiers (such as `pt-BR`) here. Prefer an exact advertised
    // locale before falling back to its base language so regional Portuguese
    // dictionaries remain distinct while ja-JP and zh-CN resolve normally.
    const exact = canonicalLanguageCodes.get(mapped.toLowerCase());
    if (exact)
        return exact;
    const base = mapped.split("-", 1)[0] || "en";
    return canonicalLanguageCodes.get(base) ?? base;
};
function getLangs() {
    const langs = Object.fromEntries(Object.entries(languageMetadata).map(([language, metadata]) => [language, { ...metadata }]));
    for (const [language, metadata] of Object.entries(langs)) {
        const strings = translationSets[language];
        if (strings && metadata.name) {
            metadata.strings = strings;
        }
    }
    return langs;
}
const LANGS = getLangs();
const getCurrentLanguage = () => {
    return normalizeLanguage(window.LocalizationManager?.m_rgLocalesToUse?.[0]);
};
/**
 * Translate a key to the current language
 *
 * @param key - Translation key
 * @param originalString - Original text (fallback)
 * @param replacements - Named values for placeholders such as {profile}
 * @returns Translated string or original text if translation not found
 *
 * @example
 * t('CONTENT_FPS_MULTIPLIER', 'FPS Multiplier')
 */
const t = (key, originalString, replacements = {}) => {
    const lang = getCurrentLanguage();
    const translated = lang === "en"
        ? originalString
        : LANGS[lang]?.strings?.[key] ?? originalString;
    return Object.entries(replacements).reduce((text, [name, value]) => text.split(`{${name}}`).join(String(value)), translated);
};

/**
 * Centralized toast notification utilities
 * Provides consistent success/error messaging patterns
 */
/**
 * Show a success toast notification
 */
function showSuccessToast(title, body) {
    toaster.toast({
        title,
        body,
    });
}
/**
 * Show an error toast notification
 */
function showErrorToast(title, body) {
    toaster.toast({
        title,
        body,
    });
}
/**
 * Standard success messages for common operations
 */
const ToastMessages = {
    get INSTALL_ERROR() {
        return {
            title: t("TOAST_INSTALL_FAILED", "Installation Failed"),
            body: t("TOAST_UNKNOWN_ERROR", "Unknown error occurred"),
        };
    },
    get UNINSTALL_SUCCESS() {
        return {
            title: t("TOAST_UNINSTALL_COMPLETE", "MAKO Renderer Removed"),
            body: t("TOAST_UNINSTALL_COMPLETE_DESC", "MAKO Renderer files have been removed"),
        };
    },
    get UNINSTALL_ERROR() {
        return {
            title: t("TOAST_UNINSTALL_FAILED", "Uninstallation Failed"),
            body: t("TOAST_UNKNOWN_ERROR", "Unknown error occurred"),
        };
    },
    get CONFIG_UPDATE_ERROR() {
        return {
            title: t("TOAST_CONFIG_UPDATE_FAILED", "Update Failed"),
            body: t("TOAST_CONFIG_UPDATE_FAILED_DESC", "Failed to update configuration"),
        };
    },
    get CLIPBOARD_SUCCESS() {
        return {
            title: t("TOAST_CLIPBOARD_SUCCESS", "Copied to Clipboard!"),
            body: t("TOAST_CLIPBOARD_SUCCESS_DESC", "Launch option ready to paste"),
        };
    },
    get CLIPBOARD_ERROR() {
        return {
            title: t("TOAST_CLIPBOARD_FAILED", "Copy Failed"),
            body: t("TOAST_CLIPBOARD_FAILED_DESC", "Unable to copy to clipboard"),
        };
    },
};
/**
 * Show installation error toast
 */
function showInstallErrorToast(error) {
    showErrorToast(ToastMessages.INSTALL_ERROR.title, error || ToastMessages.INSTALL_ERROR.body);
}
/**
 * Show uninstallation success toast
 */
function showUninstallSuccessToast() {
    showSuccessToast(ToastMessages.UNINSTALL_SUCCESS.title, ToastMessages.UNINSTALL_SUCCESS.body);
}
/**
 * Show uninstallation error toast
 */
function showUninstallErrorToast(error) {
    showErrorToast(ToastMessages.UNINSTALL_ERROR.title, error || ToastMessages.UNINSTALL_ERROR.body);
}
/**
 * Show clipboard error toast
 */
function showClipboardErrorToast() {
    showErrorToast(ToastMessages.CLIPBOARD_ERROR.title, ToastMessages.CLIPBOARD_ERROR.body);
}

function useInstallationStatus() {
    const [isInstalled, setIsInstalled] = SP_REACT.useState(false);
    const [installationStatus, setInstallationStatus] = SP_REACT.useState("");
    const [engineUpdateRequired, setEngineUpdateRequired] = SP_REACT.useState(false);
    const [hostArchitectureSupported, setHostArchitectureSupported] = SP_REACT.useState(true);
    const [installedEngineVersion, setInstalledEngineVersion] = SP_REACT.useState();
    const [expectedEngineVersion, setExpectedEngineVersion] = SP_REACT.useState();
    const checkInstallation = async () => {
        try {
            const status = await checkMakoInstalled();
            setIsInstalled(status.installed);
            setEngineUpdateRequired(Boolean(status.engine_update_required));
            setInstalledEngineVersion(status.installed_engine_version);
            setExpectedEngineVersion(status.expected_engine_version);
            setHostArchitectureSupported(status.host_architecture_supported !== false);
            if (status.installed) {
                setInstallationStatus(t("STATUS_ENGINE_INSTALLED", "MAKO Renderer installed"));
            }
            else if (status.host_architecture_supported === false && status.error) {
                setInstallationStatus(status.error);
            }
            else {
                setInstallationStatus(t("STATUS_ENGINE_NOT_INSTALLED", "MAKO Renderer not installed"));
            }
            return status.installed;
        }
        catch (error) {
            setInstallationStatus(t("STATUS_ENGINE_NOT_INSTALLED", "MAKO Renderer not installed"));
            setEngineUpdateRequired(false);
            // A transient RPC failure is not evidence that the native host is
            // unsupported. Only the backend's explicit compatibility result should
            // disable the installation action.
            setHostArchitectureSupported(true);
            setInstalledEngineVersion(undefined);
            setExpectedEngineVersion(undefined);
            return false;
        }
    };
    SP_REACT.useEffect(() => {
        checkInstallation();
    }, []);
    return {
        isInstalled,
        installationStatus,
        engineUpdateRequired,
        hostArchitectureSupported,
        installedEngineVersion,
        expectedEngineVersion,
        setIsInstalled,
        setInstallationStatus,
        checkInstallation,
    };
}
function useDllDetection() {
    const [dllDetected, setDllDetected] = SP_REACT.useState(false);
    const [dllDetectionStatus, setDllDetectionStatus] = SP_REACT.useState("");
    const checkDllDetection = async () => {
        try {
            const result = await checkLosslessScalingDll();
            setDllDetected(result.detected);
            if (result.detected) {
                setDllDetectionStatus(t("STATUS_LOSSLESS_INSTALLED", "Lossless Scaling installed"));
            }
            else {
                setDllDetectionStatus(t("STATUS_LOSSLESS_NOT_INSTALLED", "Lossless Scaling not installed — required for Frame Generation and LS1; MAKO Scaler remains available"));
            }
        }
        catch (error) {
            setDllDetectionStatus(t("STATUS_LOSSLESS_NOT_INSTALLED", "Lossless Scaling not installed — required for Frame Generation and LS1; MAKO Scaler remains available"));
        }
    };
    SP_REACT.useEffect(() => {
        checkDllDetection();
    }, []);
    return {
        dllDetected,
        dllDetectionStatus,
    };
}
function useRuntimeScalingStatus(profileName, enabled) {
    const [runtimeState, setRuntimeState] = SP_REACT.useState({
        ...EMPTY_RUNTIME_SCALING_UI_STATE,
    });
    SP_REACT.useEffect(() => {
        let active = true;
        const refresh = async () => {
            if (!enabled) {
                if (active) {
                    setRuntimeState({ ...EMPTY_RUNTIME_SCALING_UI_STATE });
                }
                return;
            }
            try {
                const status = await getRuntimeStatus(profileName);
                if (active) {
                    setRuntimeState(runtimeScalingUiState(status, profileName));
                }
            }
            catch {
                if (active) {
                    setRuntimeState({ ...EMPTY_RUNTIME_SCALING_UI_STATE });
                }
            }
        };
        void refresh();
        const interval = setInterval(refresh, RUNTIME_STATUS_POLL_INTERVAL_MS);
        return () => {
            active = false;
            clearInterval(interval);
        };
    }, [enabled, profileName]);
    return runtimeState;
}
function useMakoConfig() {
    const [config, setConfig] = SP_REACT.useState(() => getDefaults());
    const loadRequestId = SP_REACT.useRef(0);
    const loadMakoConfig = SP_REACT.useCallback(async (profileName) => {
        const requestId = ++loadRequestId.current;
        try {
            const result = profileName
                ? await getProfileConfig(profileName)
                : await getMakoConfig();
            if (requestId !== loadRequestId.current)
                return;
            if (result.success && result.config) {
                // Older installed configurations (or a backend that has not yet been
                // reloaded) may not contain fields introduced by a newer frontend.
                // Preserve the generated defaults for any fields missing from the
                // response so an in-place plugin update never renders undefined values.
                setConfig({ ...getDefaults(), ...result.config });
            }
            else {
                console.log("MAKO Renderer config not available, using defaults:", result.error);
                setConfig(getDefaults());
            }
        }
        catch (error) {
            if (requestId !== loadRequestId.current)
                return;
            console.error("Error loading MAKO Renderer config:", error);
            setConfig(getDefaults());
        }
    }, []);
    const updateConfig = SP_REACT.useCallback(async (newConfig) => {
        try {
            const normalizedConfig = { ...getDefaults(), ...newConfig };
            const result = await updateMakoConfigFromObject(normalizedConfig);
            if (result.success) {
                setConfig(normalizedConfig);
            }
            else {
                showErrorToast(ToastMessages.CONFIG_UPDATE_ERROR.title, result.error || ToastMessages.CONFIG_UPDATE_ERROR.body);
            }
            return result;
        }
        catch (error) {
            showErrorToast(ToastMessages.CONFIG_UPDATE_ERROR.title, String(error));
            return configFailureResult(String(error));
        }
    }, []);
    const updateField = SP_REACT.useCallback(async (fieldName, value) => {
        const newConfig = { ...config, [fieldName]: value };
        return updateConfig(newConfig);
    }, [config, updateConfig]);
    const applyConfigPatch = SP_REACT.useCallback((changes) => {
        setConfig((currentConfig) => ({ ...currentConfig, ...changes }));
    }, []);
    const replaceConfig = SP_REACT.useCallback((canonicalConfig) => {
        setConfig({ ...getDefaults(), ...canonicalConfig });
    }, []);
    SP_REACT.useEffect(() => {
        loadMakoConfig();
    }, []);
    return {
        config,
        setConfig,
        applyConfigPatch,
        replaceConfig,
        loadMakoConfig,
        updateConfig,
        updateField,
    };
}

function useProfileManagement() {
    const [profiles, setProfiles] = SP_REACT.useState([]);
    const [currentProfile, setCurrentProfileState] = SP_REACT.useState(DEFAULT_PROFILE_NAME);
    const [isLoading, setIsLoading] = SP_REACT.useState(false);
    // Load profiles on hook initialization
    const loadProfiles = SP_REACT.useCallback(async () => {
        try {
            const result = await getProfiles();
            if (result.success && result.profiles) {
                setProfiles(result.profiles);
                const resolvedProfile = result.current_profile &&
                    result.profiles.includes(result.current_profile)
                    ? result.current_profile
                    : result.profiles.includes(DEFAULT_PROFILE_NAME)
                        ? DEFAULT_PROFILE_NAME
                        : result.profiles[0];
                if (resolvedProfile)
                    setCurrentProfileState(resolvedProfile);
                return result;
            }
            else {
                console.error("Failed to load profiles:", result.error);
                showErrorToast(t("PROFILE_LOAD_FAILED", "Failed to load profiles"), result.error || t("PROFILE_UNKNOWN_ERROR", "Unknown error"));
                return result;
            }
        }
        catch (error) {
            console.error("Error loading profiles:", error);
            showErrorToast(t("PROFILE_LOAD_ERROR", "Error loading profiles"), String(error));
            return profilesFailureResult(String(error));
        }
    }, []);
    // Delete a profile
    const handleDeleteProfile = SP_REACT.useCallback(async (profileName) => {
        if (profileName === DEFAULT_PROFILE_NAME) {
            showErrorToast(t("PROFILE_CANNOT_DELETE_TITLE", "Cannot delete default profile"), t("PROFILE_CANNOT_DELETE_MSG", "The default profile cannot be deleted"));
            return profileFailureResult(t("PROFILE_CANNOT_DELETE_TITLE", "Cannot delete default profile"));
        }
        setIsLoading(true);
        try {
            const result = await deleteProfile(profileName);
            if (result.success) {
                showSuccessToast(t("PROFILE_DELETED", "Profile deleted"), `${t("PROFILE_DELETED_DESC", "Deleted profile:")} ${profileName}`);
                await loadProfiles();
                // If we deleted the current profile, it should have switched to default
                if (currentProfile === profileName) {
                    setCurrentProfileState(DEFAULT_PROFILE_NAME);
                }
                return result;
            }
            else {
                console.error("Failed to delete profile:", result.error);
                showErrorToast(t("PROFILE_DELETE_FAILED", "Failed to delete profile"), result.error || t("PROFILE_UNKNOWN_ERROR", "Unknown error"));
                return result;
            }
        }
        catch (error) {
            console.error("Error deleting profile:", error);
            showErrorToast(t("PROFILE_DELETE_ERROR", "Error deleting profile"), String(error));
            return profileFailureResult(String(error));
        }
        finally {
            setIsLoading(false);
        }
    }, [currentProfile, loadProfiles]);
    // Rename a profile
    const handleRenameProfile = SP_REACT.useCallback(async (oldName, newName) => {
        if (oldName === DEFAULT_PROFILE_NAME) {
            showErrorToast(t("PROFILE_CANNOT_RENAME_TITLE", "Cannot rename default profile"), t("PROFILE_CANNOT_RENAME_MSG", "The default profile cannot be renamed"));
            return profileFailureResult(t("PROFILE_CANNOT_RENAME_TITLE", "Cannot rename default profile"));
        }
        setIsLoading(true);
        try {
            const result = await renameProfile(oldName, newName);
            if (result.success) {
                // Use the normalized name returned from backend (spaces converted to dashes)
                const actualNewName = result.profile_name || newName;
                showSuccessToast(t("PROFILE_RENAMED", "Profile renamed"), `${t("PROFILE_RENAMED_DESC", "Renamed profile to:")} ${actualNewName}`);
                await loadProfiles();
                // Update current profile if it was renamed
                if (currentProfile === oldName) {
                    setCurrentProfileState(actualNewName);
                }
                return result;
            }
            else {
                console.error("Failed to rename profile:", result.error);
                showErrorToast(t("PROFILE_RENAME_FAILED", "Failed to rename profile"), result.error || t("PROFILE_UNKNOWN_ERROR", "Unknown error"));
                return result;
            }
        }
        catch (error) {
            console.error("Error renaming profile:", error);
            showErrorToast(t("PROFILE_RENAME_ERROR", "Error renaming profile"), String(error));
            return profileFailureResult(String(error));
        }
        finally {
            setIsLoading(false);
        }
    }, [currentProfile, loadProfiles]);
    // Set the current active profile
    const handleSetCurrentProfile = SP_REACT.useCallback(async (profileName) => {
        setIsLoading(true);
        try {
            const result = await setCurrentProfile(profileName);
            if (result.success) {
                setCurrentProfileState(profileName);
                showSuccessToast(t("PROFILE_SWITCHED", "Profile switched"), `${t("PROFILE_SWITCHED_DESC", "Switched to profile:")} ${profileName}`);
                return result;
            }
            else {
                console.error("Failed to switch profile:", result.error);
                showErrorToast(t("PROFILE_SWITCH_FAILED", "Failed to switch profile"), result.error || t("PROFILE_UNKNOWN_ERROR", "Unknown error"));
                return result;
            }
        }
        catch (error) {
            console.error("Error switching profile:", error);
            showErrorToast(t("PROFILE_SWITCH_ERROR", "Error switching profile"), String(error));
            return profileFailureResult(String(error));
        }
        finally {
            setIsLoading(false);
        }
    }, []);
    const handleSyncCurrentProfile = SP_REACT.useCallback(async (appId) => {
        try {
            const result = await syncCurrentProfile(appId || "");
            if (result.success && result.profile_name) {
                setCurrentProfileState(result.profile_name);
            }
            else if (!result.success) {
                console.error("Failed to synchronise current profile:", result.error);
            }
            return result;
        }
        catch (error) {
            console.error("Error synchronising current profile:", error);
            return profileFailureResult(String(error), { changed: false });
        }
    }, []);
    // Update configuration for a specific profile
    const handleUpdateProfileConfig = SP_REACT.useCallback(async (profileName, config) => {
        setIsLoading(true);
        try {
            const result = await updateProfileConfig(profileName, config);
            if (result.success) {
                return result;
            }
            else {
                console.error("Failed to update profile config:", result.error);
                showErrorToast(t("PROFILE_UPDATE_CONFIG_FAILED", "Failed to update profile config"), result.error || t("PROFILE_UNKNOWN_ERROR", "Unknown error"));
                return result;
            }
        }
        catch (error) {
            console.error("Error updating profile config:", error);
            showErrorToast(t("PROFILE_UPDATE_CONFIG_ERROR", "Error updating profile config"), String(error));
            return configFailureResult(String(error));
        }
        finally {
            setIsLoading(false);
        }
    }, [currentProfile]);
    const handleUpdateProfileConfigFields = SP_REACT.useCallback(async (profileName, changes) => {
        setIsLoading(true);
        try {
            const result = await updateProfileConfigFields(profileName, changes);
            if (!result.success) {
                console.error("Failed to update profile fields:", result.error);
                showErrorToast(t("PROFILE_UPDATE_CONFIG_FAILED", "Failed to update profile config"), result.error || t("PROFILE_UNKNOWN_ERROR", "Unknown error"));
            }
            return result;
        }
        catch (error) {
            console.error("Error updating profile fields:", error);
            showErrorToast(t("PROFILE_UPDATE_CONFIG_ERROR", "Error updating profile config"), String(error));
            return configFailureResult(String(error));
        }
        finally {
            setIsLoading(false);
        }
    }, []);
    // Initialize profiles on mount
    SP_REACT.useEffect(() => {
        loadProfiles();
    }, [loadProfiles]);
    return {
        profiles,
        currentProfile,
        isLoading,
        loadProfiles,
        deleteProfile: handleDeleteProfile,
        renameProfile: handleRenameProfile,
        setCurrentProfile: handleSetCurrentProfile,
        syncCurrentProfile: handleSyncCurrentProfile,
        updateProfileConfig: handleUpdateProfileConfig,
        updateProfileConfigFields: handleUpdateProfileConfigFields,
    };
}

function useInstallationActions() {
    const [isInstalling, setIsInstalling] = SP_REACT.useState(false);
    const [isUninstalling, setIsUninstalling] = SP_REACT.useState(false);
    const [isInstallCompletionVisible, setIsInstallCompletionVisible] = SP_REACT.useState(false);
    const handleInstall = async (setIsInstalled, setInstallationStatus, reloadConfig, operation = "install") => {
        setIsInstalling(true);
        setInstallationStatus(operation === "update"
            ? t("STATUS_ENGINE_UPDATING", "Updating MAKO Renderer...")
            : t("STATUS_ENGINE_INSTALLING", "Installing MAKO Renderer..."));
        try {
            const result = await installMako();
            if (result.success) {
                setInstallationStatus(result.message ||
                    t("STATUS_ENGINE_INSTALLED", "MAKO Renderer installed"));
                setIsInstallCompletionVisible(true);
                const completionDelay = new Promise((resolve) => {
                    setTimeout(resolve, MAKO_INSTALL_COMPLETION_DURATION_MS);
                });
                if (reloadConfig) {
                    await Promise.all([reloadConfig(), completionDelay]);
                }
                else {
                    await completionDelay;
                }
                setIsInstallCompletionVisible(false);
                setIsInstalled(true);
            }
            else {
                setInstallationStatus(`${t("STATUS_INSTALL_FAILED", "Installation failed:")} ${result.error}`);
                showInstallErrorToast(result.error);
            }
        }
        catch (error) {
            setInstallationStatus(`${t("STATUS_INSTALL_FAILED", "Installation failed:")} ${error}`);
            showInstallErrorToast(String(error));
        }
        finally {
            setIsInstallCompletionVisible(false);
            setIsInstalling(false);
        }
    };
    const handleUninstall = async (setIsInstalled, setInstallationStatus) => {
        setIsUninstalling(true);
        setInstallationStatus(t("STATUS_ENGINE_REMOVING", "Removing MAKO Renderer..."));
        try {
            const result = await uninstallMako();
            if (result.success) {
                setIsInstalled(false);
                setInstallationStatus(t("STATUS_ENGINE_REMOVED", "MAKO Renderer removed successfully!"));
                showUninstallSuccessToast();
            }
            else {
                setInstallationStatus(`${t("STATUS_UNINSTALL_FAILED", "Uninstallation failed:")} ${result.error}`);
                showUninstallErrorToast(result.error);
            }
        }
        catch (error) {
            setInstallationStatus(`${t("STATUS_UNINSTALL_FAILED", "Uninstallation failed:")} ${error}`);
            showUninstallErrorToast(String(error));
        }
        finally {
            setIsUninstalling(false);
        }
    };
    return {
        isInstalling,
        isUninstalling,
        isInstallCompletionVisible,
        handleInstall,
        handleUninstall,
    };
}

const PROFILE_SYNC_INTERVAL_MS = 2000;
/**
 * Coordinates the profile being edited with Decky's running-game state.
 *
 * A live game locks the editor to its resolved profile. After that game exits,
 * the editor returns to Default exactly once; later offline profile selections
 * remain untouched until another game starts.
 */
function useProfileSession({ isInstalled, loadProfileConfig, syncCurrentProfile, }) {
    const [mainRunningApp, setMainRunningApp] = SP_REACT.useState(undefined);
    const [editingProfile, setEditingProfile] = SP_REACT.useState(DEFAULT_PROFILE_NAME);
    const editingProfileRef = SP_REACT.useRef(DEFAULT_PROFILE_NAME);
    const gameWasRunningRef = SP_REACT.useRef(false);
    SP_REACT.useEffect(() => {
        if (isInstalled) {
            void loadProfileConfig(editingProfileRef.current);
        }
    }, [isInstalled, loadProfileConfig]);
    SP_REACT.useEffect(() => {
        let cancelled = false;
        let syncInFlight = false;
        const checkRunningApp = async () => {
            const runningApp = DFL.Router.MainRunningApp;
            if (syncInFlight)
                return;
            syncInFlight = true;
            try {
                const result = await syncCurrentProfile(runningApp ? String(runningApp.appid) : undefined);
                if (!cancelled && result.success) {
                    const gameIsRunning = Boolean(result.game_running && runningApp);
                    const nextEditingProfile = gameIsRunning
                        ? result.profile_name || DEFAULT_PROFILE_NAME
                        : gameWasRunningRef.current
                            ? DEFAULT_PROFILE_NAME
                            : undefined;
                    const editingProfileChanged = Boolean(nextEditingProfile &&
                        nextEditingProfile !== editingProfileRef.current);
                    // On exit, reset the editor before unlocking profile controls. On
                    // launch, lock controls before following the detected game profile.
                    if (!gameIsRunning && editingProfileChanged && nextEditingProfile) {
                        editingProfileRef.current = nextEditingProfile;
                        setEditingProfile(nextEditingProfile);
                    }
                    setMainRunningApp(gameIsRunning ? runningApp : undefined);
                    gameWasRunningRef.current = gameIsRunning;
                    if (gameIsRunning && editingProfileChanged && nextEditingProfile) {
                        editingProfileRef.current = nextEditingProfile;
                        setEditingProfile(nextEditingProfile);
                    }
                    if (editingProfileChanged && nextEditingProfile) {
                        await loadProfileConfig(nextEditingProfile);
                    }
                }
            }
            finally {
                syncInFlight = false;
            }
        };
        void checkRunningApp();
        const interval = setInterval(() => void checkRunningApp(), PROFILE_SYNC_INTERVAL_MS);
        return () => {
            cancelled = true;
            clearInterval(interval);
        };
    }, [loadProfileConfig, syncCurrentProfile]);
    const selectEditingProfile = SP_REACT.useCallback((profileName) => {
        editingProfileRef.current = profileName;
        setEditingProfile(profileName);
    }, []);
    const getEditingProfile = SP_REACT.useCallback(() => editingProfileRef.current, []);
    return {
        mainRunningApp,
        editingProfile,
        selectEditingProfile,
        getEditingProfile,
    };
}

const PROFILE_CONFIG_SAVE_DELAY_MS = 250;
const BASE_FPS_CAP_SAVE_DELAY_MS = 1000;
function saveDelayForChanges(changes) {
    const keys = Object.keys(changes);
    const baseFpsCapDrag = keys.includes("base_fps_cap") &&
        keys.every((key) => key === "base_fps_cap" ||
            (key === "dynamic_cadence_recovery" &&
                changes.dynamic_cadence_recovery === false));
    return baseFpsCapDrag
        ? BASE_FPS_CAP_SAVE_DELAY_MS
        : PROFILE_CONFIG_SAVE_DELAY_MS;
}
/**
 * Creates one bounded persistence boundary for every profile control.
 *
 * UI state updates optimistically, while rapid edits merge by profile and only
 * one backend request can be active at a time. Each callback retains the
 * profile selected in the render that created it, so queued writes cannot move
 * to a newly selected profile. Pending writes flush when Decky unmounts the
 * quick-access panel.
 */
function useProfileConfigWriter({ editingProfile, getEditingProfile, updateProfileConfigFields, loadProfileConfig, applyConfigPatch, replaceConfig, }) {
    const pendingWrites = SP_REACT.useRef(new Map());
    const pendingOrder = SP_REACT.useRef([]);
    const saveTimer = SP_REACT.useRef(null);
    const writeInFlight = SP_REACT.useRef(false);
    const flushImmediately = SP_REACT.useRef(false);
    const mounted = SP_REACT.useRef(true);
    const flushNextWriteRef = SP_REACT.useRef(() => undefined);
    const scheduleWrite = SP_REACT.useCallback((delay = PROFILE_CONFIG_SAVE_DELAY_MS) => {
        if (saveTimer.current !== null)
            clearTimeout(saveTimer.current);
        saveTimer.current = setTimeout(() => {
            saveTimer.current = null;
            flushNextWriteRef.current();
        }, delay);
    }, []);
    const reconcileProfile = SP_REACT.useCallback(async (profileName) => {
        if (mounted.current && getEditingProfile() === profileName) {
            try {
                await loadProfileConfig(profileName);
            }
            catch {
                return;
            }
            const newerChanges = pendingWrites.current.get(profileName)?.changes;
            if (newerChanges && getEditingProfile() === profileName) {
                applyConfigPatch(newerChanges);
            }
        }
    }, [applyConfigPatch, getEditingProfile, loadProfileConfig]);
    const flushNextWrite = SP_REACT.useCallback(async () => {
        if (writeInFlight.current)
            return;
        const profileName = pendingOrder.current.shift();
        if (!profileName) {
            flushImmediately.current = false;
            return;
        }
        const pendingWrite = pendingWrites.current.get(profileName);
        if (!pendingWrite) {
            flushNextWriteRef.current();
            return;
        }
        pendingWrites.current.delete(profileName);
        writeInFlight.current = true;
        try {
            const result = await updateProfileConfigFields(profileName, pendingWrite.changes);
            if (mounted.current && getEditingProfile() === profileName) {
                if (result.success && result.config) {
                    const newerChanges = pendingWrites.current.get(profileName)?.changes;
                    replaceConfig({
                        ...result.config,
                        ...(newerChanges || {}),
                    });
                }
                else {
                    await reconcileProfile(profileName);
                }
            }
        }
        catch {
            await reconcileProfile(profileName);
        }
        finally {
            writeInFlight.current = false;
            if (pendingOrder.current.length > 0) {
                if (flushImmediately.current || !mounted.current) {
                    flushNextWriteRef.current();
                }
                else {
                    const nextProfile = pendingOrder.current[0];
                    scheduleWrite(pendingWrites.current.get(nextProfile)?.delayMs ??
                        PROFILE_CONFIG_SAVE_DELAY_MS);
                }
            }
            else {
                flushImmediately.current = false;
            }
        }
    }, [
        getEditingProfile,
        reconcileProfile,
        replaceConfig,
        scheduleWrite,
        updateProfileConfigFields,
    ]);
    flushNextWriteRef.current = () => void flushNextWrite();
    SP_REACT.useEffect(() => {
        mounted.current = true;
        return () => {
            mounted.current = false;
            flushImmediately.current = true;
            if (saveTimer.current !== null) {
                clearTimeout(saveTimer.current);
                saveTimer.current = null;
            }
            flushNextWriteRef.current();
        };
    }, []);
    const saveConfigChanges = SP_REACT.useCallback((changes) => {
        const targetProfile = editingProfile;
        const ownedChanges = { ...changes };
        if (getEditingProfile() === targetProfile) {
            applyConfigPatch(ownedChanges);
        }
        let pendingWrite = pendingWrites.current.get(targetProfile);
        const requestedDelay = saveDelayForChanges(ownedChanges);
        if (!pendingWrite) {
            pendingWrite = { changes: {}, delayMs: requestedDelay };
            pendingWrites.current.set(targetProfile, pendingWrite);
            pendingOrder.current.push(targetProfile);
        }
        else {
            pendingWrite.delayMs = Math.min(pendingWrite.delayMs, requestedDelay);
        }
        pendingWrite.changes = {
            ...pendingWrite.changes,
            ...ownedChanges,
        };
        scheduleWrite(pendingWrite.delayMs);
        return Promise.resolve();
    }, [applyConfigPatch, editingProfile, getEditingProfile, scheduleWrite]);
    const saveConfigField = SP_REACT.useCallback(async (fieldName, value) => {
        return saveConfigChanges({
            [fieldName]: value,
        });
    }, [saveConfigChanges]);
    return { saveConfigChanges, saveConfigField };
}

// THIS FILE IS AUTO GENERATED
function FiAlertCircle (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 24 24","fill":"none","stroke":"currentColor","strokeWidth":"2","strokeLinecap":"round","strokeLinejoin":"round"},"child":[{"tag":"circle","attr":{"cx":"12","cy":"12","r":"10"},"child":[]},{"tag":"line","attr":{"x1":"12","y1":"8","x2":"12","y2":"12"},"child":[]},{"tag":"line","attr":{"x1":"12","y1":"16","x2":"12.01","y2":"16"},"child":[]}]})(props);
}function FiAlertTriangle (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 24 24","fill":"none","stroke":"currentColor","strokeWidth":"2","strokeLinecap":"round","strokeLinejoin":"round"},"child":[{"tag":"path","attr":{"d":"M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"},"child":[]},{"tag":"line","attr":{"x1":"12","y1":"9","x2":"12","y2":"13"},"child":[]},{"tag":"line","attr":{"x1":"12","y1":"17","x2":"12.01","y2":"17"},"child":[]}]})(props);
}function FiCheckCircle (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 24 24","fill":"none","stroke":"currentColor","strokeWidth":"2","strokeLinecap":"round","strokeLinejoin":"round"},"child":[{"tag":"path","attr":{"d":"M22 11.08V12a10 10 0 1 1-5.93-9.14"},"child":[]},{"tag":"polyline","attr":{"points":"22 4 12 14.01 9 11.01"},"child":[]}]})(props);
}function FiInfo (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 24 24","fill":"none","stroke":"currentColor","strokeWidth":"2","strokeLinecap":"round","strokeLinejoin":"round"},"child":[{"tag":"circle","attr":{"cx":"12","cy":"12","r":"10"},"child":[]},{"tag":"line","attr":{"x1":"12","y1":"16","x2":"12","y2":"12"},"child":[]},{"tag":"line","attr":{"x1":"12","y1":"8","x2":"12.01","y2":"8"},"child":[]}]})(props);
}function FiLink (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 24 24","fill":"none","stroke":"currentColor","strokeWidth":"2","strokeLinecap":"round","strokeLinejoin":"round"},"child":[{"tag":"path","attr":{"d":"M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"},"child":[]},{"tag":"path","attr":{"d":"M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"},"child":[]}]})(props);
}

function StatusRow$1({ ready, text, separated = false }) {
    const accent = ready ? "#65b9c9" : "#c89558";
    const Icon = ready ? FiCheckCircle : FiAlertCircle;
    return (window.SP_REACT.createElement("div", { style: {
            minHeight: "38px",
            padding: "7px 10px",
            boxSizing: "border-box",
            display: "flex",
            alignItems: "center",
            gap: "9px",
            borderTop: separated ? "1px solid rgba(77, 170, 190, 0.16)" : "none",
            color: "#e6f2f5",
            fontSize: "13px",
            fontWeight: "500",
            lineHeight: "1.3"
        } },
        window.SP_REACT.createElement(Icon, { "aria-hidden": "true", style: {
                width: "16px",
                height: "16px",
                flex: "0 0 16px",
                color: accent
            } }),
        window.SP_REACT.createElement("span", null, text)));
}
function StatusDisplay({ dllDetected, dllDetectionStatus, isInstalled, installationStatus, topMargin = "0" }) {
    return (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
        window.SP_REACT.createElement("div", { style: {
                marginTop: topMargin,
                marginBottom: "0",
                width: "100%",
                boxSizing: "border-box",
                overflow: "hidden",
                background: "linear-gradient(135deg, rgba(7, 31, 49, 0.72), rgba(8, 55, 68, 0.46))",
                border: "1px solid rgba(77, 170, 190, 0.28)",
                borderRadius: "6px",
                boxShadow: "inset 0 1px 0 rgba(255, 255, 255, 0.035), 0 2px 5px rgba(0, 0, 0, 0.16)"
            } },
            window.SP_REACT.createElement(StatusRow$1, { ready: dllDetected, text: dllDetectionStatus }),
            window.SP_REACT.createElement(StatusRow$1, { ready: isInstalled, text: installationStatus, separated: true }))));
}

// THIS FILE IS AUTO GENERATED
function FaCheck (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 512 512"},"child":[{"tag":"path","attr":{"d":"M173.898 439.404l-166.4-166.4c-9.997-9.997-9.997-26.206 0-36.204l36.203-36.204c9.997-9.998 26.207-9.998 36.204 0L192 312.69 432.095 72.596c9.997-9.997 26.207-9.997 36.204 0l36.203 36.204c9.997 9.997 9.997 26.206 0 36.204l-294.4 294.401c-9.998 9.997-26.207 9.997-36.204-.001z"},"child":[]}]})(props);
}function FaClipboard (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 384 512"},"child":[{"tag":"path","attr":{"d":"M384 112v352c0 26.51-21.49 48-48 48H48c-26.51 0-48-21.49-48-48V112c0-26.51 21.49-48 48-48h80c0-35.29 28.71-64 64-64s64 28.71 64 64h80c26.51 0 48 21.49 48 48zM192 40c-13.255 0-24 10.745-24 24s10.745 24 24 24 24-10.745 24-24-10.745-24-24-24m96 114v-20a6 6 0 0 0-6-6H102a6 6 0 0 0-6 6v20a6 6 0 0 0 6 6h180a6 6 0 0 0 6-6z"},"child":[]}]})(props);
}function FaCog (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 512 512"},"child":[{"tag":"path","attr":{"d":"M487.4 315.7l-42.6-24.6c4.3-23.2 4.3-47 0-70.2l42.6-24.6c4.9-2.8 7.1-8.6 5.5-14-11.1-35.6-30-67.8-54.7-94.6-3.8-4.1-10-5.1-14.8-2.3L380.8 110c-17.9-15.4-38.5-27.3-60.8-35.1V25.8c0-5.6-3.9-10.5-9.4-11.7-36.7-8.2-74.3-7.8-109.2 0-5.5 1.2-9.4 6.1-9.4 11.7V75c-22.2 7.9-42.8 19.8-60.8 35.1L88.7 85.5c-4.9-2.8-11-1.9-14.8 2.3-24.7 26.7-43.6 58.9-54.7 94.6-1.7 5.4.6 11.2 5.5 14L67.3 221c-4.3 23.2-4.3 47 0 70.2l-42.6 24.6c-4.9 2.8-7.1 8.6-5.5 14 11.1 35.6 30 67.8 54.7 94.6 3.8 4.1 10 5.1 14.8 2.3l42.6-24.6c17.9 15.4 38.5 27.3 60.8 35.1v49.2c0 5.6 3.9 10.5 9.4 11.7 36.7 8.2 74.3 7.8 109.2 0 5.5-1.2 9.4-6.1 9.4-11.7v-49.2c22.2-7.9 42.8-19.8 60.8-35.1l42.6 24.6c4.9 2.8 11 1.9 14.8-2.3 24.7-26.7 43.6-58.9 54.7-94.6 1.5-5.5-.7-11.3-5.6-14.1zM256 336c-44.1 0-80-35.9-80-80s35.9-80 80-80 80 35.9 80 80-35.9 80-80 80z"},"child":[]}]})(props);
}function FaDownload (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 512 512"},"child":[{"tag":"path","attr":{"d":"M216 0h80c13.3 0 24 10.7 24 24v168h87.7c17.8 0 26.7 21.5 14.1 34.1L269.7 378.3c-7.5 7.5-19.8 7.5-27.3 0L90.1 226.1c-12.6-12.6-3.7-34.1 14.1-34.1H192V24c0-13.3 10.7-24 24-24zm296 376v112c0 13.3-10.7 24-24 24H24c-13.3 0-24-10.7-24-24V376c0-13.3 10.7-24 24-24h146.7l49 49c20.1 20.1 52.5 20.1 72.6 0l49-49H488c13.3 0 24 10.7 24 24zm-124 88c0-11-9-20-20-20s-20 9-20 20 9 20 20 20 20-9 20-20zm64 0c0-11-9-20-20-20s-20 9-20 20 9 20 20 20 20-9 20-20z"},"child":[]}]})(props);
}function FaTimes (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 352 512"},"child":[{"tag":"path","attr":{"d":"M242.72 256l100.07-100.07c12.28-12.28 12.28-32.19 0-44.48l-22.24-22.24c-12.28-12.28-32.19-12.28-44.48 0L176 189.28 75.93 89.21c-12.28-12.28-32.19-12.28-44.48 0L9.21 111.45c-12.28 12.28-12.28 32.19 0 44.48L109.28 256 9.21 356.07c-12.28 12.28-12.28 32.19 0 44.48l22.24 22.24c12.28 12.28 32.2 12.28 44.48 0L176 322.72l100.07 100.07c12.28 12.28 32.2 12.28 44.48 0l22.24-22.24c12.28-12.28 12.28-32.19 0-44.48L242.72 256z"},"child":[]}]})(props);
}function FaTrash (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 448 512"},"child":[{"tag":"path","attr":{"d":"M432 32H312l-9.4-18.7A24 24 0 0 0 281.1 0H166.8a23.72 23.72 0 0 0-21.4 13.3L136 32H16A16 16 0 0 0 0 48v32a16 16 0 0 0 16 16h416a16 16 0 0 0 16-16V48a16 16 0 0 0-16-16zM53.2 467a48 48 0 0 0 47.9 45h245.8a48 48 0 0 0 47.9-45L416 128H32z"},"child":[]}]})(props);
}

/** Restrict Decky's open string type to directions supported by Steam. */
function MakoFocusable(props) {
    return window.SP_REACT.createElement(DFL.Focusable, { ...props });
}
const makoPanelDivider = "1px solid rgba(77, 170, 190, 0.2)";
const makoAccentColor = "#83bff0";
const makoSectionGap = "26px";
const makoSectionTailGap = "12px";
const makoPanelStyle = {
    overflow: "hidden",
    border: "1px solid rgba(77, 170, 190, 0.28)",
    borderRadius: "8px",
    background: "linear-gradient(135deg, rgba(7, 31, 49, 0.68), rgba(8, 55, 68, 0.38))",
    boxShadow: "inset 0 1px 0 rgba(255, 255, 255, 0.035), 0 2px 6px rgba(0, 0, 0, 0.18)",
};
const makoPanelSectionHeaderStyle = {
    padding: "12px 14px 9px",
    color: "#edf8fb",
    fontSize: "14px",
    fontWeight: 600,
    lineHeight: 1.25,
    letterSpacing: "0.15px",
};
function MakoSectionTail({ children }) {
    return (window.SP_REACT.createElement("div", { "data-mako-section-tail": "true", style: {
            width: "100%",
            boxSizing: "border-box",
            paddingBottom: makoSectionTailGap,
        } }, children));
}
const makoPanelItemStyle = {
    padding: "12px 14px",
    borderTop: makoPanelDivider,
};
const trailingParentheticalPattern = /(\s*)(\([^()]+\)|（[^（）]+）)\s*$/u;
/** Render a translated restart-bound label while keeping its qualifier visually secondary. */
function MakoRestartLabel({ label }) {
    const match = trailingParentheticalPattern.exec(label);
    if (!match || match.index === undefined)
        return window.SP_REACT.createElement("span", null, label);
    return (window.SP_REACT.createElement("span", null,
        label.slice(0, match.index),
        match[1],
        window.SP_REACT.createElement("span", { "data-mako-restart-marker": "true", style: {
                fontSize: "0.72em",
                fontWeight: 500,
                opacity: 0.72,
                verticalAlign: "0.08em",
                whiteSpace: "nowrap",
            } }, match[2])));
}
/** Mark an intentionally early-access control without turning the label into a warning. */
function MakoExperimentalBadge({ label }) {
    return (window.SP_REACT.createElement("span", { "data-mako-experimental-badge": "true", style: {
            display: "inline-flex",
            alignItems: "center",
            padding: "1px 5px",
            border: "1px solid rgba(244, 162, 89, 0.5)",
            borderRadius: "999px",
            background: "rgba(104, 59, 19, 0.42)",
            color: "#f7d9b4",
            fontSize: "0.62em",
            fontWeight: 600,
            lineHeight: 1.35,
            letterSpacing: "0.15px",
            textTransform: "uppercase",
            whiteSpace: "nowrap",
        } }, label));
}
/** Keep experimental setting labels on one shared compact spacing rhythm. */
function MakoExperimentalSettingLabel({ label, badgeLabel, }) {
    return (window.SP_REACT.createElement("span", { "data-mako-experimental-setting-label": "true", style: {
            display: "inline-flex",
            alignItems: "center",
            columnGap: "6px",
            rowGap: "6px",
            flexWrap: "wrap",
        } },
        window.SP_REACT.createElement(MakoRestartLabel, { label: label }),
        window.SP_REACT.createElement(MakoExperimentalBadge, { label: badgeLabel })));
}
/** Use info for context and potential performance effects; reserve warning for known added runtime cost. */
function MakoInlineTip({ children, tone = "info", }) {
    const isWarning = tone === "warning";
    const accentColor = isWarning ? "#f4a259" : makoAccentColor;
    const Icon = isWarning ? FiAlertTriangle : FiInfo;
    return (window.SP_REACT.createElement("div", { role: "note", "data-tone": tone, style: {
            display: "flex",
            alignItems: "flex-start",
            gap: "6px",
            marginTop: "7px",
            padding: "6px 8px",
            border: isWarning
                ? "1px solid rgba(244, 162, 89, 0.34)"
                : "1px solid rgba(91, 163, 209, 0.24)",
            borderLeft: isWarning
                ? "2px solid rgba(244, 162, 89, 0.86)"
                : "2px solid rgba(131, 191, 240, 0.78)",
            borderRadius: "5px",
            background: isWarning
                ? "linear-gradient(90deg, rgba(104, 59, 19, 0.5), rgba(69, 37, 12, 0.2))"
                : "linear-gradient(90deg, rgba(24, 67, 94, 0.42), rgba(8, 39, 56, 0.18))",
            color: isWarning ? "#f7d9b4" : "#c8dce8",
            fontSize: "10px",
            fontWeight: 450,
            lineHeight: 1.35,
            letterSpacing: "0.05px",
        } },
        window.SP_REACT.createElement(Icon, { "aria-hidden": "true", size: 11, style: {
                flex: "0 0 11px",
                marginTop: "1px",
                color: accentColor,
            } }),
        window.SP_REACT.createElement("span", { style: { minWidth: 0 } }, children)));
}
function MakoSettingRelationship({ children }) {
    return (window.SP_REACT.createElement("div", { "data-mako-setting-relationship": "true", style: {
            display: "flex",
            alignItems: "flex-start",
            gap: "5px",
            marginTop: "5px",
            color: "#93adb7",
            fontSize: "9.5px",
            fontWeight: 450,
            lineHeight: 1.35,
            letterSpacing: "0.03px",
        } },
        window.SP_REACT.createElement(FiLink, { "aria-hidden": "true", size: 10, style: {
                flex: "0 0 10px",
                marginTop: "1px",
                color: "rgba(131, 191, 240, 0.78)",
            } }),
        window.SP_REACT.createElement("span", { style: { minWidth: 0 } }, children)));
}
function MakoReleaseIdentity({ version, codename, bottomMargin = "2px", }) {
    const codenameSlug = codename
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, "");
    return (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
        window.SP_REACT.createElement("div", { "aria-label": `Current release: MAKO Decky v${version}, ${codename}`, style: {
                width: "100%",
                boxSizing: "border-box",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                margin: "-2px 0 0",
                marginBottom: bottomMargin,
                padding: "2px 4px 4px",
                opacity: 0.5,
                color: "#a8bdc2",
                fontSize: "10px",
                fontWeight: 600,
                lineHeight: 1.2,
                letterSpacing: "0.55px",
                whiteSpace: "nowrap",
            } },
            window.SP_REACT.createElement("span", null,
                "v",
                version),
            window.SP_REACT.createElement("span", { "aria-hidden": "true", style: { padding: "0 6px", color: "#557f88" } }, "-"),
            window.SP_REACT.createElement("span", { style: { color: makoAccentColor } }, codenameSlug))));
}
function MakoSectionHeader({ children, description, topMargin = makoSectionGap, }) {
    return (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
        window.SP_REACT.createElement("div", { style: {
                width: "100%",
                boxSizing: "border-box",
                marginTop: topMargin,
                marginBottom: "6px",
                color: "#edf8fb",
                fontSize: "14px",
                fontWeight: "600",
                lineHeight: "1.25",
                letterSpacing: "0.15px",
            } },
            window.SP_REACT.createElement("div", { style: {
                    paddingBottom: "8px",
                    borderBottom: "4px solid rgba(77, 170, 190, 0.48)",
                } }, children),
            description && (window.SP_REACT.createElement("div", { style: {
                    marginTop: "8px",
                    color: "#aebfc5",
                    fontSize: "11px",
                    fontWeight: "400",
                    lineHeight: "1.35",
                    letterSpacing: "normal",
                } }, description)))));
}
function MakoCompactSpinner({ size = 18 }) {
    return (window.SP_REACT.createElement("span", { "aria-hidden": "true", style: {
            width: `${size}px`,
            height: `${size}px`,
            display: "inline-flex",
            alignItems: "center",
            justifyContent: "center",
            flex: `0 0 ${size}px`,
            overflow: "hidden",
        } },
        window.SP_REACT.createElement(DFL.Spinner, { width: size, height: size, style: {
                width: `${size}px`,
                height: `${size}px`,
                maxWidth: `${size}px`,
                maxHeight: `${size}px`,
                display: "block",
                flex: `0 0 ${size}px`,
            } })));
}
function makoDialogButtonStyle(isFocused, variant = "normal") {
    const danger = variant === "danger";
    const focusColor = danger ? "#e36a79" : "#52d5e8";
    return {
        color: danger ? "#fff0f5" : "#eefbfe",
        background: danger
            ? "linear-gradient(135deg, #3b1725 0%, #64253a 58%, #7d3048 100%)"
            : "linear-gradient(135deg, #071f31 0%, #0a4358 58%, #0b5967 100%)",
        border: danger
            ? "1px solid rgba(183, 82, 118, 0.62)"
            : "1px solid rgba(65, 158, 178, 0.62)",
        borderRadius: "4px",
        outline: isFocused ? `2px solid ${focusColor}` : "none",
        outlineOffset: "2px",
        boxShadow: isFocused
            ? danger
                ? "0 0 0 3px rgba(227, 106, 121, 0.2), 0 0 10px rgba(166, 48, 72, 0.34)"
                : "0 0 0 3px rgba(82, 213, 232, 0.2), 0 0 10px rgba(43, 142, 163, 0.32)"
            : "inset 0 1px 0 rgba(255, 255, 255, 0.08), 0 2px 5px rgba(0, 0, 0, 0.22)",
        transition: "background 120ms ease, box-shadow 120ms ease",
    };
}
function MakoButtonTheme() {
    return (window.SP_REACT.createElement("style", null, `
      .Mako_DialogButton:not(.disabled):not([disabled]):not([aria-disabled="true"]):hover,
      .Mako_DialogButton button:hover:not(:disabled) {
        background: linear-gradient(135deg, #092a40 0%, #0b5067 58%, #0d6875 100%) !important;
        border-color: rgba(79, 188, 209, 0.78) !important;
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.12), 0 0 9px rgba(39, 150, 171, 0.26) !important;
      }

      .Mako_DialogButton--danger:not(.disabled):not([disabled]):not([aria-disabled="true"]):hover,
      .Mako_DialogButton--danger button:hover:not(:disabled) {
        background: linear-gradient(135deg, #481b2c 0%, #732a43 58%, #913852 100%) !important;
        border-color: rgba(208, 102, 139, 0.78) !important;
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.1), 0 0 9px rgba(170, 57, 98, 0.24) !important;
      }

      .Mako_BrandButton button {
        color: #eefbfe !important;
        background: linear-gradient(135deg, #071f31 0%, #0a4358 58%, #0b5967 100%) !important;
        border: 1px solid rgba(65, 158, 178, 0.62) !important;
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.08), 0 2px 5px rgba(0, 0, 0, 0.22) !important;
        text-shadow: 0 1px 2px rgba(0, 13, 23, 0.72);
        transition: background 120ms ease, box-shadow 120ms ease, filter 120ms ease;
      }

      .Mako_BrandButton button:hover:not(:disabled) {
        background: linear-gradient(135deg, #092a40 0%, #0b5067 58%, #0d6875 100%) !important;
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.12), 0 0 9px rgba(39, 150, 171, 0.26) !important;
      }

      .Mako_BrandButton button:focus,
      .Mako_BrandButton button:focus-visible {
        outline: 2px solid #52d5e8 !important;
        outline-offset: 2px !important;
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.12), 0 0 0 3px rgba(82, 213, 232, 0.2), 0 0 10px rgba(43, 142, 163, 0.32) !important;
      }

      .Mako_BrandButton button:disabled {
        filter: saturate(0.4) brightness(0.68);
      }

      .Mako_BrandButton--danger button {
        background: linear-gradient(135deg, #3b1725 0%, #64253a 58%, #7d3048 100%) !important;
        border-color: rgba(183, 82, 118, 0.62) !important;
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.07), 0 2px 5px rgba(0, 0, 0, 0.24) !important;
      }

      .Mako_BrandButton--danger button:hover:not(:disabled) {
        background: linear-gradient(135deg, #481b2c 0%, #732a43 58%, #913852 100%) !important;
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.1), 0 0 9px rgba(170, 57, 98, 0.24) !important;
      }

      .Mako_BrandButton--danger button:focus,
      .Mako_BrandButton--danger button:focus-visible {
        outline: 2px solid #e36a79 !important;
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.1), 0 0 0 3px rgba(227, 106, 121, 0.2), 0 0 10px rgba(166, 48, 72, 0.34) !important;
      }
    `));
}

function MakoInstallCountdown({ durationMs, }) {
    return (window.SP_REACT.createElement("svg", { "aria-hidden": "true", width: "24", height: "24", viewBox: "0 0 24 24", style: { display: "block", transform: "rotate(-90deg)" } },
        window.SP_REACT.createElement("circle", { cx: "12", cy: "12", r: "9", fill: "none", stroke: "rgba(208, 138, 160, 0.24)", strokeWidth: "2.5" }),
        window.SP_REACT.createElement("circle", { cx: "12", cy: "12", r: "9", pathLength: "1", fill: "none", stroke: "#d08aa0", strokeWidth: "2.5", strokeLinecap: "round", strokeDasharray: "1", strokeDashoffset: "0" },
            window.SP_REACT.createElement("animate", { attributeName: "stroke-dashoffset", from: "0", to: "1", dur: `${durationMs}ms`, fill: "freeze" }))));
}
function MakoInstallCompletion() {
    return (window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "10px" } },
        window.SP_REACT.createElement(MakoInstallCountdown, { durationMs: MAKO_INSTALL_COMPLETION_DURATION_MS }),
        window.SP_REACT.createElement("div", { style: {
                display: "flex",
                flexDirection: "column",
                alignItems: "flex-start",
                gap: "2px",
            } },
            window.SP_REACT.createElement("div", { style: { fontWeight: 600 } }, t("TOAST_INSTALL_COMPLETE", "Installation Complete")),
            window.SP_REACT.createElement("div", { style: { fontSize: "12px", opacity: 0.82 } }, t("TOAST_INSTALL_COMPLETE_DESC", "Restarting your device is recommended.")))));
}

function InstallationButton({ isInstalled, isInstalling, isInstallCompletionVisible, isUninstalling, hostArchitectureSupported, onInstall, onUninstall, topMargin = "0" }) {
    const renderButtonContent = () => {
        if (isInstallCompletionVisible) {
            return window.SP_REACT.createElement(MakoInstallCompletion, null);
        }
        if (isInstalling) {
            return (window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px" } },
                window.SP_REACT.createElement(MakoCompactSpinner, null),
                window.SP_REACT.createElement("div", null, t("INSTALL_INSTALLING", "Installing MAKO Renderer..."))));
        }
        if (isUninstalling) {
            return (window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px" } },
                window.SP_REACT.createElement(MakoCompactSpinner, null),
                window.SP_REACT.createElement("div", null, t("INSTALL_UNINSTALLING", "Removing MAKO Renderer..."))));
        }
        if (isInstalled) {
            return (window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px" } },
                window.SP_REACT.createElement(FaTrash, null),
                window.SP_REACT.createElement("div", null, t("INSTALL_REMOVE_RENDERER", "Remove MAKO Renderer"))));
        }
        return (window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px" } },
            window.SP_REACT.createElement(FaDownload, null),
            window.SP_REACT.createElement("div", null, t("INSTALL_RENDERER", "Install MAKO Renderer"))));
    };
    return (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
        window.SP_REACT.createElement("div", { className: `Mako_BrandButton${isInstalled ? " Mako_BrandButton--danger" : ""}`, style: { marginTop: topMargin } },
            window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: isInstalled ? onUninstall : onInstall, disabled: isInstalling || isInstallCompletionVisible || isUninstalling || !hostArchitectureSupported }, renderButtonContent()))));
}

/**
 * Keeps one collapsible Decky section in local storage.
 *
 * Reading intentionally fails silently so damaged or unavailable browser
 * storage falls back to the product default. Writes retain the existing
 * warning because a storage failure should not make the controls unusable.
 */
function usePersistentCollapseState(storageKey, defaultCollapsed, warningLabel) {
    const [collapsed, setCollapsed] = SP_REACT.useState(() => {
        try {
            const saved = localStorage.getItem(storageKey);
            return saved !== null ? JSON.parse(saved) : defaultCollapsed;
        }
        catch {
            return defaultCollapsed;
        }
    });
    SP_REACT.useEffect(() => {
        try {
            localStorage.setItem(storageKey, JSON.stringify(collapsed));
        }
        catch (error) {
            console.warn(`Failed to save ${warningLabel} collapse state:`, error);
        }
    }, [collapsed, storageKey, warningLabel]);
    return [collapsed, setCollapsed];
}

const DEFAULT_CONFIGURATION$2 = getDefaults();
function adaptiveModeChanges(enabled) {
    return { adaptive: enabled };
}
function baseFpsCapChanges(value) {
    return {
        base_fps_cap: value,
        dynamic_cadence_recovery: false,
    };
}
function dynamicCadenceRecoveryChanges(enabled) {
    if (!enabled) {
        return { dynamic_cadence_recovery: false };
    }
    return {
        dynamic_cadence_recovery: true,
        adaptive_auto_base_fps_cap: false,
        base_fps_cap: 0,
    };
}
function isFractionalAdaptivePresetEnabled(config) {
    return (config.adaptive &&
        !(config.adaptive_auto_base_fps_cap ??
            DEFAULT_CONFIGURATION$2.adaptive_auto_base_fps_cap));
}
function fractionalAdaptivePresetChanges(enabled) {
    if (!enabled) {
        return {
            adaptive_auto_base_fps_cap: true,
            dynamic_cadence_recovery: false,
        };
    }
    return {
        frame_generation_enabled: true,
        adaptive: true,
        adaptive_auto_base_fps_cap: false,
        dynamic_cadence_recovery: false,
    };
}
function steadyBaseCapChanges(enabled) {
    return {
        adaptive_auto_base_fps_cap: enabled,
        dynamic_cadence_recovery: false,
    };
}

// THIS FILE IS AUTO GENERATED
function RiArrowDownSFill (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 24 24","fill":"currentColor"},"child":[{"tag":"path","attr":{"d":"M12 16L6 10H18L12 16Z"},"child":[]}]})(props);
}function RiArrowUpSFill (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 24 24","fill":"currentColor"},"child":[{"tag":"path","attr":{"d":"M12 8L18 14H6L12 8Z"},"child":[]}]})(props);
}function RiEditLine (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 24 24","fill":"currentColor"},"child":[{"tag":"path","attr":{"d":"M6.41421 15.89L16.5563 5.74785L15.1421 4.33363L5 14.4758V15.89H6.41421ZM7.24264 17.89H3V13.6473L14.435 2.21231C14.8256 1.82179 15.4587 1.82179 15.8492 2.21231L18.6777 5.04074C19.0682 5.43126 19.0682 6.06443 18.6777 6.45495L7.24264 17.89ZM3 19.89H21V21.89H3V19.89Z"},"child":[]}]})(props);
}function RiDeleteBinLine (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 24 24","fill":"currentColor"},"child":[{"tag":"path","attr":{"d":"M17 6H22V8H20V21C20 21.5523 19.5523 22 19 22H5C4.44772 22 4 21.5523 4 21V8H2V6H7V3C7 2.44772 7.44772 2 8 2H16C16.5523 2 17 2.44772 17 3V6ZM18 8H6V20H18V8ZM9 11H11V17H9V11ZM13 11H15V17H13V11ZM9 4V6H15V4H9Z"},"child":[]}]})(props);
}

function CollapseControl({ containerClassName, collapsed, onToggle, }) {
    return (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
        window.SP_REACT.createElement("div", { className: containerClassName, style: { marginTop: "2px", marginBottom: "4px" } },
            window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", bottomSeparator: "none", onClick: onToggle }, collapsed ? (window.SP_REACT.createElement(RiArrowDownSFill, { style: { transform: "translate(0, -13px)", fontSize: "1.5em" } })) : (window.SP_REACT.createElement(RiArrowUpSFill, { style: { transform: "translate(0, -12px)", fontSize: "1.5em" } }))))));
}

function AdvancedRenderingConfigurationGroup({ config, onConfigChange, onConfigUpdate, collapsed, onToggle, }) {
    const steadyBaseFpsCap = Math.max(ADAPTIVE_MINIMUM_BASE_FPS, config.target_fps / 2);
    const steadyBaseFpsCapLabel = Number.isInteger(steadyBaseFpsCap)
        ? steadyBaseFpsCap.toFixed(0)
        : steadyBaseFpsCap.toFixed(1);
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement(MakoSectionHeader, null, t("CONFIG_SECTION_TITLE", "Advanced Rendering Settings")),
        window.SP_REACT.createElement(CollapseControl, { containerClassName: "MAKO_ConfigCollapseButton_Container", collapsed: collapsed, onToggle: onToggle }),
        !collapsed && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.SliderField, { label: `${t("CONFIG_BASE_FPS_CAP", "Base FPS Cap")}${config.base_fps_cap > 0 ? ` (${config.base_fps_cap} FPS)` : ` (${t("CONFIG_BASE_FPS_CAP_OFF", "Off")})`}`, description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                        window.SP_REACT.createElement("div", null, t("CONFIG_BASE_FPS_CAP_DESC", "Caps real application frames before frame generation. Works with DirectX, OpenGL through Zink, and Vulkan.")),
                        config.adaptive && config.adaptive_auto_base_fps_cap ? (window.SP_REACT.createElement(MakoSettingRelationship, null, t("CONFIG_BASE_FPS_CAP_STEADY_RELATION", "Controlled by Steady Base Cap ({fps} FPS). Your manual value remains saved.", { fps: steadyBaseFpsCapLabel }))) : config.dynamic_cadence_recovery ? (window.SP_REACT.createElement(MakoSettingRelationship, null, t("CONFIG_BASE_FPS_CAP_RECOVERY_RELATION", "Changing this cap turns Dynamic Cadence Recovery off."))) : null), value: config.base_fps_cap, min: BASE_FPS_CAP_MIN, max: BASE_FPS_CAP_UI_MAX, step: 1, disabled: !config.frame_generation_enabled ||
                        (config.adaptive && config.adaptive_auto_base_fps_cap), onChange: (value) => onConfigUpdate(baseFpsCapChanges(value)) })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: t("CONFIG_DISABLE_MAKO_NEXT_LAUNCH", "Disable MAKO Renderer on Next Launch"), description: t("CONFIG_DISABLE_MAKO_NEXT_LAUNCH_DESC", "Troubleshooting only. Stops MAKO Renderer loading the next time the game starts. Use Frame Generation above to switch synthesis on or off."), checked: config.disable_mako, onChange: (value) => onConfigChange(DISABLE_MAKO, value) })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: t("CONFIG_FRAME_GENERATION_REFRESH_GUARD", "Auto-disable Frame Generation by Refresh Rate"), description: t("CONFIG_FRAME_GENERATION_REFRESH_GUARD_DESC", "Pauses frame generation when Gamescope confirms the current display is at or below the threshold, then resumes your selected mode above it. Does nothing when refresh feedback is unavailable."), bottomSeparator: config.frame_generation_refresh_threshold > 0
                        ? undefined
                        : "none", checked: config.frame_generation_refresh_threshold > 0, onChange: (value) => onConfigChange(FRAME_GENERATION_REFRESH_THRESHOLD, value ? FRAME_GENERATION_REFRESH_THRESHOLD_PRESET : 0) })),
            config.frame_generation_refresh_threshold > 0 && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.SliderField, { label: `${t("CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD", "Refresh Rate Threshold")} (${config.frame_generation_refresh_threshold} Hz)`, description: t("CONFIG_FRAME_GENERATION_REFRESH_THRESHOLD_DESC", "Choose the highest refresh rate where frame generation should remain paused."), value: config.frame_generation_refresh_threshold, min: FRAME_GENERATION_REFRESH_THRESHOLD_UI_MIN, max: FRAME_GENERATION_REFRESH_THRESHOLD_MAX, step: 1, onChange: (value) => onConfigChange(FRAME_GENERATION_REFRESH_THRESHOLD, value) })))))));
}

function CompatibilityConfigurationGroup({ config, onConfigChange, onConfigUpdate, collapsed, onToggle, }) {
    const cadenceProbeInterval = config.dynamic_cadence_probe_interval_seconds;
    const cadenceProbeIntervalValues = DYNAMIC_CADENCE_PROBE_INTERVAL_SECONDS_VALUES.includes(cadenceProbeInterval)
        ? [...DYNAMIC_CADENCE_PROBE_INTERVAL_SECONDS_VALUES]
        : [
            ...DYNAMIC_CADENCE_PROBE_INTERVAL_SECONDS_VALUES,
            cadenceProbeInterval,
        ].sort((left, right) => left - right);
    const cadenceProbeIntervalOptions = cadenceProbeIntervalValues.map((value) => ({ data: value, label: `${value}s` }));
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement(MakoSectionHeader, null, t("CONFIG_WORKAROUNDS_TITLE", "Compatibility Settings")),
        window.SP_REACT.createElement(CollapseControl, { containerClassName: "MAKO_WorkaroundsCollapseButton_Container", collapsed: collapsed, onToggle: onToggle }),
        !collapsed && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: t("CONFIG_DISABLE_HDR_EXPOSURE", "Disable HDR"), description: t("CONFIG_DISABLE_HDR_EXPOSURE_DESC", "HDR is unavailable in this release. This required setting keeps the stable SDR path active."), checked: true, disabled: true, onChange: () => undefined })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: t("DYNAMIC_CADENCE_RECOVERY", "Dynamic Cadence Recovery"), description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                        window.SP_REACT.createElement("div", null, t("DYNAMIC_CADENCE_RECOVERY_DESC", "Helps games and emulators that switch native rates, such as 30 FPS gameplay and 60 FPS menus. It periodically checks for a rate change and recovers the correct cadence, but each check can briefly affect pacing. Enable it only for affected games.")),
                        window.SP_REACT.createElement(MakoSettingRelationship, null, t("DYNAMIC_CADENCE_RECOVERY_RELATION", "Turning this on disables Steady Base Cap and Base FPS Cap. Changing either cap later turns Recovery off."))), checked: config.dynamic_cadence_recovery, onChange: (value) => onConfigUpdate(dynamicCadenceRecoveryChanges(value)) })),
            config.dynamic_cadence_recovery && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.Field, { label: t("DYNAMIC_CADENCE_PROBE_INTERVAL", "Cadence Probe Interval"), description: window.SP_REACT.createElement("span", { style: { display: "block", paddingBottom: "6px" } }, t("DYNAMIC_CADENCE_PROBE_INTERVAL_DESC", "How often Recovery tests the native frame rate. 0.1 seconds is aggressive and may cause frequent brief pacing hitches; 2 seconds is the default, while 3 seconds checks least often. Test per game.")), childrenLayout: "below", childrenContainerWidth: "max" },
                    window.SP_REACT.createElement(DFL.Dropdown, { rgOptions: cadenceProbeIntervalOptions, selectedOption: cadenceProbeInterval, onChange: (option) => onConfigChange(DYNAMIC_CADENCE_PROBE_INTERVAL_SECONDS, Number(option.data)) })))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: window.SP_REACT.createElement(MakoRestartLabel, { label: t("CONFIG_GAMESCOPE_WSI_COMPATIBILITY", "Gamescope WSI (Restart)") }), description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                        window.SP_REACT.createElement("div", null, t("CONFIG_GAMESCOPE_WSI_COMPATIBILITY_DESC", "May reduce coloured or pixelated motion artifacts in some games by using Gamescope's presentation path. Scaling enables it automatically. For FG-only profiles, enable it only for affected games.")),
                        !config.scaling_enabled && (window.SP_REACT.createElement(MakoInlineTip, { tone: "warning" }, t("CONFIG_GAMESCOPE_WSI_COMPATIBILITY_WARNING", "This compatibility path is limited to supported 64-bit host launches. Leave it off when the game does not need it, as it may impact performance.")))), checked: config.scaling_enabled || config.gamescope_wsi_compatibility, disabled: config.scaling_enabled, onChange: (value) => onConfigChange(GAMESCOPE_WSI_COMPATIBILITY, value) })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: window.SP_REACT.createElement(MakoRestartLabel, { label: t("CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY", "Game Swapchain Images (Restart)") }), description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                        window.SP_REACT.createElement("div", null, t("CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_DESC", "Can fix games that fail to start with Frame Generation by preserving the game's requested swapchain image minimum. Enable it only for affected games.")),
                        window.SP_REACT.createElement(MakoInlineTip, { tone: "warning" }, t("CONFIG_SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY_WARNING", "Generated frames may be skipped when the compositor has no spare image, which can reduce smoothness or performance under pressure."))), checked: config.swapchain_image_count_compatibility, onChange: (value) => onConfigChange(SWAPCHAIN_IMAGE_COUNT_COMPATIBILITY, value) })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: window.SP_REACT.createElement(MakoRestartLabel, { label: t("CONFIG_DISABLE_STEAMDECK_MODE", "Disable Steam Deck Mode (Restart)") }), description: t("CONFIG_DISABLE_STEAMDECK_MODE_DESC", "Disables Steam Deck mode. Unlocks hidden settings in some games."), checked: config.disable_steamdeck_mode, onChange: (value) => onConfigChange(DISABLE_STEAMDECK_MODE, value) })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: window.SP_REACT.createElement(MakoRestartLabel, { label: t("CONFIG_ENABLE_ZINK", "Enable Zink for OpenGL Games (Restart)") }), description: t("CONFIG_ENABLE_ZINK_DESC", "Uses the Vulkan-based OpenGL implementation for OpenGL games. May cause crashes or freezes in some games."), checked: config.enable_zink, onChange: (value) => onConfigChange(ENABLE_ZINK, value) })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: window.SP_REACT.createElement(MakoRestartLabel, { label: t("CONFIG_FORCE_ALSA_AUDIO", "Force ALSA Audio (Restart)") }), description: t("CONFIG_FORCE_ALSA_AUDIO_DESC", "May improve compatibility with modes such as Zink and reduce audio stuttering or sudden loud sounds. Disable to restore normal audio defaults."), bottomSeparator: "none", checked: config.force_alsa_audio, onChange: (value) => onConfigChange(FORCE_ALSA_AUDIO, value) }))))));
}

function ExternalToolsConfigurationGroup({ config, onConfigChange, collapsed, onToggle, }) {
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement(MakoSectionHeader, null, t("CONFIG_EXTERNAL_TOOLS_TITLE", "External Tools")),
        window.SP_REACT.createElement(CollapseControl, { containerClassName: "MAKO_ExternalToolsCollapseButton_Container", collapsed: collapsed, onToggle: onToggle }),
        !collapsed && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: window.SP_REACT.createElement(MakoRestartLabel, { label: t("CONFIG_ENABLE_MANGOHUD", "Enable MangoHud (Restart)") }), description: t("CONFIG_ENABLE_MANGOHUD_DESC", "Uses the host-installed MangoHud and your existing MangoHud configuration. See the expert guide for per-game environment overrides."), checked: config.external_vulkan_layer === EXTERNAL_VULKAN_LAYER_MANGOHUD, onChange: (value) => onConfigChange(EXTERNAL_VULKAN_LAYER, value
                        ? EXTERNAL_VULKAN_LAYER_MANGOHUD
                        : EXTERNAL_VULKAN_LAYER_NONE) })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: window.SP_REACT.createElement(MakoExperimentalSettingLabel, { label: t("CONFIG_ENABLE_VKBASALT", "Enable vkBasalt (Restart)"), badgeLabel: t("EXPERIMENTAL_LABEL", "Experimental") }), description: t("CONFIG_ENABLE_VKBASALT_DESC", "Keep it off unless you are testing vkBasalt with this game. Uses a host-installed vkBasalt layer for this profile. The initial test lane is limited to 64-bit native Vulkan or Proton games launched directly by Steam on SteamOS."), bottomSeparator: "none", checked: config.external_vulkan_layer === EXTERNAL_VULKAN_LAYER_VKBASALT, onChange: (value) => onConfigChange(EXTERNAL_VULKAN_LAYER, value
                        ? EXTERNAL_VULKAN_LAYER_VKBASALT
                        : EXTERNAL_VULKAN_LAYER_NONE) }))))));
}

function ManualOverridesConfigurationGroup({ config, onConfigChange, collapsed, onToggle, }) {
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement(MakoSectionHeader, null, t("CONFIG_MANUAL_OVERRIDES_TITLE", "Manual Overrides")),
        window.SP_REACT.createElement(CollapseControl, { containerClassName: "MAKO_ManualOverridesCollapseButton_Container", collapsed: collapsed, onToggle: onToggle }),
        !collapsed && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement("div", { className: "MAKO_ManualOverrideFields" },
                window.SP_REACT.createElement(DFL.TextField, { label: window.SP_REACT.createElement(MakoRestartLabel, { label: t("CONFIG_DLL_PATH", "Lossless.dll Path (Restart)") }), description: t("CONFIG_DLL_PATH_DESC", "Optional full path to Lossless.dll. Leave blank to use MAKO Renderer automatic discovery."), value: config.dll, onChange: (event) => onConfigChange(DLL, event.currentTarget.value) }),
                window.SP_REACT.createElement(DFL.TextField, { label: window.SP_REACT.createElement(MakoRestartLabel, { label: t("CONFIG_GPU", "GPU (Restart)") }), description: window.SP_REACT.createElement("span", { className: "MAKO_GpuDescription" }, t("CONFIG_GPU_DESC", "Optional GPU name, vendor:device ID, or PCI bus ID. Restart the game after changing it.")), value: config.gpu, onChange: (event) => onConfigChange(GPU, event.currentTarget.value) }),
                window.SP_REACT.createElement(DFL.TextField, { label: t("CONFIG_ACTIVE_IN", "Matched Processes"), description: t("CONFIG_ACTIVE_IN_DESC", "Executable or process names separated by commas. Running-game capture fills these automatically; edit them only when a launcher or emulator needs an additional process alias."), value: config.active_in, onChange: (event) => onConfigChange(ACTIVE_IN, event.currentTarget.value) }))))));
}

const WORKAROUNDS_COLLAPSED_KEY = "mako-workarounds-collapsed";
const CONFIG_COLLAPSED_KEY = "mako-config-collapsed";
const EXTERNAL_TOOLS_COLLAPSED_KEY = "mako-external-tools-collapsed";
const MANUAL_OVERRIDES_COLLAPSED_KEY = "mako-manual-overrides-collapsed";
const collapseControlStyles = `
  .MAKO_ConfigCollapseButton_Container > div > div > div > button,
  .MAKO_ConfigCollapseButton_Container > div > div > div > div > button,
  .MAKO_WorkaroundsCollapseButton_Container > div > div > div > button,
  .MAKO_ExternalToolsCollapseButton_Container > div > div > div > button,
  .MAKO_ManualOverridesCollapseButton_Container > div > div > div > button {
    height: 10px !important;
  }
  .MAKO_WorkaroundsCollapseButton_Container > div > div > div > div > button,
  .MAKO_ExternalToolsCollapseButton_Container > div > div > div > div > button,
  .MAKO_ManualOverridesCollapseButton_Container > div > div > div > div > button {
    height: 10px !important;
  }
`;
function FrameGenerationConfigurationSection({ config, onConfigChange, onConfigUpdate, initiallyCollapsed = true, }) {
    const [configCollapsed, setConfigCollapsed] = usePersistentCollapseState(CONFIG_COLLAPSED_KEY, initiallyCollapsed, "frame generation advanced settings");
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement("style", null, collapseControlStyles),
        window.SP_REACT.createElement(AdvancedRenderingConfigurationGroup, { config: config, onConfigChange: onConfigChange, onConfigUpdate: onConfigUpdate, collapsed: configCollapsed, onToggle: () => setConfigCollapsed(!configCollapsed) })));
}
function ConfigurationSection({ config, onConfigChange, onConfigUpdate, includeAdvancedRendering = true, }) {
    const [workaroundsCollapsed, setWorkaroundsCollapsed] = usePersistentCollapseState(WORKAROUNDS_COLLAPSED_KEY, true, "workarounds");
    const [manualOverridesCollapsed, setManualOverridesCollapsed] = usePersistentCollapseState(MANUAL_OVERRIDES_COLLAPSED_KEY, true, "manual overrides");
    const [externalToolsCollapsed, setExternalToolsCollapsed] = usePersistentCollapseState(EXTERNAL_TOOLS_COLLAPSED_KEY, true, "external tools");
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement("style", null, `${collapseControlStyles}
        .MAKO_ManualOverrideFields {
          display: flex;
          flex-direction: column;
          gap: 12px;
          width: 100%;
          min-width: 0;
          margin: 10px 0 0;
        }
        .MAKO_ManualOverrideFields > * {
          margin-bottom: 0 !important;
        }
        .MAKO_ManualOverrideFields > * + * {
          margin-top: 0 !important;
        }
        .MAKO_GpuDescription {
          display: block;
          padding-bottom: 10px;
        }
      `),
        includeAdvancedRendering && (window.SP_REACT.createElement(FrameGenerationConfigurationSection, { config: config, onConfigChange: onConfigChange, onConfigUpdate: onConfigUpdate, initiallyCollapsed: false })),
        window.SP_REACT.createElement(CompatibilityConfigurationGroup, { config: config, onConfigChange: onConfigChange, onConfigUpdate: onConfigUpdate, collapsed: workaroundsCollapsed, onToggle: () => setWorkaroundsCollapsed(!workaroundsCollapsed) }),
        window.SP_REACT.createElement(ExternalToolsConfigurationGroup, { config: config, onConfigChange: onConfigChange, collapsed: externalToolsCollapsed, onToggle: () => setExternalToolsCollapsed(!externalToolsCollapsed) }),
        window.SP_REACT.createElement(ManualOverridesConfigurationGroup, { config: config, onConfigChange: onConfigChange, collapsed: manualOverridesCollapsed, onToggle: () => setManualOverridesCollapsed(!manualOverridesCollapsed) })));
}

const DEFAULT_CONFIGURATION$1 = getDefaults();
function effectiveScalingMethod(config) {
    return config.scaling_enabled && config.ultra_performance
        ? SCALING_METHOD_LS1_PERFORMANCE
        : config.scaling_method;
}
function ultraPerformanceChanges(enabled) {
    return {
        [ULTRA_PERFORMANCE]: enabled,
        [FLOW_SCALE]: enabled
            ? ULTRA_PERFORMANCE_FLOW_SCALE
            : DEFAULT_CONFIGURATION$1.flow_scale,
        [PERFORMANCE_MODE]: enabled,
        [ALLOW_FP16]: DEFAULT_CONFIGURATION$1.allow_fp16,
    };
}

function useScalingModelStatus(config, enabled) {
    const method = effectiveScalingMethod(config);
    const applicable = enabled &&
        config.scaling_enabled &&
        (method === SCALING_METHOD_LS1 || method === SCALING_METHOD_LS1_PERFORMANCE);
    const key = JSON.stringify([config.dll, method, config.scaling_sharpness]);
    const [result, setResult] = SP_REACT.useState(null);
    SP_REACT.useEffect(() => {
        if (!applicable)
            return;
        let active = true;
        let timer;
        const refresh = async () => {
            let compatible = null;
            try {
                const status = await checkScalingModel(config.dll, method, config.scaling_sharpness);
                if (typeof status.compatible === "boolean")
                    compatible = status.compatible;
            }
            catch {
                // A missing/older backend is not evidence of model incompatibility.
            }
            if (active) {
                setResult({ key, compatible });
                timer = setTimeout(refresh, SCALING_MODEL_POLL_INTERVAL_MS);
            }
        };
        timer = setTimeout(refresh, SCALING_MODEL_DEBOUNCE_MS);
        return () => {
            active = false;
            clearTimeout(timer);
        };
    }, [applicable, key, config.dll, method, config.scaling_sharpness]);
    return applicable && result?.key === key ? result.compatible : null;
}

/**
 * Owns the editable profile list and its backend transactions.
 *
 * This is deliberately separate from runtime profile synchronisation: the
 * offline dropdown selects a profile to edit and must never become a runtime
 * override. A running game is captured explicitly and otherwise locks the
 * editor to the profile selected by the runtime session.
 */
function useProfileEditorModel({ editingProfile, onProfileChange, mainRunningApp, }) {
    const [profiles, setProfiles] = SP_REACT.useState([]);
    const [profileDetails, setProfileDetails] = SP_REACT.useState([]);
    const [selectedProfile, setSelectedProfile] = SP_REACT.useState(editingProfile || DEFAULT_PROFILE_NAME);
    const editingProfileRef = SP_REACT.useRef(editingProfile || DEFAULT_PROFILE_NAME);
    const [isLoading, setIsLoading] = SP_REACT.useState(false);
    const loadProfiles = async (preferredProfile) => {
        try {
            const result = await getProfiles();
            if (!result.success || !result.profiles) {
                throw new Error(result.error || t("PROFILE_UNKNOWN_ERROR", "Unknown error"));
            }
            setProfiles(result.profiles);
            setProfileDetails(result.profile_details || []);
            const resolvedProfile = result.profiles.includes(editingProfileRef.current)
                ? editingProfileRef.current
                : preferredProfile && result.profiles.includes(preferredProfile)
                    ? preferredProfile
                    : result.current_profile &&
                        result.profiles.includes(result.current_profile)
                        ? result.current_profile
                        : result.profiles.includes(DEFAULT_PROFILE_NAME)
                            ? DEFAULT_PROFILE_NAME
                            : result.profiles[0];
            if (resolvedProfile)
                setSelectedProfile(resolvedProfile);
            return resolvedProfile || DEFAULT_PROFILE_NAME;
        }
        catch (error) {
            console.error("Error loading profiles:", error);
            showErrorToast(t("PROFILE_LOAD_FAILED", "Failed to load profiles"), String(error));
            return DEFAULT_PROFILE_NAME;
        }
    };
    SP_REACT.useEffect(() => {
        void loadProfiles(editingProfile || DEFAULT_PROFILE_NAME);
    }, []);
    SP_REACT.useEffect(() => {
        if (editingProfile) {
            editingProfileRef.current = editingProfile;
            setSelectedProfile(editingProfile);
        }
    }, [editingProfile]);
    const selectedDetails = SP_REACT.useMemo(() => profileDetails.find((profile) => profile.profile_name === selectedProfile), [profileDetails, selectedProfile]);
    const runningProfile = SP_REACT.useMemo(() => profileDetails.find((profile) => profile.steam_app_id &&
        profile.steam_app_id === String(mainRunningApp?.appid || "")), [profileDetails, mainRunningApp]);
    const notifyProfileChanged = async (profileName) => {
        const resolvedProfile = await loadProfiles(profileName);
        await onProfileChange?.(resolvedProfile || profileName);
        return resolvedProfile;
    };
    const switchProfile = async (profileName) => {
        setIsLoading(true);
        try {
            if (!profiles.includes(profileName)) {
                throw new Error(`Profile '${profileName}' does not exist`);
            }
            editingProfileRef.current = profileName;
            setSelectedProfile(profileName);
            await onProfileChange?.(profileName);
        }
        catch (error) {
            showErrorToast(t("PROFILE_SWITCH_FAILED", "Failed to switch profile"), String(error));
        }
        finally {
            setIsLoading(false);
        }
    };
    const saveRunningGame = async () => {
        if (!mainRunningApp)
            return;
        setIsLoading(true);
        try {
            const result = await captureGameProfile(String(mainRunningApp.appid), mainRunningApp.display_name, selectedProfile);
            if (!result.success || !result.profile_name) {
                throw new Error(result.error || "Unknown error");
            }
            showSuccessToast(t("PROFILE_GAME_SAVED", "Game profile saved"), result.profile?.processes?.length
                ? `${mainRunningApp.display_name}: ${result.profile.processes.join(", ")}`
                : mainRunningApp.display_name);
            editingProfileRef.current = result.profile_name;
            setSelectedProfile(result.profile_name);
            await notifyProfileChanged(result.profile_name);
        }
        catch (error) {
            showErrorToast(t("PROFILE_GAME_SAVE_FAILED", "Could not save game profile"), String(error));
        }
        finally {
            setIsLoading(false);
        }
    };
    const renameSelectedProfile = async (newName) => {
        setIsLoading(true);
        try {
            const result = await renameProfile(selectedProfile, newName);
            if (!result.success || !result.profile_name) {
                throw new Error(result.error || "Unknown error");
            }
            editingProfileRef.current = result.profile_name;
            setSelectedProfile(result.profile_name);
            await notifyProfileChanged(result.profile_name);
            showSuccessToast(t("PROFILE_RENAMED", "Profile renamed"), newName);
        }
        catch (error) {
            showErrorToast(t("PROFILE_RENAME_FAILED", "Failed to rename profile"), String(error));
        }
        finally {
            setIsLoading(false);
        }
    };
    const deleteSelectedProfile = async () => {
        setIsLoading(true);
        try {
            const deletedName = selectedDetails?.display_name || selectedProfile;
            const result = await deleteProfile(selectedProfile);
            if (!result.success)
                throw new Error(result.error || "Unknown error");
            const nextProfile = result.current_profile || DEFAULT_PROFILE_NAME;
            editingProfileRef.current = nextProfile;
            setSelectedProfile(nextProfile);
            await notifyProfileChanged(nextProfile);
            showSuccessToast(t("PROFILE_DELETED", "Profile deleted"), deletedName);
        }
        catch (error) {
            showErrorToast(t("PROFILE_DELETE_FAILED", "Failed to delete profile"), String(error));
        }
        finally {
            setIsLoading(false);
        }
    };
    const profileOptions = profiles.map((profileName) => {
        const detail = profileDetails.find((item) => item.profile_name === profileName);
        return {
            data: profileName,
            label: detail?.display_name ||
                (profileName === DEFAULT_PROFILE_NAME
                    ? t("PROFILE_DEFAULT", "Default")
                    : profileName),
        };
    });
    return {
        selectedProfile,
        selectedDetails,
        runningProfile,
        profileOptions,
        isLoading,
        switchProfile,
        saveRunningGame,
        renameSelectedProfile,
        deleteSelectedProfile,
    };
}

const PROFILES_COLLAPSED_KEY = "mako-profiles-collapsed";
function TextInputModal({ title, description, defaultValue = "", okText = "OK", cancelText = "Cancel", onOK, closeModal, }) {
    const [value, setValue] = SP_REACT.useState(defaultValue);
    const handleOK = () => {
        if (value.trim()) {
            onOK(value.trim());
            closeModal?.();
        }
    };
    return (window.SP_REACT.createElement(DFL.ModalRoot, null,
        window.SP_REACT.createElement("div", { style: { padding: "16px", minWidth: "400px" } },
            window.SP_REACT.createElement("h2", { style: { marginBottom: "16px" } }, title),
            window.SP_REACT.createElement("p", { style: { marginBottom: "24px" } }, description),
            window.SP_REACT.createElement(DFL.Field, { label: t("PROFILE_NAME_LABEL", "Name"), childrenLayout: "below", childrenContainerWidth: "max" },
                window.SP_REACT.createElement(DFL.TextField, { value: value, onChange: (event) => setValue(event?.target?.value || ""), style: { width: "100%" } })),
            window.SP_REACT.createElement(MakoFocusable, { style: {
                    display: "flex",
                    justifyContent: "flex-end",
                    gap: "8px",
                    marginTop: "24px",
                }, "flow-children": "row" },
                window.SP_REACT.createElement(DFL.DialogButton, { onClick: closeModal }, cancelText),
                window.SP_REACT.createElement(DFL.DialogButton, { onClick: handleOK, disabled: !value.trim() }, okText)))));
}
function ProfileManagement({ editingProfile, onProfileChange, mainRunningApp, topMargin, }) {
    const [focusedAction, setFocusedAction] = SP_REACT.useState(null);
    const [profilesCollapsed, setProfilesCollapsed] = usePersistentCollapseState(PROFILES_COLLAPSED_KEY, false, "profiles");
    const { selectedProfile, selectedDetails, runningProfile, profileOptions, isLoading, switchProfile, saveRunningGame, renameSelectedProfile, deleteSelectedProfile, } = useProfileEditorModel({
        editingProfile,
        onProfileChange,
        mainRunningApp,
    });
    const showRenameProfile = () => {
        if (selectedProfile === DEFAULT_PROFILE_NAME)
            return;
        DFL.showModal(window.SP_REACT.createElement(TextInputModal, { title: t("PROFILE_RENAME_TITLE", "Rename Profile"), description: t("PROFILE_RENAME_DESC_PREFIX", "Choose a friendly name for this game or process profile."), defaultValue: selectedDetails?.display_name || selectedProfile, okText: t("PROFILE_RENAME_BTN", "Rename"), cancelText: t("PROFILE_CANCEL_BTN", "Cancel"), onOK: (name) => void renameSelectedProfile(name) }));
    };
    const showDeleteProfile = () => {
        if (selectedProfile === DEFAULT_PROFILE_NAME)
            return;
        DFL.showModal(window.SP_REACT.createElement(DFL.ConfirmModal, { strTitle: t("PROFILE_DELETE_TITLE", "Delete Game / Process Profile"), strDescription: t("PROFILE_DELETE_CONFIRM", 'Delete "{profile}" and all of its saved settings?', { profile: selectedDetails?.display_name || selectedProfile }), strOKButtonText: t("PROFILE_DELETE_BTN", "Delete"), strCancelButtonText: t("PROFILE_CANCEL_BTN", "Cancel"), onOK: () => void deleteSelectedProfile() }));
    };
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement("style", null, `
        .Mako_ProfilesCollapseButton_Container > div > div > div > button,
        .Mako_ProfilesCollapseButton_Container > div > div > div > div > button {
          height: 10px !important;
        }
      `),
        window.SP_REACT.createElement(MakoSectionHeader, { topMargin: topMargin }, t("PROFILE_SECTION_TITLE", "Game / Process Profiles")),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement("div", { style: {
                    fontSize: "11px",
                    lineHeight: "1.35",
                    color: "#b8c5d6",
                    marginBottom: "4px",
                } }, t("PROFILE_HELP", "Start a game and save its process once. MAKO selects saved profiles automatically; outside a game, the dropdown only chooses which profile to edit."))),
        mainRunningApp && !runningProfile && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement("div", { className: "Mako_BrandButton" },
                window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: () => void saveRunningGame(), disabled: isLoading }, t("PROFILE_SAVE_RUNNING", "Save profile for {game}", {
                    game: mainRunningApp.display_name,
                }))))),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement("div", { className: "Mako_ProfilesCollapseButton_Container", style: { marginTop: "2px", marginBottom: "4px" } },
                window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", bottomSeparator: "none", onClick: () => setProfilesCollapsed(!profilesCollapsed) }, profilesCollapsed ? (window.SP_REACT.createElement(RiArrowDownSFill, { style: { transform: "translate(0, -13px)", fontSize: "1.5em" } })) : (window.SP_REACT.createElement(RiArrowUpSFill, { style: { transform: "translate(0, -12px)", fontSize: "1.5em" } }))))),
        !profilesCollapsed && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.Field, { label: t("PROFILE_SAVED_LABEL", "Saved profile"), childrenLayout: "below", childrenContainerWidth: "max", bottomSeparator: "none" },
                    window.SP_REACT.createElement(DFL.Dropdown, { rgOptions: profileOptions, selectedOption: selectedProfile, onChange: (option) => void switchProfile(String(option.data)), disabled: isLoading || !!mainRunningApp }))),
            selectedDetails && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement("div", { style: {
                        width: "100%",
                        padding: "6px 8px",
                        boxSizing: "border-box",
                        borderRadius: "4px",
                        background: "rgba(255,255,255,0.06)",
                        color: "#c8d3df",
                        fontSize: "10px",
                        lineHeight: "1.35",
                        overflowWrap: "anywhere",
                    } },
                    window.SP_REACT.createElement("div", null, selectedDetails.kind === PROFILE_KIND_DEFAULT
                        ? t("PROFILE_DETAIL_DEFAULT", "Open a game to save its profile")
                        : selectedDetails.kind === PROFILE_KIND_GAME
                            ? t("PROFILE_DETAIL_GAME", "Saved game")
                            : t("PROFILE_DETAIL_PROCESS", "Saved process")),
                    selectedDetails.steam_app_id && (window.SP_REACT.createElement("div", null, t("PROFILE_STEAM_APP_ID", "Steam app ID: {app_id}", {
                        app_id: selectedDetails.steam_app_id,
                    }))),
                    selectedDetails.kind !== PROFILE_KIND_DEFAULT && (window.SP_REACT.createElement("div", null, selectedDetails.processes.length
                        ? t("PROFILE_PROCESSES", "Processes: {processes}", {
                            processes: selectedDetails.processes.join(", "),
                        })
                        : t("PROFILE_PROCESSES_EMPTY", "Processes: enter one in Matched Processes below"))),
                    mainRunningApp && (window.SP_REACT.createElement("div", { style: { marginTop: "4px", color: "#d9b98c" } }, t("PROFILE_MANAGE_WHEN_IDLE", "Close the running game to rename or delete profiles.")))))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(MakoSectionTail, null,
                    window.SP_REACT.createElement(MakoFocusable, { style: {
                            display: "flex",
                            flexDirection: "column",
                            alignItems: "stretch",
                            gap: "6px",
                            width: "100%",
                            marginTop: "6px",
                        }, "flow-children": "column", noFocusRing: true },
                        window.SP_REACT.createElement(DFL.DialogButton, { className: "Mako_DialogButton", style: {
                                width: "100%",
                                minWidth: 0,
                                height: "34px",
                                display: "flex",
                                alignItems: "center",
                                justifyContent: "center",
                                gap: "6px",
                                padding: "4px 8px",
                                fontSize: "12px",
                                ...makoDialogButtonStyle(focusedAction === "edit"),
                            }, onClick: showRenameProfile, onGamepadFocus: () => setFocusedAction("edit"), onGamepadBlur: () => setFocusedAction(null), disabled: isLoading ||
                                selectedProfile === DEFAULT_PROFILE_NAME ||
                                !!mainRunningApp },
                            window.SP_REACT.createElement(RiEditLine, { size: 16 }),
                            window.SP_REACT.createElement("span", null, t("PROFILE_RENAME_BTN", "Rename"))),
                        window.SP_REACT.createElement(DFL.DialogButton, { className: "Mako_DialogButton Mako_DialogButton--danger", style: {
                                width: "100%",
                                minWidth: 0,
                                height: "34px",
                                display: "flex",
                                alignItems: "center",
                                justifyContent: "center",
                                gap: "6px",
                                padding: "4px 8px",
                                fontSize: "12px",
                                ...makoDialogButtonStyle(focusedAction === "delete", "danger"),
                            }, onClick: showDeleteProfile, onGamepadFocus: () => setFocusedAction("delete"), onGamepadBlur: () => setFocusedAction(null), disabled: isLoading ||
                                selectedProfile === DEFAULT_PROFILE_NAME ||
                                !!mainRunningApp },
                            window.SP_REACT.createElement(RiDeleteBinLine, { size: 16 }),
                            window.SP_REACT.createElement("span", null, t("PROFILE_DELETE_BTN", "Delete"))))))))));
}

/**
 * Clipboard utilities for reliable copy operations across different environments
 */
/**
 * Reliably copy text to clipboard using multiple fallback methods
 * This is especially important in gaming mode where clipboard APIs may behave differently
 */
async function copyToClipboard(text) {
    const tempInput = document.createElement('input');
    tempInput.value = text;
    tempInput.style.position = 'absolute';
    tempInput.style.left = '-9999px';
    document.body.appendChild(tempInput);
    try {
        tempInput.focus();
        tempInput.select();
        let copySuccess = false;
        try {
            if (document.execCommand('copy')) {
                copySuccess = true;
            }
        }
        catch (e) {
            try {
                await navigator.clipboard.writeText(text);
                copySuccess = true;
            }
            catch (clipboardError) {
                console.error('Both copy methods failed:', e, clipboardError);
            }
        }
        return copySuccess;
    }
    finally {
        document.body.removeChild(tempInput);
    }
}
/**
 * Verify that text was successfully copied to clipboard
 */
async function verifyCopy(expectedText) {
    try {
        const readBack = await navigator.clipboard.readText();
        return readBack === expectedText;
    }
    catch (e) {
        return true;
    }
}
/**
 * Copy text with verification and return success status
 */
async function copyWithVerification(text) {
    const copySuccess = await copyToClipboard(text);
    if (!copySuccess) {
        return { success: false, verified: false };
    }
    const verified = await verifyCopy(text);
    return { success: true, verified };
}

function useClipboardFeedback(getText) {
    const [isLoading, setIsLoading] = SP_REACT.useState(false);
    const [showSuccess, setShowSuccess] = SP_REACT.useState(false);
    SP_REACT.useEffect(() => {
        if (!showSuccess) {
            return undefined;
        }
        const timer = setTimeout(() => setShowSuccess(false), CLIPBOARD_SUCCESS_DURATION_MS);
        return () => clearTimeout(timer);
    }, [showSuccess]);
    const copyToClipboard = async () => {
        if (isLoading || showSuccess) {
            return;
        }
        setIsLoading(true);
        try {
            const text = await getText();
            const { success, verified } = await copyWithVerification(text);
            if (!success) {
                showClipboardErrorToast();
                return;
            }
            setShowSuccess(true);
            if (!verified) {
                console.log("Copy verification failed but copy likely worked");
            }
        }
        catch {
            showClipboardErrorToast();
        }
        finally {
            setIsLoading(false);
        }
    };
    return { isLoading, showSuccess, copyToClipboard };
}

function SmartClipboardButton() {
    const getLaunchOptionText = async () => {
        try {
            const result = await getLaunchOption();
            return result.launch_option || DEFAULT_STEAM_LAUNCH_OPTION;
        }
        catch (error) {
            return DEFAULT_STEAM_LAUNCH_OPTION;
        }
    };
    const { isLoading, showSuccess, copyToClipboard } = useClipboardFeedback(getLaunchOptionText);
    return (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
        window.SP_REACT.createElement("div", { className: "Mako_BrandButton", style: { marginTop: "16px" } },
            window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", bottomSeparator: "none", onClick: copyToClipboard, disabled: isLoading || showSuccess },
                window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px" } },
                    showSuccess ? (window.SP_REACT.createElement(FaCheck, { style: { color: "#7dffac" } })) : isLoading ? (window.SP_REACT.createElement(FaClipboard, { style: {
                            animation: "pulse 1s ease-in-out infinite",
                            opacity: 0.7,
                        } })) : (window.SP_REACT.createElement(FaClipboard, null)),
                    window.SP_REACT.createElement("div", { style: {
                            color: showSuccess ? "#7dffac" : "inherit",
                            fontWeight: showSuccess ? "bold" : "normal",
                        } }, showSuccess
                        ? t("CLIPBOARD_COPIED", "Copied to clipboard")
                        : isLoading
                            ? t("CLIPBOARD_COPYING", "Copying...")
                            : t("CLIPBOARD_COPY_LAUNCH", "Copy Launch Option"))))),
        window.SP_REACT.createElement("style", null, `
        @keyframes pulse {
          0% { opacity: 0.7; }
          50% { opacity: 1; }
          100% { opacity: 0.7; }
        }
      `)));
}

function UsageInstructions() {
    const [launchOption, setLaunchOption] = SP_REACT.useState(DEFAULT_STEAM_LAUNCH_OPTION);
    SP_REACT.useEffect(() => {
        getLaunchOption()
            .then((result) => setLaunchOption(result.launch_option || DEFAULT_STEAM_LAUNCH_OPTION))
            .catch(() => undefined);
    }, []);
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement(MakoSectionHeader, null, t("USAGE_TITLE", "Usage Instructions")),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement("div", { style: {
                    fontSize: "12px",
                    lineHeight: "1.4",
                    opacity: "0.8",
                    whiteSpace: "pre-wrap",
                } }, t("USAGE_DESC", "Copy the launch option into your Steam game's launch options to enable MAKO Renderer for frame generation, scaling, or both."))),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement("div", { style: {
                    fontSize: "12px",
                    lineHeight: "1.4",
                    opacity: "0.8",
                    backgroundColor: "rgba(255, 255, 255, 0.1)",
                    padding: "8px",
                    borderRadius: "4px",
                    fontFamily: "monospace",
                    marginTop: "8px",
                    marginBottom: "8px",
                    textAlign: "center",
                } },
                window.SP_REACT.createElement("strong", null, launchOption))),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement("div", { style: {
                    fontSize: "11px",
                    lineHeight: "1.3",
                    opacity: "0.6",
                    marginTop: "8px",
                } }, t("USAGE_MAKO_CONFIG_NOTE", "This command applies MAKO only to the game you launch with it."))),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement("div", { style: {
                    fontSize: "11px",
                    lineHeight: "1.3",
                    opacity: "0.6",
                    marginTop: "4px",
                } }, t("USAGE_ISOLATION_NOTE", "Do not combine MAKO with another frame-generation or scaling tool for the same game."))),
        window.SP_REACT.createElement(SmartClipboardButton, null)));
}

function FgmodClipboardButton() {
    const [fgmodExists, setFgmodExists] = SP_REACT.useState(false);
    const [checkingFgmod, setCheckingFgmod] = SP_REACT.useState(true);
    // Check for fgmod directory on component mount
    SP_REACT.useEffect(() => {
        const checkFgmod = async () => {
            try {
                const result = await checkFgmodDirectory();
                setFgmodExists(result.exists);
            }
            catch (error) {
                console.error("Error checking fgmod directory:", error);
                setFgmodExists(false);
            }
            finally {
                setCheckingFgmod(false);
            }
        };
        checkFgmod();
    }, []);
    const getFgmodLaunchOptionText = async () => {
        const launchOption = await getLaunchOption();
        return `~/fgmod/fgmod ${launchOption.launch_option || DEFAULT_STEAM_LAUNCH_OPTION}`;
    };
    const { isLoading, showSuccess, copyToClipboard } = useClipboardFeedback(getFgmodLaunchOptionText);
    // Don't render if fgmod directory doesn't exist or we're still checking
    if (checkingFgmod || !fgmodExists) {
        return null;
    }
    return (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
        window.SP_REACT.createElement("div", { className: "Mako_BrandButton" },
            window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", bottomSeparator: "none", onClick: copyToClipboard, disabled: isLoading || showSuccess },
                window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px" } },
                    showSuccess ? (window.SP_REACT.createElement(FaCheck, { style: { color: "#7dffac" } })) : isLoading ? (window.SP_REACT.createElement(FaClipboard, { style: {
                            animation: "pulse 1s ease-in-out infinite",
                            opacity: 0.7,
                        } })) : (window.SP_REACT.createElement(FaClipboard, null)),
                    window.SP_REACT.createElement("div", { style: {
                            color: showSuccess ? "#7dffac" : "inherit",
                            fontWeight: showSuccess ? "bold" : "normal",
                        } }, showSuccess
                        ? t("CLIPBOARD_COPIED", "Copied to clipboard")
                        : isLoading
                            ? t("CLIPBOARD_COPYING", "Copying...")
                            : t("CLIPBOARD_MAKO_FGMOD", "MAKO + DeckyFG"))))),
        window.SP_REACT.createElement("style", null, `
        @keyframes pulse {
          0% { opacity: 0.7; }
          50% { opacity: 1; }
          100% { opacity: 0.7; }
        }
      `)));
}

const DEFAULT_CONFIGURATION = getDefaults();
function FpsMultiplierControl({ config, onConfigChange, onConfigUpdate, }) {
    const [focusedControl, setFocusedControl] = SP_REACT.useState(null);
    const targetFps = config.target_fps;
    const adaptiveMaxMultiplier = config.adaptive_max_multiplier ??
        DEFAULT_CONFIGURATION.adaptive_max_multiplier;
    const frameGenerationEnabled = config.frame_generation_enabled ??
        DEFAULT_CONFIGURATION.frame_generation_enabled;
    const automaticBaseFpsCap = Math.max(ADAPTIVE_MINIMUM_BASE_FPS, targetFps / 2);
    const automaticBaseFpsCapLabel = Number.isInteger(automaticBaseFpsCap)
        ? automaticBaseFpsCap.toFixed(0)
        : automaticBaseFpsCap.toFixed(1);
    const multiplierButtonStyle = (isFocused) => ({
        height: "34px",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: "2px 0px 0px",
        minWidth: "48px",
        fontSize: "22px",
        fontWeight: "bold",
        ...makoDialogButtonStyle(isFocused),
        transform: isFocused ? "scale(1.04)" : "none",
        scrollMarginTop: "28px",
        scrollMarginBottom: "28px",
    });
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ToggleField, { label: t("FRAME_GENERATION_ENABLED", "Frame Generation"), description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                    window.SP_REACT.createElement("div", null, t("FRAME_GENERATION_ENABLED_DESC", "Leave it on to use Fixed or Adaptive Frame Generation. When off, neither mode generates frames; your settings stay saved.")),
                    window.SP_REACT.createElement(MakoInlineTip, { tone: "info" }, t("FRAME_GENERATION_ENABLED_WARNING", "Keep this on if you want frame generation."))), checked: frameGenerationEnabled, bottomSeparator: frameGenerationEnabled ? undefined : "none", onChange: (value) => onConfigChange(FRAME_GENERATION_ENABLED, value) })),
        frameGenerationEnabled && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: t("ADAPTIVE_TITLE", "Adaptive Frame Generation"), description: t("ADAPTIVE_DESC", "Adjusts frame generation to reach Target FPS. The steady base cap is the default for smoother pacing. Enable Fractional Adaptive to keep more real frames, but test it per game."), checked: config.adaptive, onChange: (value) => onConfigUpdate(adaptiveModeChanges(value)) })),
            config.adaptive && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                    window.SP_REACT.createElement(DFL.ToggleField, { label: t("FRACTIONAL_ADAPTIVE_PRESET", "Fractional Adaptive"), description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                            window.SP_REACT.createElement("div", null, t("FRACTIONAL_ADAPTIVE_PRESET_DESC", "Mixes generation ratios to reach targets such as 60 real FPS → 90 displayed FPS. It keeps more real frames and may reduce input lag and ghosting, but can feel less smooth in some games.")),
                            window.SP_REACT.createElement(MakoSettingRelationship, null, t("FRACTIONAL_ADAPTIVE_PRESET_RELATION", "Cannot be combined with Steady Base Cap. Changing it also turns Dynamic Cadence Recovery off."))), checked: isFractionalAdaptivePresetEnabled(config), onChange: (value) => onConfigUpdate(fractionalAdaptivePresetChanges(value)) })),
                window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                    window.SP_REACT.createElement(DFL.SliderField, { label: `${t("ADAPTIVE_TARGET_FPS", "Target FPS")} (${targetFps})`, description: t("ADAPTIVE_TARGET_FPS_DESC", "Desired displayed FPS. Fractional Adaptive may mix ratios to reach it; Steady Base Cap starts at half the target and can align a validated lower integer rung."), value: targetFps, min: TARGET_FPS_MIN, max: TARGET_FPS_MAX, step: 1, onChange: (value) => onConfigChange(TARGET_FPS, value) })),
                window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                    window.SP_REACT.createElement(DFL.ToggleField, { label: `${t("ADAPTIVE_AUTO_BASE_FPS_CAP", "Steady Base Cap")} (${automaticBaseFpsCapLabel} FPS)`, description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                            window.SP_REACT.createElement("div", null, t("ADAPTIVE_AUTO_BASE_FPS_CAP_DESC", "The default Adaptive mode. Starts at half the target; with Smooth Cadence it can align a validated 3x–5x rung. Pros: usually smoother pacing. Cons: fewer real frames and potentially more input lag and ghosting.")),
                            window.SP_REACT.createElement(MakoSettingRelationship, null, t("ADAPTIVE_AUTO_BASE_FPS_CAP_RELATION", "Overrides Base FPS Cap. Cannot be combined with Fractional Adaptive or Dynamic Cadence Recovery."))), checked: config.adaptive_auto_base_fps_cap ??
                            DEFAULT_CONFIGURATION.adaptive_auto_base_fps_cap, onChange: (value) => onConfigUpdate(steadyBaseCapChanges(value)) })),
                window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                    window.SP_REACT.createElement(DFL.SliderField, { label: `${t("ADAPTIVE_MAX_MULTIPLIER", "Maximum Adaptive Multiplier")} (${adaptiveMaxMultiplier}x)`, description: window.SP_REACT.createElement("span", { style: { display: "block", paddingBottom: "2px" } }, t("ADAPTIVE_MAX_MULTIPLIER_DESC", "Interpolation ceiling. 3x is balanced; 2x usually looks best, 4x gives more headroom, and 5x is for high-refresh displays with substantial GPU and memory headroom. Test per game.")), value: adaptiveMaxMultiplier, min: ADAPTIVE_MAX_MULTIPLIER_MIN, max: ADAPTIVE_MAX_MULTIPLIER_MAX, step: 1, validValues: "steps", minimumDpadGranularity: 1, notchCount: ADAPTIVE_MAX_MULTIPLIER_MAX -
                            ADAPTIVE_MAX_MULTIPLIER_MIN +
                            1, notchTicksVisible: true, onChange: (value) => onConfigChange(ADAPTIVE_MAX_MULTIPLIER, value) })),
                window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                    window.SP_REACT.createElement(DFL.ToggleField, { label: t("ADAPTIVE_SMOOTH_CADENCE", "Smooth Cadence"), description: t("ADAPTIVE_SMOOTH_CADENCE_DESC", "Uses a validated constant interpolation cadence. With Steady Base Cap, it can align proven 3x–5x demand to an exact target rung. It can make motion smoother, but may lower real-frame cadence and increase input lag. Enabled by default; disable it if a game feels more responsive without it."), bottomSeparator: "none", checked: config.adaptive_stable_cadence ??
                            DEFAULT_CONFIGURATION.adaptive_stable_cadence, onChange: (value) => onConfigChange(ADAPTIVE_STABLE_CADENCE, value) })))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.Field, { label: t("MULTIPLIER_TITLE", "Fixed FPS Multiplier"), bottomSeparator: "none", description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                        window.SP_REACT.createElement("span", { style: { display: "block", paddingTop: "8px" } }, t("MULTIPLIER_DESC", "Sets Fixed mode to 2x–5x. Fixed may perform better than Adaptive in some games, especially when frame pacing is uneven or unstable. 5x is a high-cost option for high-refresh displays. Test both per game. With Dynamic Cadence Recovery, this is a ceiling against confirmed Gamescope refresh; Adaptive manages its own multiplier.")),
                        config.adaptive && (window.SP_REACT.createElement(MakoSettingRelationship, null, t("MULTIPLIER_ADAPTIVE_RELATION", "Unavailable while Adaptive Frame Generation is enabled.")))), childrenLayout: "below" },
                    window.SP_REACT.createElement(MakoFocusable, { style: {
                            width: "100%",
                            boxSizing: "border-box",
                            marginTop: "6px",
                            display: "flex",
                            justifyContent: "center",
                            alignItems: "center",
                        }, "flow-children": "row", noFocusRing: true },
                        window.SP_REACT.createElement(DFL.DialogButton, { className: "Mako_DialogButton", style: {
                                ...multiplierButtonStyle(focusedControl === "decrease"),
                                marginLeft: "0px",
                            }, onClick: () => onConfigChange(MULTIPLIER, Math.max(FIXED_MULTIPLIER_UI_MIN, config.multiplier - 1)), onGamepadFocus: () => setFocusedControl("decrease"), onGamepadBlur: () => setFocusedControl((current) => current === "decrease" ? null : current), disabled: config.adaptive ||
                                config.multiplier <= FIXED_MULTIPLIER_UI_MIN }, "\u2212"),
                        window.SP_REACT.createElement("div", { style: {
                                marginLeft: "20px",
                                marginRight: "20px",
                                fontSize: "16px",
                                fontWeight: "bold",
                                color: config.adaptive
                                    ? "rgba(255, 255, 255, 0.45)"
                                    : "white",
                                minWidth: "60px",
                                textAlign: "center",
                            } }, config.adaptive
                            ? t("ADAPTIVE_VALUE", "Adaptive")
                            : `${config.multiplier}X`),
                        window.SP_REACT.createElement(DFL.DialogButton, { className: "Mako_DialogButton", style: {
                                ...multiplierButtonStyle(focusedControl === "increase"),
                                marginLeft: "0px",
                            }, onClick: () => onConfigChange(MULTIPLIER, Math.min(FIXED_MULTIPLIER_UI_MAX, config.multiplier + 1)), onGamepadFocus: () => setFocusedControl("increase"), onGamepadBlur: () => setFocusedControl((current) => current === "increase" ? null : current), disabled: config.adaptive ||
                                config.multiplier >= FIXED_MULTIPLIER_UI_MAX }, "+")))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: t("CONFIG_PERFORMANCE_MODE", "Lighter FG Model"), description: t("CONFIG_PERFORMANCE_MODE_DESC", "Reduces GPU work by using a lighter frame-generation model at the cost of more ghosting. Ultra Performance locks this on."), checked: config.ultra_performance || config.performance_mode, disabled: config.ultra_performance, onChange: (value) => onConfigChange(PERFORMANCE_MODE, value), bottomSeparator: "none" }))))));
}

function ScalingControl({ config, disabled = false, runtimeActivationSupported = null, runtimeInactiveReason = null, runtimeFactorCeiling = null, modelCompatible = null, runtimeRequestedMethod = null, runtimeMakoFallback = false, runtimeActiveMethod = null, onConfigChange, }) {
    const effectiveScalingMethod$1 = effectiveScalingMethod(config);
    const scalerActive = effectiveScalingMethod$1 !== SCALING_METHOD_NATIVE;
    const ls1Selected = effectiveScalingMethod$1 === SCALING_METHOD_LS1 ||
        effectiveScalingMethod$1 === SCALING_METHOD_LS1_PERFORMANCE;
    const activeFallback = runtimeMakoFallback && runtimeRequestedMethod === effectiveScalingMethod$1;
    const modelUnavailable = modelCompatible === false && runtimeActiveMethod !== effectiveScalingMethod$1;
    const runningSurfaceUnsupported = runtimeActivationSupported === false ||
        runtimeInactiveReason === "gamescope-wsi-surface-unproven";
    const unavailableControlClassName = runningSurfaceUnsupported
        ? "MAKO_ScalingUnavailableControl"
        : undefined;
    const steppedRuntimeCeiling = runtimeFactorCeiling === null
        ? null
        : Math.max(SCALING_FACTOR_MIN, Math.min(SCALING_FACTOR_MAX, Math.floor((runtimeFactorCeiling + 0.0001) * 10) / 10));
    const factorMaximum = !config.scaling_supersampling && steppedRuntimeCeiling !== null
        ? steppedRuntimeCeiling
        : SCALING_FACTOR_MAX;
    const displayedFactor = Math.min(config.scaling_factor, factorMaximum);
    const factorLimited = !config.scaling_supersampling && factorMaximum < SCALING_FACTOR_MAX;
    const factorHasNoHeadroom = !config.scaling_supersampling &&
        factorMaximum <= SCALING_FACTOR_MIN + 0.0001;
    const scalingMethodOptions = [
        {
            data: SCALING_METHOD_NATIVE,
            label: t("SCALING_METHOD_NATIVE", "Native Resolution"),
        },
        {
            data: SCALING_METHOD_MAKO,
            label: t("SCALING_METHOD_MAKO", "MAKO Scaler"),
        },
        {
            data: SCALING_METHOD_LS1,
            label: t("SCALING_METHOD_LS1", "LS1 Quality"),
        },
        {
            data: SCALING_METHOD_LS1_PERFORMANCE,
            label: t("SCALING_METHOD_LS1_PERFORMANCE", "LS1 Performance"),
        },
    ];
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement("style", null, `
        .MAKO_ScalingUnavailableControl {
          filter: grayscale(1);
        }
      `),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ToggleField, { label: window.SP_REACT.createElement(MakoExperimentalSettingLabel, { label: t("SCALING_ENABLED", "Enable Scaling (Restart)"), badgeLabel: t("EXPERIMENTAL_LABEL", "Experimental") }), description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                    window.SP_REACT.createElement("div", null, t("SCALING_ENABLED_DESC", "Enable before starting the game. When off, scaling is fully disabled. Supports Lossless Scaling models and MAKO Scaler.")),
                    window.SP_REACT.createElement(MakoInlineTip, { tone: "warning" }, t("SCALING_ENABLED_WARNING", "Leave Scaling off when you do not need it, as it consumes resources. Using it with Frame Generation may affect performance; try different performance settings or a lower in-game resolution."))), checked: config.scaling_enabled, disabled: disabled, bottomSeparator: config.scaling_enabled ? undefined : "none", onChange: (value) => onConfigChange(SCALING_ENABLED, value) })),
        config.scaling_enabled && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.Field, { label: t("SCALING_METHOD", "Scaling Method"), description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                        window.SP_REACT.createElement("div", null, t("SCALING_METHOD_DESC", "Choose the scaling model. You can change it while the game is running.")),
                        runningSurfaceUnsupported ? (window.SP_REACT.createElement(MakoInlineTip, { tone: "warning" }, t("SCALING_RUNTIME_SURFACE_UNSUPPORTED", "This running surface does not support MAKO scaling. Quality Supersampling, Scale Factor, and Sharpness are locked until a supported surface is detected. Frame Generation remains available."))) : (window.SP_REACT.createElement(MakoInlineTip, { tone: "info" },
                            window.SP_REACT.createElement("span", { style: { whiteSpace: "pre-line" } }, t("SCALING_METHOD_COMPARISON_TIP", "How scaling works:\n1. In Steam, set Game Resolution to your display's maximum resolution (Steam Deck: 1280 × 800; Steam Machine: 3840 × 2160).\n2. In the game, choose a lower resolution, such as 480p, 720p, or more.\n3. Use a Scale Factor to enlarge the image. 2x doubles your resolution.\n\nReducing the resolution of the game and scaling it back can substantially increase performance, with an image-quality trade-off."))))), childrenLayout: "below", childrenContainerWidth: "max" },
                    window.SP_REACT.createElement(DFL.Dropdown, { rgOptions: scalingMethodOptions, selectedOption: effectiveScalingMethod$1, disabled: disabled || config.ultra_performance, onChange: (option) => onConfigChange(SCALING_METHOD, String(option.data)) }),
                    ls1Selected && (activeFallback || modelUnavailable) && (window.SP_REACT.createElement(MakoInlineTip, { tone: "warning" }, activeFallback
                        ? t("SCALING_LS1_ACTIVE_FALLBACK", "LS1 is unavailable for this game. MAKO Scaler is active. Your LS1 selection is preserved.")
                        : t("SCALING_LS1_UNAVAILABLE", "The selected LS1 model could not be loaded during the availability check. MAKO Scaler is used automatically if LS1 cannot load. Your LS1 selection is preserved."))))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement("div", { className: unavailableControlClassName, style: { width: "100%" } },
                    window.SP_REACT.createElement(DFL.ToggleField, { label: t("SCALING_SUPERSAMPLING", "Quality Supersampling"), description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                            window.SP_REACT.createElement("div", null, t("SCALING_SUPERSAMPLING_DESC", "Allows exceeding a Gamescope output limit for higher-quality downsampling, increasing GPU and memory use. Does not change scaling on other desktop surfaces.")),
                            config.scaling_supersampling && (window.SP_REACT.createElement(MakoInlineTip, { tone: "warning" }, t("SCALING_SUPERSAMPLING_WARNING", "Supersampling is enabled. Where a Gamescope output limit applies, MAKO may exceed it for a sharper downsampled image.")))), checked: config.scaling_supersampling, disabled: disabled || runningSurfaceUnsupported, onChange: (value) => onConfigChange(SCALING_SUPERSAMPLING, value) }))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.SliderField, { label: `${t("SCALING_FACTOR", "Scale Factor")} (${displayedFactor.toFixed(1)}x${factorLimited ? ` ${t("SCALING_FACTOR_LIMIT_SUFFIX", "display limit")}` : ""})`, description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                        window.SP_REACT.createElement("span", { style: { display: "block", paddingTop: "3px" } }, t("SCALING_FACTOR_DESC", "Sets the output-to-input size ratio for every method. With a fixed output size, higher values lower the source resolution. When the game controls the window size, lower its resolution in the game first; higher factors enlarge MAKO's output and can increase GPU cost.")),
                        factorLimited && (window.SP_REACT.createElement(MakoInlineTip, { tone: "info" }, factorHasNoHeadroom
                            ? t("SCALING_FACTOR_NO_HEADROOM", "This resolution already fills the display. Lower the in-game resolution or enable Quality Supersampling.")
                            : t("SCALING_FACTOR_DEVICE_LIMIT", "Current display limit: {factor}x. Your saved {saved}x value is preserved; enable Quality Supersampling to use it.", {
                                factor: factorMaximum.toFixed(1),
                                saved: config.scaling_factor.toFixed(1),
                            })))), value: displayedFactor, min: SCALING_FACTOR_MIN, max: factorMaximum, step: 0.1, validValues: "steps", minimumDpadGranularity: 0.1, notchCount: factorHasNoHeadroom
                        ? 3
                        : Math.round((factorMaximum - SCALING_FACTOR_MIN) / 0.1) + 1, notchTicksVisible: true, className: unavailableControlClassName, disabled: disabled || runningSurfaceUnsupported || factorHasNoHeadroom, onChange: (value) => onConfigChange(SCALING_FACTOR, Number(value.toFixed(1))) })),
            scalerActive && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.SliderField, { label: `${t("SCALING_SHARPNESS", "Scaling Sharpness")} (${Math.round(config.scaling_sharpness * 100)}%)`, description: t("SCALING_SHARPNESS_DESC", "For MAKO, applies this 0–100% multiplier to its 3x sharpening baseline. For LS1, selects one of five learned sharpness variants."), value: config.scaling_sharpness, min: SCALING_SHARPNESS_MIN, max: SCALING_SHARPNESS_MAX, step: 0.01, className: unavailableControlClassName, disabled: disabled || runningSurfaceUnsupported, bottomSeparator: "none", onChange: (value) => onConfigChange(SCALING_SHARPNESS, Number(value.toFixed(2))) })))))));
}

// THIS FILE IS AUTO GENERATED
function MdBolt (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 24 24"},"child":[{"tag":"path","attr":{"d":"M11 21h-1l1-7H7.5c-.58 0-.57-.32-.38-.66.19-.34.05-.08.07-.12C8.48 10.94 10.42 7.54 13 3h1l-1 7h3.5c.49 0 .56.33.47.51l-.07.15C12.96 17.55 11 21 11 21z"},"child":[]}]})(props);
}

function PerformanceConfigurationGroup({ config, onConfigChange, onConfigUpdate, }) {
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement(MakoSectionHeader, null, t("CONTENT_PERFORMANCE_SETTINGS", "Performance Settings")),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ToggleField, { label: window.SP_REACT.createElement("span", { style: {
                        display: "inline-flex",
                        alignItems: "center",
                        gap: "5px",
                    } },
                    window.SP_REACT.createElement(MdBolt, { "aria-hidden": "true", size: 16, color: "#f4a259" }),
                    window.SP_REACT.createElement(MakoRestartLabel, { label: t("CONFIG_ULTRA_PERFORMANCE", "Ultra Performance (Restart)") })), description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                    window.SP_REACT.createElement("div", null, t("CONFIG_ULTRA_PERFORMANCE_DESC", "Reduces MAKO's GPU workload on low-power devices. Uses 75% Flow Scale, the Lighter FG Model, FP16 when supported, and LS1 Performance when Scaling is enabled. Trades image quality for performance across the active MAKO features.")),
                    window.SP_REACT.createElement(MakoInlineTip, { tone: "info" }, t("CONFIG_ULTRA_PERFORMANCE_WARNING", "Turning Ultra Performance on or off requires a game restart. Other compatible profile controls remain available after startup."))), checked: config.ultra_performance, onChange: (value) => onConfigUpdate(ultraPerformanceChanges(value)) })),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.SliderField, { label: `${t("CONFIG_FLOW_SCALE", "Flow Scale")} (${Math.round((config.ultra_performance ? ULTRA_PERFORMANCE_FLOW_SCALE : config.flow_scale) * 100)}%)`, description: t("CONFIG_FLOW_SCALE_DESC", "Controls the internal motion-estimation resolution used only for Frame Generation. Lower values reduce GPU work; higher values favour quality."), value: config.ultra_performance
                    ? ULTRA_PERFORMANCE_FLOW_SCALE
                    : config.flow_scale, min: FLOW_SCALE_MIN, max: FLOW_SCALE_MAX, step: 0.01, disabled: config.ultra_performance, onChange: (value) => onConfigChange(FLOW_SCALE, value) })),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ToggleField, { label: window.SP_REACT.createElement(MakoRestartLabel, { label: t("CONFIG_ALLOW_FP16", "Allow FP16 (Restart)") }), description: t("CONFIG_ALLOW_FP16_DESC", "Global renderer setting: applies to all profiles and cannot be changed per game. Improves performance on AMD; disable for older NVIDIA GPUs. Restart the game after changing it."), checked: config.ultra_performance || config.allow_fp16, disabled: config.ultra_performance, onChange: (value) => onConfigChange(ALLOW_FP16, value), bottomSeparator: "none" }))));
}

function FeatureSettings({ config, disabled = false, runtimeState, scalingModelCompatible = null, onConfigChange, onConfigUpdate, }) {
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement(MakoSectionHeader, null, t("CONTENT_FPS_MULTIPLIER", "Frame Generation")),
        window.SP_REACT.createElement(FpsMultiplierControl, { config: config, onConfigChange: onConfigChange, onConfigUpdate: onConfigUpdate }),
        window.SP_REACT.createElement(MakoSectionHeader, null, t("CONTENT_SCALING", "Spatial Settings")),
        window.SP_REACT.createElement(ScalingControl, { config: config, disabled: disabled, runtimeActivationSupported: runtimeState.scalingActivationSupported, runtimeInactiveReason: runtimeState.inactiveReason, runtimeFactorCeiling: runtimeState.nonSupersamplingFactorCeiling, modelCompatible: scalingModelCompatible, runtimeRequestedMethod: runtimeState.requestedMethod, runtimeActiveMethod: runtimeState.scalingActive ? runtimeState.activeMethod : null, runtimeMakoFallback: runtimeState.scalingActive &&
                runtimeState.activeMethod === "mako" &&
                Boolean(runtimeState.fallbackReason), onConfigChange: onConfigChange }),
        window.SP_REACT.createElement(PerformanceConfigurationGroup, { config: config, onConfigChange: onConfigChange, onConfigUpdate: onConfigUpdate }),
        window.SP_REACT.createElement(FrameGenerationConfigurationSection, { config: config, onConfigChange: onConfigChange, onConfigUpdate: onConfigUpdate })));
}

function methodLabel(method) {
    switch (method) {
        case "mako":
            return t("SCALING_METHOD_MAKO", "MAKO Scaler");
        case "ls1":
            return t("SCALING_METHOD_LS1", "LS1 Quality");
        case "ls1-performance":
            return t("SCALING_METHOD_LS1_PERFORMANCE", "LS1 Performance");
        default:
            return t("SCALING_METHOD_NATIVE", "Native Resolution");
    }
}
function liveMethodLabel(method) {
    switch (method) {
        case "native":
            return t("LIVE_STATUS_NATIVE", "Native");
        case "ls1-performance":
            return t("LIVE_STATUS_LS1_PERFORMANCE", "LS1 Perf");
        default:
            return methodLabel(method);
    }
}
function resolution(width, height) {
    return width > 0 && height > 0 ? `${width} × ${height}` : "—";
}
function scalingInactiveNotice(reason) {
    switch (reason) {
        case "variable-surface-memory-budget":
            return t("LIVE_STATUS_SCALING_MEMORY_LIMIT", "The requested render resolution exceeds this GPU's memory safety limit. Lower the in-game resolution.");
        case "gamescope-presentation-target-no-headroom":
        case "variable-surface-no-headroom":
            return t("LIVE_STATUS_SCALING_NO_HEADROOM", "This input already fills the display target. Lower the in-game resolution or enable Quality Supersampling.");
        default:
            return null;
    }
}
function StatusDetail({ label, value, }) {
    return (window.SP_REACT.createElement("div", { "data-mako-live-status-detail": "true", style: {
            display: "grid",
            gridTemplateColumns: "minmax(0, 0.8fr) minmax(0, 1.2fr)",
            gap: "5px",
            alignItems: "baseline",
            marginTop: "2px",
        } },
        window.SP_REACT.createElement("span", { style: { color: "#839da5" } }, label),
        window.SP_REACT.createElement("span", { style: {
                color: "#d7e7eb",
                textAlign: "right",
                overflowWrap: "anywhere",
            } }, value)));
}
function StatusRow({ label, active, separated, children, }) {
    return (window.SP_REACT.createElement("div", { style: {
            display: "grid",
            gridTemplateColumns: "8px minmax(0, 1fr)",
            columnGap: "6px",
            padding: "6px 8px",
            borderLeft: separated ? makoPanelDivider : undefined,
        } },
        window.SP_REACT.createElement("span", { "aria-hidden": "true", style: {
                width: "7px",
                height: "7px",
                marginTop: "3px",
                borderRadius: "50%",
                background: active ? "#5fe3b1" : "#738891",
                boxShadow: active ? "0 0 7px rgba(95, 227, 177, 0.55)" : "none",
            } }),
        window.SP_REACT.createElement("div", { style: { minWidth: 0 } },
            window.SP_REACT.createElement("div", { style: { color: "#edf8fb", fontSize: "10px", fontWeight: 650 } }, label),
            window.SP_REACT.createElement("div", { style: {
                    marginTop: "2px",
                    color: "#b6c9cf",
                    fontSize: "9px",
                    lineHeight: 1.3,
                } }, children))));
}
function StatusNotices({ children }) {
    return (window.SP_REACT.createElement("div", { "data-mako-live-status-notices": "true", style: {
            display: "grid",
            gap: "4px",
            marginTop: "8px",
            color: "#f7d9b4",
        } }, children));
}
function StatusFooterNotices({ children }) {
    return (window.SP_REACT.createElement("div", { "data-mako-live-status-footer": "true", style: {
            display: "grid",
            gap: "4px",
            padding: "6px 10px",
            borderTop: makoPanelDivider,
            color: "#f7d9b4",
            fontSize: "9px",
            lineHeight: 1.35,
        } }, children));
}
function RuntimeStatusCard({ runtimeState, }) {
    const inactiveNotice = runtimeState.scalingEnabled && !runtimeState.scalingActive
        ? scalingInactiveNotice(runtimeState.inactiveReason)
        : null;
    const memoryConstraintNotice = runtimeState.scalingActive &&
        runtimeState.constraintReason === "variable-surface-memory-budget" &&
        runtimeState.requestedFactor > runtimeState.effectiveFactor + 0.005;
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement(MakoSectionHeader, null, t("LIVE_STATUS_TITLE", "Live Status")),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(MakoSectionTail, null,
                window.SP_REACT.createElement("div", { "aria-label": t("LIVE_STATUS_TITLE", "Live Status"), style: { ...makoPanelStyle, width: "100%" } },
                    window.SP_REACT.createElement("div", { style: {
                            padding: "4px 8px",
                            display: "flex",
                            alignItems: "baseline",
                            justifyContent: "flex-end",
                            gap: "8px",
                        } },
                        window.SP_REACT.createElement("span", { style: {
                                color: runtimeState.hasContext ? makoAccentColor : "#93a5ab",
                                fontSize: "8.5px",
                                fontWeight: 600,
                                textTransform: "uppercase",
                            } }, runtimeState.hasContext
                            ? t("LIVE_STATUS_CONNECTED", "MAKO is active")
                            : t("LIVE_STATUS_WAITING", "Waiting for MAKO"))),
                    !runtimeState.hasContext ? (window.SP_REACT.createElement("div", { style: {
                            padding: "8px 10px",
                            borderTop: makoPanelDivider,
                            color: "#b6c9cf",
                            fontSize: "10px",
                            lineHeight: 1.4,
                        } }, t("LIVE_STATUS_WAITING_DESC", "Live status is unavailable, but MAKO may still be active. Some games and emulators may not report live metrics. Check Frame Generation or Scaling manually."))) : (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                        window.SP_REACT.createElement("div", { "data-mako-live-status-grid": "compact-two-column", style: {
                                display: "grid",
                                gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
                                borderTop: makoPanelDivider,
                            } },
                            window.SP_REACT.createElement(StatusRow, { label: t("CONTENT_FPS_MULTIPLIER", "Frame Generation"), active: runtimeState.frameGenerationActive },
                                runtimeState.frameGenerationActive ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                    window.SP_REACT.createElement(StatusDetail, { label: t("LIVE_STATUS_MODE", "Mode"), value: runtimeState.frameGenerationMode === "adaptive"
                                            ? t("ADAPTIVE_VALUE", "Adaptive")
                                            : t("LIVE_STATUS_FIXED_VALUE", "Fixed") }),
                                    runtimeState.frameGenerationMode === "adaptive" ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                        window.SP_REACT.createElement(StatusDetail, { label: t("LIVE_STATUS_ADAPTIVE_STYLE", "Style"), value: runtimeState.frameGenerationAdaptiveStyle ===
                                                "steady"
                                                ? t("LIVE_STATUS_STEADY_VALUE", "Steady")
                                                : t("LIVE_STATUS_FRACTIONAL_VALUE", "Fractional") }),
                                        window.SP_REACT.createElement(StatusDetail, { label: t("LIVE_STATUS_TARGET", "Target"), value: `${runtimeState.frameGenerationTargetFps ?? "—"} FPS` }),
                                        window.SP_REACT.createElement(StatusDetail, { label: t("LIVE_STATUS_MAX_MULTIPLIER", "Max factor"), value: `${runtimeState.frameGenerationMultiplier ?? "—"}×` }))) : (window.SP_REACT.createElement(StatusDetail, { label: t("LIVE_STATUS_MULTIPLIER", "Factor"), value: `${runtimeState.frameGenerationMultiplier ?? "—"}×` })))) : runtimeState.frameGenerationEnabled ? (t("LIVE_STATUS_FG_INACTIVE", "On in settings, but not currently generating frames.")) : (t("LIVE_STATUS_OFF", "Off")),
                                runtimeState.frameGenerationPending && (window.SP_REACT.createElement(StatusNotices, null, t("LIVE_STATUS_PENDING", "A saved change is still applying or needs a restart.")))),
                            window.SP_REACT.createElement(StatusRow, { label: t("FEATURE_UPSCALING_TAB", "Upscaling"), active: runtimeState.scalingActive, separated: true }, runtimeState.scalingActive ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                window.SP_REACT.createElement(StatusDetail, { label: t("LIVE_STATUS_MODEL", "Model"), value: liveMethodLabel(runtimeState.activeMethod) }),
                                window.SP_REACT.createElement(StatusDetail, { label: t("LIVE_STATUS_ORIGINAL_RESOLUTION", "Input"), value: resolution(runtimeState.sourceWidth, runtimeState.sourceHeight) }),
                                runtimeState.supersamplingActive ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                    window.SP_REACT.createElement(StatusDetail, { label: t("LIVE_STATUS_RENDER_RESOLUTION", "Render"), value: resolution(runtimeState.presentationWidth, runtimeState.presentationHeight) }),
                                    window.SP_REACT.createElement(StatusDetail, { label: t("LIVE_STATUS_DISPLAY_RESOLUTION", "Display"), value: resolution(runtimeState.gamescopeTargetWidth, runtimeState.gamescopeTargetHeight) }))) : (window.SP_REACT.createElement(StatusDetail, { label: t("LIVE_STATUS_SCALED_RESOLUTION", "Output"), value: resolution(runtimeState.presentationWidth, runtimeState.presentationHeight) })),
                                window.SP_REACT.createElement(StatusDetail, { label: t("LIVE_STATUS_MULTIPLIER", "Factor"), value: `${runtimeState.effectiveFactor.toFixed(2)}×` }))) : runtimeState.scalingEnabled ? (runtimeState.scalingActivationSupported === false ? (t("LIVE_STATUS_SCALING_UNAVAILABLE", "Unavailable for this running surface.")) : (t("LIVE_STATUS_SCALING_INACTIVE", "On in settings, but the game image is not being upscaled."))) : (t("LIVE_STATUS_OFF", "Off")))),
                        (runtimeState.supersamplingActive ||
                            runtimeState.fallbackReason ||
                            runtimeState.scalingPending ||
                            inactiveNotice ||
                            memoryConstraintNotice) && (window.SP_REACT.createElement(StatusFooterNotices, null,
                            runtimeState.supersamplingActive && (window.SP_REACT.createElement("div", { style: { color: makoAccentColor } }, t("LIVE_STATUS_SUPERSAMPLING", "Quality Supersampling active."))),
                            memoryConstraintNotice && (window.SP_REACT.createElement("div", null, t("LIVE_STATUS_SCALING_MEMORY_CONSTRAINED", "Requested {requested}×; limited to {effective}× by this GPU's memory safety limit.", {
                                requested: runtimeState.requestedFactor.toFixed(2),
                                effective: runtimeState.effectiveFactor.toFixed(2),
                            }))),
                            inactiveNotice && window.SP_REACT.createElement("div", null, inactiveNotice),
                            runtimeState.fallbackReason && (window.SP_REACT.createElement("div", null, t("LIVE_STATUS_SCALING_FALLBACK", "You selected {requested}; MAKO is using {active} instead.", {
                                requested: methodLabel(runtimeState.requestedMethod),
                                active: methodLabel(runtimeState.activeMethod),
                            }))),
                            runtimeState.scalingPending && (window.SP_REACT.createElement("div", null, t("LIVE_STATUS_PENDING", "A saved change is still applying or needs a restart."))))))))))));
}

const SUPPORTED_FLATPAK_RUNTIME_VERSION_LIST = SUPPORTED_FLATPAK_RUNTIMES.map(({ version }) => version).join(", ");
function UnderlinedWelcomeText({ children }) {
    return (window.SP_REACT.createElement("span", { style: {
            textDecorationLine: "underline",
            textDecorationColor: "rgba(131, 191, 240, 0.8)",
            textUnderlineOffset: "2px",
        } }, children));
}
function WelcomeNotice({ separated }) {
    const [tipsCollapsed, setTipsCollapsed] = usePersistentCollapseState("mako-welcome-tips-collapsed", false, "welcome tips");
    const expanded = !tipsCollapsed;
    return (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
        window.SP_REACT.createElement("div", { role: "note", style: {
                ...makoPanelStyle,
                width: "100%",
                boxSizing: "border-box",
                marginTop: separated ? "8px" : undefined,
                padding: "12px",
            } },
            window.SP_REACT.createElement("div", { style: {
                    color: "#edf8fb",
                    fontSize: "13px",
                    fontWeight: 700,
                    lineHeight: 1.3,
                    display: "flex",
                    alignItems: "flex-start",
                    gap: "7px",
                } },
                window.SP_REACT.createElement("span", { "aria-hidden": "true", style: { fontSize: "16px", lineHeight: 1 } }, "\uD83E\uDD88"),
                window.SP_REACT.createElement("span", { style: { flex: 1, minWidth: 0 } }, t("WELCOME_TITLE", "Hello from the MAKO Team!"))),
            expanded && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                window.SP_REACT.createElement("div", { style: {
                        marginTop: "7px",
                        color: "#c8dce8",
                        fontSize: "11px",
                        lineHeight: 1.42,
                    } },
                    window.SP_REACT.createElement("div", null,
                        t("WELCOME_LIVE_UPDATES", "Many settings apply live."),
                        " ",
                        t("WELCOME_RESTART_REQUIRED", "Options marked Restart require a game restart."),
                        " ",
                        t("WELCOME_PERFORMANCE_NOTE", "Game resolution and scaling changes can affect performance."),
                        " ",
                        t("WELCOME_CLEAN_SESSION_PREFIX", "If anything "),
                        window.SP_REACT.createElement(UnderlinedWelcomeText, null, t("WELCOME_CLEAN_SESSION_WRONG", "looks or feels wrong")),
                        t("WELCOME_CLEAN_SESSION_AFTER", " after "),
                        window.SP_REACT.createElement(UnderlinedWelcomeText, null, t("WELCOME_CLEAN_SESSION_CHANGES", "several changes")),
                        t("WELCOME_CLEAN_SESSION_RESTART_SEPARATOR", ", "),
                        window.SP_REACT.createElement(UnderlinedWelcomeText, null, t("WELCOME_CLEAN_SESSION_RESTART", "restart the game for a clean new session.")))),
                window.SP_REACT.createElement("div", { style: {
                        marginTop: "9px",
                        paddingTop: "8px",
                        borderTop: makoPanelDivider,
                        color: "#9fc1ca",
                        fontSize: "10.5px",
                        lineHeight: 1.4,
                    } }, t("WELCOME_ENJOY", "Every game is different. Find the best settings that work for you and enjoy playing. MAKO keeps improving with every release, so keep an eye on the release page!")))),
            window.SP_REACT.createElement("div", { style: {
                    display: "flex",
                    justifyContent: "center",
                    marginTop: expanded ? "9px" : "8px",
                } },
                window.SP_REACT.createElement(DFL.DialogButton, { "aria-expanded": expanded, style: {
                        width: "auto",
                        minWidth: "78px",
                        height: "28px",
                        padding: "4px 10px",
                        fontSize: "11px",
                        flexShrink: 0,
                    }, onClick: () => setTipsCollapsed((current) => !current) }, expanded
                    ? t("WELCOME_TIPS_COLLAPSE", "Hide tips")
                    : t("WELCOME_TIPS_EXPAND", "Show tips"))))));
}
/** Purely visual status notices shown above MAKO Decky's controls. */
function ContentNotices({ developmentBuildInfo, mainRunningApp, showWelcome, engineUpdateRequired, installedEngineVersion, expectedEngineVersion, isInstalling, isInstallCompletionVisible, isUninstalling, onInstall, }) {
    const [showDevelopmentDetails, setShowDevelopmentDetails] = SP_REACT.useState(false);
    const hasDevelopmentNotice = Boolean(developmentBuildInfo);
    const hasRunningAppNotice = Boolean(mainRunningApp);
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        developmentBuildInfo && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement("div", { style: {
                    padding: "8px 12px",
                    width: "100%",
                    boxSizing: "border-box",
                    backgroundColor: "rgba(33, 150, 243, 0.16)",
                    borderRadius: "4px",
                    border: "1px solid rgba(33, 150, 243, 0.5)",
                    color: "#a8d8ff",
                    fontSize: "13px",
                    overflow: "hidden",
                } },
                window.SP_REACT.createElement("div", { style: {
                        display: "flex",
                        alignItems: "center",
                        gap: "8px",
                        minWidth: 0,
                    } },
                    window.SP_REACT.createElement("div", { style: { flex: 1, minWidth: 0 } },
                        window.SP_REACT.createElement("div", { style: { fontWeight: "bold" } }, "\uD83E\uDDEA Local development deployment"),
                        window.SP_REACT.createElement("div", { style: {
                                marginTop: "2px",
                                color: "#d6ecff",
                                fontSize: "11px",
                                whiteSpace: "nowrap",
                                overflow: "hidden",
                                textOverflow: "ellipsis",
                            } },
                            "MAKO Decky ",
                            window.SP_REACT.createElement("code", null, developmentBuildInfo.plugin.commit),
                            developmentBuildInfo.plugin.dirty ? "*" : "",
                            " · MAKO Renderer ",
                            developmentBuildInfo.engine ? (window.SP_REACT.createElement("code", null, developmentBuildInfo.engine.commit)) : ("unchanged"),
                            developmentBuildInfo.engine?.dirty ? "*" : "")),
                    window.SP_REACT.createElement(DFL.DialogButton, { "aria-expanded": showDevelopmentDetails, style: {
                            width: "72px",
                            minWidth: "72px",
                            height: "30px",
                            padding: "4px 8px",
                            fontSize: "12px",
                        }, onClick: () => setShowDevelopmentDetails((current) => !current) }, showDevelopmentDetails ? "Hide" : "Details")),
                showDevelopmentDetails && (window.SP_REACT.createElement("div", { style: {
                        display: "flex",
                        flexDirection: "column",
                        gap: "8px",
                        marginTop: "8px",
                        paddingTop: "8px",
                        borderTop: "1px solid rgba(33, 150, 243, 0.35)",
                        overflowWrap: "anywhere",
                    } },
                    window.SP_REACT.createElement("div", { style: { color: "#d6ecff" } },
                        window.SP_REACT.createElement("span", { style: { color: "#83bff0" } }, "Deployed"),
                        " ",
                        new Date(developmentBuildInfo.generatedAt).toLocaleString()),
                    window.SP_REACT.createElement("div", null,
                        window.SP_REACT.createElement("div", { style: { color: "#83bff0", fontWeight: "600" } }, "MAKO Decky"),
                        window.SP_REACT.createElement("div", null,
                            "Commit: ",
                            window.SP_REACT.createElement("code", null, developmentBuildInfo.plugin.commit),
                            developmentBuildInfo.plugin.dirty ? " + local edits" : ""),
                        window.SP_REACT.createElement("div", null,
                            "Frontend:",
                            " ",
                            developmentBuildInfo.plugin.frontendDeployed
                                ? "deployed"
                                : "unchanged"),
                        window.SP_REACT.createElement("div", null,
                            "Backend:",
                            " ",
                            developmentBuildInfo.plugin.backendDeployed
                                ? "deployed"
                                : "unchanged")),
                    window.SP_REACT.createElement("div", null,
                        window.SP_REACT.createElement("div", { style: { color: "#83bff0", fontWeight: "600" } }, "MAKO Renderer"),
                        developmentBuildInfo.engine ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                            window.SP_REACT.createElement("div", null,
                                "Commit:",
                                " ",
                                window.SP_REACT.createElement("code", null, developmentBuildInfo.engine.commit),
                                developmentBuildInfo.engine.dirty
                                    ? " + local edits"
                                    : ""),
                            window.SP_REACT.createElement("div", null,
                                "64-bit layer:",
                                " ",
                                developmentBuildInfo.engine.layer64Sha256 ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                    "deployed \u00B7 SHA-256",
                                    " ",
                                    window.SP_REACT.createElement("code", null, developmentBuildInfo.engine.layer64Sha256.slice(0, 12)))) : ("unchanged")),
                            window.SP_REACT.createElement("div", null,
                                "32-bit layer:",
                                " ",
                                developmentBuildInfo.engine.layer32Sha256 ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                    "deployed \u00B7 SHA-256",
                                    " ",
                                    window.SP_REACT.createElement("code", null, developmentBuildInfo.engine.layer32Sha256.slice(0, 12)))) : ("unchanged")),
                            window.SP_REACT.createElement("div", null,
                                "Flatpak bundles:",
                                " ",
                                developmentBuildInfo.engine.flatpakArchiveSha256 ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                    SUPPORTED_FLATPAK_RUNTIME_VERSION_LIST,
                                    " deployed \u00B7 SHA-256",
                                    " ",
                                    window.SP_REACT.createElement("code", null, developmentBuildInfo.engine.flatpakArchiveSha256.slice(0, 12)))) : ("unchanged")))) : (window.SP_REACT.createElement("div", null, "Unchanged by this deployment")))))))),
        showWelcome && window.SP_REACT.createElement(WelcomeNotice, { separated: hasDevelopmentNotice }),
        mainRunningApp && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement("div", { style: {
                    marginTop: hasDevelopmentNotice || showWelcome ? "8px" : undefined,
                    padding: "8px 12px",
                    width: "100%",
                    boxSizing: "border-box",
                    backgroundColor: "rgba(0, 255, 0, 0.1)",
                    borderRadius: "4px",
                    border: "1px solid rgba(0, 255, 0, 0.3)",
                    fontSize: "13px",
                    overflowWrap: "anywhere",
                } },
                window.SP_REACT.createElement("strong", null, mainRunningApp.display_name),
                " ",
                t("CONTENT_RUNNING", "running."),
                " ",
                t("PROFILE_CAPTURE_READY", "MAKO selects saved profiles automatically. If this game is new, save it below; restart the game after changing restart-only settings.")))),
        engineUpdateRequired && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement("div", { style: {
                    marginTop: hasDevelopmentNotice || showWelcome || hasRunningAppNotice
                        ? "8px"
                        : undefined,
                    padding: "12px",
                    borderRadius: "8px",
                    background: "rgba(255, 152, 0, 0.16)",
                    border: "1px solid rgba(255, 152, 0, 0.7)",
                    color: "#ffd08a",
                } },
                window.SP_REACT.createElement("div", { style: { fontWeight: "bold", marginBottom: "4px" } }, t("CONTENT_ENGINE_UPDATE_REQUIRED", "MAKO Renderer update required")),
                window.SP_REACT.createElement("div", { style: { fontSize: "13px", marginBottom: "10px" } },
                    t("CONTENT_ENGINE_INSTALLED", "Installed:"),
                    " ",
                    installedEngineVersion ||
                        t("CONTENT_ENGINE_NOT_RECORDED", "not recorded"),
                    ". ",
                    t("CONTENT_ENGINE_EXPECTS", "This plugin expects:"),
                    " ",
                    expectedEngineVersion ||
                        t("CONTENT_ENGINE_BUNDLED_VERSION", "the bundled version"),
                    ".",
                    !installedEngineVersion &&
                        ` ${t("CONTENT_ENGINE_PREDATES_TRACKING", "The installed payload predates version tracking.")}`,
                    " ",
                    t("CONTENT_ENGINE_UPDATE_DESC", "Reinstall MAKO Renderer to apply the version bundled with this plugin. Then update the matching runtime extensions for prepared Flatpak apps.")),
                window.SP_REACT.createElement("div", { className: "Mako_BrandButton" },
                    window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: onInstall, disabled: isInstalling || isInstallCompletionVisible || isUninstalling }, isInstallCompletionVisible ? (window.SP_REACT.createElement(MakoInstallCompletion, null)) : (window.SP_REACT.createElement("div", { style: {
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "center",
                            gap: "8px",
                        } },
                        isInstalling && window.SP_REACT.createElement(MakoCompactSpinner, null),
                        window.SP_REACT.createElement("span", null, isInstalling
                            ? t("CONTENT_UPDATING_RENDERER", "Updating MAKO Renderer...")
                            : t("CONTENT_UPDATE_RENDERER", "Update MAKO Renderer")))))))))));
}

function AdvancedDetailsModal({ closeModal, }) {
    const [dllStats, setDllStats] = SP_REACT.useState(null);
    const [configContent, setConfigContent] = SP_REACT.useState(null);
    const [scriptContent, setScriptContent] = SP_REACT.useState(null);
    const [loading, setLoading] = SP_REACT.useState(true);
    const [error, setError] = SP_REACT.useState(null);
    SP_REACT.useEffect(() => {
        const loadData = async () => {
            try {
                setLoading(true);
                setError(null);
                // Load all data in parallel
                const [dllResult, configResult, scriptResult] = await Promise.all([
                    getDllStats(),
                    getConfigFileContent(),
                    getLaunchScriptContent(),
                ]);
                setDllStats(dllResult);
                setConfigContent(configResult);
                setScriptContent(scriptResult);
            }
            catch (err) {
                setError(err instanceof Error
                    ? err.message
                    : t("ADVANCED_DETAILS_FAILED_LOAD_DATA", "Failed to load data"));
            }
            finally {
                setLoading(false);
            }
        };
        loadData();
    }, []);
    const formatSHA256 = (hash) => {
        // Format SHA256 hash for better readability (add spaces every 8 characters)
        return hash.replace(/(.{8})/g, "$1 ").trim();
    };
    const copyToClipboard = async (text) => {
        try {
            await navigator.clipboard.writeText(text);
            // Could add a toast notification here if desired
        }
        catch (err) {
            console.error("Failed to copy to clipboard:", err);
        }
    };
    const copyableValueStyle = {
        display: "block",
        minWidth: 0,
        maxWidth: "100%",
        overflowWrap: "anywhere",
        wordBreak: "break-word",
    };
    const pathStyle = {
        ...copyableValueStyle,
        marginBottom: "9px",
        color: "#b9cbd0",
        fontSize: "12px",
        lineHeight: 1.35,
    };
    const detailLabelStyle = {
        marginBottom: "4px",
        color: "#a9c4cb",
        fontSize: "11px",
        fontWeight: 600,
        lineHeight: 1.3,
        textTransform: "uppercase",
        letterSpacing: "0.35px",
    };
    const detailValueStyle = {
        ...copyableValueStyle,
        color: "#edf8fb",
        fontSize: "13px",
        lineHeight: 1.4,
    };
    const codeBlockStyle = {
        boxSizing: "border-box",
        width: "100%",
        maxWidth: "100%",
        maxHeight: "180px",
        margin: 0,
        padding: "8px",
        overflow: "auto",
        border: "1px solid rgba(77, 170, 190, 0.18)",
        borderRadius: "4px",
        background: "rgba(0, 10, 18, 0.42)",
        color: "#dcecef",
        fontSize: "0.8em",
        whiteSpace: "pre-wrap",
        overflowWrap: "anywhere",
        wordBreak: "break-word",
    };
    return (window.SP_REACT.createElement(DFL.ModalRoot, { closeModal: closeModal },
        window.SP_REACT.createElement(DFL.DialogHeader, null, t("CONTENT_ADVANCED_DETAILS", "Advanced Details")),
        window.SP_REACT.createElement(DFL.DialogBody, null,
            loading && (window.SP_REACT.createElement("div", { style: {
                    ...makoPanelStyle,
                    margin: "8px 0 18px",
                    padding: "18px",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: "9px",
                    color: "#dcecef",
                } },
                window.SP_REACT.createElement(MakoCompactSpinner, null),
                window.SP_REACT.createElement("span", null, t("ADVANCED_DETAILS_LOADING", "Loading information...")))),
            error && (window.SP_REACT.createElement("div", { style: {
                    ...makoPanelStyle,
                    margin: "8px 0 18px",
                    padding: "14px",
                    color: "#ffb3b9",
                } },
                t("ADVANCED_DETAILS_ERROR_PREFIX", "Error:"),
                " ",
                error)),
            !loading && !error && (window.SP_REACT.createElement(MakoFocusable, { "flow-children": "column" },
                window.SP_REACT.createElement("div", { style: { ...makoPanelStyle, margin: "8px 0 18px" } },
                    dllStats && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                        window.SP_REACT.createElement("div", { style: makoPanelSectionHeaderStyle }, t("ADVANCED_DETAILS_LIBRARY", "Lossless Scaling Library")),
                        !dllStats.success ? (window.SP_REACT.createElement("div", { style: {
                                ...makoPanelItemStyle,
                                color: "#ffb3b9",
                                overflowWrap: "anywhere",
                            } }, dllStats.error ||
                            t("ADVANCED_DETAILS_FAILED_DLL_STATS", "Failed to get DLL stats"))) : (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                            window.SP_REACT.createElement("div", { style: makoPanelItemStyle },
                                window.SP_REACT.createElement("div", { style: detailLabelStyle }, t("ADVANCED_DETAILS_DLL_PATH", "DLL Path")),
                                window.SP_REACT.createElement(MakoFocusable, { onClick: () => dllStats.dll_path &&
                                        copyToClipboard(dllStats.dll_path), onActivate: () => dllStats.dll_path &&
                                        copyToClipboard(dllStats.dll_path), style: detailValueStyle }, dllStats.dll_path ||
                                    t("ADVANCED_DETAILS_NOT_AVAILABLE", "Not available"))),
                            window.SP_REACT.createElement("div", { style: makoPanelItemStyle },
                                window.SP_REACT.createElement("div", { style: detailLabelStyle }, t("ADVANCED_DETAILS_DLL_HASH", "DLL SHA256 Hash")),
                                window.SP_REACT.createElement(MakoFocusable, { onClick: () => dllStats.dll_sha256 &&
                                        copyToClipboard(dllStats.dll_sha256), onActivate: () => dllStats.dll_sha256 &&
                                        copyToClipboard(dllStats.dll_sha256), style: {
                                        ...detailValueStyle,
                                        fontFamily: "monospace",
                                        fontSize: "12px",
                                    } }, dllStats.dll_sha256
                                    ? formatSHA256(dllStats.dll_sha256)
                                    : t("ADVANCED_DETAILS_NOT_AVAILABLE", "Not available"))),
                            dllStats.dll_source && (window.SP_REACT.createElement("div", { style: makoPanelItemStyle },
                                window.SP_REACT.createElement("div", { style: detailLabelStyle }, t("ADVANCED_DETAILS_DETECTION_SOURCE", "Detection Source")),
                                window.SP_REACT.createElement("div", { style: detailValueStyle }, dllStats.dll_source))))))),
                    scriptContent && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                        window.SP_REACT.createElement("div", { style: {
                                ...makoPanelSectionHeaderStyle,
                                borderTop: makoPanelDivider,
                            } }, t("ADVANCED_DETAILS_LAUNCH_SCRIPT", "Launch Script")),
                        window.SP_REACT.createElement("div", { style: makoPanelItemStyle }, !scriptContent.success ? (window.SP_REACT.createElement("div", { style: { color: "#ffb3b9", overflowWrap: "anywhere" } },
                            t("ADVANCED_DETAILS_SCRIPT_NOT_FOUND_PREFIX", "Script not found:"),
                            " ",
                            scriptContent.error)) : (window.SP_REACT.createElement("div", { style: { minWidth: 0 } },
                            window.SP_REACT.createElement("div", { style: pathStyle },
                                t("ADVANCED_DETAILS_PATH_PREFIX", "Path:"),
                                " ",
                                scriptContent.path),
                            window.SP_REACT.createElement(MakoFocusable, { onClick: () => scriptContent.content &&
                                    copyToClipboard(scriptContent.content), onActivate: () => scriptContent.content &&
                                    copyToClipboard(scriptContent.content) },
                                window.SP_REACT.createElement("pre", { style: codeBlockStyle }, scriptContent.content ||
                                    t("ADVANCED_DETAILS_NO_CONTENT", "No content")))))))),
                    configContent && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                        window.SP_REACT.createElement("div", { style: {
                                ...makoPanelSectionHeaderStyle,
                                borderTop: makoPanelDivider,
                            } }, t("ADVANCED_DETAILS_CONFIG_FILE", "Configuration File")),
                        window.SP_REACT.createElement("div", { style: makoPanelItemStyle }, !configContent.success ? (window.SP_REACT.createElement("div", { style: { color: "#ffb3b9", overflowWrap: "anywhere" } },
                            t("ADVANCED_DETAILS_CONFIG_NOT_FOUND_PREFIX", "Config not found:"),
                            " ",
                            configContent.error)) : (window.SP_REACT.createElement("div", { style: { minWidth: 0 } },
                            window.SP_REACT.createElement("div", { style: pathStyle },
                                t("ADVANCED_DETAILS_PATH_PREFIX", "Path:"),
                                " ",
                                configContent.path),
                            window.SP_REACT.createElement(MakoFocusable, { onClick: () => configContent.content &&
                                    copyToClipboard(configContent.content), onActivate: () => configContent.content &&
                                    copyToClipboard(configContent.content) },
                                window.SP_REACT.createElement("pre", { style: codeBlockStyle }, configContent.content ||
                                    t("ADVANCED_DETAILS_NO_CONTENT", "No content"))))))))),
                window.SP_REACT.createElement(DFL.DialogControlsSection, null,
                    window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                        window.SP_REACT.createElement("div", { className: "Mako_BrandButton" },
                            window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: closeModal }, t("ADVANCED_DETAILS_CLOSE", "Close"))))))))));
}

const MAKO_FLATPAK_GUIDE_URL = "https://github.com/eugeniosegala/MAKO/blob/main/plugin/docs/LAUNCHERS.md";
function translateFlatpakRuntime(version) {
    return t("FLATPAK_RUNTIME_VERSION", "Runtime {version}", { version });
}
const FlatpaksModal = ({ closeModal }) => {
    const [extensionStatus, setExtensionStatus] = SP_REACT.useState(null);
    const [flatpakApps, setFlatpakApps] = SP_REACT.useState(null);
    const [loading, setLoading] = SP_REACT.useState(true);
    const [operationInProgress, setOperationInProgress] = SP_REACT.useState(null);
    const [appErrors, setAppErrors] = SP_REACT.useState({});
    const [wrapperPath, setWrapperPath] = SP_REACT.useState(DEFAULT_MAKO_WRAPPER_PATH);
    const loadData = async () => {
        setLoading(true);
        try {
            const [statusResult, appsResult, launchOptionResult] = await Promise.all([
                checkFlatpakExtensionStatus(),
                getFlatpakApps(),
                getLaunchOption().catch(() => null),
            ]);
            setExtensionStatus(statusResult);
            setFlatpakApps(appsResult);
            if (launchOptionResult?.wrapper_path) {
                setWrapperPath(launchOptionResult.wrapper_path);
            }
        }
        catch (error) {
            console.error("Error loading Flatpak data:", error);
        }
        finally {
            setLoading(false);
        }
    };
    SP_REACT.useEffect(() => {
        loadData();
    }, []);
    const handleExtensionOperation = async (operation, version) => {
        const operationId = `${operation}-${version}`;
        setOperationInProgress(operationId);
        try {
            const result = operation === "install"
                ? await installFlatpakExtension(version)
                : await uninstallFlatpakExtension(version);
            if (result.success) {
                // Reload status after operation
                const newStatus = await checkFlatpakExtensionStatus();
                setExtensionStatus(newStatus);
                showSuccessToast(t("FLATPAK_EXTENSION_UPDATED", "Flatpak extension updated"), result.message ||
                    `${version} ${t("FLATPAK_RUNTIME_EXTENSION_UPDATED", "runtime extension updated")}`);
            }
            else {
                const action = operation === "install"
                    ? t("FLATPAK_INSTALL_ACTION", "install")
                    : t("FLATPAK_UNINSTALL_ACTION", "uninstall");
                showErrorToast(t("FLATPAK_EXTENSION_FAILED", "Flatpak extension failed"), result.error ||
                    result.message ||
                    `${t("FLATPAK_EXTENSION_ACTION_FAILED", "Could not")} ${action} ${version} ${t("FLATPAK_RUNTIME_EXTENSION", "runtime extension")}`);
            }
        }
        catch (error) {
            console.error(`Error ${operation}ing extension:`, error);
            showErrorToast(t("FLATPAK_EXTENSION_FAILED", "Flatpak extension failed"), String(error));
        }
        finally {
            setOperationInProgress(null);
        }
    };
    const handleAppOverrideToggle = async (app) => {
        const hasOverrides = app.has_filesystem_override &&
            app.has_wrapper_override &&
            app.has_required_env_override !== false;
        const operationId = `app-${app.app_id}`;
        setOperationInProgress(operationId);
        setAppErrors((current) => {
            const next = { ...current };
            delete next[app.app_id];
            return next;
        });
        try {
            const result = hasOverrides
                ? await removeFlatpakAppOverride(app.app_id)
                : await setFlatpakAppOverride(app.app_id);
            if (result.success) {
                // Reload apps data after operation
                const newApps = await getFlatpakApps();
                setFlatpakApps(newApps);
                showSuccessToast(t("FLATPAK_APPLICATION_UPDATED", "Flatpak application updated"), result.message ||
                    `${app.app_name || app.app_id} ${t("FLATPAK_UPDATED", "updated")}`);
            }
            else {
                setAppErrors((current) => ({
                    ...current,
                    [app.app_id]: result.error ||
                        result.message ||
                        `${t("FLATPAK_APPLICATION_ACTION_FAILED", "Could not update")} ${app.app_name || app.app_id}`,
                }));
            }
        }
        catch (error) {
            console.error("Error toggling app override:", error);
            setAppErrors((current) => ({ ...current, [app.app_id]: String(error) }));
        }
        finally {
            setOperationInProgress(null);
        }
    };
    const confirmOperation = (operation, title, description) => {
        DFL.showModal(window.SP_REACT.createElement(DFL.ConfirmModal, { strTitle: title, strDescription: description, onOK: operation, onCancel: () => { } }));
    };
    const handleRuntimePrimaryAction = (version, installed) => {
        const operation = installed
            ? "uninstall"
            : "install";
        const action = () => handleExtensionOperation(operation, version);
        if (operation === "uninstall") {
            confirmOperation(action, t("FLATPAK_UNINSTALL_TITLE", "Uninstall Runtime Extension"), `${t("FLATPAK_UNINSTALL_CONFIRM_PREFIX", "Are you sure you want to uninstall the")} ${version} ${t("FLATPAK_UNINSTALL_CONFIRM_SUFFIX", "runtime extension?")}`);
            return;
        }
        action();
    };
    if (loading) {
        return (window.SP_REACT.createElement(DFL.ModalRoot, { closeModal: closeModal },
            window.SP_REACT.createElement(DFL.DialogHeader, null, t("FLATPAK_MODAL_TITLE", "Flatpak Extensions")),
            window.SP_REACT.createElement(DFL.DialogBody, null,
                window.SP_REACT.createElement("div", { style: {
                        display: "flex",
                        justifyContent: "center",
                        padding: "20px",
                    } },
                    window.SP_REACT.createElement(MakoCompactSpinner, { size: 28 })))));
    }
    const instructionSteps = [
        {
            id: "try-first",
            title: t("FLATPAK_STEP_WRAPPER_PATH", "Wrapper installed on this device:"),
            command: wrapperPath,
        },
        {
            id: "final-result",
            title: t("FLATPAK_STEP_FINAL", 'Target for a shortcut that originally used "/usr/bin/flatpak":'),
            command: `"${wrapperPath}" "/usr/bin/flatpak"`,
        },
    ];
    const focusableInstructionStyle = {
        padding: "10px",
        background: "rgba(0, 0, 0, 0.3)",
        borderRadius: "6px",
        marginBottom: "12px",
    };
    const commandStyle = {
        fontFamily: "monospace",
        fontSize: "0.85em",
        background: "rgba(0, 0, 0, 0.45)",
        padding: "8px",
        borderRadius: "4px",
        marginTop: "6px",
        overflowWrap: "anywhere",
    };
    return (window.SP_REACT.createElement(DFL.ModalRoot, { closeModal: closeModal },
        window.SP_REACT.createElement(DFL.DialogHeader, null, t("FLATPAK_MODAL_TITLE", "Flatpak Extensions")),
        window.SP_REACT.createElement(DFL.DialogBody, null,
            window.SP_REACT.createElement(MakoFocusable, { "flow-children": "column" },
                window.SP_REACT.createElement("div", { style: {
                        ...makoPanelStyle,
                        margin: "8px 0 18px",
                    } },
                    window.SP_REACT.createElement("div", { style: makoPanelSectionHeaderStyle }, t("FLATPAK_RUNTIME_INSTALLER", "Runtime Extension Installer")),
                    extensionStatus && extensionStatus.success ? (SUPPORTED_FLATPAK_RUNTIMES.map((runtime) => {
                        const installBusy = operationInProgress === `install-${runtime.version}`;
                        const uninstallBusy = operationInProgress === `uninstall-${runtime.version}`;
                        const isBusy = installBusy || uninstallBusy;
                        const installed = extensionStatus[runtime.statusField];
                        return (window.SP_REACT.createElement("div", { key: runtime.version, style: makoPanelItemStyle },
                            window.SP_REACT.createElement("div", { style: {
                                    display: "flex",
                                    alignItems: "center",
                                    gap: "10px",
                                } },
                                installed ? (window.SP_REACT.createElement(FaCheck, { style: { color: "#65b9c9", flex: "0 0 16px" } })) : (window.SP_REACT.createElement(FaTimes, { style: { color: "#c89558", flex: "0 0 16px" } })),
                                window.SP_REACT.createElement("div", { style: { minWidth: 0 } },
                                    window.SP_REACT.createElement("div", { style: { color: "#edf8fb", fontWeight: 600 } }, translateFlatpakRuntime(runtime.version)),
                                    window.SP_REACT.createElement("div", { style: {
                                            marginTop: "2px",
                                            color: "#b9cbd0",
                                            fontSize: "12px",
                                        } }, installed
                                        ? t("FLATPAK_INSTALLED", "Installed")
                                        : t("FLATPAK_NOT_INSTALLED", "Not installed")))),
                            window.SP_REACT.createElement("div", { style: { display: "flex", gap: "8px", marginTop: "10px" } },
                                installed && (window.SP_REACT.createElement("div", { className: "Mako_BrandButton", style: { flex: 1, minWidth: 0 } },
                                    window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: () => handleExtensionOperation("install", runtime.version), disabled: isBusy }, installBusy ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                        window.SP_REACT.createElement(MakoCompactSpinner, null),
                                        " ",
                                        t("FLATPAK_UPDATING_BTN", "Updating..."))) : (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                        window.SP_REACT.createElement(FaDownload, null),
                                        " ",
                                        t("FLATPAK_UPDATE_BTN", "Update")))))),
                                window.SP_REACT.createElement("div", { className: `Mako_BrandButton${installed ? " Mako_BrandButton--danger" : ""}`, style: { flex: 1, minWidth: 0 } },
                                    window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: () => handleRuntimePrimaryAction(runtime.version, installed), disabled: isBusy }, uninstallBusy ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                        window.SP_REACT.createElement(MakoCompactSpinner, null),
                                        " ",
                                        t("FLATPAK_UNINSTALLING_BTN", "Uninstalling..."))) : installBusy && !installed ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                        window.SP_REACT.createElement(MakoCompactSpinner, null),
                                        " ",
                                        t("FLATPAK_INSTALLING_BTN", "Installing..."))) : installed ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                        window.SP_REACT.createElement(FaTrash, null),
                                        " ",
                                        t("FLATPAK_UNINSTALL_BTN", "Uninstall"))) : (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                        window.SP_REACT.createElement(FaDownload, null),
                                        " ",
                                        t("FLATPAK_INSTALL_BTN", "Install"))))))));
                    })) : (window.SP_REACT.createElement("div", { style: makoPanelItemStyle },
                        window.SP_REACT.createElement("div", { style: {
                                display: "flex",
                                alignItems: "flex-start",
                                gap: "10px",
                            } },
                            window.SP_REACT.createElement(FaTimes, { style: {
                                    color: "#c89558",
                                    flex: "0 0 16px",
                                    marginTop: "2px",
                                } }),
                            window.SP_REACT.createElement("div", null,
                                window.SP_REACT.createElement("div", { style: { color: "#edf8fb", fontWeight: 600 } }, t("FLATPAK_ERROR", "Error")),
                                window.SP_REACT.createElement("div", { style: {
                                        marginTop: "3px",
                                        color: "#b9cbd0",
                                        fontSize: "12px",
                                        overflowWrap: "anywhere",
                                    } }, extensionStatus?.error ||
                                    t("FLATPAK_ERROR_STATUS", "Failed to check extension status")))))),
                    window.SP_REACT.createElement("div", { style: {
                            ...makoPanelSectionHeaderStyle,
                            borderTop: makoPanelDivider,
                        } }, t("FLATPAK_APPS_TITLE", "Flatpak Applications")),
                    window.SP_REACT.createElement("div", { style: {
                            ...makoPanelItemStyle,
                            color: "#b9cbd0",
                            fontSize: "12px",
                            lineHeight: 1.4,
                        } },
                        window.SP_REACT.createElement("div", { style: {
                                color: "#edf8fb",
                                fontSize: "13px",
                                fontWeight: 600,
                                marginBottom: "4px",
                            } }, t("FLATPAK_PREPARE_APPLICATION", "Prepare an application")),
                        t("FLATPAK_PREPARE_APPLICATION_DESC", "Install the matching runtime extension, then prepare the app. Heroic and Lutris need a per-game wrapper; emulators are prepared app-wide. Open the launcher setup guide for steps.")),
                    flatpakApps && flatpakApps.success ? (flatpakApps.apps.length > 0 ? (flatpakApps.apps.map((app) => {
                        const hasOverrides = app.has_filesystem_override &&
                            app.has_wrapper_override &&
                            app.has_required_env_override !== false;
                        const partialOverrides = app.has_filesystem_override ||
                            app.has_wrapper_override ||
                            app.has_env_override;
                        const appBusy = operationInProgress === `app-${app.app_id}`;
                        let statusColor = "#c89558";
                        let statusText = t("FLATPAK_STATUS_NO_OVERRIDES", "No overrides");
                        if (hasOverrides) {
                            statusColor = "#65b9c9";
                            statusText = t("FLATPAK_STATUS_CONFIGURED", "Prepared");
                        }
                        else if (partialOverrides) {
                            statusColor = "#d58a39";
                            statusText = t("FLATPAK_STATUS_PARTIAL", "Partial");
                        }
                        const appError = appErrors[app.app_id];
                        const description = PER_GAME_WRAPPER_FLATPAK_APP_IDS.some((appId) => appId === app.app_id)
                            ? t("FLATPAK_PER_GAME_APP_DESC", "{app_id} - {status}. Enable MAKO per game using {wrapper_path}. See the launcher setup guide for the correct field.", {
                                app_id: app.app_id,
                                status: statusText,
                                wrapper_path: app.wrapper_path,
                            })
                            : t("FLATPAK_DIRECT_APP_DESC", "{app_id} - {status}. Preparation applies to this entire Flatpak app. Follow the launcher setup guide for EmuDeck and Steam shortcuts.", {
                                app_id: app.app_id,
                                status: statusText,
                            });
                        return (window.SP_REACT.createElement("div", { key: app.app_id, style: {
                                ...makoPanelItemStyle,
                                display: "flex",
                                alignItems: "center",
                                gap: "10px",
                            } },
                            window.SP_REACT.createElement(FaCog, { style: {
                                    color: appError ? "#d96d79" : statusColor,
                                    flex: "0 0 16px",
                                } }),
                            window.SP_REACT.createElement("div", { style: { flex: 1, minWidth: 0 } },
                                window.SP_REACT.createElement("div", { style: {
                                        color: "#edf8fb",
                                        fontWeight: 600,
                                        overflowWrap: "anywhere",
                                    } }, app.app_name || app.app_id),
                                window.SP_REACT.createElement("div", { style: {
                                        marginTop: "3px",
                                        color: "#b9cbd0",
                                        fontSize: "12px",
                                        lineHeight: 1.35,
                                        overflowWrap: "anywhere",
                                    } }, description),
                                appError && (window.SP_REACT.createElement("div", { style: {
                                        marginTop: "5px",
                                        color: "#ff9b9b",
                                        fontSize: "12px",
                                        lineHeight: 1.35,
                                        overflowWrap: "anywhere",
                                    } }, appError))),
                            window.SP_REACT.createElement("div", { "aria-busy": appBusy, style: {
                                    flex: "0 0 auto",
                                    position: "relative",
                                    display: "inline-flex",
                                    alignItems: "center",
                                    justifyContent: "center",
                                } },
                                window.SP_REACT.createElement(DFL.Toggle, { value: hasOverrides, onChange: () => {
                                        if (!appBusy)
                                            void handleAppOverrideToggle(app);
                                    } }),
                                appBusy && (window.SP_REACT.createElement("div", { role: "status", style: {
                                        position: "absolute",
                                        inset: "1px 4px 1px 1px",
                                        display: "flex",
                                        alignItems: "center",
                                        justifyContent: "center",
                                        boxSizing: "border-box",
                                        pointerEvents: "none",
                                        overflow: "hidden",
                                        border: "1px solid rgba(101, 185, 201, 0.42)",
                                        borderRadius: "999px",
                                        background: "rgba(8, 39, 56, 0.9)",
                                    } },
                                    window.SP_REACT.createElement(MakoCompactSpinner, { size: 14 }))))));
                    })) : (window.SP_REACT.createElement("div", { style: makoPanelItemStyle },
                        window.SP_REACT.createElement("div", { style: { color: "#edf8fb", fontWeight: 600 } }, t("FLATPAK_NO_APPS", "No Flatpak Apps Found")),
                        window.SP_REACT.createElement("div", { style: {
                                marginTop: "3px",
                                color: "#b9cbd0",
                                fontSize: "12px",
                            } }, t("FLATPAK_NO_APPS_DESC", "No Flatpak applications are currently installed"))))) : (window.SP_REACT.createElement("div", { style: makoPanelItemStyle },
                        window.SP_REACT.createElement("div", { style: { color: "#edf8fb", fontWeight: 600 } }, t("FLATPAK_ERROR", "Error")),
                        window.SP_REACT.createElement("div", { style: {
                                marginTop: "3px",
                                color: "#b9cbd0",
                                fontSize: "12px",
                                overflowWrap: "anywhere",
                            } }, flatpakApps?.error ||
                            t("FLATPAK_ERROR_APPS", "Failed to load Flatpak applications")))),
                    window.SP_REACT.createElement("div", { style: {
                            ...makoPanelSectionHeaderStyle,
                            borderTop: makoPanelDivider,
                        } }, t("FLATPAK_STEAM_CONFIG_TITLE", "Manual Steam shortcut reference")),
                    window.SP_REACT.createElement("div", { style: {
                            ...makoPanelItemStyle,
                            display: "flex",
                            flexDirection: "column",
                        } },
                        window.SP_REACT.createElement("div", { style: {
                                fontWeight: "bold",
                                marginBottom: "8px",
                                color: "#fff",
                            } }, t("FLATPAK_STEAM_CONFIG_HEADER", "Target example (does not configure Steam)")),
                        window.SP_REACT.createElement("div", { style: {
                                fontSize: "0.9em",
                                lineHeight: "1.4",
                                marginBottom: "8px",
                            } }, t("FLATPAK_STEAM_CONFIG_DESC", "Use this only for a manually added Steam shortcut whose original Target is /usr/bin/flatpak. Prepare that Flatpak application above first, then leave Start In and Launch Options unchanged. Heroic, Lutris, and EmuDeck have separate steps in the launcher setup guide.")),
                        window.SP_REACT.createElement("div", { style: {
                                fontSize: "0.9em",
                                lineHeight: "1.4",
                                marginBottom: "12px",
                                color: "#ffa500",
                            } },
                            window.SP_REACT.createElement("strong", null, t("FLATPAK_IMPORTANT_LABEL", "IMPORTANT:")),
                            " ",
                            t("FLATPAK_STEAM_CONFIG_IMPORTANT", "Replace TARGET only. Do not paste this into Launch Options.")),
                        instructionSteps.map((step) => (window.SP_REACT.createElement(MakoFocusable, { key: step.id, focusWithinClassName: "gpfocuswithin", onActivate: () => { }, style: focusableInstructionStyle },
                            window.SP_REACT.createElement("div", { style: { fontWeight: "bold" } }, step.title),
                            window.SP_REACT.createElement("div", { style: commandStyle }, step.command)))),
                        window.SP_REACT.createElement("div", { className: "Mako_BrandButton" },
                            window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: () => DFL.Navigation.NavigateToExternalWeb(MAKO_FLATPAK_GUIDE_URL) }, t("FLATPAK_OPEN_README", "Open launcher setup guide"))))),
                window.SP_REACT.createElement(DFL.DialogControlsSection, null,
                    window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                        window.SP_REACT.createElement("div", { className: "Mako_BrandButton" },
                            window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: closeModal }, t("FLATPAK_CLOSE", "Close")))))))));
};

const localDevelopmentBuildInfo = null;

const currentRelease = {"version":"3.2.0","codename":"The Captain"};

function Content() {
    const { isInstalled, installationStatus, engineUpdateRequired, hostArchitectureSupported, installedEngineVersion, expectedEngineVersion, setIsInstalled, setInstallationStatus, checkInstallation, } = useInstallationStatus();
    const { dllDetected, dllDetectionStatus } = useDllDetection();
    const { config, applyConfigPatch, replaceConfig, loadMakoConfig } = useMakoConfig();
    const { updateProfileConfigFields, syncCurrentProfile } = useProfileManagement();
    const { isInstalling, isUninstalling, isInstallCompletionVisible, handleInstall, handleUninstall, } = useInstallationActions();
    const { mainRunningApp, editingProfile, selectEditingProfile, getEditingProfile, } = useProfileSession({
        isInstalled,
        loadProfileConfig: loadMakoConfig,
        syncCurrentProfile,
    });
    const scalingRuntimeState = useRuntimeScalingStatus(editingProfile, Boolean(isInstalled && mainRunningApp));
    const scalingModelCompatible = useScalingModelStatus(config, isInstalled);
    const { saveConfigChanges: handleConfigChanges, saveConfigField: handleConfigChange, } = useProfileConfigWriter({
        editingProfile,
        getEditingProfile,
        updateProfileConfigFields,
        loadProfileConfig: loadMakoConfig,
        applyConfigPatch,
        replaceConfig,
    });
    const onInstall = async () => {
        await handleInstall(setIsInstalled, setInstallationStatus, loadMakoConfig, engineUpdateRequired ? "update" : "install");
        await checkInstallation();
    };
    const onUninstall = () => {
        handleUninstall(setIsInstalled, setInstallationStatus);
    };
    const handleShowAdvancedDetails = () => {
        DFL.showModal(window.SP_REACT.createElement(AdvancedDetailsModal, null));
    };
    const handleShowFlatpaks = () => {
        DFL.showModal(window.SP_REACT.createElement(FlatpaksModal, null));
    };
    const keepFocusedControlVisible = (event) => {
        const target = event.target;
        // Decky's controller navigation can move focus before its scroll container
        // has caught up, most noticeably when navigating from the bottom back to
        // the first controls. Centre the newly focused control without animation
        // so the top of the plugin is fully reachable and no scroll requests queue.
        requestAnimationFrame(() => {
            target.scrollIntoView({
                block: "center",
                inline: "nearest",
                behavior: "auto",
            });
        });
    };
    const hasDevelopmentNotice = Boolean(localDevelopmentBuildInfo);
    const hasRunningAppNotice = Boolean(isInstalled && mainRunningApp);
    const hasEngineUpdateNotice = Boolean(isInstalled && engineUpdateRequired);
    const hasTopNotice = isInstalled ||
        hasDevelopmentNotice ||
        hasRunningAppNotice ||
        hasEngineUpdateNotice;
    return (window.SP_REACT.createElement("div", { onFocusCapture: keepFocusedControlVisible },
        window.SP_REACT.createElement(MakoButtonTheme, null),
        window.SP_REACT.createElement(DFL.PanelSection, null,
            window.SP_REACT.createElement(MakoReleaseIdentity, { version: currentRelease.version, codename: currentRelease.codename, bottomMargin: hasTopNotice ? "8px" : "2px" }),
            window.SP_REACT.createElement(ContentNotices, { developmentBuildInfo: localDevelopmentBuildInfo, mainRunningApp: isInstalled ? mainRunningApp : undefined, showWelcome: isInstalled, engineUpdateRequired: isInstalled && engineUpdateRequired, installedEngineVersion: installedEngineVersion, expectedEngineVersion: expectedEngineVersion, isInstalling: isInstalling, isInstallCompletionVisible: isInstallCompletionVisible, isUninstalling: isUninstalling, onInstall: onInstall }),
            !isInstalled && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                window.SP_REACT.createElement(InstallationButton, { isInstalled: isInstalled, isInstalling: isInstalling, isInstallCompletionVisible: isInstallCompletionVisible, isUninstalling: isUninstalling, hostArchitectureSupported: hostArchitectureSupported, onInstall: onInstall, onUninstall: onUninstall }),
                window.SP_REACT.createElement(StatusDisplay, { dllDetected: dllDetected, dllDetectionStatus: dllDetectionStatus, isInstalled: isInstalled, installationStatus: installationStatus, topMargin: "16px" }))),
            isInstalled && (window.SP_REACT.createElement(ProfileManagement, { editingProfile: editingProfile, mainRunningApp: mainRunningApp, topMargin: "18px", onProfileChange: async (profileName) => {
                    selectEditingProfile(profileName);
                    await loadMakoConfig(profileName);
                } })),
            isInstalled && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                mainRunningApp && (window.SP_REACT.createElement(RuntimeStatusCard, { runtimeState: scalingRuntimeState })),
                window.SP_REACT.createElement(FeatureSettings, { config: config, disabled: engineUpdateRequired, runtimeState: scalingRuntimeState, scalingModelCompatible: scalingModelCompatible, onConfigChange: handleConfigChange, onConfigUpdate: handleConfigChanges }))),
            window.SP_REACT.createElement(UsageInstructions, null),
            isInstalled && window.SP_REACT.createElement(FgmodClipboardButton, null),
            isInstalled && (window.SP_REACT.createElement(ConfigurationSection, { config: config, onConfigChange: handleConfigChange, onConfigUpdate: handleConfigChanges, includeAdvancedRendering: false })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement("div", { className: "Mako_BrandButton", style: {
                        width: "100%",
                        boxSizing: "border-box",
                        marginTop: "16px",
                        paddingTop: "16px",
                        borderTop: "1px solid rgba(77, 170, 190, 0.28)",
                    } },
                    window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", bottomSeparator: "none", onClick: handleShowFlatpaks }, t("CONTENT_FLATPAK_SETUP", "Flatpak Setup")))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement("div", { className: "Mako_BrandButton" },
                    window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", bottomSeparator: "none", onClick: handleShowAdvancedDetails }, t("CONTENT_ADVANCED_DETAILS", "Advanced Details")))),
            isInstalled && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                window.SP_REACT.createElement(StatusDisplay, { dllDetected: dllDetected, dllDetectionStatus: dllDetectionStatus, isInstalled: isInstalled, installationStatus: installationStatus, topMargin: "16px" }),
                window.SP_REACT.createElement(InstallationButton, { isInstalled: isInstalled, isInstalling: isInstalling, isInstallCompletionVisible: isInstallCompletionVisible, isUninstalling: isUninstalling, hostArchitectureSupported: hostArchitectureSupported, onInstall: onInstall, onUninstall: onUninstall, topMargin: "16px" }))))));
}

var index = definePlugin(() => {
    console.log("MAKO Decky initializing");
    return {
        name: "MAKO Decky",
        titleView: window.SP_REACT.createElement("div", { className: DFL.staticClasses.Title }, "MAKO Decky"),
        alwaysRender: true,
        content: window.SP_REACT.createElement(Content, null),
        icon: window.SP_REACT.createElement(GiSharkFin, null),
        onDismount() {
            console.log("MAKO Decky unloading");
        }
    };
});

export { index as default };
//# sourceMappingURL=index.js.map
