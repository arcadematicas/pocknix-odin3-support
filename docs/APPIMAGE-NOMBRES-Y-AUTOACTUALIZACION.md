# AppImage: nombres que cambian solos y auto-actualización

**Fecha**: 3 de octubre de 2026
**Alcance**: DeckStation ARM (`/opt/deckstation/`), la capa de emulación de la Odin 3.
**Estado de este documento**: análisis + **propuesta**. El parche propuesto **NO está aplicado**.

Todo lo que aquí afirma como "medido" se obtuvo leyendo la consola Odin 3 por SSH en modo
solo lectura (`ssh odin`, usuario `deck`) el 3/10/2026. Donde no se pudo comprobar, se dice
explícitamente.

---

## 1. El problema, en una línea

El nombre del fichero AppImage **no lo pone DeckStation**: lo pone el upstream, y cambia
cuando el upstream renombra el asset. Todo lo que apunte a
`"<Emulador>-<version>-<arquitectura>.AppImage"` se rompe en la siguiente actualización.

## 2. El caso que ya rompió algo: Xenia Edge (commit `3d5aa63`)

La regla de ES-DE apuntaba al nombre **con arquitectura**:

```xml
<emulator name="XENIA-EDGE">
    <rule type="staticpath">
        <entry>./Apps/xenia_edge/xenia_edge_linux.AppImage</entry>
```

y el fichero que hay de verdad es:

```
Apps/xenia_edge/xenia_edge_linux_aarch64.AppImage
```

Motivo: el upstream pasó a publicar el asset como `xenia_edge_linux_aarch64.AppImage`
(haciendo explícita la arquitectura) y el Updater descargó al nombre nuevo. La regla
antigua quedó apuntando a un fichero que no existe.

**Cómo se arregló**: se cambió la entrada a `./Apps/xenia_edge/lanzar.sh`, o sea el
wrapper, que ya resuelven el nombre real por patrón. Fue el arreglo correcto y es
justo el modelo que se propone generalizar aquí.

**Detalle que sigue pendiente**: `Apps/xenia_edge/.version` está **vacío**. No lo
escribió el Updater. Mientras tanto el Updater no puede saber si ese emulador está al día
y no lo ofrece como actualizable. No se ha investigado el motivo.

## 3. Por qué no es un caso suelto: 27 de 29 AppImages se pueden renombrar solos

Medido en la consola (`tools/check-appimage-nombres.sh --ssh odin`):

| Métrica | Valor |
|---|---|
| Carpetas en `Apps/` | 34 |
| Ficheros `*.AppImage` | 29 (+1 con otro nombre) |
| Con info de AUTO-UPDATE embebida (`.upd_info`) | **27** |
| Con nombre FRÁGIL (lleva versión y/o arquitectura) | **29** |
| Huérfanos (`.AppImage.bak` sin su `.AppImage`) | 0 |
| Sin `.home` | 0 |
| **Sin `.upd_info`** | **2**: `RPCS3` y `xenia_edge` |

Los 27 llevan dentro el bloque `.upd_info` que AppImage usa para saber de dónde
auto-actualizarse. Ejemplos reales extraídos del ELF:

```
gh-releases-zsync|pkgforge-dev|MAME-AppImage|latest|*aarch64.AppImage.zsync
gh-releases-zsync|pkgforge-dev|<...>|latest|<...>aarch64.AppImage.zsync
gh-releases-zsync|Vita3K|Vita3K|continuous|Vita3K-aarch64.AppImage.zsync
zsync|https://stable.eden-emu.dev/...            (Eden, no pkgforge)
```

Es decir: 27 de los 29 pueden ser renombrados en la próxima actualización sin que nadie
toca nada. El riesgo no es hipotético, es la operación normal del sistema.

**Riesgo latente, NO activo**: ningún AppImage tiene un `.zsync` suelto al lado ni una
carpeta `auto-updates-policy/`, y `appimageupdatetool` / `AppImageUpdate` / `zsyncmake`
**no están instalados**; nada en DeckStation los invoca. Ese canal de auto-actualización
automática está cerrado hoy. Si alguien lo abriera, pasarían a renombrarse sin pasar por el
Updater. No se ha tocado nada para que siga así.

