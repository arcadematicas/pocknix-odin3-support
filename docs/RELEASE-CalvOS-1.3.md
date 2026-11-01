# Release **CalvOS 1.3** — AYN Odin 3

**Fecha**: 1/11/2026 · **Artefacto**: `pocknix-sm8750-sd.img` (24,5 GiB; 11,6 GB comprimida)

```
sha256 (img)  13cbc1de85779cb6086132f463e3290619942567604573f8fd5b2544cff43431
sha256 (zst)  31ee0c4f7939fc1a02b21c99e926ee4b54ee5f7a23b1e312592307a4c481d8d1
```

Se graba en una microSD y arranca desde ella: **la memoria interna no se toca**.

Versión anterior publicada: **CalvOS 1.2 (11/10/2026)**. Esto es lo que ha cambiado desde entonces
(el árbol de build lo sigue llamando internamente "0.4"; la numeración pública es CalvOS 1.x).

---

## 1. Actualizaciones: repositorios propios (lo que faltaba en 1.2)

La 1.2 se actualizaba desde nuestro repo, pero **el refactor de escritorio nunca se publicó**: el
paquete `pocknix-desktop` pasó a depender del virtual `pocknix-desktop-flavour` y **no había ningún
proveedor publicado en R2**, así que cualquiera que intentara actualizar se encontraba una transacción
rota. En casa no se notaba porque compilamos del árbol. **Ahora está publicado y probado** (Jarvis
actualizó su Odin sin `--overwrite`).

- **Tres repos firmados** (clave `85C433EE12621EED`): `[pocknix]` (SoC), `[pocknix-shared]` y
  `[pocknix-base]`. **Sin `[aur]`** (ofrecía paquetes que bajaban versiones y rompían el sistema).
- **Base ALARM espejada**: snapshot `20260826.2` con 893 paquetes en `[pocknix-base]`, así un `-Syu`
  resuelve contra el snapshot congelado y **no** contra la ALARM viva.
- **`pocknix-base` / `pocknix-update`**: política `--overwrite` acotada y autorreparación de ficheros
  huérfanos que dejaron las imágenes viejas.
- **El kernel entra siempre por paquete** (`linux-pocknix-sm8750`): el hook 90 regenera
  `/flash/KERNEL` y el 91 mantiene el par. Además `pocknix-kernel-guard` comprueba a los 75 s que los
  módulos son del mismo build y, si no, reinstala desde `/flash/modules-<ver>.tar.zst` y reinicia una
  vez. `pocknix-core 0.1.0-6`.
- **Publicado lo que estaba solo en el árbol**: sabores de escritorio (`pocknix-desktop-plasma-mobile`,
  `-kde`), `pocknix-homescreen`, `msm-firmware-loader` y el overlay sin ficheros duplicados.
- Herramientas nuevas de control: `check-sync.sh` (el build **aborta** si el árbol no coincide con el
  centro), `check-kernel-patches.sh` (falla con cualquier `.rej`) y `check-upstream-packages.sh`.

## 2. Escritorio y personalización

- **Plasma Mobile** como escritorio único (`pocknix-desktop` → `plasma-mobile`), con
  `pocknix-homescreen`, `plasma-nano` y el arreglo táctil del panel. El sabor Plasma de ratón **no se
  publica** (la Odin es táctil).
- **Branding completo**: splash de arranque (plymouth), splash de Plasma, fondo `PocknixOS` 1920×1080 y
  seed del fondo en el primer login. Fondo de arranque `odin3-splash`.
- **KScreen instalado** de serie: Ajustes → Pantalla funciona, rotación 270 y escala correctas.
- **Baloo (indexador) apagado por defecto** sin pisar `~/.config`; el overlay ya **no** empaqueta
  `baloofilerc` (era un choque de dos dueños y rompía la actualización sin `--overwrite`).
- **Un solo dueño por fichero**: `powerdevilrc` sale del overlay, `steamos-session-select` sale de
  `pocknix-desktop` (desde `-27` es de `pocknix-session`) → se acabaron los conflictos al actualizar.
- **Coredumps limitados a 1 GB** (antes hasta el 10 % del sistema de ficheros) y `systemd-oomd` con
  umbrales (95 % swap / 70 % de presión 45 s) para que un juego que se desmadre no arrastre el sistema.
