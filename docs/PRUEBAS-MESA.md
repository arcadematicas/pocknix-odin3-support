# PRUEBAS DE MESA — comparar nuestra Mesa con la de Valve (Deckard)

**Qué:** protocolo para medir si la **Mesa de Valve** (el paquete `deckard-mesa-linux-aarch64`
del Steam Frame) rinde mejor o peor que **la nuestra** (Mesa estable `26.2.3` y/o una build de
Turnip pineada en `/usr/share/pocknix/vk-arm/`).

**Por qué:** la Mesa de Valve es Mesa *main* de desarrollo (26.3.0_devel) compilada por Valve
para el SM8650, con sus propios flags y con `libgallium` dentro. Nuestro SM8750 (Adreno 830) es
del mismo linaje (Gen8) que ya funciona con Turnip ≥ 26.1, así que la prueba tiene sentido —
pero **nadie ha medido** si rinde más o menos. Sin medir, es una ciruela con nombre bonito.

**Cómo se hace:** las dos Mesas quedan como **payloads** de `vk-arm` y se eligen **por juego**;
el MangoHUD escribe un CSV por frame y `tools/mesa-bench-compare.py` los compara.

---

## 1. Preparar las dos Mesas

```bash
# nuestra referencia (ya está en la imagen)
ls -d /usr/share/pocknix/vk-arm/*/

# la de Valve: dry-run primero (dice qué haría sin tocar nada)
tools/install-deckard-mesa.sh --dry-run
sudo tools/install-deckard-mesa.sh          # instala la última del repo de Valve
# o, sin red, desde un paquete ya descargado:
sudo tools/install-deckard-mesa.sh --file /home/fransis/deckard-paquetes/deckard-mesa-linux-aarch64-26.3.0_devel+gitabc426bb-1-aarch64.pkg.tar.zst
```

Queda en `/usr/share/pocknix/vk-arm/<version>-valve/` (p. ej. `26.3.0-valve`): el nombre es la
versión de Mesa **sin** el sufijo `_devel+git<hash>`, para que sea estable entre bumps del mismo
punto de release (un `26.3.0` nuevo sobrescribe el directorio en vez de acumular uno por hash).
La pkgver completa que se instaló sí queda en `VERSION.txt` dentro del directorio. Al repetir la
instalación, la versión anterior de ese mismo directorio se aparta a `26.3.0-valve.prev`.

> ⚠️ **El menú de PocknixControl está en el BACKEND, y el desplegable solo pinta directorios que
> tengan `icd.json`.** Si no aparece la entrada, mira que el directorio tenga el `icd.json`
> (el `.prev` no lo tiene a propósito, para que no se pueda elegir por error).

### Cómo llevar el script a la Odin

`tools/sync-to-os.sh` sincroniza `packages/`, `overlay/`, `kernel/` y la capa vendored, **pero no
`tools/`**: el script y el comparador hay que copiarlos a la Odin a mano (o añadirlos al sync si
los quieres en la imagen).

```bash
# 1) el script (desde el PC)
scp pocknix-odin3-support/tools/install-deckard-mesa.sh odin:/tmp/
scp pocknix-odin3-support/tools/mesa-bench-compare.py   odin:/tmp/
ssh odin 'sudo install -Dm755 /tmp/install-deckard-mesa.sh /usr/local/bin/pocknix-mesa-valve'

# 2) el comparador, en el PC (el CSV se genera en la Odin y se copia aquí)
scp 'odin:/home/deck/mangologs/*.csv' ./mangologs/
./tools/mesa-bench-compare.py nuestra-26.2.3:mangologs/a.csv valve:mangologs/b.csv

# 3) si instalas desde un paquete ya descargado, ese .pkg.tar.zst también va a la Odin:
scp deckard-paquetes/deckard-mesa-*.pkg.tar.zst odin:/tmp/
ssh odin 'sudo pocknix-mesa-valve --file /tmp/deckard-mesa-*.pkg.tar.zst'
```

### Dependencias: `libdisplay-info`