> **Arreglado en el detector al escribir este doc**: `upd_info()` hacía `return 1` en
> cuanto `readelf` estaba instalado pero la sección `.upd_info` salía vacía, así que **el
> fallback a `strings` era código muerto** y "no tiene info de auto-update" era
> indistinguible de "no he podido leer este fichero". Ahora los tres casos se distinguen
> (`si` / `no` / `?`), el fallback es alcanzable y los ilegibles se cuentan aparte. En la
> consola da igual (los 29 son ELF con la sección de verdad, leída por `readelf`), pero
> el detector ya no puede infrapontar en silencio.

## 4. Matiz importante y verificado: el `.home` NO depende del nombre (ya está blindado)

Esto es lo que más se exagera al hablar de este tema, así que conviene dejarlo claro con lo
que se comprobó de verdad:

- El `.home` portable **no lo crea el runtime de AppImage**. En DeckStation lo crea
  `scripts/deploy-lanzar-sh.sh:asegurar_home()` (crea `${img}.home`) y lo **exporta**
  `lanzar.sh` (`export HOME=<lo que encuentre>`).
- Tanto `lanzar.sh` como `deckstation-configs.sh:resolve_home()` lo localizan por
  **patrón `*.home`**, no por nombre exacto. Renombrar el AppImage **no** rompe el `.home`.
- Se probó con el runtime real (`xenia_edge_linux_aarch64.AppImage`): llegó hasta GTK+ y
  **no creó ningún `.home`**. Sus cadenas relevantes en el ELF son `%s.home`, `.home`,
  `TARGET_APPIMAGE`, `APPDIR`, `OWD` — lógica presente, pero sin efecto en este
  escenario.

**Conclusión**: el `.home` por nombre ya está protegido. Lo que queda realmente roto es:

1. **Rutas por nombre en el `es_find_rules.xml`** (Xenia, y MAME — ver §6).
2. **`.AppImage.bak` huérfano**: el Updater renombra el viejo a `.bak` *antes* de escribir
   el nuevo (línea 1339-1344) y lo borra al terminar con éxito (1499-1503). Si la
   descarga se queda a medias, el `.bak` se queda **sin su `.AppImage`** y el lanzador no
   encuentra nada que lanzar.

## 5. Caso real en la consola ahora mismo: `BigPEmu` con `.bak` sin `.AppImage`

```
Apps/BigPEmu/BigPEmu-1.221-anylinux-aarch64.AppImage.bak     NO HAY .AppImage
```

Una actualización a medias. **No está roto del todo**: `BigPEmu` es el único emulador con
`lanzar.sh` propio (divergente de la plantilla, hace `exec ./bigpemu/bigpemu` con
`LANG=es_ES`), y `Apps/BigPEmu/bigpemu/bigpemu` **sí existe** → arranca. Pero el AppImage
no lo encuentra nadie.

## 6. La regla que queda frágil hoy: `MAME`

`es_find_rules.xml` línea 451, única entrada que sigue apuntando a un `*.AppImage` por
nombre en vez de a `lanzar.sh`:

```xml
<emulator name="MAME">
    <rule type="staticpath">
        <entry>./Apps/MAME/MAME-0.289-1-anylinux-aarch64.AppImage</entry>
```

Coincide ahora mismo, y en cuanto MAME suba de versión el Updater descargará
`MAME-0.290-1-anylinux-aarch64.AppImage` (mismo criterio que en el §3) y esta ruta se
romperá exactamente como se rompió la de Xenia. **Es el fallo que ya sabemos que va a
pasar**, no uno hipotético.

## 7. El guardian de rutas rotas: qué revisa y por qué no da falsos positivos

`tools/check-appimage-rutas.sh --ssh odin` (ejecutado contra la consola):

- `34 rutas de ./Apps/... existen y resuelven`
- `1 ROTA`: `RETROARCH [staticpath]` →
  `.../RetroArch-Linux-aarch64/RetroArch-Linux-aarch64.AppImage.home/.config/retroarch/cores`
  — es el **layout antiguo**, cuando RetroArch venía como AppImage. Ya no existe (ahora
  RetroArch es el binario nativo del buildbot). Ruta muerta, pero inocua: el RetroArch que
  se usa hoy se lanza por `Apps/RetroArch/RetroArch-Linux-aarch64/lanzar.sh`.
