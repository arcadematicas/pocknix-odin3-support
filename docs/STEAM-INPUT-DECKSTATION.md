# Steam Input OFF para el atajo DeckStation (automático al arrancar Steam)

Fecha: 2026-10-17 · Consola: ODIN 3 (`pocknix-1`) · Paquete: `pocknix-steam` (script `pocknix-steam-sync`)

## 1. El problema

Al lanzar el atajo **DeckStation** desde Steam (Game Mode), Steam **se apropiaba
del mando** (Steam Input) y se lo traducía a su mando virtual. Resultado: los
emuladores que arranca ES-DE se quedaban **sin eventos** — es el mismo motivo por
el que en su día se dejó de capturar el mando físico con InputPlumber
(ver `MANDO-ODIN3-RETROARCH.md`).

Hasta ahora la solución era **manual**: entrar al **QAM** y poner
*Steam Input: desactivado* para ese atajo. Con esto pasa a ser **automático**:
al arrancar Steam, antes de que la interfaz aparezca, el ajuste ya está puesto.

## 2. Dónde vive el ajuste (encontrado, no adivinado)

El ajuste del QAM **no** está en `shortcuts.vdf` (ahí solo van los atajos). Vive
en el `localconfig.vdf` de la cuenta:

```
~/.local/share/Steam/userdata/<steamid>/config/localconfig.vdf
  └─ UserLocalConfigStore
       └─ apps
            └─ <appid>            (p.ej. 2879226642)
                 └─ UseSteamControllerConfig   ← la clave
```

- `"UseSteamControllerConfig" "1"` → **Steam Input activado**
- `"UseSteamControllerConfig" "0"` → **Steam Input desactivado**
- **Clave ausente = activado** (es el valor por defecto de Steam)

Se confirmó comparando el fichero antes/después de togglear el ajuste a mano en
el QAM (el valor pasó a `0` a las 14:38 y la clave quedó en la línea ~1271).

### appid de DeckStation

`shortcuts.vdf` guarda el appid **con signo** y `localconfig.vdf` **sin signo**:

```
shortcuts.vdf :  -1415740654
localconfig   :   2879226642   ( = -1415740654 & 0xFFFFFFFF )
```

En esta cuenta SteamID es `4682409`.

## 3. Dónde se escribe y por qué ahí

Lo escribe **`pocknix-steam-sync`** (`packages/pocknix-steam/pocknix-steam-sync`),
el script que `pocknix-steam` ejecuta **justo antes de lanzar Steam**, en el
arranque de Game Mode como usuario `deck`.

Ese es el **único momento seguro**:

- Steam **reescribe** `localconfig.vdf` al salir, así que cualquier cambio hecho
  con Steam abierto se pierde (o peor, se pisa a medias).
- Antes de que Steam arranque el fichero está quieto y somos los únicos que
  escribimos.

La función es `disable_steam_input(cfgdir, entries)`. El appid se saca del
propio atajo (mismo `appname == "DeckStation"` que ya usa el script para el
resto), no de una constante.

### Garantías del código

- **Idempotente:** si el valor ya es `"0"`, **no toca el fichero** (ni mtime, ni
  backup).
- **No corruptivo:** editor de VDF en **stdlib puro** (no usa el módulo `vdf`):
  tokeniza el texto y lo re-emite **respetando el orden de claves**.
  Round-trip verificado **byte a byte** contra el `localconfig.vdf` real de la
  Odin (69 KB, con blobs JSON dentro).
- **Backup + validación:** antes de escribir deja `localconfig.vdf.pocknix-bak`
  y **re-parsea** lo que va a escribir para comprobar que la clave quedó a `"0"`;
  si algo no cuadra, **no escribe**. La escritura es atómica (`os.replace`) y
  conserva los permisos originales.
- **Silencioso si no procede:** si el atajo no está en la lista, o el fichero no
  existe, o no se puede leer/parsear → no hace nada y avisa por `stderr`.
- **Reversible** (ver §5).

Cuando cambia algo imprime una línea:

```
[pocknix-steam-sync] 4682409: Steam Input OFF para DeckStation (appid 2879226642)
```

## 4. Qué se verificó (y qué no)

Verificado **sin reiniciar Steam ni la consola** (no se puede tocar mientras se
usa):

- Editor VDF: idempotencia (`0` → byte-idéntico), `1`→`0`, clave ausente (se
  añade), bloque de `apps` ausente, diff de **una sola línea** al cambiar.
- Ruta completa `disable_steam_input` en sandbox (copia del `localconfig.vdf`
  real): `1`→`0` con backup; ya-`0` sin tocar; sin DeckStation → no-op; sin
  fichero → no-op.
- El `localconfig.vdf` **real** de la Odin quedó **intacto** durante las pruebas.

**Pendiente de verificación real:** el efecto end-to-end (que al arrancar Game
Mode la interfaz levante con el atajo ya en Steam Input OFF) **necesita el
siguiente arranque de Steam**, que no se ha hecho. En la Odin el valor ya lo puso
el usuario a mano a `0`, así que el script será idempotente y no reescribirá
hasta que Steam vuelva a ponerlo a `1`.

## 5. Cómo revertir (volver a Steam Input ON)

La clave puede quedar a `1` de dos maneras:

1. **Con Steam cerrado**, ponerla a mano en `localconfig.vdf`:
   ```
   "UseSteamControllerConfig"		"1"
   ```
   (o borrar esa línea: ausente = activado). El backup bueno está en
   `localconfig.vdf.pocknix-bak` (es el estado **previo** al primer cambio del
   script).
2. **Quitar la llamada** a `disable_steam_input(...)` en `main()` de
   `pocknix-steam-sync` y publicar el paquete (`pkgrel` nuevo).

## 6. Referencias

- Script: `packages/pocknix-steam/pocknix-steam-sync` (función
  `disable_steam_input` + editor `_vdf_*` + `_localconfig_set_app_key`).
- Lanzador: `packages/pocknix-steam/pocknix-steam` (`/usr/bin/pocknix-steam-sync`
  antes de Steam).
- Contexto del mando: `docs/MANDO-ODIN3-RETROARCH.md`,
  `docs/MANDOS-DE-OTROS-SISTEMAS.md`.
- `UseSteamControllerConfig`: confirmado con `markurei/steam-input-disabler`.