El driver de Valve está compilado contra las librerías de **SteamOS**, no contra las nuestras. La
diferencia que nos ha mordido: SteamOS construye `libdisplay-info` con el **soname
`libdisplay-info.so.1`** y nuestro sistema (`libdisplay-info` 0.3.0) instala el
**`libdisplay-info.so.3`**. El loader busca por soname *exacto*, así que sin un `.so.1` el ICD
**no carga** — y sin decir nada, porque `vulkaninfo` simplemente no lista el dispositivo:

```console
$ ldd /usr/share/pocknix/vk-arm/26.3.0-valve/libvulkan_freedreno.so | grep 'not found'
	libdisplay-info.so.1 => not found
```

**El apaño** (crea el soname que falta apuntando al fichero real que ya tenemos):

```bash
sudo ln -sf libdisplay-info.so.0.3.0 /usr/lib/libdisplay-info.so.1
VK_DRIVER_FILES=/usr/share/pocknix/vk-arm/26.3.0-valve/icd.json vulkaninfo --summary
```

> ⚠️ Es un apaño, no una solución: si `libdisplay-info` actualiza y cambia de soname (o lo
> borra al reinstalar el paquete), hay que repetirlo. Por eso el script **no se queda ahí**.

`install-deckard-mesa.sh` lo hace solo, en este orden de preferencia:

1. **Revisa TODAS las dependencias** con `ldd` sobre el driver recién extraído y lista las que
   no resuelven. Si el `.so` es de otra arquitectura que el host (nuestro PC es x86_64 y el driver
   aarch64), `ldd` no vale: lee los `DT_NEEDED` con `readelf` y comprueba cada soname contra la
   caché de `ldconfig` y los directorios habituales.
2. **Si hay `patchelf`** (lo preferred): copia la gemela **dentro del payload** con el soname que
   pide Valve y pone `RPATH=$ORIGIN` (como `DT_RPATH`, con `--force-rpath`, que es lo que hace
   falta para lo que se carga con `dlopen`). El payload queda **autocontenido y `/usr/lib` no se
   toca**. → `sudo pacman -S patchelf`
3. **Si no hay `patchelf`**: crea el symlink en `/usr/lib` (o en `$POCKNIX_LIB_DIR`), **avisa** de
   que es un apaño, y apunta a la gemela con el soname real más alto que encuentre.
4. Cualquier otra dependencia sin resolver se avisa una por una: si el ICD no carga, casi
   siempre es porque falta una.
5. **Al final lo comprueba de verdad**, no se fía del script:
   `VK_DRIVER_FILES=<payload>/icd.json vulkaninfo --summary` tiene que mostrar `turnip`. Como root
   lo lanza con `runuser` como el usuario de la sesión (root no ve el `/dev/dri` del usuario), y
   el resultado sale en el `RESUMEN`. **Si no aparece turnip, borra el symlink que ha creado él
   mismo** y deja el sistema como estaba. Con `--no-verificar` se salta (útil sin GPU visible).

En la Odin, `patchelf` **no** está instalado, así que va por el symlink:

```console
AVISO: patchelf NO esta instalado: no puedo meter libdisplay-info.so.1 en el payload con RPATH
AVISO:    -> creo el symlink /usr/lib/libdisplay-info.so.1 -> libdisplay-info.so.0.3.0
AVISO:    es un apaño: si libdisplay-info cambia de soname, hay que repetir esto
...
   Verificacion     : OK (vulkaninfo ve turnip)
```

---

## 2. Cómo SELECCIONAR la Mesa por juego (⚠️ NO está en el menú global del QAM)

El selector de Mesa es **por juego**, y está **oculto** hasta activar el interruptor:

```
PocknixControl → pestaña "Games" → elegir el juego →
   activar "Use Per-Game Settings" →
   aparece el desplegable "Mesa Version" → elegir la Mesa a probar
```

- El plugin escribe `mesaVersion` en `/etc/pocknix/game-tweaks.json` para ese juego.
- En el lanzamiento, `pocknix-proton-wrapper` apunta `VK_DRIVER_FILES` al
  `icd.json` del directorio elegido.
- **No hay nada que cambiar en el menú global del QAM** (Perfil de energía, FPS, etc.): buscar
  ahí es perder el tiempo.

**Sesión nueva = driver nuevo.** La Mesa solo entra en los procesos que se lanzan después, así
que **reinicia sesión (o la consola) tras instalar una Mesa nueva** antes de medir.

