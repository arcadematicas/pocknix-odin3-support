# WProton 1.72 (`arm-2026-10-11a`) — la version nueva de stshunz (11/10/2026)

**Origen**: stshunz nos paso `wproton_arm.sh` para probar SIN decir que traia. Este documento es el
**analisis del diff** (contra la 1.72 que ya corria) y lo que hicimos.

## Identificacion
| | |
|---|---|
| md5 | `d1e6c5a14e2ae8c912592828851be5f8` |
| bytes | 2.063.166 |
| `WPROTON_VERSION` | `1.72` |
| `WPROTON_BUILD` | `arm-2026-10-11a` (la anterior: `arm-2026-10-01a`) |

## Que corrige (delta real: +903 / -52 lineas, 30 hunks)
1. **Limite de la API de GitHub** (justo lo que habiamos reportado; el autor **cita el informe de Pocknix**):
   - **`GITHUB_TOKEN` opcional** (en el script, o en un `github.key` junto a el; tambien detecta un
     `.txt` con el prefijo) → **60/h → 5000/h**.
   - Acceso unificado a GitHub con **cache + reintentos + via alternativa SIN API**:
     `gh_api_get()`, `gh_assets_latest()`, `gh_assets_json_a_urls()`. Sustituye los `curl` sueltos a
     `api.github.com` de umu-launcher, dwarfs, squashfuse y fuse-overlayfs.
2. **Diagnostico visible** (menu): cuota de la API de GitHub + estado de umu
   (`gh_cuota_diagnostico`, `umu_pendiente_fich`): "*no se pudo obtener la URL de umu-launcher*" y
   media hora despues iba solo — eso era el limite por IP.
3. **BUG GORDO que nosotros no vimos** (lo caza el): la marca de "primera vez" **dependia de
   `umu-run`** → si umu no se podia bajar (cuota agotada), WProton **se creia en su primera vez en
   CADA arranque** y repetia la ceremonia completa (ventana de instalacion, runners, la pregunta de
   Steam). Ahora la marca manda y hay `umu_reintentar_si_falta`.
4. **Un token `ghp_…` se colaba como clave de SteamGridDB** (pasaba el filtro de "16+ alfanumericos"):
   se guardaba en `sgdb.key`, se borraba el `.txt`… y no funcionaba ni una cosa ni la otra.

## Que hicimos nosotros
- **Vendorizado**: `packages/shared/wproton-arm/wproton_arm.sh` (1.60 → 1.72) + `pkgrel 2` en el
  arbol (`arcadematicas/pocknix-os`, `odin3-sm8750`).
- **Publicado en R2**: `wproton-arm-1.0.0-2` (para que llegue con `-Syu`).
- **Instalado a mano en la SD de 1 TB** (probarlo) y **dentro de `calvos-1.2`** (verificado: el
  fichero de la imagen tiene este mismo md5).
- Informe previo que origino su arreglo: `docs/REPORTE-WPROTON-UMU-403-2026-10-11.md`.

## Pendiente de Fransis
Probarlo en la 1TB: primer arranque + el menu de diagnostico (cuota de la API / estado de umu).
