# Bootanimation Odin 3 en Pocknix (splash de arranque)

Recreación del bootanimation oficial del AYN Odin 3 (el de Android) como splash
de arranque en Pocknix, **sin Plymouth** — dibujando los frames directamente en
`/dev/fb0` (el mismo mecanismo que usa ROCKNIX/`rocknix-splash`).

## Por qué no Plymouth

Plymouth se probó primero (tema `script` con los frames reducidos). Falla en el
panel DSI-1 de la Odin:

- El renderer **DRM** de plymouthd no dibuja en el conector DSI-1 (panel sin
  EDID). plymouthd se queda en `initialize_environment` sin abrir el socket
  cuando el VT/tty ya lo ocupa otro proceso, y en el arranque tomaba el tty1
  pero no pintaba nada (prompt congelado).
- El renderer **frame-buffer** tampoco avanzaba en pruebas en vivo porque kwin
  tiene el DRM master.

El enfoque de ROCKNIX (que sí funciona en handhelds) es **dibujar en `/dev/fb0`**
desde un servicio systemd ordenado antes de que el compositor tome el display.
ArmadaOS hace lo mismo con un binario C (`armada-splash`) + dracut, y desinstala
Plymouth a propósito ("plymouth would fight it for the VT").

## Cómo funciona

1. El bootanimation se extrae de la ROM Android del Odin 3 (ver más abajo).
2. Los frames se convierten a **raw BGRX del fb0** (`1080x1920`, stride `4352`)
   con la orientación corregida (ver `convert_frames.py`).
3. `odin3-splash-play.service` arranca en `multi-user.target`
   (`After=local-fs.target`) y el script `odin3-splash-play.sh` vuelca cada
   frame con `cat frame.raw > /dev/fb0` a ~30 fps.
4. Tras reproducir la animación una vez, mantiene el último frame (logo final,
   el `part1` estático del `desc.txt`) hasta que kwin/gamescope toma el display.
5. `timeout 1` en cada `cat`: si el write se bloquea (el compositor ya tiene el
   DRM master), el reproductor sale limpio.
6. **Plymouth queda enmascarado** para que no pelee por el VT:
   `systemctl mask plymouth-start plymouth-quit plymouth-quit-wait plymouth-read-write plymouth-quit-on-ready`.

## Detalles del panel / orientación

- El fb0 es `msmdrmfb`, **1080x1920 (portrait)** a nivel de scanout, stride
  `4352` (= 1080×4 + 32 padding), 32 bpp **BGRX**.
- El usuario sostiene la Odin en **landscape**, así que el contenido se dibuja
  con una transformación `flip(vertical) + transpose` para que se vea derecha:
  `fb0[y][x] = A[1080-1-x][y]` (verificado empíricamente con una imagen de
  prueba de flechas).
- No hay rotación de DRM aplicada (el archivo `rotation` del conector no existe;
  el `echo 3 > rotation` de `odin3-display.service` falla silenciosamente).

## Instalación en la Odin

```sh
# 1. Convertir los frames (en la PC, con Pillow+numpy):
#    python3 convert_frames.py           # lee frames_reduced/, escribe frames_raw/
#    tar czf frames_raw.tar.gz frames_raw/
#    scp frames_raw.tar.gz deck@<odin>:/tmp/

# 2. En la Odin:
sudo mkdir -p /usr/share/odin3-splash/frames
sudo tar xzf /tmp/frames_raw.tar.gz -C /usr/share/odin3-splash/ --strip-components=1
sudo mv /usr/share/odin3-splash/frame_*.raw /usr/share/odin3-splash/frames/ 2>/dev/null

# 3. Instalar servicio y script
sudo cp odin3-splash.service /etc/systemd/system/
sudo cp odin3-splash-play.sh /usr/local/bin/ && sudo chmod +x /usr/local/bin/odin3-splash-play.sh
sudo systemctl daemon-reload && sudo systemctl enable odin3-splash.service

# 4. Enmascarar Plymouth (si se probó antes)
sudo systemctl mask plymouth-start plymouth-quit plymouth-quit-wait \
  plymouth-read-write plymouth-quit-on-ready
```

## Extracción del bootanimation (desde la ROM)

La ROM del Odin 3 trae el sistema en `super_*.img` fragmentados
(`/run/media/.../Odin3_20251206/`). Los fragmentos NO son contiguos: hay huecos
entre los `start_sector` del `rawprogram_unsparse0.xml`. Para reconstruir:

```sh
# Reconstruir super (1111634 sectores de 4096, usando los start_sector del XML)
truncate -s $((1111634*4096)) super_combined.img
dd if=super_1.img of=super_combined.img bs=4096 seek=46888 conv=notrunc
# ... (cada fragmento en su start_sector)
# Extraer la particion super (lun 0) y desempaquetar con lpunpack
dd if=super_combined.img of=super_part.img bs=4096 skip=46888 count=1064746
lpunpack super_part.img super_out/
# Montar product_a.img -> /tmp/product_rom
# El bootanimation esta en: /tmp/product_rom/media/bootanimation.zip
```

`bootanimation-odin3.zip` (original, ~105 MB) se conserva **localmente** en
`config/` pero **no está versionado** en Git (excede el límite de 100 MB de
GitHub; ver `.gitignore`). Su `desc.txt`: `1920 1080 30` — `p 1 1 part0`
(animación, 1 loop) + `p 0 0 part1` (logo final estático). Los frames reducidos
(`frames_reduced/`, 960x540, 24 MB) se generaron para el intento de Plymouth;
`convert_frames.py` los escala a 1920x1080 antes de aplicar la transformación.

## Referencia

- Mecanismo de ROCKNIX: binario `rocknix-splash` en initramfs + servicio que
  dibuja en fb0 (`cat frame.raw > /dev/fb0`); ver mod de la comunidad
  `amosjerbi/rocknix-splash`.
- Mecanismo de ArmadaOS: `armada-os/armada-packages/armada-splash` (C + libdrm,
  módulo dracut `91armada-splash`, desinstala Plymouth).
