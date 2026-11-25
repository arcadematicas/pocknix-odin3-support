# hakuX: actualizar directo de GitHub (diseño, 25/11/2026)

Decisión de Fransis (25/11): el botón debe bajar la **última estable** de
`portare-ch/hakuX-lr` directamente, como un core suelto de RetroArch, sin esperar a que
nosotros montemos el paquete. Solo **estable** (nada de *nightly*).

## Por qué

`libretro-hakux` se empaqueta y se firma (`.pkg.tar.xz`), así que el botón solo puede
ofrecer lo que haya en **nuestro** repo. Upstream publica estable casi a diario; el paquete
se quedó en 0.25.2 mientras upstream iba por 0.38.0.

## Diseño (tres piezas)

1. **`scripts/deckstation-hakux-update.sh`** (usuario, sin root):
   - consulta los releases de GitHub, se queda con el **último no-prerelease** cuyo tag sea
     `linux-v*` (los `nightly-*` son prerelease y se ignoran);
   - elige el asset `*aarch64*.tar.gz` (el nombre cambió en 0.38.0: `hakux-*` → `hakux-lr-*`,
     así que se busca por patrón, no por nombre fijo) y su `.sha256`;
   - descarga a un temporal, **verifica el sha256** del sidecar del release;
   - extrae `*_libretro.so` y `*_libretro.info`, y los instala en la carpeta de cores de
     DeckStation (la que usa ES-DE) con los nombres de siempre: `hakux_libretro.so` /
     `hakux_libretro.info`;
   - guarda la versión anterior como `hakux_libretro.so.bak-<ver>`, escribe `hakux.version`
     junto al core y añade `hakux_libretro.so` a `cores/.loose-overrides`;
   - imprime la versión instalada y de dónde salió.
2. **Menú del Updater**: opción nueva «Actualizar hakuX desde GitHub (última estable)», en
   hilo aparte como las demás, mostrando la última línea del script. La opción actual
   («core propio», la del paquete) se queda como vuelta a la base del sistema.
3. **Puente** (`deckstation-cores.sh`): **no sobrescribir** los cores listados en
   `cores/.loose-overrides`. Si no, el pack del sistema pisaría el hakuX bajado de GitHub en
   la siguiente pasada.

## Requisitos y límites

- Sin root: todo cae en `/opt/deckstation/...`, que es de `deck`.
- Confianza: la del `sha256` que publica `portare-ch` (mismo nivel que un core del buildbot).
- Si un día el asset cambia de layout, el script debe **abortar con mensaje claro** en vez de
  instalar algo a medias (comparar que exista exactamente un `*_libretro.so`).
- El paquete `libretro-hakux` se queda como **base para instalaciones nuevas**.

## Validación

1. `--dry-run`: muestra versión remota, asset, sha256 y destino sin escribir.
2. Ejecución real con la 0.38.0 ya publicada (debe decir "ya está la última" o reinstalar).
3. Comprobar en RetroArch que `display_version` es la nueva, y que el pack **no** la pisa
   tras ejecutarlo a mano.
4. Rollback: restaurar `hakux_libretro.so.bak-<ver>` y quitar la línea de `.loose-overrides`.
