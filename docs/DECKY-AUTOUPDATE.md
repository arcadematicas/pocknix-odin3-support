# Auto-actualización de Decky Loader (Odin 3)

**Fecha**: 17/10/2026 · **Dispositivo**: AYN Odin 3 (SM8750) · **Paquete**: `pocknix-decky` (pkgrel 54)
**Estado**: implementado en el centro; pendiente de **compilar/publicar** e instalar en la Odin.

---

## 1. TL;DR

- En la Odin, **Decky Loader corre vía FEX** (`pocknix-decky-loader.service`, descripción
  *"Decky Loader (via FEX)"*) con el `PluginLoader` **x86_64 oficial** de
  `SteamDeckHomebrew/decky-loader`, en `/home/deck/homebrew/services/PluginLoader`.
- El **botón de actualizar del QAM** están roto en ARM (cliente Steam ARM64 + Decky), así que
  **no había forma de actualizarlo a mano**. Este trabajo lo resuelve en dos frentes:
  1. **`tools/check-decky.sh`** (en el centro): compara nuestra versión con la última release
     **estable** upstream. Solo informa; exit ≠ 0 si hay desactualización (para CI/hooks).
  2. **`pocknix-decky-update`** (en el dispositivo, paquete `pocknix-decky`): actualiza el
     `PluginLoader` de `~/homebrew` a la última release **estable** por sí solo, vía
     `pocknix-decky-update.timer` (diario + poco después del arranque). **No reinicia nada.**
- **NO se parchea el frontend de Decky.** Decisión del usuario: que lo arregle upstream.

---

## 2. Contexto

- El `PluginLoader` es el binario **x86_64** que arranca Decky. En la Odin se ejecuta bajo
  **FEX** con un namespace `binfmt_misc` privado (`pocknix-decky-run`); ver el comentario de esa
  unidad.
- Nuestro paquete **`pocknix-decky`** trae ese `PluginLoader` (+ los plugins del OS) en
  `/usr/share/decky-loader/`. Al arrancar, `pocknix-decky-sync.service` siembra `deck`'s
  `~/homebrew` — pero **solo si la versión empaquetada es estrictamente más nueva** que la de
  `~/homebrew` (nunca degrada una actualización del propio Decky). Ese `sort -V` es la línea que
  respetamos.
- La release upstream más reciente **estable** es **`v3.2.10`** (2026-10-04). Hasta ahora el
  paquete llevaba **`v3.2.9`** → al ser el QAM inutilizable, no había manera limpia de subir.
- El paquete define la versión en `_loaderver` (PKGBUILD); de ahí se genera
  `/usr/share/decky-loader/.loader.version` y, al sembrar, `~/homebrew/services/.loader.version`.

> ⚠️ **Prereleases**: upstream publica `-preN`. El autoactualizador y el check usan **solo
> releases estables** por defecto (el endpoint `releases/latest` excluye prereleases y drafts).

---

## 3. Qué hace el autoactualizador (`pocknix-decky-update`)

1. Pregunta a la API de GitHub la **última release estable** de `SteamDeckHomebrew/decky-loader`.
2. Lee `~/homebrew/services/.loader.version` y compara con **`sort -V`** (normaliza `-pre` →
   `~pre`, así una prerelease ordena *por debajo* del release — misma convención que
   `pocknix-decky-sync`). Nunca compara strings.
3. Si la de upstream es **más nueva**:
   - **backup**: `PluginLoader.bak-<ver>-<fecha>` y `.loader.version.bak-<fecha>`.
   - **descarga** el asset `PluginLoader` a un temporal **en el mismo directorio**.
   - **valida**: que sea un **ELF ejecutable x86_64** (`\x7fELF`, `e_machine=0x3e`) y de
     **tamaño razonable** (~26 MB hoy; acepta 5 MB–200 MB). Si la release publicara un
     checksum (`.sha256`/checksum asset) se verificaría también; **hoy no lo publica**.
   - **instala de forma atómica**: `mv` (rename dentro del mismo FS) sobre el `PluginLoader`
     con owner **`deck:deck`** y modo **0755**, y escribe `.loader.version`. El `mv` atómico
     garantiza que un loader **en marcha** sigue con su inodo viejo: nunca se trunca un binario
     en uso.
