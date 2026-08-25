# Open issue: KScreen doesn't enumerate the panel (Plasma Mobile desktop)

## Symptom
On the AYN Odin 3 running pocknix-os (kernel 7.1.0, plasma-mobile), the **game
session works** but the **desktop (Plasma Mobile)** has display problems:

- System Settings → Display shows **no monitor** (no resolution / rotation).
- The quick-settings **screen rotation** toggle isn't available.
- System Settings shows an error **"could not find plugin usr"** (partially).

The panel is **connected and enabled** at the DRM level (`card0-DSI-1`,
1080x1920, status=connected, enabled=yes) and **kwin_wayland sees it**
(`org.kde.KWin.activeOutputName` → `DSI-1`), but **KScreen** exposes no outputs
(`/org/kde/KScreen/Output` → UnknownObject; `kscreen-doctor -o` empty).
The screen renders (composited) but is **180° rotated** in the desktop, and
kwin ignores the panel `rotation` property from the device tree.

## Environment
- Kernel: 7.1.0 (sm8750), mesa 26.1.6, kwin 6.7.4, plasma-mobile 6.7.4, Qt 6.
- Backends present: `KSC_KWayland.so`, `KSC_XRandR.so`, `KSC_Fake.so`.
- `kscreen_backend_launcher` runs with `WAYLAND_DISPLAY=wayland-0`, but the
  KWayland backend reports no outputs.

## What we tried (didn't solve)
- `kscreen-doctor -o` / `output.DSI-1.rotation.*` → no effect.
- `qdbus org.kde.KScreen requestBackend KWayland` → no effect.
- Restarting `plasma-kscreen.service` / killing `kscreen_backend_launcher` →
  still no outputs.
- Setting `rotation` in `~/.config/kwinoutputconfig.json` → kwin resets it to
  `None` (autoorotation "InTabletMode" overrides).
- Changing the panel `rotation` in the device tree → kwin ignores it (screen
  stays 180° off); gamescope is unaffected (it uses its own orientation flag).

## Ask
How to get **KScreen/KWayland** to enumerate the `DSI-1` output so the desktop
display settings (and rotation) work on a fixed-orientation handheld panel
under Plasma Mobile?
