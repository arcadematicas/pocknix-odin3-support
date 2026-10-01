# ES-DE no lanza NINGÚN juego (DeckStation lanzado desde Steam)

**Fecha**: 02/10/2026 (madrugada)
**Síntoma reportado**: «desde ES-DE no me abre ningún juego, incluso he cambiado de emulador»
**Estado**: diagnosticado, arreglado y verificado en la Odin. **Pendiente**: confirmación de
Fransis y pasar el hallazgo a stshunz (es un fallo de DeckStation, no nuestro).

---

## 1. Qué se veía

- ES-DE arranca perfecto (94 sistemas, 4255 juegos) y **sí ejecuta** los juegos: su log expande
  el comando correcto.
- Pero el juego **no aparece**, ni con RetroArch ni con DuckStation, ni cambiando de emulador.
- **ES-DE no da ni un solo error.** El log solo dice:

  ```
  Info:   Launching game "Silent Hill" from system "Sony PlayStation (psx)"...
  Info:   Expanded emulator launch command:
  Info:   ./Apps/RetroArch/lanzar.sh -L .../cores/swanstation_libretro.so ./ROMs/psx/Silent\ Hill.chd
  ```

- Y **el emulador no escribe su log** (RetroArch/DuckStation): muere antes de empezar.

## 2. Cómo se localizó

1. **Descartar el juego**: lanzando el comando a mano (por SSH, con `DISPLAY=:0`) el juego
   **funciona** (RetroArch aguanta corriendo). O sea: la cadena emulador+ROM está bien.
2. **Huella en el lanzador**: se insertó una línea temporal al principio de
   `Apps/RetroArch/lanzar.sh` que escribe `cwd`, `args` y el entorno en `/tmp/ds-lanzar.log`.
   Fransis volvió a probar desde ES-DE y **la huella quedó VACÍA** → **el lanzador no llegaba a
   ejecutarse**.
3. **Mirar el entorno del ES-DE vivo** (`/proc/<pid>/environ`, `readlink /proc/<pid>/cwd`):

   ```
   cwd: /opt/deckstation          ← correcto
   PATH=/tmp/.path1001            ← ¡AQUÍ ESTÁ!
   LD_PRELOAD=/home/deck/.local/share/Steam/ubuntu12_64/gameoverlayrenderer.so:...
   LD_LIBRARY_PATH=:/home/deck/.local/share/Steam/linuxarm64
   HOME=/opt/deckstation/DeckStation.AppImage.home
   ```

4. **Y `/tmp/.path1001` contiene solo dos enlaces**:

   ```
   fusermount  -> /usr/bin/fusermount3
   fusermount3 -> /usr/bin/fusermount3
   ```

5. **Prueba de laboratorio** (la que lo cierra):

   | Prueba | Resultado |
   |---|---|
   | `lanzar.sh` original + `PATH=/tmp/.path1001` | `readlink: command not found` → **exit 127** |
   | `lanzar.sh` arreglado + el mismo PATH roto | **exit 124** (el juego corrió 12 s) ✓ |

## 3. Causa raíz

**Steam** mete al entorno de las apps que lanza `PATH=/tmp/.pathNNNN`, un directorio que prepara
para poder montar AppImages dentro de su entorno. **Reemplaza el PATH entero** (no lo amplía), y
ahí dentro solo hay `fusermount`.

El `lanzar.sh` de DeckStation muere en su **línea 12** (`readlink`, `dirname`), mucho antes de
llegar al emulador. Y muere **en silencio**, que es lo que hacía el problema tan confuso: ES-DE no
da error y el emulador ni existe todavía.

**Cuándo**: a las 17:01 del 01/10 RetroArch **sí** arrancó desde ES-DE; a las 23:25 ya no. El
gatillo es **lanzar DeckStation desde Steam** (el `/tmp/.path1001` se creó a las 23:25). Antes se
lanzaba por otra vía (escritorio), con un PATH normal.

### ¿Lo causó nuestro paquete `pocknix-wsquashfs`?

**No, y hay tres razones** (queda escrito por si alguien vuelve a mirar las fechas y sospecha):

1. Aquella transacción de `pacman` instaló **solo `squashfs-tools`**, ninguna librería.
2. El fallo es de **PATH**, y ese PATH lo pone Steam (`/tmp/.path1001`), no pacman.
3. Es una **coincidencia de hora** (23:25): a las 23:25 también se abrió DeckStation desde Steam
   por primera vez. La nota de la huella vacía delata que el script no llegaba a correr, algo
   imposible de provocar instalando `squashfs-tools`.

## 4. El arreglo

En **`scripts/lanzar.sh`** (la plantilla que `deploy-lanzar-sh.sh` copia a `Apps/<Emulador>/`),
al principio:

```bash
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
export PATH
```

Se pone el PATH normal **delante** y se **conserva el de Steam al final** (que sí hace falta: es
el que trae `fusermount` para montar los AppImage).

Aplicado en la Odin a: la **plantilla** (`/opt/deckstation/scripts/lanzar.sh`, es de root → sudo) y
a **los 31 `Apps/*/lanzar.sh`**.

### Alternativa sin tocar código

En Steam → DeckStation → Propiedades → Opciones de lanzamiento:

```
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin %command%
```

Cubre además cualquier otro script lanzado desde ES-DE (los `.sh` de ports, linuxgames, etc.).

## 5. Cómo comprobarlo

1. Desde ES-DE, lanzar un juego que se sabe bueno (p. ej. **Silent Hill**, LZMA).
2. Si arranca → arreglado.

## 6. Pendientes / relacionados

- [ ] Confirmación de Fransis.
- [ ] Pasar el hallazgo a **stshunz** (afecta a cualquier DeckStation lanzado desde Steam).
- [ ] **Rayman (USA).chd está roto de otra forma**: es el ÚNICO de 17 CHD del catálogo
      comprimido con **ZSTD** (`cdzs`), y los cores de RetroArch no lo leen
      (`[libretro ERROR] Failed to open CHD ...: unsupported format`). Los otros 16 usan LZMA
      (`cdlz`) y van bien. Arreglo: reconvertir ese CHD a LZMA con `chdman copy -c lzma`, o usar
      el DuckStation standalone con él.
