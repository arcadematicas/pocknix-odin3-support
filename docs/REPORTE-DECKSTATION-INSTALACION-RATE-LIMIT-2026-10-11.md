# REPORTE — DeckStation: la PRIMERA INSTALACIÓN revienta el límite de la API de GitHub

**Para**: stshunz · **De**: arcadematicas (Alfred) · **Fecha**: 11/10/2026
**Dispositivo**: AYN Odin 3 (aarch64), Pocknix/CalvOS

## Resumen
El **Updater esta bien** (ya detecta el 403 y avisa de `github_token.txt`). El que se pasa de
rosca es la **instalacion inicial**: pide **metadatos por la API de GitHub para ~25 apps**
(`/releases` y `/releases/tags/<tag>` = ~2 llamadas por app, ~50 en pocos minutos) y la API sin
token tiene **60 peticiones/hora POR IP**. Al compartir la IP con el PC (que ademas trabaja en
paralelo) el cupo se agota y **algunos emuladores no se descargan**.

## Evidencia
`/opt/deckstation/logs/setup.log`:
```
[2026-10-11 17:57:53] Instalando los emuladores (son ~1,5 GB; puede tardar)...
[2026-10-11 17:59:36] [WARN] Algun emulador fallo; se puede reintentar desde el Updater
```
Resultado: `Apps/` quedo con 26 carpetas y **`xenia_edge` SIN AppImage**.
En la MISMA ventana, el log de WProton recogio el 403 del cupo:
`wproton_20261011_180715.log` -> `curl: (22) ... error: 403` + *"No se pudo obtener la URL..."*.
(Ver `docs/REPORTE-WPROTON-UMU-403-2026-10-11.md`.)

Ojo: lo que consume cuota son **los metadatos**, NO las descargas
(`github.com/.../releases/download/...` no pasa por `api.github.com`). Resolviendo los metadatos
sin API, la instalacion entera puede bajar todo sin tocar el cupo.

## Fix propuesto (VERIFICADO, sin API y sin cuota)
1. **Resolver sin API** (comprobado en vivo con Amiberry):
   - tag: `https://github.com/<owner>/<repo>/releases.atom` (feed Atom, **sin cuota**)
     ```
     <title>Amiberry: 8.3.0</title>
     ```
   - assets: `https://github.com/<owner>/<repo>/releases/expanded_assets/<tag>` (HTML, **sin cuota**)
     ```
     releases/download/8.3.0%402026-09-01_1788278384/Amiberry-8.3.0-anylinux-aarch64.AppImage
     ```
   - (o directamente `.../releases/latest/download/<asset>` si el nombre es estable)
2. **Fallback**: mantener la API como via rapida y **caer al plan (1) en 403/429**.
3. **Reintentos con backoff** respetando `X-RateLimit-Reset` (hoy ya lo lee, pero **devuelve None**;
   mejor esperar y reintentar una vez).
4. **Token opcional**: `github_token.txt` (ya soportado) -> 5000/h; documentarlo en el setup.
5. **Cache** de `repo -> tag -> asset` en la SD: la segunda pasada no consulta nada.
6. **No abortar**: seguir con el resto y **reintentar los fallidos al final**.

### Boceto de codigo (para `updater.py`)
```python
def _github_latest_no_api(owner_repo, pattern):
    """Tag y assets sin gastar cuota de la API: releases.atom + expanded_assets."""
    import re
    atom = requests.get(f"https://github.com/{owner_repo}/releases.atom", timeout=15).text
    m = re.search(r"<id>tag:github.com,2008:Repository/\d+/([^<]+)</id>", atom)
    if not m:
        return None, []
    tag = m.group(1)
    html = requests.get(
        f"https://github.com/{owner_repo}/releases/expanded_assets/{tag}", timeout=15
    ).text
    assets = re.findall(
        r'href="(/[^"]+/releases/download/[^"]+)"', html
    )
    assets = [a for a in assets if re.search(pattern, a, re.I)]
    return tag, assets
```
Usar `_github_latest_no_api()` cuando `fetch_github_releases()` reciba 403/429, y **cachear**
el resultado igual que hoy (`self._cache_set`).

## Impacto
- La primera instalacion deja de depender del cupo -> **todos los emuladores bajan**.
- Y de paso el Updater se vuelve resiliente en equipos con IP compartida (nuestra casa: Odin +
  PC + moviles).

## Reproducir
`api.github.com/rate_limit` -> `core.limit = 60` (sin token). Lanzar el setup con el cupo
consumido (o ~60 consultas seguidas desde la misma red) y ver el `[WARN] Algun emulador fallo`.