- **Panel de Control de Hooandee vendorizado v0.76.0** (sin delta propio: el `hdr=True` del perfil
  `ayn_odin3` ya está en upstream) con *siembra-solo-si-falta* para que se autoactualice.
- **Tema Eclipse 0.3.5**: se instala **una vez** y a partir de ahí lo actualiza el Panel de Control
  (se acabó el pin que revertía la versión del usuario). CSS Loader incluido.
- **Dither 8bpc** del panel (armada) y bitácora de rotación/color por plano.

## 3. Batería

- **Salud real**: `charge_full_design` = **7.838.000 µAh**, upower da **98,6 %** de salud, 35,11 Wh y
  "tiempo hasta carga completa" (antes `ENODATA` y un 100 % inventado).
- **MangoHUD con % y tiempo correctos**: `CHARGE_NOW` sale del **coulomb counter** (`2102`/`2121`); el
  firmware devolvía `status.capacity` = 0.
- **Potencia real**: `power_now = V×I` (`2108`) → 4,87 W medidos frente a los ~51 W falsos.
- **Perfiles de energía fiables desde el arranque**: el `adreno` reescribía `max_freq` 10 s después del
  probe y la consola arrancaba a 389 MHz. Ahora `pocknix-power-profile verify` aplica, comprueba y
  exige que el valor **aguante 6 s**; una regla udev y un hook al despertar lo repiten. En `medio`:
  **832 MHz GPU / 2,84 GHz prime**; en `alto`: **4.320.000 Hz** y 1,1 GHz.
- **Ventilador estable**: el `pwm-fan` registraba cooling device y el thermal lo movía a saltos
  (0↔225 con el SoC a 50 °C), pisando la curva del panel. Sin `#cooling-cells` el rango queda **27-59**
  y no hay oscilaciones audibles (probado con *The Quarry*).
- **LED de carga**: pendiente (el canal PWM 3 lo usa el ventilador y el trigger de SteamOS no existe en
  nuestro kernel; irá con un servicio que lea `power_supply`).

## 4. Suspensión

- **`deep` por defecto** (antes `s2idle`): noche completa **0,14 %/h** en 13 h 31 min (1,85 % de
  batería) frente a **0,44 %/h** con `s2idle`. Es el **tercio** de consumo.
- Antes de eso: **0,37 W → 0,24–0,26 W** dormida (hooks `zz-inputplumber` y `zz-wifi`, udev
  `99-wifi-pm`, limpieza de parches que peleaban entre sí).
- **GMU al despertar arreglada** (kernel 28, parches `2122`/`2123` de armada): la IRQ HFI limpia solo
  CM3 y la máscara va antes de arrancar la GMU. **Desaparecen** `a6xx_gmu_resume`, `GMU OOB` y
  `44050000 preemption timed out`. Confirmado por Jarvis y por nuestra consola.
- **WiFi y suspensión** (BSP 42, hook `zz-wifi`): el `ath12k` abortaba con `-110`; ahora el PCI
  (`17cb:110e`) sale en `pre` y se re-escanea en `post`, y `wlan0` vuelve sola.
- **SoCCP en D3**: faltaba `firmware-name` en el DTS; ahora `remoteproc0` está *running* y el
  coprocesador suelta el voto de bus (`in D3, boot bus vote dropped`).
- **Isla SSC apagada** de forma controlada (`msm-firmware-loader 1.8.0-6`, `hexagonrpc 0.5.0-3`,
  `libssc 0.4.4-2`): con la isla activa, un `s2idle` justo después de cerrar un sensor colgaba el SoC.
- **Auditoría**: 9 h suspendida y despertar limpio; `pocknix-sleep-report` mide con `charge_now` (µAh)
  y vatios medios, así que las cifras son comparables.

## 5. Audio: auriculares sí, micrófono sigue pendiente

- **Auriculares: volumen real**. Los controles HPH del WCD939x venían del wcd938x y no hacían nada: la
  etapa estaba clavada a **+6 dB** (el doble). Con `2109` van a `HPH_NEW_INT_PA_GAIN_CTL` y 0 dB es 0 dB.
