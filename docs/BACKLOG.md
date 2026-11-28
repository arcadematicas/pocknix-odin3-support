# Backlog CalvOS (vivo)

Actualizado: **27/11/2026 (noche)**. Este es el único sitio donde se apunta lo que queda;
cuando algo se cierra, se borra de aquí y queda en el historial (`docs/historico/`, CHANGELOG,
commits). Cada punto lleva **siguiente acción** y quién la puede hacer.

Leyenda: `[ ]` pendiente · `[x]` hecho · **(F)** Fransis delante · **(A)** Alfred solo.

---

## 0. Como se trabaja (para no perder nada)

- **Fransis pide en el chat**, en lenguaje normal; no hace falta que consulte nada. Alfred lo
  apunta aqui (si es trabajo nuestro) o en `docs/UPSTREAM-TRACKER.md` (si es en un repo ajeno),
  con siguiente accion. Si es una idea sin fecha, va a **Ideas** al final.
- **Para consultar**: solo hay dos sitios. `docs/BACKLOG.md` = lo que debemos hacer.
  `docs/UPSTREAM-TRACKER.md` = lo que hemos abierto/comentado fuera y en que estado esta
  (`Depende de: ellos / nosotros / hecho`).
- Al **empezar una sesion** se lee el backlog; al **cerrar algo**, se tacha/mueve al historial y
  se commit. Nada se queda solo en la conversacion.


---

## 1. Odin 3 — pruebas en la consola

- [ ] **(F)** Peanuts: abrir launcher, ver Metroid / Astral Chain / Echoes of Wisdom, preparar uno
      (10-40 min) y jugar. En el log debe verse `language: DM_LANG=es is es`.
- [ ] **(F)** Mando en modo juego con Peanuts (Steam Input ON y OFF). En escritorio ya va con
      `SDL_GAMECONTROLLER_IGNORE_DEVICES=0x2020/0x3001`.
