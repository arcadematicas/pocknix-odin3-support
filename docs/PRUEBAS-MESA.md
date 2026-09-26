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

## 7. Referencias

- `tools/install-deckard-mesa.sh` — instala la Mesa de Valve como payload de `vk-arm`.
- `tools/mesa-bench-compare.py` — compara los CSV y da el veredicto.
- `tools/check-mesa.sh` — qué Mesa/qué ramas de Turnip tenemos y cuáles hay upstream.
- `packages/soc/pocknix-turnip-arm/PKGBUILD` — nuestras builds de Turnip (una por rama).
- `/home/fransis/deckard-paquetes/GUIA-ADAPTACION.md` — qué más trae el repo de Valve
  (Vulkan layers RPO/FDM, UCM, sysctls) y qué se puede adaptar a la Odin 3.
