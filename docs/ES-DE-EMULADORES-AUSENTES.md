# ES-DE: que no ofrezca emuladores que no estan instalados

## El problema

ES-DE resuelve las variables `%EMULATOR_X%` de cada `<command>` de
`es_systems.xml` usando `es_find_rules.xml`: ese fichero dice, por cada
`<emulator name="X">`, **donde** hay que buscar el emulador (una o varias
rutas, en reglas `systempath` / `staticpath` / `corepath`).

Si el emulador no esta instalado, ninguna de sus rutas existe, la variable
se queda sin resolver y **ES-DE ofrece la opcion igual**: aparece en el
selector de emulador del sistema, se elige y no ocurre nada (o sale
`emulator not found`).

El caso que motivo este trabajo: el sistema **n3ds** ofrecia

```
Citra            ->  %EMULATOR_RETROARCH% -L %CORE_RETROARCH%/citra_libretro.so
Citra 2018       ->  %EMULATOR_RETROARCH% -L %CORE_RETROARCH%/citra2018_libretro.so
Citra (Standalone)->  %EMULATOR_CITRA% %ROM%
```

`Citra (Standalone)` es un emulador **standalone**: en la consola no hay
`Apps/Citra/`, y `%EMULATOR_CITRA%` no resuelve a nada — se ofrece y está muerto.

## Que habia ya: `deckstation-cores-sync.sh`

El mecanismo ya existía, pero **solo para los cores de RetroArch**:
`scripts/deckstation-cores-sync.sh` borra del `es_systems.xml` activo los
`<command>` cuyo `%CORE_RETROARCH%/xxx.so` no esta en la carpeta portable de
RetroArch.

Los emuladores **standalone** (Citra, Cemu, PPSSPP, Xenia, MAME, ares...)
no tenian nada. Este trabajo generaliza ese mismo mecanismo a todos ellos.

## La solucion: `scripts/deckstation-emulators-sync.sh`

Se apoya en la misma logica que el script de cores, con una fuente de verdad
distinta: **`es_find_rules.xml`**.

1. Parsea `es_find_rules.xml` y saca, por cada `<emulator name="X">`, sus
   `<entry>` agrupados por tipo de regla.
2. Un emulador esta **ausente** si **ninguna** de sus rutas existe. Se
   comprueban las tres formas de entrada que usa el fichero:
   - `~/algo` → se prueban **todos** los HOME candidatos (`$HOME`, el
     `.home` del AppImage de DeckStation y el home real del usuario). Basta
     con que uno exista: ante la duda se considera instalado.
   - `./Apps/...` o `../...` → relativo a `DECKSTATION_ROOT` (que es de donde
     sale `exec "$DECKSTATION_ROOT/DeckStation.AppImage"`, luego es el cwd de
     ES-DE) y al cwd actual.
   - `/ruta/absoluta` → tal cual.
   - nombre "pelado" (`citra`, `dev.ares.ares`, ...) → `shutil.which()` en el
     PATH y, si parece un AppID de flatpak, en
     `/var/lib/flatpak/exports/{bin,share}` y
     `~/.local/share/flatpak/exports/{bin,share}`.
   - Los `<entry>` con formato `ruta|argumentos` (flatpak) se truncan por el `|`.
   - Se respetan los comodines (`citra-qt*.AppImage`) con `glob`.
3. Lee el `es_systems.xml` **activo** y quita las lineas `<command>` que
   usen un emulador ausente.

### Lo que NO toca

- El **source** (`configs/es-de/custom_systems/es_systems.xml`) no se modifica:
  manda siempre, y si mañana se instala un emulador su comando vuelve a
  aparecer solo (lo resucita `deckstation-cores-sync.sh`, que regenera).
- Solo se borran lineas `<command>` **enteras** y de una sola linea (que es
  como estan todas; verificado). Nada mas del fichero.
- El XML resultante se valida con `ElementTree` **antes** de escribir. Si no
  parsea, no se toca el activo y se avisa.
- Backup del activo en `es_systems.xml.bak-emus` antes de escribir.
- Si no hay nada que quitar, **no escribe** (no cambia ni la fecha del fichero).
- Un sistema al que el filtro le vacias todos los comandos se queda con el
  primero: un sistema sin `<command>` se muestra en ES-DE pero no se puede
  jugar, que es peor que un comando que no arranca. Avisa en el informe.
- Los `corepath` se ignoran aqui (los mira `deckstation-cores-sync.sh`): un
  emulador que solo tenga reglas `corepath` no se considera ausente.

### Por que NO regenera desde el source (a diferencia del de cores)

Los dos scripts podan el **mismo fichero activo**:

- `deckstation-cores-sync.sh` **regenera** el activo desde el source (asi un
  core instalado mañana reaparece solo).
- `deckstation-emulators-sync.sh` **filtra el activo en el sitio**.

Si el de emuladores regenerara desde el source, **desharia** lo que acaba de
hacer el de cores: volveria a escribir comandos con cores que faltan. Por eso
el de emuladores va **siempre despues**, en los dos sitios donde se llama
(`deckstation-setup.sh` y `deckstation-launcher.sh`), y los dos filtros se
componen. Cada uno deja el comando si lo suyo (el core / el emulador) existe.

