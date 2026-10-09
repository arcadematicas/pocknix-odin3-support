# Decky CSS Loader + tema Hooandee Eclipse (de serie)

Desde pocknix-decky `pkgrel=49` la imagen trae, de fábrica:

- **CSS Loader** (SDH-CssLoader 2.1.2, GPL) vendored en
  `packages/pocknix-decky/css-loader/` y empaquetado en
  `/usr/share/decky-plugins/CSSLoader`. `pocknix-decky-sync.service` lo siembra en
  `~/homebrew/plugins/CSSLoader` en cada arranque (y hace `chown deck`).
- El oneshot `pocknix-decky-theme-eclipse.service`, que instala y activa el tema
  **Hooandee Eclipse** la primera vez.

## Por qué el tema NO viaja en la imagen

El tema es obra de Hooandee y no se redistribuye. El paquete solo lleva **URL + sha256**;
el script (`/usr/lib/pocknix/pocknix-decky-theme-eclipse`) lo descarga del catálogo
oficial en el primer arranque y verifica el hash antes de extraerlo:

- URL: `https://hooandee.github.io/panel-de-control/themes/v1/hooandee-eclipse/0.2.5/theme.zip`
- sha256: `c8da01e28119eae00f9a05148f756a9a43fc3b03635de1c90e95f8e6c1fe7e43`

## Comportamiento

1. Crea `/home/deck/.steam/steam/.cef-enable-remote-debugging` (si existe el dir) y lo
   chown a `deck` — sin esto CSS Loader no puede hablar con la UI de Steam.
2. Si falta `~/homebrew/themes/css_translations.json`, copia el snapshot estable de
   deckthemes que viaja en `/usr/share/pocknix/css_translations.json` (fallback offline;
   el plugin se baja el suyo cuando hay red).
3. Si NO existe `~/homebrew/themes/Hooandee Eclipse`: descarga, verifica sha256, extrae
   con `bsdtar`/`unzip` y escribe `config_USER.json` = `{"active": true}` (los parches
   usan los valores por defecto del manifiesto, que es el aspecto con el que se publica).
4. **Idempotente**: si el tema ya está, no toca su config. **Tolerante a offline**: sin
   red sale con 0 en silencio y reintenta al siguiente arranque. Nunca rompe el boot.

El nombre/formato del config se comprobó en `css_theme.py`:
`configPath + ("_ROOT.json" if USER=="root" else "_USER.json")`, y la clave que activa el
tema es `"active": true`.

## Orden de arranque

`pocknix-decky-sync.service` → `pocknix-decky-theme-eclipse.service` →
`pocknix-decky-loader.service` (todas tras `network-online.target`).
