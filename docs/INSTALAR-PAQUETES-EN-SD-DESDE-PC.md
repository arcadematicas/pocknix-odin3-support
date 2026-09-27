# Instalar paquetes aarch64 en una SD de Pocknix desde el PC (sin arrancar la Odin)

**Qué:** cómo meter paquetes `.pkg.tar.*` **aarch64** en la SD de la Odin 3 **desde el PC
x86_64**, sin enchufarla, sin SSH y sin arrancar nada.

**Por qué:** la SD es btrfs con snapshots y se toca fácil; arrancarla para instalar un paquete es
lentísimo y obliga a meter la Odin en el bootloader. El PC (CachyOS) ya tiene `qemu-aarch64-static`
y los handlers de `binfmt_misc` registrados, así que un **chroot aarch64 sobre la SD montada**
funciona perfectamente.

**Cuándo se usa:** sustituir paquetes del sistema (Mesa, Turnip, kernel…), probar un paquete de
Valve, o instalar cualquier `.pkg` que no esté en los repos de ALARM.

> ⚠️ **Esto escribe en la SD como si fueras la Odin.** Nada de esto es reversible con un `pacman
> -U` al revés. Toca lo que toque, lee las trampas del final **antes** de empezar.

---

## 0. Requisitos (comprobados)

En el PC (CachyOS):

```bash
# el intérprete aarch64
pacman -Q qemu-aarch64-static

# el handler de binfmt: debe existir y estar habilitado
ls -l /proc/sys/fs/binfmt_misc/qemu-aarch64
```

Si el fichero no está, hay que activarlo:

```bash
sudo systemctl enable --now systemd-binfmt
```

---

## 1. Montar la SD

La SD de la Odin son 2 particiones útiles: la **FAT** (el bootloader, `/flash`) y la **btrfs** de
la raíz (`POCKNIX_ROOT`). Para instalar paquetes solo hace falta **la btrfs** (raíz y sus
subvolúmenes).

```bash
# ver las particiones de la SD
lsblk -f

# montar la raíz de la SD (sustituir el dispositivo por el de la SD)
sudo mount /dev/mmcblk0p2 /mnt
```

Si no está montada a pelo (por el tema de los subvolúmenes), se puede forzar en solo lectura de
rescate:

```bash
sudo mount -o ro,rescue=all /dev/mmcblk0p2 /mnt
```

A partir de aquí, `RAIZ_SD=/mnt`.

---

## 2. Montar `/dev`, `/proc` y `/sys` dentro de la SD

Un chroot sin `/dev`, `/proc` y `/sys` es un chroot roto: `pacman` no ve nada y no puede hacer nada.

```bash
RAIZ_SD=/mnt
sudo mount --bind /dev  "$RAIZ_SD/dev"
sudo mount --bind /proc "$RAIZ_SD/proc"
sudo mount --bind /sys  "$RAIZ_SD/sys"
```

---

## 3. Copiar `qemu-aarch64-static` a la SD

Es el paso que hace posible todo lo demás: los binarios de la SD son aarch64 y el PC es x86_64, así
que sin el intérprete en `usr/bin` **nada arranca**.

```bash
RAIZ_SD=/mnt
sudo cp /usr/bin/qemu-aarch64-static "$RAIZ_SD/usr/bin/"
sudo chmod +x    "$RAIZ_SD/usr/bin/qemu-aarch64-static"
```

---

## 4. Entrar en el chroot

```bash
sudo chroot /mnt /usr/bin/qemu-aarch64-static /bin/bash
```

Dentro, **`uname -m` tiene que decir `aarch64`** — si dice otra cosa, el intérprete no está
registrado y lo que se está ejecutando es otra cosa (o nada):

```console
# uname -m
aarch64
```

Si te pide shell interactivo y se queda tonto, entra con el flag explícito:

```bash
sudo chroot /mnt /usr/bin/qemu-aarch64-static /bin/bash -i
```

---

## 5. Instalar el paquete

Dentro del chroot:

```bash
# meter el paquete en la SD (desde otra terminal del PC, o con cp antes de entrar)
cd /tmp
pacman -U --noconfirm /tmp/<paquete>.pkg.tar.zst
```

### Paquetes NUESTROS

Los que compilamos nosotros están en el **localrepo** del árbol de build:

```
/home/fransis/pocknix-odin3-project/pocknix-os/build/localrepo/sm8750/
```

Por ejemplo:

```
mesa-2:26.2.3-1-aarch64.pkg.tar.xz
vulkan-freedreno-2:26.2.3-1-aarch64.pkg.tar.xz
```

```bash
pacman -U --noconfirm /home/fransis/.../build/localrepo/sm8750/mesa-2:26.2.3-1-aarch64.pkg.tar.xz
```

### ⚠️ Lo que SÍ hay que hacer antes

Pocknix lanza el hook **`pocknix: pre-update btrfs snapshot`** antes de cada transacción de
pacman → **hay un snapshot btrfs de seguridad**. Aun así, comprobar que existe antes de tocar nada:

```bash
# desde el PC, con la SD montada
sudo btrfs subvolume list "$RAIZ_SD" | grep -i snap
```

---

## 6. Limpiar

