# PocknixControl: pestaña PROPIA en el QAM (17/10/2026)

## El problema
El cliente de Steam del **13/10/2026** partió el CSS del menú rápido: el `TitleView` del menú
de Decky busca `staticClasses.Title` y ya no existe →

```
TypeError: Cannot read properties of undefined (reading 'Title')
    at TitleView (http://localhost:1337/frontend/chunk-BJJdCYVd.js:5483)
```

Consecuencia: **la pestaña del menú de Decky deja de renderizarse**. Un plugin normal
(`definePlugin({ content })`) vive DENTRO de esa pestaña → **PocknixControl quedaba
inaccesible** (el plugin de Hooandee no, porque registra su propia pestaña).

Issues upstream (abiertas el 16-17/10): `SteamDeckHomebrew/decky-loader` **#988** y **#989**.
> *"the Oct 13 client split the quick access menu's CSS. There's a `TitleView` looking for
> `staticClasses.Title` and that doesn't exist anymore"*

Decisión de Fransis: **NO** parchear el frontend de Decky (que lo arreglen ellos) pero **sí**
dar a nuestro plugin su propia pestaña, para que nuestros ajustes estén siempre accesibles.

## La solución (implementada)
`src/qamTab.tsx` + `src/index.tsx`:

- Nos registramos en la **misma tabla de pestañas del QAM** que usa Decky:
  `window.__TABS_HOOK_INSTANCE` (`{ tabs, add, removeById }`) → `add({ id, title, content, icon })`.
  Es el mismo mecanismo que usa el plugin "Panel de Control" de Hooandee.
- `id = 0x504b43` ("PKC") y marca `__pkcOwner = "pocknix-control"`: la limpieza sólo toca
  **nuestra** pestaña.
- **Título propio** con `staticClasses?.Title` (optional chaining): si Steam vuelve a cambiar
  el CSS, el className queda `undefined` y la pestaña **sigue saliendo**; lo que no puede
  pasar es que un `TypeError` impida el registro (es el fallo de hoy).
- **Reintentos**: al cargar el plugin el hook puede no existir aún → 20 intentos cada 500 ms.
- **Degradación limpia**: si el hook no está (otra versión de Decky), avisa por consola y el
  plugin sigue con su pestaña normal de Decky. Nada se rompe.
- `onDismount` → cancelar reintentos + `unregisterQamTab()` + deshacer el parche del menú
  contextual de la biblioteca.

## Build y despliegue
```bash
tools/sync-to-os.sh
cd <árbol>/packages/shared/pocknix-decky/pocknix-control && npm run build   # dist/index.js
cp dist/index.js <centro>/packages/pocknix-decky/pocknix-control/dist/      # sin .map
# bump pkgrel de packages/pocknix-decky
```
En el dispositivo: reemplazar `/home/deck/homebrew/plugins/PocknixControl/dist/index.js`
(root:root, backup previo) y **reiniciar Steam** (no hace falta la consola).

## Verificar
- En el bundle compilado deben aparecer `__TABS_HOOK_INSTANCE` y `staticClasses?.Title`.
- En el QAM debe salir **"Pocknix Control"** como pestaña propia (además de la de Decky).
- Revertir: restaurar `index.js.bak-20261017` (o `pacman -S pocknix-decky` con el paquete
  anterior) y reiniciar Steam.

## Estado
- Centro: `src/qamTab.tsx`, `src/index.tsx`, `dist/index.js` compilado, `pkgrel` **54 → 55**.
- **Pendiente**: desplegar el `dist/index.js` en la Odin (estaba sin red) y compilar/publicar
  el paquete; y la prueba de Fransis (reiniciar Steam → QAM).