### ⚠️ Aviso importante: dónde SÍ y dónde NO aplica la Mesa de Valve

| Cómo corre el juego | Driver que usa | ¿Aplica la Mesa de Valve? |
|---|---|---|
| **Proton ARM64** (nativo) | `vk-arm` (nuestro Turnip / el de Valve) | ✅ **SÍ** |
| **Proton x86-64 + FEX** (WProton) | `vk-arm` — FEX *thunkea* Vulkan al stack **aarch64 del host**, y **DXVK es arm64** | ✅ **SÍ** |
| **Contenedor SLR x86** (imagen x86 completa) | `vk-x86` (lo que haya en la rootfs de FEX) | ❌ **NO** (no hay Mesa de Valve x86) |

O sea: en la Odin, **casi todo juego de Steam es Proton ARM64 o ARM Proton + FEX → la Mesa de
Valve SÍ aplica**. Solo los contenedores x86 se quedan fuera.

---

## 3. Cómo MEDIR (MangoHUD con log a CSV)

MangoHUD está instalado y parcheado (toggle con el paddle M2, o F12 para el HUD).
Para **loggear a CSV**:

```bash
MANGOHUD_CONFIG="fps_only,output_folder=/home/deck/mangologs,autostart_log=1,log_duration=90" \
  <lanzar el juego>
```

| Opción | Qué hace |
|---|---|
| `fps_only` | HUD mínimo (no estorba ni añade coste) |
| `output_folder=...` | **Dónde aparecen los CSV** |
| `autostart_log=1` | **empieza a loggear solo** al lanzar el juego |
| `log_duration=90` | segundos que dura el log (90 s ≈ 5000+ frames a 60 fps) |

Los CSV salen en `/home/deck/mangologs/<nombre-del-juego>_<fecha>.csv`, uno por ejecución, con
cabecera y **una fila por frame**.

**Alternativa**: dejar `autostart_log` fuera y pulsar **F12** para iniciar/parar el log a mano
(mismo MangoHUD, mismos CSV). Útil cuando el juego tarda en cargar y no quieres el calentamiento
en el log… aunque entonces conviene empezar el log **ya en la escena**, no en el menú.

---

## 4. Reglas para que la comparación sea JUSTA

Esto es lo que separa una medida útil de una cifra inventada. **La Odin baja de frecuencia**, así que
el orden de las pasadas importa.

| # | Regla | Por qué |
|---|---|---|
| 1 | **Mismo juego, misma escena/ruta, mismos ajustes gráficos** | Es la variable que cambiamos: la Mesa. Nada más. |
| 2 | **Misma resolución y mismo perfil de energía** | El perfil cambia las frecuencias de CPU/GPU; mezclarlo arruina la medida. |
| 3 | **Mismo save/state**: empezar la escena desde el mismo punto | Las escenas cargadas desde disco son las que más dan stutter. |
| 4 | **Descartar la primera pasada** (calentamiento) | La primera pasada paga: compilación de shaders, caché del driver en frío, páginas a disco, frecuencia de la CPU subiendo. El script ya descarta el 10 % inicial de cada CSV, pero la pasada completa se tira. |
| 5 | **Alternar A/B/A/B** (nunca dos A seguidas de dos B) | La Odin se **calienta y baja de frecuencia** con el rato. Si haces todas las A primero y las B después, mides el "enfriado" contra el "caliente". Alternando, cada variante padece las mismas condiciones. |
| 6 | **Mediana de 2-3 pasadas por variante** | Un frame perdido (actualización en segundo plano, notificación, cambio de red) se lleva una pasada entera. Con mediana, se va. |
| 7 | **Repetir en al menos 2-3 juegos distintos** | Un driver puede ganar en un juego y perder en otro (compilación de shaders distinta, extensiones). Un solo juego no es un veredicto. |
| 8 | **Anotar qué versión de cada Mesa** (`VERSION.txt` en el directorio de `vk-arm`) | Sin esto, dentro de dos semanas nadie sabe qué se comparó. |

### Plantilla de la sesión