Al terminar, **desde el PC** (no desde el chroot):

```bash
RAIZ_SD=/mnt

# borrar los .pkg temporales que se copiaron
rm -f "$RAIZ_SD"/tmp/*.pkg.tar.*

# retirar el intérprete (no debe quedarse en la imagen)
sudo rm -f "$RAIZ_SD/usr/bin/qemu-aarch64-static"

# desmontar /dev, /proc y /sys (en orden inverso)
sudo umount "$RAIZ_SD/sys"
sudo umount "$RAIZ_SD/proc"
sudo umount "$RAIZ_SD/dev"

# desmontar la SD
sudo umount "$RAIZ_SD"
```

> ⚠️ Si el `umount` dice `target is busy`, casi siempre es que se ha quedado un proceso del chroot
> vivo. En el PC: `sudo fuser -vm "$RAIZ_SD"` para verlo, y matar lo que haga falta. **No hagas
> `umount -l` a lo bruto** con la SD conectada: el btrfs se ha corrompido ya dos veces así.

---

## ⚠️ TRAMPAS COMPROBADAS (27/09/2026)

Estas cinco están todas sacadas de hacerlo de verdad. Las cinco muerden.

### a) 🟡 El chroot NO tiene red: `pacman` no puede descargar nada

El `/etc/resolv.conf` de la SD es un **enlace al stub de `systemd-resolved`**, y ese servicio no
está corriendo en un chroot. Resultado: DNS no resuelve y `pacman -S` se queda colgado o falla al
bajar las dependencias.

**Solución: descargar las dependencias en el PC con `curl` y meterlas dentro**, para instalarlas
todas juntas y sin red:

```bash
# en el PC — los repos del sistema aarch64 están en mirror.archlinuxarm.org
# (bajar la .db del repo, sacar la versión exacta de cada dependencia que falte y bajar el .pkg)
REPO=alarm        # o core, extra, aur...

curl -LO "https://mirror.archlinuxarm.org/aarch64/$REPO/os/$REPO.db.tar.gz"
# con la .db a mano: localizar cada dependencia que falte y bajar su .pkg.tar.zst a /tmp
```

```bash
# y dentro del chroot, instalar el paquete + SUS dependencias de golpe
pacman -U --noconfirm /tmp/dep1-*.pkg.tar.zst /tmp/dep2-*.pkg.tar.zst /tmp/<paquete>.pkg.tar.zst
```

### b) 🔴 `pacman -U --noconfirm` NO acepta la pregunta "Remove mesa? [y/N]"

Cuando el paquete nuevo **reemplaza** a uno instalado (típico: `provides: mesa`), pacman pregunta
por la eliminación **a notwithstanding del `--noconfirm`** y con `--noconfirm` se queda colgado o
falla a mitad.

**Solución: quitar ANTES los paquetes en conflicto**, y luego instalar:

```bash
# dentro del chroot
pacman -Rdd --noconfirm mesa vulkan-freedreno
pacman -U     --noconfirm /tmp/<paquete>.pkg.tar.zst
```

> ⚠️ `-Rdd` no mira dependencias: es justo lo que se quiere aquí (lo que se quita es lo que el
> paquete nuevo va a sustituir), pero **comprobar después que no se ha ido nada importante**
> (`pacman -Qkk`, `vulkaninfo --summary`).

### c) 📦 Los paquetes nuestros están en `build/localrepo/sm8750/`

No en `/var/cache/pacman` ni en los repos de ALARM. Ver §5.

### d) 🟢 Pocknix lanza el hook `pocknix: pre-update btrfs snapshot` antes de cada transacción

Buena noticia: **cada `pacman` deja un snapshot btrfs** detrás. Si algo sale mal, se vuelve al
anterior (herramienta `pocknix-rollback`). Aun así, comprobar que el subvolumen de snapshots
existe antes de empezar (ver §5).

### e) 🧹 Al terminar: borrar los `.pkg`, quitar `qemu-aarch64-static` y desmontar

Ver §6. Olvidar el `qemu-aarch64-static` en la imagen es ruido innecesario; **olvidar desmontar
`/dev`, `/proc` y `/sys` antes de la SD** es desmontar la SD con el kernel de dentro ->
`target is busy` y, si se fuerza, corrupto.

---

## 📌 Resumen en 30 segundos

```
1. lsblk -f                                       → ver la SD
2. mount /dev/mmcblk0p2 /mnt                      → la raíz
3. mount --bind /dev /proc /sys  en /mnt/{dev,proc,sys}
4. cp /usr/bin/qemu-aarch64-static  /mnt/usr/bin/
5. chroot /mnt /usr/bin/qemu-aarch64-static /bin/bash   → uname -m == aarch64
6. pacman -Rdd --noconfirm <conflictos>           → si el paquete los reemplaza
7. pacman -U  --noconfirm /tmp/<paquete>.pkg.tar.*
8. salir; rm /mnt/tmp/*.pkg; rm /mnt/usr/bin/qemu-aarch64-static
9. umount /mnt/{sys,proc,dev} y luego /mnt
```

Y recuerda: **el chroot no tiene DNS** (trampa a) → las dependencias se bajan antes en el PC.