4. **NO reinicia nada** (ni Decky ni Steam). El cambio **entra en el siguiente arranque** del
   loader / de Steam. Esto es deliberado: reiniciar Decky en caliente con Steam en modo juego
   crashea `steamwebhelper` (ver AGENTS).

**Tolerante a fallos e idempotente**: sin red sale **0** con aviso (no rompe el timer); si ya
está al día, **no hace nada**. Todo queda en el **journal** (`logger -t pocknix-decky-update`) y,
en éxito/fallo, se intenta avisar por **Telegram** (`avisar-telegram.sh` si existe; si no, solo
journal).

### Interacción con `pocknix-decky-sync`

No hay conflicto: `pocknix-decky-sync` re-siembra desde `/usr/share` **solo si el bundle es más
nuevo**. Como el autoactualizador solo sube a la última **estable**, un `~/homebrew` ya
actualizado **nunca se degrada** por el seed.

---

## 4. Dónde vive cada cosa

| Fichero | Dónde (centro) | Dónde (dispositivo) |
|---|---|---|
| Autoactualizador | `packages/pocknix-decky/pocknix-decky-update` | `/usr/local/bin/pocknix-decky-update` |
| Unidad | `packages/pocknix-decky/pocknix-decky-update.service` | `/etc/systemd/system/pocknix-decky-update.service` |
| Timer | `packages/pocknix-decky/pocknix-decky-update.timer` | `/etc/systemd/system/pocknix-decky-update.timer` |
| Herramienta de check (solo centro) | `tools/check-decky.sh` | — (no se empaqueta) |
| Esta doc | `docs/DECKY-AUTOUPDATE.md` | — |

- El **enable** del timer lo hace el **PKGBUILD** creando el symlink
  `/etc/systemd/system/timers.target.wants/pocknix-decky-update.timer` → `../pocknix-decky-update.timer`.
  Así el paquete es **dueño** del enable: desinstalarlo lo deshabilita.
- **Registro en el sync**: `pocknix-decky` **ya** se sincroniza como un `overlay` de
  **directorio entero** en `tools/sync-to-os.sh`, así que los ficheros nuevos viajan solos
  (verificado con `sync-to-os.sh --dry-run`). `check-sync.sh` también lo vigila. No hizo falta
  tocar ningún script de sync; solo se añadió un comentario aclaratorio.

---

## 5. Cuándo corre

`pocknix-decky-update.timer`:

- **`OnBootSec=10min`** — poco después del arranque, con margen para que suba la red y para que
  `pocknix-decky-sync` haya sembrado `~/homebrew`.
- **`OnCalendar=daily`** + `Persistent=true` — una vez al día (y recupera el chequeo si el
  equipo estaba apagado a esa hora).
- `RandomizedDelaySec=15min` — reparte el disparo para no coincidir con el arranque de un juego.

La unidad tiene `ConditionPathExists=/home/deck/homebrew/services/PluginLoader` (si Decky no
está sembrado, no hay nada que actualizar) y baja prioridad (`Nice=10`,
`IOSchedulingClass=idle`): es un chequeo de fondo que **nunca** debe competir con un juego.

---

## 6. Cómo se prueba

### a) En el centro (informativo)

```bash
tools/check-decky.sh                       # usa el PKGBUILD del centro
tools/check-decky.sh --tree ~/…/pocknix-os # usa el árbol de compilación
tools/check-decky.sh --prereleases         # incluye -pre
tools/check-decky.sh --loader-version-file /tmp/ver   # fuerza "nuestra" versión (pruebas)
```

Salida esperada (con el paquete ya en v3.2.10):

```
  nuestra       : v3.2.10   (packages/pocknix-decky/PKGBUILD (_loaderver))
  upstream      : v3.2.10   (última release ESTABLE; 2026-10-04T21:22:37Z)
  asset         : PluginLoader (26151976 B)
  -> ✅ al día (v3.2.10)
```

Exit code: **0** al día, **1** desactualizado, **2** sin red/API/parseo.

### b) En un portátil (sin la Odin), el autoactualizador