```
1. Instalar Mesa de Valve -> reiniciar sesión.
2. Lanzar juego A -> F12/F12, 90 s de log (pasada de calentamiento, se tira).
3. Seleccionar Mesa "26.2.3" -> lanzar -> 2-3 logs de 90 s   [A1 A2 A3]
4. Seleccionar Mesa "<...>-valve" -> lanzar -> 2-3 logs      [B1 B2 B3]
5. Repetir alternando A/B otra vez si la diferencia es < 3 %.
6. Trocar a un segundo juego y repetir (3 y 4).
```

---

## 5. Cómo INTERPRETAR los logs

```bash
tools/mesa-bench-compare.py \
    26.2.3:/home/deck/mangologs/posta2_26.2.3_1.csv \
    26.2.3:/home/deck/mangologs/posta2_26.2.3_2.csv \
    26.3.0-valve:/home/deck/mangologs/posta2_valve_1.csv \
    26.3.0-valve:/home/deck/mangologs/posta2_valve_2.csv
```

Cada argumento es `nombre:ruta.csv`; **el primero es la referencia** y el resto se compara
contra él. El script:

- **descarta el 10 % inicial** de cada CSV (calentamiento);
- calcula **FPS medio**, **1 % low**, **0,1 % low** (media de los frames *más lentos*, la
  definición de CapFrameX), **frametime medio**, **desviación típica** y nº de **stutters**
  (frames con frametime > 2× la mediana);
- saca una **tabla** con el **% de mejora/empeoramiento** frente a la referencia;
- da un veredicto por variante: `MEJOR` / `PEOR` / `EMPATE` (±1 % en FPS medio).

**Cómo leerlo:**

| Señal | Qué significa |
|---|---|
| FPS medio ↑ mucho (> 5 %) | La Mesa de Valve renderiza más rápido en ese juego. |
| FPS medio igual ±1 % | Empate: los 1 % low y los stutters deciden. |
| **1 % low / stutters ↑↓** | Lo que se nota jugando. Un +2 % de FPS medio con un 1 % low 20 % peor es una **peor** Mesa para el jugador. |
| desv. típica ↑ | Jitter: la Mesa de Valve tiene frames más irregulares. |
| Ráfagas de stutter solo en una variante | Sospecha de compilación de shaders / caché: repetir con la caché de shaders ya caliente. |

**Ojo con el "1 % low"** en juegos por debajo de 60 fps: por definición es un frame de
"16,6 ms × 60/varios"; comparar 1 % low entre juegos distintos no significa nada. Solo comparar
**dentro del mismo juego y la misma escena**.

---

## 6. Qué hacer con el resultado

- **Si la de Valve gana claramente (> 3 % de FPS medio y/o 1 % low mejor en 2-3 juegos)**: la
  nuestra se queda como alternativa; seguir actualizando `tools/check-mesa.sh` + el
  `pocknix-turnip-arm` para traernos lo suyo. No tocar el driver del sistema sin motivo.
- **Si pierde o empata**: la de Valve se queda como opción de referencia (y para ver qué nos
  traen de upstream), y la nuestra sigue. Se puede dejar instalada o borrar el directorio `-valve`.
- **Si un juego peta con la Mesa de Valve** (crash, pantalla negra, Vulkan `GPU stall`): apuntar
  el juego + log a la lista de "no usar" y comparar el resto. **Un solo juego roto no invalida
  la comparación**; sí la invalida "cambiar la Mesa de todo".

---

## 🏁 RESULTADOS — primera sesión (26/09/2026)

**Juego**: Dead Island (app 91310, original de Steam). **Ajustes**: VSync **desactivado**, tope de FPS
a 100. **Rutina**: mismo guardado y mismo recorrido en las 5 pasadas.
**Medición**: MangoHUD a CSV, y se comparan **los mismos 90 s de juego real** (columna `elapsed`,
del segundo 120 al 210) para quitar de en medio la carga y el calentamiento.

| Corrida | Mesa | FPS medio | 1 % low | 0,1 % low | ft medio | stutter |
|---|---|---|---|---|---|---|
| 23:47 | 26.2 | 64,2 | 18,2 | 5,1 | 16,09 ms | 56 |
| 23:55 | **valve** | 71,1 | 52,7 | 46,4 | 14,24 ms | 0 |
| 00:03 | 26.2 | 66,5 | 29,3 | 23,4 | 15,47 ms | 35 |
| 00:09 | **valve** | 77,1 | 45,5 | 31,5 | 13,50 ms | 6 |
| 00:18 | **devel** | 69,1 | 43,4 | 31,8 | 15,05 ms | 2 |

