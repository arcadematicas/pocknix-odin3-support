# REPORTE — WProton: fallo al instalar umu-launcher por límite de la API de GitHub (403)

**Para**: stshunz · **De**: arcadematicas (Alfred) · **Fecha**: 11/10/2026
**Dispositivo**: AYN Odin 3 (aarch64), Pocknix/CalvOS, kernel 7.2.9
**WProton**: v1.60 → se auto-actualizó a **v2.01** durante la sesión (el fallo es el mismo en ambas)

## Qué pasa
En el **primer arranque**, WProton no consigue instalar `umu-launcher`:

```
18:07:15 [INFO] Descargando umu-launcher (zipapp)...
curl: (22) The requested URL returned error: 403
18:07:15 [AVISO] comunidad: curl fallo al pedir la lista de profiles/ (codigo HTTP 403)
18:07:15 [AVISO] comunidad: el repositorio no devolvio ninguna entrada (codigo HTTP ?); se sigue con la copia guardada si la hay
18:07:15 [INFO] ERROR: No se pudo obtener la URL de umu-launcher
18:07:15 [INFO] ERROR-UI: No se pudo obtener la URL de umu-launcher
```

Logs: `/opt/wproton/logs/wproton_20261011_180715.log` (el del 403) y
`/opt/wproton/logs/wproton_20261011_180410.log` (primer arranque).

## Causa raíz
`gh_latest_asset()` (en `wproton.sh`, ~línea 14939) resuelve la URL del asset **con la API de
GitHub** y **sin reintentos ni plan B**:

```bash
gh_latest_asset() {
    # $1 = repo, $2 = patron grep -> imprime URL del asset (x86_64)
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
        | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 \
        | filter_assets | grep -iE "$2" | head -n1
}
```

- `curl -fsSL` **corta con código 22** en cuanto la respuesta no es 2xx → el pipeline sale vacío →
  `setup_umu()` recibe URL vacía y aborta.
- La API de GitHub **sin token = 60 peticiones/hora por IP**. La primera puesta en marcha coincide
  con la instalación de DeckStation (~25 repos) y con trabajo desde el PC de la misma red →
  **la cuota (por IP pública, compartida) se agota y llegan 403**.
- No es un fallo permanente: repetir más tarde funciona (verificado: ahora la API responde 200).

## Impacto
- Sin `umu-run` no se pueden lanzar los runners tipo **umu** (UMU-Proton, y GE-Proton por umu),
  que es justo lo que WProton instala en el primer arranque.
- Afecta a **cualquier** helper que use `gh_latest_asset`/`gh_release_tags`/`gh_tag_assets`
  (GE-Proton, UMU-Proton, Wine, y el mensaje de "comunidad" que también dio 403).

## Fix propuesto (sin depender de la cuota)
1. **Reintentos con backoff** en 403/429, respetando `Retry-After`, y **no usar `-f`** para poder
   leer el cuerpo del error.
2. **Plan B sin API** (no consume cuota) — resolver el asset por las vías públicas:
   - tag: `https://github.com/<repo>/releases.atom` (feed; sin cuota),
   - assets: `https://github.com/<repo>/releases/expanded_assets/<tag>` (HTML; sin cuota),
     o directamente `https://github.com/<repo>/releases/latest/download/<asset>` si el nombre del
     asset es estable.
3. **`GITHUB_TOKEN` opcional** (si está en el entorno o en `settings.conf`, se manda
   `Authorization: Bearer`; 5000/h).
4. **Cachear** la lista resuelta (repo → tag → URL) para no repetir la consulta.
5. Si aun así falla, **no abortar** la puesta en marcha: dejar el resto funcionando y reintentar
   en segundo plano (hoy se pierde el primer arranque entero).

## Extra (cosmético, por si interesa)
En el menú pygame aparecen repetidos:
```
MESA: error: fd_pipe_new2:49: unsupported GPU id 0x0 / chip id 0xe844050000
glx: failed to create dri3 screen
failed to load driver: msm
```
El menú funciona (cae a `llvmpipe`/swrast) pero convendría abrir con `fd_fdinfo`/GBM o forzar
`GALLIUM_DRIVER=zink` en la Odin.

## Cómo reproducirlo
1. WProton en un equipo donde la IP ya haya consumido la cuota de la API (o lanzar ~60 consultas
   seguidas contra `api.github.com` desde la misma red).
2. Primer arranque de WProton → se ve el 403 y "No se pudo obtener la URL de umu-launcher".
