# Incidente 2026-09-25 — bootloop y kernel panic por `nologreplay` (RESUELTO)

**Fecha del incidente:** 25/09/2026 (noche) · **Resuelto:** 26/09/2026
**Repos:** `pocknix-os` (rama `odin3-sm8750`) + `pocknix-odin3-support`

## Resumen

La imagen de SD no arrancaba: **kernel panic con la raíz sin montar y sin ningún log**. La causa
era `nologreplay` usado como opción de montaje de btrfs en montajes `rw` — **no es una opción
válida en Linux 7.2** y btrfs aborta el montaje de la raíz. El veredicto inicial del 25/09
("causa probable: la transferencia o el flasheo, no el contenido de la imagen") era **erróneo**:
sí era nuestro software.

## Síntoma

- Bootloop / kernel panic. La pantalla no daba ninguna pista útil.
- El mensaje clave, leído de la pantalla (el único sitio donde aparecía):

  ```
  VFS: Cannot open root device "PARTLABEL=POCKNIX_ROOT" or unknown-block(179,2)
  ```

- **`179,2` = `/dev/mmcblk0p2`**: el kernel **SÍ resolvió el `PARTLABEL`** y encontró la partición
  root de la SD. Lo que falló fue **montar el btrfs**, no localizar el dispositivo.
- **Sin logs**: el fallo ocurre **antes de userspace**, así que systemd nunca escribe journal.
  `/var/log` es un subvolumen aparte (`@var-log`) y estaba **vacío** porque el sistema no había
  arrancado ni una sola vez.

## Causa raíz

Se pasó `nologreplay` como opción de montaje en montajes `rw`, en **dos sitios**:

1. **cmdline del kernel**: `rootflags=nologreplay` → `devices/sm8750/profile.conf` (commit `191fbd4`).
2. **`/etc/fstab`**: `,nologreplay` en las 5 líneas btrfs → `scripts/build-sd-image.sh`
   (commit `404257a`; en el centro `451b8b3`).

En Linux 7.2, `nologreplay` **no es una opción de primer nivel** de btrfs. En
`fs/btrfs/super.c`, la tabla de opciones tiene:

```c
	/* Rescue options. */
	fsparam_enum("rescue", Opt_rescue, btrfs_parameter_rescue),
	/* Deprecated, with alias rescue=usebackuproot */
	__fsparam(NULL, "usebackuproot", Opt_usebackuproot, fs_param_deprecated, NULL),
	/* For compatibility only, alias for "rescue=nologreplay". */
	fsparam_flag("norecovery", Opt_norecovery),
```

`nologreplay` solo existe como **valor** del enum de `rescue=` (`{ "nologreplay",
Opt_rescue_nologreplay }`). **No hay ningún `fsparam_flag("nologreplay", ...)`.** Y una opción
desconocida aborta el montaje:

```c
	default:
		btrfs_err(NULL, "unrecognized mount option '%s'", param->key);
		return -EINVAL;
```

Es decir: `nologreplay` → `-EINVAL` → **la raíz no monta** → panic antes de userspace → **sin logs**.

Además, incluso la forma válida **no sirve aquí**: `rescue=nologreplay` / `norecovery` la rechaza
`check_ro_option()` en montajes `rw`:

```c
static bool check_ro_option(const struct btrfs_fs_info *fs_info,
			    unsigned long long mount_opt, unsigned long long opt,
			    const char *opt_name)
{
	if (mount_opt & opt) {
		btrfs_err(fs_info, "%s must be used with ro mount option", opt_name);
		return true;
	}
	return false;
}
```

→ **La conclusión es quitarlo**, no sustituirlo por otra forma.

## Por qué era invisible

- Falla **antes** de que arranque systemd → no hay journal.
- `/var/log` es un **subvolumen aparte** (`@var-log`); sin un arranque bueno, está vacío.
- El `cmdline` llevaba `panic=5`: reiniciaba a los 5 s, así que el mensaje aparecía en pantalla y
  desaparecía antes de poder leerlo.

