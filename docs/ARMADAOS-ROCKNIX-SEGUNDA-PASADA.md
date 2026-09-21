# ArmadaOS y ROCKNIX — qué nos sirve y qué no (21/09/2026)

Segunda pasada sobre ambos proyectos, ya con casi todo lo del primer estudio
(`ARMADAOS-STUDY.md`) portado. El objetivo era buscar lo que **queda** por aprovechar.

**Conclusión corta: estamos muy al día.** De ROCKNIX no falta nada (vendorizamos su kernel y
sus parches) y de ArmadaOS solo queda una pieza real (el rendimiento por juego).

---

## ROCKNIX: no falta nada ✅

ROCKNIX **sí soporta la Odin 3 nativamente** (63 parches del SM8750, incluidos
`0047-arm64-dts-qcom-Add-AYN-Odin3`, `0601-ROCKNIX-odin3-pwm-fan-sysfs`,
`0602-ROCKNIX-odin3-rtc-persist-offset-sdam`, `0612-ROCKNIX-odin3-q6apm-start-mi2s-port-at-prepare`).
Pero **ya los tenemos todos**:

| Comprobación | Resultado |
|---|---|
| Parches SM8750 | **Los tenemos** — 66 en `kernel/sm8750/patches/20-sm8750/`, incluidos los 7 del WiFi/WCN7860 (`0039`–`0045`) y los de la Odin 3 |
| Config del kernel | **Idéntica** a la suya (8631 vs 8632 líneas; la única diferencia es `CONFIG_RUSTC_HAS_SUSPICIOUS_RUNTIME_SYMBOL_DEFINITIONS`, auto-generada) |
| UCM de audio | **El mismo** que usamos (el de Teguh Sobirin) |
| Micrófono | Tampoco lo tienen → confirma que nuestro bloqueo es de bring-up, no de config |

Se debe a que `make sync` vendoriza ROCKNIX (`vendor/rocknix-sm8750` + sus parches).

> ⚠️ **Matiz importante**: los parches WiFi de ROCKNIX **no cubren** nuestra regresión del 7.2.6.
> Esa está en cambios de **mainline** en `drivers/bus/mhi/host/*` y `pcie-qcom.c`, que sus parches
> no tocan. Sigue siendo problema nuestro (o nos quedamos en 7.2.4).

---

## ArmadaOS: de la lista original, casi todo cubierto

Verificado uno a uno contra nuestro árbol:

| Feature de ArmadaOS | Estado en Pocknix |
|---|---|
| `dbus-update-activation-environment` | ✅ portado |
| `STEAM_GAMESCOPE_*` (VRR, tearing, HDR, NIS, fps dinámico) | ✅ portado |
| `armada-game-launch` (wrapper de Proton) | ✅ portado |
| Perfiles de energía (CPU caps, GPU caps, underclock) | ✅ `pocknix-power-profile` (bajo/medio/alto) |
| Curvas de ventilador | ✅ `pocknix-fancontrol` |
| Per-game (governor + power profile) | ✅ `pocknix-pergame-power` |
| Calibración de sticks / deadzone | ✅ propio |
| RGB | ✅ plugin Decky |
| Suspensión s2idle | ✅ resuelto (`SUSPEND-ISSUE.md`) |
| `controller-type` (deck/xb360/ds5) | ✅ **`pocknix-gamepad-target`, y mejor**: 10 tipos (`deck, deck-uhid, xb360, xbox-elite, xbox-series, ds5, ds5-edge, horipad-steam…`) y **decide por sesión** (deck en Steam, xb360 en escritorio). El suyo es estático |
| `armada-fixups` (normalizar Proton) | ❌ **no aplica**: el problema es que ArmadaOS usa nombres **versionados** (`proton-cachyos-11.0-<hash>-arm64`); los nuestros son **estables** (`compatibilitytools.d/proton-cachyos`) |
| Thunks de FEX | ✅ **ya vienen compilados**: `fex-emu` se construye desde fuente *"because no prebuilt ships thunks"*. El `Thunks: {}` del `Config.json` es normal (FEX los autodetecta) |
| `backlight-acl` | N/A — la Odin 3 tiene **un solo** backlight |
| MTP (`mtp-gadget`) | 🟢 pendiente pero **bajo valor**: ya tenemos Samba |
| `touchscreen-inhibit` | 🟢 menor |

### ❌ HDR: descartado por inviabilidad técnica

`ayn-odin-3.conf` de ArmadaOS declara `ARMADA_HDR_NITS=650`, pero **no se puede portar**:

- Nuestro gamescope **sí** tiene todos los flags (`--hdr-enabled`, `--hdr-itm-enable`,
  `--hdr-itm-target-nits`, `--hdr-itm-sdr-nits`, `--hdr-sdr-content-nits`).
- **El driver no expone HDR**: el conector `card0-DSI-1` **no tiene** `hdr_output_metadata`
  (la property que gamescope necesita para mandar metadatos HDR10PQ), ni `max_bpc`, ni
  `Colorspace`; el EDID sale de **0 bytes**. Es un bloqueo de la capa DRM/panel.
- Y el propio ArmadaOS lo deja **apagado por defecto** (`ENABLE_GAMESCOPE_HDR=1` es opt-in),
  señal de que tampoco les funciona bien con el mismo kernel.

Portarlo sería **código muerto**. Queda anotado por si algún día el driver expone la property.

> Dato a favor: su `ayn-odin-3.conf` pone `ARMADA_GAMESCOPE_FORCE_COMPOSITION_ROTATION=0`, o sea
> que **también usan rotación por hardware** como nosotros → su stack de pantalla es compatible.

### 🟡 Lo único que queda: rendimiento por juego (`armada_perf.py`)

Su daemon `armada_perf.py` (+ `armada-control`) aplica por juego, con `os.setpriority` sobre los
hilos de gamescope:

| Ajuste | Qué hace | ¿Lo tenemos? |
|---|---|---|
| `gamescopeNice: -20` | prioridad de CPU para gamescope | ❌ (lanzamos gamescope **sin** prioridad) |
| `gamescopeRr: false` | SCHED_RR para gamescope | ❌ |
| `gamescopeCores: null` | pinnear gamescope a unos cores | ❌ |
| `nice: 0` | prioridad del juego | ❌ |
| `wineTopology: true` | topología de CPU que ve Wine | ❌ |

Nuestro `pocknix-pergame-power` cubre **governor + power profile**, pero no la prioridad ni el
pinning. Es lo único con valor real que queda.

**Consideración antes de hacerlo**: dar `nice -20` a gamescope requiere privilegios (nice negativo
necesita `CAP_SYS_NICE`), así que no basta con prefijar el comando — hace falta un daemon como el
suyo o un `Nice=` de systemd. Y hay que medir: si gamescope acapara CPU, puede **empeorar** el
frame pacing en vez de mejorarlo. **Primero medir, luego decidir.**

---

## ⚠️ Contradicción detectada en nuestro propio código

`pocknix-steam` lanza gamescope con **`--mangoapp`** (línea ~182):

```bash
gamescope "${GS_OUTPUT[@]}" ... --xwayland-count 2 --mangoapp --backend drm \
```

Pero el `AGENTS.md` dice explícitamente:

> **NO usar `--mangoapp` de gamescope** (modelo SteamOS: mangoapp como hermano).

O el AGENTS.md está desactualizado, o el flag se coló. **Hay que aclararlo** (afecta al HUD y a
cómo se lanza Steam).