- `9 FRÁGILES` (apuntan a un nombre con versión/arquitectura), de las cuales **la real es
  `MAME`**. Las otras 8 son entradas que apuntan a `lanzar.sh` (correcto) o a rutas de
  ES-DE que no son nuestras.
- `31 correctos, 0 con problemas` en los `Apps/*/lanzar.sh` desplegados.

**Clasificación deliberada** (esto es lo que evita los 288 falsos positivos):

| Categoría | Qué significa | ¿Aviso? |
|---|---|---|
| `ROTA` | el emulador (primer componente bajo `Apps/`) **está instalado** pero el fichero de la ruta no | **Sí**, es un fallo real |
| `AUSENTE` | el emulador **no está instalado** | No. No es un error: `es_find_rules.xml` es la lista de ES-DE upstream, 342 entradas de las cuales 19 son emuladores ausentes (Citron, Ryujinx, Citra, Wine…) |
| `FRÁGIL` | la ruta resuelve **hoy** pero lleva versión/arquitectura en el nombre → se romperá en la próxima actualización | Aviso informativo |

**Las ~288 entradas de ES-DE upstream se ignoran a propósito**: flatpak
(`org.mamedev.MAME`), `~/.local/bin/...`, nombres de aplicación. Comprobarlas todas daría
falsos positivos y el guardian sería ruido, que es peor que no existir.

## 8. La propuesta (NO aplicada)

Parche propuesto: **`docs/patches/lanzar.sh-nombre-canonico.patch`** (203 líneas).
`patch -p1 --dry-run` → `rc=0`. `git diff --stat` de `lanzar.sh` → **vacío**: el fichero
original del repo está intacto.

Se propone tocar la **plantilla** (`scripts/lanzar.sh`, que se copia a las 31 carpetas
`Apps/*/lanzar.sh`), con el mismo patrón que el arreglo del `PATH` que ya lleva dentro.
Cuatro cosas, en orden:

1. **`appimage_real()` + `canon_symlink()`** — mantiene `Apps/<App>/<App>.AppImage` como
   **symlink relativo** al AppImage real más reciente (excluye `.bak`/`.old`). Nombre
   canónico que no cambia nunca, y relativo para que sobreviva a mover la carpeta.
2. **`migrar_home_canonico()`** — mueve el `.home` viejo al nombre canónico **solo si el
   canónico no existe**. Si hubiera los dos, no fusiona: avisa y respeta lo que hubiera.
   Sin esto, una reinstalación dejaría ajustes y partidas en un directorio que ya no usa
   nadie.
3. **Lanza por el symlink**, con caída al AppImage real si el symlink no se pudo crear.
   Nombre de invocación estable ⇒ `.home` estable.
4. **Mensaje de diagnóstico** cuando no hay nada que lanzar: lista los `.bak`/`.old`
   huérfanos con el `mv` exacto a mano. Es el caso BigPEmu.

**Regla de oro**: nada de esto puede impedir que un emulador arranque. Todo el bloque va
envuelto con `|| true` y cualquier fallo cae al comportamiento de siempre. Es fontanería,
no es condición de arranque.

### El diff, resumido

```diff
+# 1b. NOMBRE CANONICO — symlink <App>.AppImage al AppImage real.
+appimage_real()   { ... }   # el más reciente por mtime, excluye .bak/.old
+canon_symlink()   { ... }   # symlink RELATIVO al real más nuevo
+migrar_home_canonico() { ... }  # .home viejo -> canónico, solo si el canónico no existe
+canon_symlink "$DIR" 2>/dev/null || true
+migrar_home_canonico "$DIR" 2>/dev/null || true

-APPIMAGE_FILE=$(find "$DIR" -maxdepth 1 \( -iname "*.AppImage" ... \) | head -n 1)
+APPIMAGE_FILE="$DIR/$(basename "$DIR").AppImage"
+if [ ! -e "$APPIMAGE_FILE" ]; then
+  APPIMAGE_FILE=$(find "$DIR" -maxdepth 1 \( -iname "*.AppImage" ... \) | head -n 1)
+fi

+  # cuando no hay nada que lanzar, avisar de los .bak huérfanos con el mv a mano
```

