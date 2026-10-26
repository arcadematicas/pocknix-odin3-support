# Red de seguridad kernel/módulos (26/10/2026)

## Qué pasó

Al instalar el kernel **1034** (parche del panel) copié `KERNEL` a `/flash` y **extraje los módulos
en la ruta equivocada**: el `modules-7.2.12.tar.zst` está enraizado en el directorio de módulos
(`./kernel/...`), no en `/`. Con `-C /` no se sobrescribió nada.

Resultado: **kernel nuevo + módulos del build anterior**. Como los dos son `7.2.12`, la versión
cuadraba y nada avisó. Al arrancar:

- sin mando, sin wifi, sin audio (los `.ko` fallan con `failed to validate module [...] BTF: -22`)
- sin red y sin USB (`usbhid` también es módulo) → **sin teclado**
- el sistema está en la memoria interna → la SD no sirve para arreglarlo desde otro equipo

Solo se pudo recuperar por casualidad: la SD estaba montada en `/opt` y desde ella se lanzó un
script táctil que usó `systemd-run` (polkit autoriza `org.freedesktop.systemd1.*` al grupo `wheel`,
así que **no pide contraseña**).

## Las tres capas del seguro

1. **`pocknix-kernel-guard`** (paquete `pocknix-kernel-guard`, repo *shared*, dependencia de
   `pocknix-core`). Timer a los **75 s** del arranque:
   - compara el md5 de `/flash/KERNEL` con el marcador del build de los módulos;
   - busca en el log del kernel `failed to validate module` (señal genérica, vale en cualquier SoC);
   - si algo no cuadra, reinstala los módulos desde `/flash/modules-<ver>.tar.zst`, `depmod`,
     corrige el marcador y **reinicia una sola vez** (flag en `/run` para no entrar en bucle).
   - Log: `/flash/pocknix-kernel-guard.log`.

2. **El par reparador en `/flash`**: `pocknix-kernel-pair` (hook alpm `91-…`) deja, tras cada
   instalación/actualización de kernel o módulos, el md5 del `KERNEL` y el tar de módulos **de ese
   mismo build**, y borra los viejos. Así el guardia siempre tiene de dónde reparar. Ocupa ~100 MB
   (hay que vigilar el espacio de `/flash`, 510 MB en total).

3. **Kit en la SD (`/opt`)**: `fix.sh`, `rollback.sh`, `diag.sh`. Sirven cuando el sistema arranca
   pero la UI no responde; se lanzan tocando el fichero en el gestor (sin teclado).

## Regla de oro (añadida a `AGENTS.md`)

> El kernel **siempre** por paquete (`linux-pocknix-sm8750`), que instala módulos y dispara
> `pocknix-build-bootimg` (hook 90) para regenerar `/flash/KERNEL`. **Nunca** copiar `KERNEL` o
> extraer módulos a mano: si hace falta, usar el par y verificar con `pocknix-kernel-guard`.

## Recuperación manual (si algo vuelve a fallar)

Con la consola arrancada y sin red/mando:

```sh
systemd-run --quiet --collect --wait --pipe /usr/local/bin/pocknix-kernel-guard   # repara y reinicia
systemd-run --quiet --collect --wait --pipe pocknix-rollback --to <id> --yes     # o vuelve a una instantánea
```

Desde otro equipo, si hay red: lo mismo por SSH (sin contraseña, `systemd-run` no la pide).

## Verificación hecha (26/10)

- Prueba real forzando un marcador falso: el guardia detectó el desajuste, reinstaló los módulos,
  corrigió el marcador y reinició → tras el arranque, `0` fallos BTF, wifi y mando OK.
- `systemctl --failed` vacío; `pocknix-kernel-guard.timer` activo.