## Los dos sitios donde estaba

| Sitio | Fichero | Commit |
|---|---|---|
| cmdline | `devices/sm8750/profile.conf` — ⚠️ **solo en el árbol, NO en el centro** | `191fbd4` |
| fstab | `scripts/build-sd-image.sh` (centro + árbol) | `404257a` (centro `451b8b3`) |

⚠️ **Nota estructural (deuda)**: el cmdline vive **solo en el árbol** (`devices/sm8750/profile.conf`);
el centro no tiene esa ruta, así que un cambio de arranque se puede colar **sin pasar por el centro**.
Conviene subir esa fuente al centro para que no vuelva a ocurrir.

## Cómo se diagnosticó

1. Se verificaron **hash de la imagen, particiones y btrfs**: todo correcto. El btrfs monta
   perfectamente desde el PC → **no era corrupción ni transferencia**.
2. Se comparó con la **imagen anterior (16/09)**, que sí arrancaba: la única diferencia relevante
   estaba en el **cmdline del kernel**.
3. Se descartaron hipótesis **por datos**, no a ojo:
   - **IOMMU / DTB**: se probó un DTB distinto (el de un kernel que funcionaba) y seguía fallando.
   - **Compresión zstd**: el btrfs de este árbol hace `select ZSTD_COMPRESS` / `ZSTD_DECOMPRESS`,
     así que el flag `COMPRESS_ZSTD` del superbloque sí está soportado.
4. Se leyó el **journal desde el PC** (montando el subvolumen `@var-log`:
   `journalctl -D <punto>/journal -b 0`) tras un arranque con el cmdline corregido.
5. Confirmación definitiva: quitar `nologreplay` del cmdline **y** del fstab y arrancar →
   **OOBE, sonido, botones y WiFi OK**.

## Trampa 2 (importante): el kernel y sus módulos deben ser del MISMO build

Al usar un kernel compilado en **otra máquina** (aunque la versión coincida), el kernel **rechaza
los módulos** de la imagen:

```
kernel: failed to validate module [usbip_core] BTF: -22
inputplumber: modprobe: ERROR: could not insert 'vhci_hcd': Invalid argument
```

| | Compilador | Image md5 |
|---|---|---|
| Kernel **bueno** (el de la imagen) | `fransis@cachyos-x8664` | `624b596fa8e819d2ad940133a94cba57` |
| Kernel ajeno probado (roto para esta imagen) | `davidusky@CachyOS` | `3c7a87639dbbc4af77d6ee21056d3bae` |

Los dos declaran `vermagic 7.2.4 SMP preempt mod_unload aarch64`, pero el **BTF no coincide** → los
módulos no cargan → **sin mando** (inputplumber necesita `vhci-hcd`) y **sin sonido** (módulos
`snd_soc_lpass_*`).

**Regla de oro**: el kernel y sus módulos salen **juntos del mismo entorno de compilación**. **No
recompilar solo el kernel** para una imagen ya construida.

## Prevención — NO HACER

- ❌ **NO** poner `nologreplay` en un montaje `rw` (ni en `rootflags=` ni en el `fstab`).
- ❌ **NO** usar un kernel de otro build para una imagen ya construida.
- ❌ **NO** dar por bueno "misma versión = compatible": comprobar el **Image md5**, no solo el número.
- ✅ Antes de dar una imagen por buena: que **arranque**, que **carguen los módulos**, que haya
  **mando y sonido**.

## Datos de referencia

- Kernel corregido (imagen de la Odin + cmdline sin `nologreplay`): `md5 75d9d63148e5399e1fa99981e2a88312`
- Image del kernel bueno: `md5 624b596fa8e819d2ad940133a94cba57` (48.118.272 bytes)
- Image del kernel ajeno (roto para nuestra imagen): `md5 3c7a87639dbbc4af77d6ee21056d3bae`
- Commits del incidente: cmdline `191fbd4` · fstab `404257a` (centro `451b8b3` / `aa31aa8`)
