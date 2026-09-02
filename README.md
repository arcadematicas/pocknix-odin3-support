# pocknix-os · AYN Odin 3 (SM8750 / Snapdragon 8 Elite)

Aportes para hacer que **pocknix-os** corra en el **AYN Odin 3** (plataforma
SM8750, Adreno 830). El objetivo es que el proyecto pocknix pueda **fusionar
este soporte** y ofrecer el Odin 3 como dispositivo soportado.

## Estado actual
- ✅ **Arranca** (kernel 7.2.0 + DTS de dispositivo).
- ✅ **Sesión de juego** (gamescope + Steam Deck gamepadui) **estable**, sin
  `VkDeviceLost`.
- ✅ **Mando + táctil** funcionando (InputPlumber, incluido el gamepad UART del
  Odin 3 vía driver `rsinput`).
- ✅ **WiFi** (NetworkManager) + **cuenta de Steam** + **juegos**.
- ✅ **Audio** — sound card `SM8750-AYN` funciona (ADSP habilitado).
- ✅ **Batería** — `pmic_glink` reporta capacidad correctamente.
- ✅ **ADSP + CDSP** corriendo (`adsp`/`cdsp` remoteproc `running`).
- ✅ **QAM** — botón Select abre el menú Quick Access.
- ⚠️ **Escritorio (Plasma Mobile)**: arranca, pero **KScreen no enumera el
  panel** (Ajustes no muestra el monitor ni la rotación) — *open issue*.
- ⚠️ **Rotación Plasma Mobile**: fix manual aplicado (`chattr +i` sobre
  `kwinoutputconfig.json`). Pendiente fix upstream de KScreen.
- ⚠️ **Sensores IIO**: `hexagonrpcd` compilado e instalado, pero los
  dispositivos IIO aún no aparecen — falta ajustar el `sns_reg_config`.

## Qué contiene
| Ruta | Qué es |
|---|---|
| `kernel/cq8725s-ayn-odin3.dts` | DTS del dispositivo Odin 3 (SM8750) — ADSP/CDSP habilitados, rutas firmware corregidas a `ayn/odin3` |
| `kernel/0001-adreno-a8xx-force-gx-collapse-before-cx.patch` | **Fix del GPU** (VkDeviceLost / GMU GX-GDSC). Complementario al `0050` de ROCKNIX |
| `kernel/0002-input-rsinput-uart-gamepad.patch` | **Fix del gamepad UART** (driver `rsinput`), necesario para el mando del Odin 3 en modo consola (backport a 7.2) |
| `config/session-fixes.md` | Documentación completa de todos los fixes (12 fixes documentados) |
| `config/odin3-post-boot-setup.sh` | Script de setup post-boot (suspensión, WiFi, rotación, sensores) |
| `config/ayn_mcu.yaml` | InputPlumber fix: Select → QuickAccess (QAM) |
| `config/hexagonrpcd/` | hexagonrpcd cross-compile + service file para sensores IIO |
| `KSCREEN-ISSUE.md` | Issue abierto: KScreen no ve el panel en escritorio |

## Lo más valioso para upstream
1. **Adreno a8xx GX-collapse fix** — resuelve el `VkDeviceLost` del compositor
   en Adreno 830 (SM8750). Afecta a GPU de esta familia. **Complementario** al
   `0050` de ROCKNIX (el `0050` define el `.power_off` del GX GDSC pero solo
   colapsa con `synced_poweroff`; este parche es quien lo activa en
   `a8xx_recover` — ambos son necesarios).
2. **DTS del Odin 3** — soporte de dispositivo SM8750 (panel, WiFi, mando),
   con firmware ADSP/CDSP apuntando a `ayn/odin3/`.
3. **Driver gamepad `rsinput`** (backport a 7.2) — sin él no se detecta el mando
   del Odin 3 en modo consola.
4. **Ajustes de sesión** — el recetario para que gamescope/Steam funcionen.

## Notas
- Basado en kernel 7.2.0 (sm8750), rebasado sobre el árbol de ROCKNIX.
- El 7.1.0 funcionaba, pero el 7.2.0 no arrancaba salvo por 2 regresiones que se
  corrigieron: (1) el DTS apuntaba el firmware ADSP/CDSP a los genéricos
  `qcom/sm8750/*.mbn` y dejaba `remoteproc_cdsp` `disabled`; (2) el `.config` se
  había regenerado perdiendo opciones. Con el DTS corregido + `.config` del 7.1,
  el 7.2.0 arranca y **supera al 7.1.0** (CDSP activo, stack LPASS completo,
  Bluetooth, gamepad).
- Sin credenciales/secretos.
- El trabajo se hizo en un fork local; estos artefactos están listos para
  portar/mergear.