### El caso "regla que apunta al vacio"

El sistema `xbox360` daba `emulator not found` porque la regla de
`XENIA-EDGE` apuntaba a `./Apps/xenia_edge/xenia_edge_linux.AppImage` y el
fichero real se llama `xenia_edge_linux_aarch64.AppImage` (le anadieron la
arquitectura al nombre). Arreglado en `3d5aa63` apuntando al lanzador.

Ese es justo el tipo de fallo que caza esta herramienta: si un emulador que
se **usa** tiene reglas y ninguna existe, sale en el informe como
`REGLA ROTA`, junto con los emuladores usados que **no tienen**
`<emulator name=...>` en `es_find_rules.xml` (aun peor: ES-DE no puede
resolverlos nunca).

## Como se usa

```bash
# En la consola, en seco (no escribe nada)
DECKSTATION_ROOT=/opt/deckstation \
  /opt/deckstation/scripts/deckstation-emulators-sync.sh --dry-run

# De verdad (hace backup en es_systems.xml.bak-emus)
DECKSTATION_ROOT=/opt/deckstation \
  /opt/deckstation/scripts/deckstation-emulators-sync.sh
```

No hay que llamarlo a mano: `deckstation-setup.sh` (tras
`deploy_cores_sync`) y `deckstation-launcher.sh` (tras el
`deckstation-cores-sync.sh`) lo ejecutan en cada arranque de DeckStation.
El launcher lo calla con `>/dev/null 2>&1` para no ensuciar la consola.

Si no esta instalado ningun emulador (no hay `Apps/`) o no hay
`es_find_rules.xml`, sale con un mensaje y no hace nada: es un no-op, no un
error.

## Salida del informe

```
  [emus-sync] reglas leidas: 103 emuladores
  [emus-sync] AUSENTES (ninguna de sus rutas existe): 70
  [emus-sync]    (en uso)  CITRA                      ninguna de sus 4 rutas existe
  [emus-sync]    (nunca)  CITRON                     ninguna de sus 2 rutas existe
  [emus-sync]    (en uso)  GOPHER2600                 sin ninguna regla en es_find_rules.xml
  ...
  [emus-sync] comandos a quitar: 255
  [emus-sync]    n3ds         Citra (Standalone)           (%CITRA% no instalado)
```

`(en uso)` = el emulador ausente aparece en algun `<command>` (por eso se
borran comandos); `(nunca)` = esta definido pero no se usa (informativo).
`REGLA ROTA` = emulador en uso que ES-DE no puede resolver nunca.

## Resultado en el sistema n3ds

Despues de aplicarlo, el bloque `<command>` de n3ds queda:

```
Azahar (Standalone)   -> se queda   (Apps/Azahar/lanzar.sh existe)
Citra                 -> se queda   (core citra_libretro.so, lo lleva el de cores)
Citra 2018            -> se queda   (core citra2018_libretro.so, idem)
Citra (Standalone)    -> SE QUITA   (%EMULATOR_CITRA% no resuelve a nada)
Shortcut or script    -> se queda   (%EMULATOR_OS-SHELL% = /usr/bin/bash)
Azahar                -> se queda   (core azahar_libretro.so)
```

Los comandos que usan cores los decide `deckstation-cores-sync.sh` (este
script no toca nada que solo dependa de un `%CORE_RETROARCH%`).

## Pruebas

### Casos limite (sin depender de la consola)

`/tmp/opencode/t/test-casos.sh` monta un arbol DeckStation de mentira y
comprueba seis cosas:

1. Se borran los emuladores ausentes y **se quedan** los que existen, los que
   resuelven por **comodin** (`cemu*.AppImage`) y los que solo tienen reglas
   `corepath`.
2. El diff contra el fichero anterior solo contiene lineas `<command>` (0
   lineas de otra cosa), el XML sigue siendo valido y se creo el backup.
3. **Idempotente**: la segunda pasada dice `nada que hacer` y no reescribe el
   fichero (no cambia ni la mtime).
4. Un sistema al que se le vacian todos los comandos **conserva el primero** y
   avisa; el sistema "mixto" conserva el suyo.
5. Sin `Apps/` es un no-op con mensaje, sin error y sin tocar nada.
6. `--dry-run` no escribe ni crea backup.

### El parser de las reglas

Se tokeniza el **texto entero**, no linea a linea, y en orden. Asi funciona
igual si un `<rule type="...">` y sus `<entry>` estan en lineas separadas (como
en el fichero real) o en la misma linea. La primera version parseaba linea a
linea y se saltaba la linea entera al ver el `<rule>`; con el fichero real no
se notaba, pero un reformateo del `.xml` habria hecho que un emulador pareciese
"sin ninguna ruta" -> se habrian borrado sus comandos de un plumazo. Los
`<entry>` que estan dentro de un `<core ...>` se ignoran (los mira el script de
cores).

Salida sobre el arbol real (maqueta con las 34 apps instaladas en la consola):
**103 emuladores leidos, 70 ausentes, 255 comandos a quitar, 0 reglas rotas**,
1110 comandos -> 855.

