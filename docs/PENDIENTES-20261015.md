# PENDIENTES 2026-10-15

## 🔴 Push del centro APARCADO — rama `master` divergida + cambios ajenos sin commitear

**Estado:** el push de `pocknix-odin3-support` está **bloqueado**. Decisión de Fransis:
**esperar** (nada de `stash`, ni commitear trabajo ajeno sin confirmar que está acabado, ni
`--force`, ni rebase forzado).

**Causa del bloqueo (dos cosas a la vez):**

1. **La rama está divergida**: `master` está **ahead 4 / behind 11** respecto a `origin/master`.
   - **Behind 11**: la rama lleva **11 commits de retraso** — conviene alinearla pronto.
   - **Ahead 4** (los 4 commits locales a publicar):
     ```
     2366cb0  docs(actualizador-QAM): fase 2 completada el 2026-10-06 (ya no 'pendiente'); §8 sigue sin publicar
     3be1675  gamescope: subir a OGC 3.16.31-ogc1 + serie de armada 0001-0027 (QAM/MangoHUD con HDR)
     0655fd6  udev: regla permanente de clasificacion del mando del Odin 3 (ID_INPUT_JOYSTICK) + gamepad-quit
     2764de2  pocknix-control: quitar la UI de ventilador y HDR (ahora son del plugin Panel de Control)
     ```
2. **Cambios sin commitear de la tarea DeckStation** (ajenos a este push; **no tocar**):
   ```
    M packages/deckstation-arm/configs/deploy-manifest.txt        (tracked)
   ?? packages/deckstation-arm/configs/roms/desktop/Moonlight.sh
   ?? packages/pocknix-desktop/pocknix-desktop
   ?? packages/pocknix-desktop/powerdevilrc
   ```
   La `M` tracked hace que `git pull --rebase` **falle antes de empezar**
   (*"cannot pull with rebase: You have unstaged changes"*).

**Qué falta para desbloquear:**

1. Que **quien lleve la tarea DeckStation** commitee (o descarte) esos cambios.
2. Después, con el árbol limpio, publicar los 4 commits locales:
   ```sh
   cd ~/pocknix-odin3-project/pocknix-odin3-support
   git pull --rebase origin master
   git push origin master
   ```

**Nota:** `origin/master` tiene **idéntica copia base** del doc del QAM
(`docs/ACTUALIZADOR-QAM-2026-10-05.md`) → el rebase debería aplicar **limpio** (sin conflicto
de contenido). Si apareciera conflicto: `git rebase --abort` y parar.

**A salvo:** el commit `2366cb0` está vivo en local (el doc del QAM quedó corregido ahí).