### Medias por variante

| Variante | FPS medio | 1 % low | 0,1 % low | ft medio | stutter | n | Δ FPS |
|---|---|---|---|---|---|---|---|
| **26.2** (nuestra estable) | 65,3 | 23,8 | 14,3 | 15,78 ms | 46 | 2 | — |
| **26.3.0-valve** | **74,1** | **49,1** | **39,0** | **13,87 ms** | **3** | 2 | **+13,4 %** |
| **26.3.0devel** (nuestra) | 69,1 | 43,4 | 31,8 | 15,05 ms | 2 | 1 | **+5,7 %** |

### Conclusiones

1. **La Mesa de Valve es la mejor: +13,4 % de FPS** y, sobre todo, **los tirones casi desaparecen**
   (1 % low de 23,8 → 49,1 fps; stutter de 46 → 3).
2. **No es solo la versión.** Nuestra `26.3 devel` da +5,7 % sobre `26.2` (eso es el salto de versión),
   pero **Valve saca otro +7,2 % sobre nuestro 26.3 con la misma versión** → **su trabajo (parches,
   tuning ARM/Adreno) aporta de verdad**.
3. **La decisión**: nos quedamos **con su Turnip** (payload `26.3.0-valve`, seleccionable por juego).
   Promocionar su **Mesa completa** al sistema queda **pendiente de medir el OpenGL**.

### ⚠️ Lo que aprendimos para la próxima vez

- **`MangoHUD` en Game Mode NO usa `~/.config/MangoHud/MangoHud.conf`**: lo lleva **mangoapp dentro
  de gamescope** y lee `MANGOHUD_CONFIGFILE` (un fichero en `/run/user/<uid>/gamescope-mangoapp-*`).
  Y para que la capa de Vulkan se active en el juego hace falta `MANGOHUD=1` en su entorno.
- **Su OpenGL NO se puede probar "a medias"**: mezclar sus drivers GL con nuestras librerías
  (`libEGL`/`libgbm`/`libglvnd`) **crashea** (`dumped core`). O es su paquete completo, o no es nada.
- **Punto de partida del OpenGL** (nuestra Mesa): `glmark2-es2-drm` → **Score 577**.
  El OpenGL del sistema va por **freedreno nativo** (`msm_dri.so`), **no** por zink.

### 📌 PENDIENTE (siguiente sesión)

- ~~**Instalación limpia completa con su Mesa entera** (Opción 1) y medir el OpenGL.~~
  → **DESCARTADA el 27/09/2026**: su paquete no trae driver OpenGL para Adreno → la Odin se queda
  sin GL. Ver la sección siguiente.
- **Auto-actualización** desde la raíz del repo de Valve (la rama buena; los `mr-XXXX` son CI de cada
  merge request y no se deben pinear), guardando la versión anterior para poder volver atrás.
- **Opción 2** (pendiente de decidir): apuntar el **ICD del sistema** a su payload para que su Turnip
  sea el predeterminado para todo, sin tocar el OpenGL.

---

## ❌ OPCIÓN 1 DESCARTADA — su Mesa entera no sirve como driver del sistema (27/09/2026)

**Qué se probó**: instalar el **paquete COMPLETO** de Mesa de Valve
(`deckard-mesa-linux-aarch64`) como **driver del sistema** en una SD de Pocknix, sustituyendo
nuestra `mesa` + `vulkan-freedreno`, y medir el OpenGL (`glmark2`, con referencia 577).

**Resultado: NO SIRVE.** No por rendimiento, sino porque **no trae driver OpenGL para Adreno**:
instalado, la Odin se queda **sin OpenGL** (escritorio, ES-DE, RetroArch, `glmark2`).

### 1. El paquete

```
/home/fransis/deckard-paquetes/deckard-mesa-linux-aarch64-26.3.0_devel+gitabc426bb-1-aarch64.pkg.tar.zst   (~11 MB)
```

Declara:

```
provides:  mesa, mesa-libgl, opengl-driver
replaces:  mesa-libgl
```

O sea: **queda registrado como `mesa` del sistema** y sustituye a la nuestra de golpe. Por eso la
instalación tiene que hacerse con cuidado: lo que se quitan son 10 ficheros que **no vuelve a
poner el paquete de Valve** (ver §4).

### 2. ✅ SÍ trae Vulkan Adreno

```
usr/lib/libvulkan_freedreno.so                 18.8 MB
usr/share/vulkan/icd.d/freedreno_icd.aarch64.json
```

La parte de Vulkan (Turnip) es exactamente lo que ya usamos como payload, y es la que da el
**+13,4 %** medido arriba.

### 3. ❌ NO trae driver OpenGL para Adreno

`usr/lib/dri/` contiene **exactamente 39 drivers**, y son:

```
apple_dri.so        armada-drm_dri.so   exynos_dri.so        gm12u320_dri.so
hdlcd_dri.so        hx8357d_dri.so      ili9163_dri.so       ili9225_dri.so
ili9341_dri.so      ili9486_dri.so      imx-dcss_dri.so      imx-drm_dri.so
imx-lcdif_dri.so    ingenic-drm_dri.so  kirin_dri.so         komeda_dri.so
libdril_dri.so      mali-dp_dri.so      mcde_dri.so          mediatek_dri.so
meson_dri.so        mi0283qt_dri.so     mxsfb-drm_dri.so     panel-mipi-dbi_dri.so
pl111_dri.so        rcar-du_dri.so      repaper_dri.so       rockchip_dri.so
rzg2l-du_dri.so     ssd130x_dri.so      st7586_dri.so        st7735r_dri.so
sti_dri.so          stm_dri.so          sun4i-drm_dri.so     udl_dri.so
vkms_dri.so         zink_dri.so         zynqmp-dpsub_dri.so
```

Leído de una tacada: **todo pantallas SPI/embebidas raras** (`ili9xxx`, `st7xxx`, `ssd130x`,
`repaper`, `pl111`…), los `kms` de SoCs de TV (**meson**, **rockchip**, **rcar-du**, **sun4i**,
**zynqmp**, **komeda**), los de framebuffer deible (`udl`, `vkms`), **`libdril`** y **`zink`**.

| Driver | ¿Lo necesita la Odin? |
|---|---|
| `zink_dri.so` | ❌ es OpenGL sobre Vulkan; aquí el OpenGL va **nativo** por `msm_dri.so` |
| `libdril_dri.so` | ❌ es el puente de los drivers proprietary de embebidos |
| el resto (SPI, KMS de TV, udl/vkms) | ❌ ninguno es el Adreno 830 |
| **`msm_dri.so`** | 🔴 **FALTA** — es el OpenGL/GLES nativo de Adreno (el de nuestra `msm_dri.so`) |
| **`swrast_dri.so`** | 🔴 **FALTA** — el rasterizador por software de Mesa |
| **`kms_swrast_dri.so`** | 🔴 **FALTA** — el mismo, para KMS |

**Los tres que faltan son exactamente los que usa la Odin.** Sin `msm_dri.so` no hay
`libEGL`/`libGL` acelerados, y sin `swrast` tampoco el camino por software: **no hay OpenGL**.

### 4. Consecuencia comprobada

Se quitó antes nuestra `mesa` + `vulkan-freedreno` y se instaló el paquete de Valve: **10 ficheros
nuestros quedaron ausentes**, entre ellos:

```
/usr/lib/dri/msm_dri.so
/usr/lib/libgallium-26.2.3-pocknix2.1.so
/usr/share/drirc.d/00-msm-defaults.conf
/usr/lib/dri/kms_swrast_dri.so
/usr/lib/dri/swrast_dri.so
/usr/lib/libGLX_indirect.so.0
```

`provides: mesa` + `replaces: mesa-libgl` lo HCCE de golpe y **no hay vuelta atrás sin reinstalar
nuestra Mesa a mano** (por eso lo del snapshot de btrfs, en la guía aparte, es de vida o muerte).

### 5. La trampa de siempre: `libdisplay-info`