## Salida real en la Odin (03/10/2026)

Copias previas, **antes** de tocar nada:

| Donde | Que |
|---|---|
| `/opt/deckstation/DeckStation.AppImage.home/ES-DE/custom_systems/es_systems.xml.bak-pre-emus` | en la consola |
| `…/es_find_rules.xml.bak-pre-emus` | en la consola |
| `/tmp/opencode/odin-pre-emus/es_systems.xml.bak-pre-emus` | en el PC (184525 bytes) |
| `/tmp/opencode/odin-pre-emus/es_find_rules.xml.bak-pre-emus` | en el PC (38632 bytes) |
| `/opt/deckstation/scripts/deckstation-launcher.sh.bak-pre-emus` | launcher de la consola, antes de cablear el script |

`--dry-run` en la consola (34 apps instaladas):

```
  [emus-sync] reglas leidas: 103 emuladores
  [emus-sync] AUSENTES (ninguna de sus rutas existe): 68
  [emus-sync]    (en uso)  CITRA                      ninguna de sus 4 rutas existe
  [emus-sync]    (en uso)  MEDNAFEN                   ninguna de sus 3 rutas existe
  [emus-sync]    (en uso)  MESEN                      ninguna de sus 2 rutas existe
  [emus-sync]    (en uso)  GOPHER2600                 sin ninguna regla en es_find_rules.xml
  [emus-sync]    (nunca)  CITRON                     ninguna de sus 2 rutas existe
  ...
  [emus-sync] reglas rotas: ninguna
  [emus-sync] definidos pero no usados por ningun comando: 2 (normal)
  [emus-sync] comandos a quitar: 180
  [emus-sync]    n3ds         Citra (Standalone)           (%CITRA% no instalado)
  [emus-sync]    snes         Mednafen (Standalone)        (%MEDNAFEN% no instalado)
  [emus-sync]    AVISO: ngage se quedaba sin comandos; se conserva el primero
  [emus-sync] SIMULACION: no se ha escrito nada
```

Aplicado de verdad: **1067 -> 887 comandos**, `quitados 180 comandos | backup en
es_systems.xml.bak-emus`.

Como se comprobo que no rompe nada:

| Comprobacion | Resultado |
|---|---|
| `diff` del activo contra el backup | **180 lineas borradas, 0 anadidas, 0 lineas que no sean `<command>`** |
| XML resultante (`ElementTree`) | valido |
| Sistemas con `<command>` | 197 antes, **197 despues**; **ninguno se queda con 0** |
| Sistemas cuyo nº de comandos no cambia | **94 de 197** (intactos) |
| Comandos que quedan | **todos identicos** a los que habia (0 comandos nuevos) |
| Emuladores instalados | mismos numeros antes/despues: RETROARCH 605/605, MAME 84/84, FLYCAST 8/8, DOLPHIN 3/3, RPCS3 3/3, PPSSPP 2/2, BIGPEMU 2/2, AZAHAR 1/1, XENIA-EDGE 1/1, CEMU 1/1, SCUMMVM 1/1, PCSX-REDUX 1/1, VITA3K 1/1, MELONDS 1/1 |
| Cruce: emuladores usados por los 180 comandos borrados | **todos** estan en la lista de ausentes (ninguno instalado se ha tocado) |
| Idempotencia | 2a pasada: `nada que hacer (el activo ya esta filtrado)`, no reescribe |
| `n3ds` | `Citra (Standalone)` fuera; `Azahar (Standalone)`, `Shortcut or script` y los comandos con core (Citra, Citra 2018, Azahar) siguen |
| `xbox360` | `Xenia Edge (Standalone)` sigue (la regla rota de `3d5aa63` esta bien) |

### ⚠️ El `es_systems.xml` activo se regenera: los arreglos manuales no sobreviven

`deckstation-cores-sync.sh` **regenera el activo desde el source** en cada
arranque, asi que cualquier retoque a mano del `es_systems.xml` de
`…/DeckStation.AppImage.home/ES-DE/custom_systems/` se pierde en el siguiente
arranque de DeckStation. Para que un cambio sea permanente va en el **source**,
`configs/es-de/custom_systems/es_systems.xml` (que es lo que edita
`inserta-cores-es-de.py`).

Por eso en la consola solo se cableo el `deckstation-launcher.sh` (backup en
`.bak-pre-emus`) y **no** el `deckstation-setup.sh`, que tenia otros cambios
locales de otra sesion de trabajo.

## Ficheros

| Fichero | Que es |
|---|---|
| `packages/deckstation-arm/scripts/deckstation-emulators-sync.sh` | el script (nuevo) |
| `packages/deckstation-arm/scripts/deckstation-setup.sh` | llama a `deploy_emulators_sync` tras `deploy_cores_sync` |
| `packages/deckstation-arm/scripts/deckstation-launcher.sh` | lo llama tras `deckstation-cores-sync.sh` |
| `packages/deckstation-arm/PKGBUILD` | instala el script nuevo (`pkgrel` 11) |