```bash
# solo comprueba (no descarga ni instala)
pocknix-decky-update --check \
  --loader /tmp/fake/services/PluginLoader --version-file /tmp/fake/services/.loader.version

# simula una versión vieja y ejercita la instalación REAL usando un asset local
pocknix-decky-update --no-telegram \
  --loader /tmp/fake/services/PluginLoader --version-file /tmp/fake/services/.loader.version \
  --owner "$USER" --asset-url "file:///path/al/PluginLoader-v3.2.10"
```

`--check` con `.loader.version` = `v3.2.10` → *"al día"*; con `v3.2.7` → *"hay versión nueva
(v3.2.7 → v3.2.10)"*. La instalación real deja backup, instala el binario (0755) y escribe
`.loader.version`; **re-ejecutarlo es no-op**. Un asset que no sea ELF x86_64 falla con exit 1 y
**deja intacto** el loader anterior.

### c) En la Odin (cuando se publique)

```bash
sudo systemctl start pocknix-decky-update.service   # lanza el chequeo ahora
journalctl -t pocknix-decky-update -n 50            # ver qué hizo
systemctl list-timers pocknix-decky-update.timer    # ver el próximo disparo
cat /home/deck/homebrew/services/.loader.version    # versión resultante
```

No hace falta reiniciar: el nuevo loader entra al siguiente arranque de Decky/Steam.

---

## 7. Cómo revertir

- **Volver a la versión que empaqueta el OS**:

  ```bash
  sudo pacman -S pocknix-decky          # reinstala el PluginLoader del repo
  sudo systemctl restart pocknix-decky-sync.service   # lo re-siembra en ~/homebrew
  ```

  (`pocknix-decky-sync` re-copia porque el bundle del repo pasa a ser **más nuevo** que el de
  `~/homebrew`... si el de `~/homebrew` es más nuevo, bórralo antes:
  `sudo rm -f /home/deck/homebrew/services/PluginLoader /home/deck/homebrew/services/.loader.version`.)

- **Backups automáticos**: cada actualización deja `PluginLoader.bak-<ver>-<fecha>` y
  `.loader.version.bak-<fecha>` junto a los originales en `~/homebrew/services/`. Restaurar =
  copiar el `.bak` encima y volver a poner su `.loader.version`.

- **Desactivar el autoactualizador** (sin desinstalar el paquete):

  ```bash
  sudo systemctl disable --now pocknix-decky-update.timer
  ```

---

## 8. Por qué NO se parchea el frontend de Decky

El fallo del QAM nuevo (el botón de actualizar / el panel) es del **frontend** de Decky en ARM y
**lo tiene que arreglar upstream**. Se decidió **no** hacer un apaño local del `index.js`/plugins
del loader: sería un parche que habría que re-aplicar en cada release y que puede romper cosas.
El autoactualizador evita ese problema por otro camino: **mantiene el binario oficial al día**,
sin tocar su frontend.

---

## 9. Notas de empaquetado (pkgrel 54)

- **`_loaderver`: `v3.2.9` → `v3.2.10`** + `sha256sums` del asset
  (`c2cf316a53e1c1d318c6dda8821c827e5db275922987f9097956d7a1576e8258`, 26151976 B, release
  2026-10-04). Así una imagen nueva **siembra ya la última** desde el arranque.
- **`pkgrel` 53 → 54**: añade el binario, las dos unidades y el enable del timer.
- Para compilar/publicar: `tools/sync-to-os.sh && tools/check-sync.sh` y luego
  `cd ../pocknix-os && sudo DEVICE=sm8750 make packages PKG="pocknix-decky"` y
  `scripts/publish-repo.sh`. En el dispositivo: `pacman -Sy --needed pocknix-decky`.

---

## 10. Límites conocidos

- La release upstream **no publica checksum** del asset `PluginLoader`; la validación es
  **ELF + arquitectura x86_64 + tamaño**. Si algún día publica `.sha256`, el script ya busca un
  asset de checksum y lo usaría (y `POCKNIX_DECKY_SHA256` / `--asset-url` permiten forzar/pinear).
- El autoactualizador **no actualiza los plugins**, solo el `PluginLoader`. Los plugins que
  llevamos (PocknixControl, SDH-CssLoader, MAKO, Panel de Control) tienen su propio ciclo; ver
  `tools/check-decky-plugins.sh` y `docs/` de cada uno.