- [ ] **(F)** RustDesk: escala **100 % + reconectar**; si el cursor cuadra, decidir 100 % o cliente
      web. (Bug KDE #466276.)
- [ ] **(F)** VA-API real: Moonlight H.264/HEVC y 4K HEVC en mpv; consumo; que no interfiera con
      captura/Steam.
- [ ] **(F)** DeckStation: PS2 (`ICO`/`Shadow of the Colossus`), PS3 (`Saint Seiya`), openbor.
- [ ] **(F)** MAKO 5 en Wind Waker: sin FG / FG ×2. LSFG (motor 4) no existe en ARM (documentado).
- [ ] **(F)** Audio: auriculares varias veces (SSP) y *crackle* de Proton/FEX (armada#893; probar
      solo `api.alsa.headroom=1024`).
- [ ] **(F)** Suspensión tras kernel 8 (audio en suspensión: ROCKNIX#3655).
- [ ] **(F)** SkywardRecomp v0.8.4 **sin** turnipfix; opcional: rama del PR #130 de Peanuts + `.nsp`.

## 2. Paquetes / repo

- [x] **(A)** `calvos-peanuts 0.1.0-1`: instalado en la Odin y **publicado** en el repo sm8750 (R2).
- [ ] **(A)** `calvos-rustdesk`: rehacer desde el **`.deb` oficial 1.5.3** (el AppImage lleva
      GStreamer 1.16 + libpipewire 0.2 y crashea al capturar en PipeWire 1.x). Incluir `.desktop`
      y unidad de servicio; mantener el `.deb` como fuente con sha256.
- [ ] **(A)** PyQt6: empaquetar (`calvos-pyqt6` con el wheel vendorizado) o dejar documentado el
      `pip --break-system-packages`; hoy es un paso manual.
- [ ] **(A)** `pocknix-system-overlay`: publicar el cambio (deps de Peanuts en `packages.list`; la
      env del mando pasó a `calvos-peanuts`).
- [ ] **(A)** **Reconstruir y publicar `pocknix-decky` y `pocknix-desktop`**: el repo ya quita el
      botón de Plasma Mobile del plugin y hace que `pocknix-desktop-select` lo rechace (shell roto,
      27/11/2026). En la Odin ya está parcheado en vivo; falta el paquete para una imagen nueva.
- [ ] **(A)** Gate de publicación: el `glibc` del repo `base` rompe `make stage`; se publica con
      `POCKNIX_STAGE_NOCHECK=1`. Arreglarlo de raíz.
- [ ] **(A)** Revisar si `pocknix-firmware-sm8750 0.1.0-5` está publicado tras el último cambio.
- [ ] **(A)** `docs/`: mover los pendientes antiguos (fechados) a `docs/historico/` cuando se
      cierren; este backlog manda.

## 3. Upstream — candidatos y estado

**Nuestros cambios que sí son candidatos a upstream** (no los parches de dispositivo):

- [x] **PR #1524 (Panel de Control, Hooandee)** — coerción motor **4→5 al guardar** y test de
      arch no soportada corregidos (`dc51f97`); **CI verde** y comentario puesto (28/11). Solo falta
      el review de Hooandee.
- [ ] **(A)** **PR aparte**: puente `power-profiles-daemon` → nivel TDP (perfiles de energía de
      Plasma en escritorio). No encaja en el PR de MAKO: toca `main.py` y un módulo nuevo.
- [ ] **RustDesk (rustdesk/rustdesk)** — abrir issue: *aarch64 AppImage bundles GStreamer 1.16 +
      libpipewire 0.2 → SIGSEGV (`pw_thread_loop_new`) al capturar con el portal ScreenCast/
      RemoteDesktop en PipeWire 1.x; el `.deb` funciona*. Adjuntar stack y versiones.
- [ ] **KDE #466276** (cursor con escalado; duplicados #471997, #524406) — comentar nuestro caso:
      Odin 3, 1 salida **rotada** a escala 1.5, RustDesk; workaround 100 % + reconectar; web client OK.
- [ ] **Armada / ROCKNIX** — compartir el fix del zumbido: `qcom,ssp-period = <6>` +
      `qcom,pcm-ports-mask = <0x204>` en `&swr1` (docs/AUDIO-ZUMBIDO-20261126.md); y ROCKNIX#3655
      (DSP en suspensión) cuando lo probemos.
- [ ] **Peanuts PR #130** — comentar que el AppImage necesita **`xcb-util-cursor`** además de
      zenity/PyQt6 (la doc no lo dice) y que en Linux el idioma va por `DM_LANG` en
      `settings.env`/`<titleID>.env`; ofrecer el hallazgo.
- [ ] **SkywardRecomp #19** — esperando respuesta; probar v0.8.4 y actualizar.
- [ ] **pocknix PR #81** — esperando review; no tocar.
- [ ] **metalmike17/appimage-vault** — revisar catálogo, ver qué sirve para la Odin y valorar
      integrarlo en la tienda (`calvos-appman` / Decky store).

## 4. Deuda técnica / seguridad

- [ ] Historia de git (~370 MB) con blobs borrados: reescribir **solo con visto bueno** de Fransis.
- [ ] Gate de publicación (ver arriba).
- [ ] Revisar permisos de `~/.config/environment.d` vs `/etc/environment.d` (el paquete ya trae el
      de `/etc`; el de usuario puede quedarse para pruebas).

## 5. Rutina automática (PC de sobremesa)

- 09:00 `watch-peanuts.py` · 09:05 `watch-releases.py` · 09:10 `upstream-tracker.py` ·
  09:15 `mako-check.sh` → Telegram. Cada aviso se traslada aquí o se cierra.
- Al empezar una sesión: leer este backlog, elegir 1-2 puntos y actualizarlo al terminar.

## 6. Ideas (sin fecha)

- Tienda de AppImages: revisar `metalmike17/appimage-vault` e integrar lo que sirva.
- Paquete propio de PyQt6 (`calvos-pyqt6`) para no depender de pip.
- Puente Plasma -> perfil de energia para el resto de dispositivos ARM (hoy es de la Odin).
