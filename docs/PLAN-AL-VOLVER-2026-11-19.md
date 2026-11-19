# Plan al volver del viaje — estado 19/11/2026

Documento de retorno. Qué está hecho y verificado, qué queda, en qué orden y con qué riesgo.
Todo lo de hoy está publicado en R2 y **la Odin está actualizada y verificada**.

---

## 1. Estado verificado (19/11, tarde)

**Odin 3** (`deck@calvos.local` / `100.113.64.20`):
- Arranque ~55 s · **0 servicios fallidos** · **0 ciclos de ordenación**.
- `pocknix-game-session.target` **activo** (flujo nuevo de `pocknix-session 7` funcionando).
- Bridge de perfiles activo y sincronizado (`balanced ↔ medio`).
- Audio `PipeWire 1.6.11` OK; gamescope + Steam arriba.
- `/flash/KERNEL` reconstruido por el BSP (18M, `KERNEL.bak` conservado).

**Repos**: `check-sync: OK` (árbol = centro). Todo lo publicado hoy está commiteado.

---

## 2. Lo que queda, por orden

### A. Siguiente paso natural (bajo riesgo, sin decisiones)
1. **Probar la imagen SD** (`build/image/sm8750/pocknix-sm8750-sd.img`, sha256 en `.sha256`).
   Si va bien: `make publish-image` y actualizar notas de release.
   El CHANGELOG **ya está al día** con todo lo de hoy.
2. **`pipewire -2` en `pocknix-base`**: hoy el stack vive en `extra` y en la Odin hubo que forzarlo
   (`pacman -Syu extra/pipewire ...`). Una imagen nueva volverá a chocar. Arreglo: congelar el
   stack `-2` en el próximo snapshot de base (`extend-base`) o subir `-2` a `[pocknix-base]`.
3. **Limpieza menor**: unidades de usuario de Plasma que quedaron `failed` el 18/11 (restos del
   perfil escritorio; no afectan a Game Mode). Y `rustdesk.service` apareció `failed` una vez.

### B. Bloqueado por una decisión tuya
4. **`pocknix-tools` 25→28** (y el store): es una reescritura QML sobre **`pocknix-ui`**, que
   **no está publicado**. Sin decidir si publicamos `pocknix-ui`, el porte no compila.
   Opciones: (a) publicar `pocknix-ui` y portar; (b) quedarnos en 25 y no seguir upstream.
5. **`pocknix-steamos-shim` 9→10**: divergencia consciente. Nuestra 9 trae el OBE marker y los
   stubs del OOBE que upstream no tiene; su 10 solo reañade `priv-write` + regla polkit.
   Revisar solo si algo del OOBE se rompe.

### C. Riesgo alto — mejor conmigo delante
6. **`bsp-common` 28→41** (40 commits): no es copiar. Reescribe arranque:
   - `pocknix-boot-deploy` reensambla `/flash/KERNEL`;
   - `pocknix-repo-line` reescribe `/etc/pacman.conf`;
   - `00-pocknix-abl-gate.hook` ya **no bloquea** (usamos OpenABL desde hace tiempo).
   Parches nuestros a **reaplicar**: fallback al ABL, `HandlePowerKey=ignore`, target `deck`,
   reglas de mando/brillo, modo fan `off`, scripts de suspensión/scx.
   Plan: rama aparte → compilar → instalar en la Odin → 2-3 reinicios → comprobar audio, mando,
   suspensión y arranque. Rollback: snapshot btrfs + `KERNEL.bak`.
7. Tras el BSP: **`pocknix-snapshots` 10** y **`pocknix-lock-migrate` 6** (dependen de
   `bsp-common>=37`).

### D. Tanda 6 — kernel (cuando el resto esté cerrado)
8. `PREEMPT_DYNAMIC` (permite probar `preempt=lazy|full|voluntary` sin recompilar),
   `UCLAMP_TASK` (ojo: con scx cargado parte del efecto se pierde) y A/B de `HZ` 250 vs 1000.
   Protocolo ya escrito en `docs/KERNEL-CACHYOS-QUE-APROVECHAMOS.md`:
   frametime en 3 escenas + consumo 30 min en reposo + 5 ciclos de suspensión, un cambio por build.

### E. Cola larga
9. **Audio de Armada** (tanda 4): SoundWire SSP (auriculares Odin 3), reinicio en resume,
   PRs #902/#903, rebase kwin/powerdevil 6.8.3, PR #669 (apagado por batería baja).
10. **Odin 3 Portal**: el hardware sigue pendiente. El soporte ya está fusionado y publicado
    (`bsp-sm8750 -53`, firmware `-5`, DTS/UCM/InputPlumber). Cuando llegue, probar el DTS y el panel.
11. **CoD2-BRO**: instalado 1.0.2, última 1.0.6.
12. **Dino Crisis**: videos siguen en inglés (Wine/Proton no negocia H.264). Ruta viable:
    convertir AVI (`Movie/*.dat`, RIFF) a PSX STR + XA y sustituir vía `mods/movie/`.
    Texturas: Studio 0.1 no exporta; las claves de `mods/textures/index.txt` son suyas.

---

## 3. Lo que necesito de ti al volver

1. **Probar un juego ARM y uno x86** (FEX) para validar los backports del wrapper:
   - `envVars`: poner una variable en Default y otra en el juego; la del juego debe ganar.
   - `game-mode`: al cerrar el juego el Panel de Control debe reaccionar en caliente.
2. **Probar la imagen SD** antes de publicarla.
3. **Decidir `pocknix-ui`** (desbloquea tools/store).
4. Confirmar si los errores de `geni_i2c`/`dma` te suenan de antes (yo no puedo comparar: el
   journal solo guarda 2 arranques).

---

## 4. Recordatorios operativos (errores que ya hemos pagado)

- `make stage` **NO va con sudo** (rclone + gpg viven en tu cuenta). `make publish` necesita
  `DEVICE=sm8750` explícito o se va a `sm8550`.
- El pin de base vive en **el centro** (`config/pocknix.conf`). Si `make snapshot` lo escribe solo
  en el árbol, el siguiente `sync-to-os.sh` lo borra y el build se va contra ALARM vivo.
- `systemctl enable` puede dejar symlinks en `/usr/lib/systemd/system/*.wants` además de `/etc`;
  si un ciclo de ordenación reaparece, mirar **los dos** sitios.
- Un paquete recompilado con bytes distintos **exige** subir `pkgrel`.