- **Sin chisporroteo**: apagar la *compander* en la UCM no basta porque DAPM la reactiva; el vigilante
  `pocknix-audio-jack` la apaga y la vigila en cada pasada.
- **Conmutación en ~17 ms** (antes *polling* cada 2 s): `pactl subscribe` con red de seguridad; el
  ecualizador del panel sigue al sink por defecto y se reengancha solo.
- **Altavoz**: era la **ruta** (el códec dejaba `HPHL/HPHR`, `RDAC` y `CLSH` encendidos), no el
  volumen. Aclarado que `SPK_L/R PCM Playback Volume` de los AW88166 es **atenuación** (0 = máximo).
- **Suelo de latencia** de PipeWire (`min-quantum = 512`) para evitar los `Broken pipe`.
- **Micrófono**: el UCM ya tiene `Mic` (DMIC2/3 → `SWR_MIC6`) y `Headset` (wcd939x → `SWR_MIC1`, con
  `Mic Jack`), PipeWire los expone y el perfil de auricular con micro aparece… **pero la captura sigue
  a cero**: el front-end abre el backend del códec del jack en vez de `TX_CODEC_DMA_TX_3`, y el UCM de
  armada pide interruptores que en nuestro kernel no existen. **Es lo próximo**, junto al giroscopio.

## 6. GPU, vídeo y HDR

- **Iris completo**: los 10 parches de armada (`0016-0025`) con **stage 1**, `low_latency`, AV1 tier,
  CABAC, sesiones a reloj máximo y el fix del buffer de cambio de resolución. Además `2110` (smp2p),
  `2111-2114` (macros de audio a pm-clock) y el stack aplica con **0 `.rej`**.
- **Mesa `2:26.3.0`** y **Turnip de Valve 0.5.x** como payload por juego (`pocknix-turnip-arm` /
  `-x86`). Medido en Dead Island: mismo FPS, **1 % low +31 %** y tirones 22 → 3.
- **gamescope `1:3.16.31.ogc1-3`** con el stack de color/HDR de armada (perfil edidless del panel,
  650 nits, gamma22, color por plano). HDR **apagado por defecto** (con HDR global el QAM y MangoHUD se
  quedaban detrás); el toggle de PocknixControl sigue disponible y Ori lo activa solo.
- **Captura por hardware**: `calvos-grabar` graba 1080p60 en tiempo real con el encoder H.264 del SoC
  (~27 Mbps, modo `kms` o `x11`). `dock-check` diagnostica la salida externa.
- **Moonlight 6.2.0** emparejado con Sunshine (VAAPI, `av1_mode = 0`): streaming estable. HDR por
  streaming **no** es posible aún (Moonlight negocia NV12; issue `moonlight-qt#2081`).

## 7. Mandos, Steam y juegos

- **Mando que se congelaba**: carrera real en `uhid_char_read()` (leía `outq[tail]` sin `qlock`). Un
  NULL podía matar el dispositivo uhid con `devlock` tomado y Steam se quedaba esperando *feature
  reports* hasta reiniciar. Parche `0014`.
- **QAM jugando**: `steamui-watchdog` ya no cuenta fallos ni reinicia la UI mientras hay un juego (ese
  reinicio a mitad de partida era el "se traba el QAM").
- **Atajos de Steam que desaparecían**: `pocknix-steam-sync` escribía `appname`/`exe` en minúsculas y
  Steam los descartaba. Corregido a `AppName`/`Exe`; los tiles sobreviven a los reinicios.
- **Por juego**: *Mesa Version* y MAKO en el Panel de Control; `fex-emu 2610` probado con juegos x86.
- **Wind Waker HD v0.4.0** nativo ARM64 desde Steam (sin WProton), en castellano, 1080p interno y
  save states compartidos con el PC.
- **DeckStation** sin el límite de la API de GitHub (feed Atom + HTML cuando la API da 403) y WProton
  `1.72` con caché, reintentos y token opcional.

## 8. Herramientas nuevas

- **`calvos-doctor`** (instalado): recoge kernel, paquetes, audio, panel, batería y logs, **redacta**
  rutas, usuario, hostname, MAC, IP, SSID y seriales, y **solo envía con `--send`**.
