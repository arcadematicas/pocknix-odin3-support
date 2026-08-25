# pocknix-os · AYN Odin 3 (SM8750 / Snapdragon 8 Elite)

Aportes para hacer que **pocknix-os** corra en el **AYN Odin 3** (plataforma
SM8750, Adreno 830). El objetivo es que el proyecto pocknix pueda **fusionar
este soporte** y ofrecer el Odin 3 como dispositivo soportado.

## Estado actual
- ✅ **Arranca** (kernel 7.1.0 + DTS de dispositivo).
- ✅ **Sesión de juego** (gamescope + Steam Deck gamepadui) **estable**, sin
  `VkDeviceLost`.
- ✅ **Mando + táctil** funcionando (InputPlumber).
- ✅ **WiFi** (NetworkManager) + **cuenta de Steam** + **juegos**.
- ⚠️ **Escritorio (Plasma Mobile)**: arranca, pero **KScreen no enumera el
  panel** (Ajustes no muestra el monitor ni la rotación) — *open issue*.

## Qué contiene
| Ruta | Qué es |
|---|---|
| `kernel/cq8725s-ayn-odin3.dts` | DTS del dispositivo Odin 3 (SM8750) |
| `kernel/0001-adreno-a8xx-force-gx-collapse-before-cx.patch` | **Fix del GPU** (VkDeviceLost / GMU GX-GDSC) |
| `config/session-fixes.md` | Ajustes de userspace (openal, lsof, InputPlumber, WiFi, NM) |
| `KSCREEN-ISSUE.md` | Issue abierto: KScreen no ve el panel en escritorio |

## Lo más valioso para upstream
1. **Adreno a8xx GX-collapse fix** — resuelve el `VkDeviceLost` del compositor
   en Adreno 830 (SM8750). Afecta a GPU de esta familia.
2. **DTS del Odin 3** — soporte de dispositivo SM8750 (panel, WiFi, mando).
3. **Ajustes de sesión** — el recetario para que gamescope/Steam funcionen.

## Notas
- Basado en kernel 7.1.0 (sm8750).
- Sin credenciales/secretos.
- El trabajo se hizo en un fork local; estos artefactos están listos para
  portar/mergear.