Sigue aplicando (ver §1): su driver pide **`libdisplay-info.so.1`** (soname de SteamOS) y nuestro
sistema tiene **`libdisplay-info.so.0.3.0`** con soname `.so.3`. Sin el symlink, el ICD no carga y
`vulkaninfo` no lista nada:

```bash
sudo ln -sf libdisplay-info.so.0.3.0 /usr/lib/libdisplay-info.so.1
```

### 6. Decisión final

| Opción | Estado |
|---|---|
| **Opción 1** — su Mesa **entera** como driver del sistema | 🔴 **DESCARTADA** (27/09/2026): sin `msm_dri.so` la Odin se queda **sin OpenGL** |
| **Opción 2** — **nuestra Mesa (OpenGL Adreno nativo) + su Turnip (Vulkan)** | ✅ **LA BUENA**: su Turnip mide **+13,4 %** y no toca el OpenGL |

**La Opción 2 es la configuración final.** En la Odin ya está como **opción seleccionable por
juego**: el payload vive en `/usr/share/pocknix/vk-arm/26.3.0-valve/` y el selector (PocknixControl
→ Games → "Use Per-Game Settings" → "Mesa Version") está arreglado.

> 📖 Cómo se instaló todo esto sin arrancar la Odin una sola vez (chroot aarch64 con
> `qemu-aarch64-static`, sin DNS, conflictos de pacman, snapshot btrfs…):
> **`docs/INSTALAR-PAQUETES-EN-SD-DESDE-PC.md`**.

## 7. ✅ `pocknix-vk-valve` — el Turnip de Valve ya está EN EL SISTEMA (27/09/2026)

La Opción 2 ya no es "instalar un payload a mano en la Odin": es **un paquete nuestro**, con lo
que implica (entra en la imagen, se actualiza con `pacman`, y queda en git).

**Qué instala** (`packages/pocknix-vk-valve/PKGBUILD`, compartido aarch64):

| Ruta | Qué es |
|---|---|
| `/usr/share/pocknix/vk-arm/26.3.0-valve/libvulkan_freedreno.so` | el Turnip de Valve (18,8 MB), **byte a byte** el de su paquete |
| `/usr/share/pocknix/vk-arm/26.3.0-valve/icd.json` | su manifest, con `library_path` reescrito al payload |
| `/usr/share/pocknix/vk-arm/26.3.0-valve/VERSION.txt` | procedencia: paquete de Valve, sha256, serie, versión nuestra |
| `/usr/lib/libdisplay-info.so.1` | **symlink** a `libdisplay-info.so.3` (el alias de la §5, ahora con dueño) |
| `/usr/share/licenses/pocknix-vk-valve/README` | licencia y procedencia (Mesa es libre; el build es de Valve) |

**Lo que NO hace** (y no debe hacerse nunca):

- **NO** instala la Mesa de Valve: ni `msm_dri.so`, ni `libgallium`, ni `usr/lib/dri/*` → el
  OpenGL de la Odin sigue siendo el nuestro (por eso la Opción 1 está descartada, §6).
- **NO** es el driver del sistema: nada cambia hasta que elijas "26.3.0-valve" en
  PocknixControl → Games → "Use Per-Game Settings" → "Mesa Version".
- **NO** toca `/etc/vulkan/icd.d`: el manifest va en el payload y lo apunta `VK_DRIVER_FILES`.

**Fuente: raíz del repo de Valve, fijada.** `source=` es un fichero **concrete** de la raíz de
`holo-packages.steamos.cloud/archlinux-deckard-hotfixes/`, con `sha256sums` puesto:

```
deckard-mesa-linux-aarch64-26.3.0_devel+gitabc426bb-1-aarch64.pkg.tar.zst
sha256: 7b259d40d5b6845cad91b6cf991da34d6c8a146683fa6009336d3bc464028938
```

> 🔴 **Los directorios `mr-XXXX/` del repo de Valve NO se pueden pinear.** Son los artefactos de
> CI de cada *merge request*: se mueven, se sobrescriben y desaparecen. Un `source=` a un
> `mr-1174/...` compila hoy y rompe dentro de dos semanas. Para refrescar: listar la raíz, ver
> el `deckard-mesa-linux-aarch64-*` más nuevo, y actualizar `_valve_pkg` + `sha256sums` juntos
> (es exactamente lo que hace `tools/install-deckard-mesa.sh`).