- **Informes desde el panel**: botón *"Enviar informe"* en la pestaña Sistema → POST a nuestro
  colector (Worker de Cloudflare) → issue en `arcadematicas/calvOS-reports`. El token de GitHub vive
  **solo** en el Worker.
- **`pocknix-sleep-report`** (consumo real en suspensión), **`calvos-grabar`**, **`dock-check`**,
  `pocknix-tools` con instalación en flash interna (`--exclude /opt`) y `tools/check-hooandee.sh`.

## 9. Versiones que lleva la imagen

| Paquete | Versión |
|---|---|
| `linux-pocknix-sm8750` | **7.2.12-28** (GMU `2122`/`2123`, `CHARGE_NOW` `2121`, iris completo) |
| `pocknix-bsp-sm8750` | **0.2.0-42** (`deep` por defecto, hook `zz-wifi`, `cma=256M`) |
| `pocknix-system-overlay` | **0.1.0-11** |
| `pocknix-core` | 0.1.0-6 |
| `pocknix-decky` | **0.1.0-63** en la imagen (la 64 publicada es el mismo contenido; se sustituye sola) |
| `mesa` / `vulkan-freedreno` | **2:26.3.0** |
| `gamescope` | **1:3.16.31.ogc1-3** |
| `msm-firmware-loader` | 1.8.0-6 |
| `fex-emu` | 2610.20261012.896a8691 |
| `moonlight-qt` | 6.2.0 |

Repos configurados: `[pocknix]`, `[pocknix-shared]`, `[pocknix-base]`. `pacman -Syu` limpio, 0
conflictos, 0 servicios fallidos.

## 10. Descarga

Tres volúmenes 7-Zip en el grupo de releases de Telegram:

👉 **https://t.me/+Pz1kfKX8UZs0OWE0**

```
pocknix-sm8750-sd.7z.001  3,9 GB  317049c5a7109e2bb0ddddf1e166f23924bb77cb03652d714bead4c669375a4d
pocknix-sm8750-sd.7z.002  3,9 GB  d34caf76e3c132d34120f1ba41d019e7d40e9f6a1d665d800fd61a423d15cbe7
pocknix-sm8750-sd.7z.003  3,8 GB  e501fc94f464a0f3a6892d1db8bc1ceb7576aa63575b283c59678ca3cb5d62f9
```

**Cómo se abre** (7-Zip 23+, PeaZip, o cualquier gestor con volúmenes `.7z.00X`):

1. Doble clic en `.7z.001` → *Extraer*: se unen solos y sale `pocknix-sm8750-sd.img.zst`.
2. Doble clic en el `.zst` → *Extraer*: sale `pocknix-sm8750-sd.img` (24,5 GiB).

Si el 7-Zip es antiguo y no abre `.zst`: `zstd -d pocknix-sm8750-sd.img.zst`.

## 11. Flashear

```sh
lsblk                       # confirmar el dispositivo, sin equivocarse
sudo dd if=pocknix-sm8750-sd.img of=/dev/sdX bs=4M conv=fsync status=progress
```

En Windows: BalenaEtcher o Raspberry Pi Imager.

Usuario `deck`, root `pocknix`, SSH desactivado por defecto (se activa en Pocknix Tools).

## 12. Actualizar desde 1.2

Se puede, pero **recomendamos flashear**: el salto incluye kernel, BSP y el refactor de escritorio
completo. Si actualizas en caliente, haz la primera pasada con la política de actualización del repo
(la de 1.2 necesitaba `--overwrite` para ficheros huérfanos) y comprueba `pacman -Q pocknix-desktop`
antes de reiniciar.

## 13. Pendiente conocido

- **Micrófono**: captura a cero (enrutado ALSA/UCM; auriculares y micro del jack ya declarados).
- **Giroscopio**: falta portar `inputplumber 0005-0008` + `libssc 0005` a 0.83.0.
- **HDR por streaming** en Moonlight (limitación del cliente).
- **LED de carga** y **formateo de SD desde Steam** (upstream lo movió a Ajustes → Almacenamiento).
- El torrent existe pero es **solo LAN** (CGNAT del operador).

## Gracias

A **Jarvis (DaViDuSkY)** por las pruebas de suspensión en su Odin, el hallazgo del `ath12k` y no
rendirse con la actualización; y a quienes reportasteis los cuelgues del QAM y del resume.
