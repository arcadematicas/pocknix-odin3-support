# Botón de encendido correcto + branding del escritorio (portado de la imagen de shuuri) — 14/10/2026

Fransis probó la imagen de shuuri (PR #135) y detectó dos cosas que **hacen mejor que la nuestra**.
Esto es lo que hay detrás y lo que hemos hecho.

## 1) Botón de encendido: mantener = menú de apagado; toque corto NO apaga la pantalla

**Causa real** (no era el `powerdevilrc`, que ya teníamos): en **Plasma Mobile** el botón está atado a
**"Turn Off Screen"** y la acción **"PowerOff"** de powerdevil queda **sin atar** → un toque solo apaga la
pantalla y no hay forma cómoda de apagar/reiniciar desde el escritorio.

**El truco de upstream** (`pocknix-desktop-kde` 0.1.0-2): un script que, **una vez por usuario**, reescribe
`~/.config/kglobalshortcutsrc`:
- `org_kde_powerdevil / PowerOff` → `"Power Off,none,Power Off"`
- `org_kde_powerdevil / "Turn Off Screen"` → `"none,Power Off,Turn Off Screen"`

(KDE lee los atajos globales **solo al arrancar la sesión** → el cambio aplica a partir del **siguiente**
arranque de la sesión; y solo toca los valores que siguen siendo los de por defecto.)

**Lo que hemos hecho (mínimo y sin adoptar la reestructuración de upstream del escritorio):**
- `overlay/etc/xdg/plasma-workspace/env/50-kde-power-key.sh` ← su script, adaptado a **hook de entorno de
  Plasma** (se *sourcea*, así que usa `return` en vez de `exit`; en su imagen vive en
  `/usr/lib/pocknix/desktop.d/`, un mecanismo que nosotros aún no tenemos).
- `overlay/etc/xdg/powerdevilrc` ← su fichero tal cual (`PowerButtonAction=1` en AC/Batería/Batería baja),
  por si algún día `pocknix-desktop` deja de traerlo (conflicto: mismo contenido, así que es inocuo).
- `build-sd-image.sh` copia `overlay/` al rootfs (línea ~102) → **entra en la imagen**.

**Pendiente**: reconstruir imagen y verificar (mantener → menú; toque corto → nada).

## 2) Escritorio: fondo Pocknix + iconos del dock

Su paquete **`pocknix-branding` 0.1.0-2** trae `/usr/share/wallpapers/PocknixOS/` (1920x1080) +
`pocknix-branding-init` (+ unidad de usuario en `plasma-plasmashell.service.wants/`) que **siembra el fondo
en el primer login** (sello `~/.config/pocknix/branding-seeded`; usa `plasma-apply-wallpaperimage`/`busctl`).
Los iconos del dock vienen de su sesión **plasma-mobile** (`pocknix-desktop-plasma-mobile`, plasma-mobile 6.7.4).

**Lo que hemos hecho:** `pocknix-branding` añadido a `devices/sm8750/packages.list` (nada dependía de él, así
que hay que instalarlo explícitamente). Además hemos **sincronizado de upstream** la familia del escritorio
que nos faltaba: `pocknix-desktop` (→ `0.1.0-31`), `pocknix-desktop-full` (-3),
**`pocknix-desktop-plasma` (-1, NUEVO)**, **`pocknix-desktop-plasma-mobile` (-2, NUEVO)**,
`pocknix-desktop-kde` (-2, NUEVO) — ahora `pocknix-desktop-plasma-mobile` ya **depende de
`pocknix-desktop-kde`**, así que la cadena del escritorio trae el paquete del botón sola.

**Ojo**: nuestra `pocknix-desktop-kde` declara `conflicts=('pocknix-desktop<0.1.0-27')` y nosotros íbamos en
**-26** → de ahí la necesidad de subir `pocknix-desktop` (ya está en **-31**).
