# FIRMWARE — Odin 3 (SM8750): blobs que linux-firmware NO trae

**Fecha**: 13/09/2026
**Estado**: RESUELTO en `pocknix-os` rama `odin3-pr` (commit `fbe787e`) — pendiente de validar con imagen limpia.

## Síntoma

Una imagen limpia de Pocknix para la Odin 3 **arrancaba pero**:

- **sin WiFi**: `iw dev` vacío, `nmcli radio` → `WIFI-HW missing`, no existe `wlan0`.
- **sin sonido**: `/proc/asound/cards` → `no soundcards` (aunque PipeWire corría).
- (de paso) **arranque lentísimo** y pantalla negra en el primer boot.

La instalación interna de la Odin funcionaba porque los blobs se habían copiado
a mano; el build **nunca** los instalaba en las rutas correctas.

## Diagnóstico (dmesg de la Odin, imagen limpia)

```
# WiFi
ath12k_wifi7_pci 0000:01:00.0: Wi-Fi 7 Hardware name: wcn7860 hw2.0
mhi mhi0: Direct firmware load for ath12k/WCN7860/hw2.0/amss.bin failed with error -2
ath12k_wifi7_pci 0000:01:00.0: failed to power up :-110
ath12k_wifi7_pci 0000:01:00.0: probe with driver ath12k_wifi7_pci failed with error -110

# ADSP/CDSP
remoteproc0: adsp is available
remoteproc0: Direct firmware load for qcom/sm8750/ayn/odin3/adsp.mbn failed with error -2
remoteproc0: request_firmware failed: -2
remoteproc1: Direct firmware load for qcom/sm8750/ayn/odin3/cdsp.mbn failed with error -2
# -> ambos quedan OFFLINE

# Audio (con ADSP arriba, ya se ve el siguiente fallo)
aw88166 4-0034: Direct firmware load for qcom/sm8750/ayn/odin3/aw883xx_acf.bin failed with error -2
aw88166 4-0034: aw88166_codec_probe failed
snd-sc8280xp sound: ASoC: failed to instantiate card -2
qcom-apm gprsvc:service:2:1: Direct firmware load for qcom/sm8750/SM8750-AYN-tplg.bin failed with error -2
qcom-apm gprsvc:service:2:1: ASoC error (-2)
```

## Causa raíz

1. **El chip WiFi de la Odin 3 es `WCN7860`** (no `WCN7850`). El driver ath12k
   busca `ath12k/WCN7860/hw2.0/`; el rootfs solo traía `WCN7850/` (chip distinto)
   y **linux-firmware upstream no tiene WCN7860 en absoluto** (verificado en
   `git.kernel.org/.../linux-firmware.git` a fecha 13/09/2026).
2. El **DTS** (`cq8725s-ayn-common.dtsi`) declara:
   - `firmware-name = "qcom/sm8750/ayn/odin3/adsp.mbn"`
   - `firmware-name = "qcom/sm8750/ayn/odin3/cdsp.mbn"`
   - `firmware-name = "qcom/sm8750/ayn/odin3/aw883xx_acf.bin"` (x2, altavoces)
   pero el override de pocknix instalaba el ADSP en `qcom/sm8750/` (sin `ayn/odin3`).
3. Faltaban además `qcom/sm8750/SM8750-AYN-tplg.bin` (topology del DSP) y los
   `.jsn` (adspr/adsps/adspua/adspuo/cdspr/battmgr).

## Solución

El firmware vive en **`ROCKNIX/extra-firmware`** (rama `master`), directorio
`SM8750/`, que se copia a `/usr/lib/firmware/`. Contiene TODO lo que falta:

```
SM8750/ath12k/WCN7860/hw2.0/   amss.bin board-2.bin m3.bin aux_ucode.bin bdwlan.elf qdss.cfg regdb.bin
SM8750/qcom/sm8750/ayn/odin3/  adsp.mbn adsp_dtb.mbn cdsp.mbn cdsp_dtb.mbn aw883xx_acf.bin
                               adspr.jsn adsps.jsn adspua.jsn adspuo.jsn cdspr.jsn battmgr.jsn
SM8750/qcom/sm8750/            SM8750-AYN-tplg.bin  (+ KONKR/MTP/QRD)
```

Cambios en `pocknix-os` (rama `odin3-pr`, commit **`fbe787e`**):

- `scripts/sync.sh`: descarga `ROCKNIX/extra-firmware` **pinnado al commit
  `30c56e2f34af37fe372166b739d6ab277f5155b5`** (tarball cacheado) → `vendor/rocknix-extra-firmware/`
  (gitignored; **sin binarios en el repo**, como pidió el maintainer).
- `devices/sm8750/profile.conf`: nueva variable `FW_EXTRA_SRC_REL=rocknix-extra-firmware/SM8750`.
- `scripts/build-image.sh` `install_firmware()`: para `SOC=sm8750` llama a
  `install_extra_firmware()` (rsync `--chown=root:root` del árbol → `/usr/lib/firmware/`);
  **muere con mensaje claro** si falta (hay que `make sync`).
- `devices/sm8750/firmware/qcom/sm8750/ayn/odin3/{adsp.mbn,adsp_dtb.mbn}`: movidos a la
  ruta que pide el DTS (eran el override del fix de batería).
- `.gitignore`: cubre la ruta nueva.

## Verificado en caliente (13/09/2026)

Copiando los blobs a la Odin y reiniciando:

- `wlan0` UP, conectada a la red, `iw dev` muestra `ssid`, canal 52 (5 GHz).
  `ath12k: fw_version 0x10048fe1 ... WLAN.GNG.1.0-04065-...`
- `remoteproc0/1` (adsp/cdsp) → `running`.
- `/proc/asound/cards` → `0 [SM8750AYN]: sm8750 - SM8750-AYN`; PipeWire lista
  `Built-in Audio Headphones playback` + `Speaker playback`.
- Steam arranca y **el login funciona** (`connection_log`: `RecvMsgClientLogOnResponse() : 'OK'`).

## Bug colateral encontrado: `pocknix-flathub.service` bloquea el arranque

En el primer boot el servicio `pocknix-flathub.service` se quedaba "activating"
descargando Flatpaks de Flathub (>300 MB) **dentro de la transacción de boot**,
bloqueando `multi-user.target`: la sesión de Steam no arrancaba (pantalla negra /
prompt) hasta que terminaba. Arreglado quitando `After=/Wants=network-online.target`
(solo el dispatcher de NM debe lanzarlo cuando hay enlace real). Commit en `fbe787e`.

## Pendiente

- Validar con una **imagen limpia recién construida** (`make build` + `make sd-image`
  en marcha el 13/09 por la tarde) — debe salir con WiFi + sonido + carga de fábrica.
- Con eso, abrir el PR a shuuri-labs (el firmware viene de su propia fuente,
  `ROCKNIX/extra-firmware`, sin binarios en el repo).