**Entra en la imagen** por `depends` de `pocknix-steam-full` (override nuestro de un solo
PKGBUILD, `pkgrel` 2 → 3), que es la capa que ya lleva `pocknix-turnip-arm` / `pocknix-turnip-x86`.
Con eso llega a las imágenes nuevas **y** a los dispositivos ya desplegados con `-Syu`.

**Compilar** (desde `pocknix-os`, `DEVICE=sm8750` es obligatorio):

```bash
cd /home/fransis/pocknix-odin3-project/pocknix-odin3-support
./tools/sync-to-os.sh && ./tools/check-sync.sh        # el paquete es NUESTRO: sin esto, ni está
cd ../pocknix-os
sudo make packages PKG="pocknix-vk-valve"              # rápido: descarga 10 MB y desempaqueta
```

`package()` es una comprobación, no un build: descarga el tar, verifica el sha256, extrae **dos**
ficheros, y se niega a terminar si

- el `.so` no es `AArch64` (un payload de otra arquitectura se instalaría sin quejarse y
  fallaría en la Odin),
- dentro no hay `libvulkan_freedreno.so` o ningún `freedreno_icd*.json` (si Valve cambia el
  layout, que lo diga el build y no la Odin),
- no hay ninguna `libdisplay-info.so.[0-9]*` (o sea, `depends=` no satisfecha),
- algún `DT_NEEDED` del driver no está en la chroot (eso avisa, no rompe: es la red de seguridad
  del `depends=`).

**Verificar sin Odin** (con el paquete ya construido en `build/localrepo`):

```bash
PKG=$(ls -t build/localrepo/pocknix-vk-valve-*.pkg.tar.zst | head -1)
bsdtar -tf "$PKG"                       # 4 rutas + el symlink, ni un byte más
bsdtar -xOf "$PKG" usr/share/pocknix/vk-arm/26.3.0-valve/icd.json
# el symlink, que es lo que falla en silencio:
bsdtar -tvf "$PKG" | grep libdisplay-info
```

En la Odin, después de instalarlo:

```bash
pacman -Qo /usr/lib/libdisplay-info.so.1        # -> pocknix-vk-valve (nuestro, no huérfano)
VK_DRIVER_FILES=/usr/share/pocknix/vk-arm/26.3.0-valve/icd.json vulkaninfo --summary
#   driverName = turnip Mesa driver   ← si NO sale, el symlink de libdisplay-info se rompió
```

**El alias se autorepara**: `pocknix-vk-valve.install` lo reapunta en cada instalación/actualización
(al symlink de SONAME, no al fichero versionado → sobrevive a un `0.3.0` → `0.3.1`) y lo borra al
desinstalar. Si algún día ALARM cambia el soname de `libdisplay-info` (`.so.3` → `.so.4`), un
`pacman -S pocknix-vk-valve` de nuevo lo arregla y lo dice en pantalla.

## 8. Referencias

- `packages/pocknix-vk-valve/PKGBUILD` — el paquete (payload + alias + auditoría de `DT_NEEDED`).
- `packages/pocknix-vk-valve/pocknix-vk-valve.install` — repara/borra el alias de libdisplay-info.
- `tools/install-deckard-mesa.sh` — instala la Mesa de Valve como payload de `vk-arm`.
- `tools/mesa-bench-compare.py` — compara los CSV y da el veredicto.
- `tools/check-mesa.sh` — qué Mesa/qué ramas de Turnip tenemos y cuáles hay upstream.
- `packages/soc/pocknix-turnip-arm/PKGBUILD` — nuestras builds de Turnip (una por rama).
- `docs/INSTALAR-PAQUETES-EN-SD-DESDE-PC.md` — instalar paquetes aarch64 en una SD de Pocknix
  desde el PC x86_64 (chroot con `qemu-aarch64-static`), sin arrancar la Odin.
- `/home/fransis/deckard-paquetes/GUIA-ADAPTACION.md` — qué más trae el repo de Valve
  (Vulkan layers RPO/FDM, UCM, sysctls) y qué se puede adaptar a la Odin 3.
