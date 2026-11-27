# RustDesk en la Odin: "seleccione la pantalla" sin diálogo (27/11/2026)

## Síntoma

Al conectar a la Odin desde otro equipo, RustDesk dice que hay que seleccionar la pantalla pero **no
aparece el diálogo de KDE** (portal ScreenCast/RemoteDesktop).

## Causa real (no era el portal)

La **AppImage de RustDesk 1.5.3** (`/opt/rustdesk/rustdesk.AppImage`) es un binario empaquetado para
Debian y busca los plugins SPA de PipeWire en la ruta de Debian:

```
/usr/lib/aarch64-linux-gnu/spa/support/libspa-support.so
```

En Arch/CalvOS están en `/usr/lib/spa-0.2/…`, así que la carga fallaba y el proceso **abortaba con
`double free or corruption`** (core dump) antes de pedir el diálogo al portal. El journal lo deja claro:

```
rustdesk[...]: can't load /usr/lib/aarch64-linux-gnu/spa/support/libspa-support.so: ... No such file or directory
rustdesk[...]: double free or corruption (!prev)
systemd-coredump[...]: Process ... (rustdesk) of user 1001 terminated abnormally with signal 6/ABRT
```

## Arreglo

Enlace de toda la carpeta de plugins SPA a la ruta que espera el binario:

```bash
sudo mkdir -p /usr/lib/aarch64-linux-gnu
sudo ln -sfn /usr/lib/spa-0.2 /usr/lib/aarch64-linux-gnu/spa
```

Verificado: tras esto RustDesk arranca, **no** aparece el error de `libspa` y ya no crashea
(proceso estable, `Gtk-WARNING` del portal sobre ajustes que no existen es inocuo).

> Nota: el portal KDE sí es el correcto. En su día recompilamos `xdg-desktop-portal-kde` 6.7.4 porque
> el binario de ALARM no registraba los tipos QML (`ScreenChooserDialog`); esa actualización ya la ha
> pisado la 6.8.3-1 del repo, pero el binario nuevo **sí** lleva el QML compilado (`ScreenChooserDialog
> 1.0`, `prefer :/qt/qml/…`), así que no hay que recompilar nada. El fallo de hoy era solo PipeWire/SPA.

## Cómo probarlo

1. RustDesk abierto en la Odin (servidor).
2. Conectar desde el otro equipo.
3. En la pantalla de la Odin debe salir el diálogo de KDE para elegir pantalla/ventana; aceptar.
4. Si el cliente se queda en negro: revisar `journalctl --user -b | grep -i rustdesk` y que exista el
   enlace `/usr/lib/aarch64-linux-gnu/spa`.