### Pruebas funcionales del parche (sandbox, no en la consola)

Ejecutadas con el `lanzar.sh` parcheado contra un fixture, **todas correctas**:

| # | Escenario | Resultado |
|---|---|---|
| 1 | Primer arranque | crea `MiEmu.AppImage -> MiEmu-1.2.3-...AppImage`, migra `.home` a `MiEmu.AppImage.home`, invoca por symlink, saves intactos |
| 2 | Renombrado a `1.3.0` (rompiendo el symlink) | el siguiente arranque reapunta el symlink; HOME y saves siguen iguales |
| 3 | Carpeta no escribible | arranca igual con el AppImage real (degradación correcta) |
| 4 | Dos `.home` con datos | **no fusiona**, deja los dos |
| 5 | Solo `.AppImage.bak` | mensaje con el `mv` a mano, `rc=1`, retazo intacto |
| 6 | **RetroArch nativo** (sin AppImage, caso real de DeckStation) | arranca por `retroarch`, **no** crea symlink canónico, y el `.home` `RetroArch-Linux-aarch64.AppImage.home` se queda donde estaba (ya coincide con el canónico) |
| 7 | **Árbol extraído** `app/AppRun` | arranca por `AppRun`, migra el `.home` al canónico conservando los datos |

Casos 6 y 7 son los que importan para DeckStation: los dos layouts que **no** son
"un AppImage y ya" siguen funcionando sin tocar nada.

## 9. Cómo comprobarlo

```bash
# Los dos detectores, contra la consola (solo lectura, no copia nada)
tools/check-appimage-nombres.sh --ssh odin     # .upd_info + nombres frágiles
tools/check-appimage-rutas.sh    --ssh odin    # ROTA / AUSENTE / FRÁGIL + lanzar.sh

# El parche, en local (dry-run: no escribe nada)
patch -p1 --dry-run < docs/patches/lanzar.sh-nombre-canonico.patch
bash -n packages/deckstation-arm/scripts/lanzar.sh   # sintaxis de la plantilla

# Contra un arbol local en vez de la consola
tools/check-appimage-nombres.sh --dir /ruta/a/deckstation
tools/check-appimage-rutas.sh    --dir /ruta/a/deckstation --solo-rotas
```

Ambos scripts aceptan `--ssh HOST` (se reenvían a sí mismos por stdin, no copian nada a
la consola) y `--dir` para trabajar sobre un árbol local.

## 10. Lo que NO se ha hecho ni verificado

Honestidad explícita, para que nadie dé por bueno algo que no lo está:

- **El parche no está aplicado** en `packages/deckstation-arm/scripts/lanzar.sh` ni en la
  consola. Es una propuesta.
- **Los detectores no se han vuelto a ejecutar contra la consola** tras la última
  conexión: `ssh odin` empezó a dar `Connection timed out` y las cifras del §3 y §7 son
  las de la ejecución completa anterior. Conviene volver a pasarlos cuando la consola
  vuelva.
- **No se ha probado en la consola**: el parche solo se ha probado en un sandbox local.
  No se ha arrancado ningún emulador real con la versión parcheada.
- **No se ha tocado** `es_find_rules.xml`: la entrada frágil de `MAME` (§6) sigue ahí.
  El arreglo natural sería apuntarla a `./Apps/MAME/lanzar.sh`, igual que se hizo con
  Xenia, pero no se ha aplicado.
- **No se ha investigado** por qué `Apps/xenia_edge/.version` está vacío (§2).
- **El `.AppImage.bak` de BigPEmu sigue sin restaurar** (§5). Se deja como está: BigPEmu
  arranca por su `lanzar.sh` propio.
- **Riesgo latente no cerrado**: nada impide que alguien instale `AppImageUpdate` y abra
  el canal de auto-actualización por `.upd_info` (§3). No se ha instalado ni bloqueado.