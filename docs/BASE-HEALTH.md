# Salud de la base ALARM — cadencia y vigilancia

La imagen no hace rolling release de la base: va sobre un **snapshot congelado** de ALARM
(`[pocknix-base]`, `POCKNIX_BASE_SNAPSHOT` en `config/pocknix.conf`). Este documento fija
cada cuánto se re-corta y cómo se vigila lo que no se puede dejar pasar.

## Cadencia

| Cuándo | Qué |
|---|---|
| **Cada mes** | `tools/check-base-health.sh` (automático: timer del 1 a las 09:00). 10 minutos si no hay nada. |
| **Cada 2–3 meses** | Re-corte de base + release de mantenimiento (1.4, 1.5…). |
| **Inmediato** | CVE Critical/High **con parche** en `glibc`, `systemd`, `openssl`, `pipewire`, `polkit`, `sudo` u `openssh`. |

Reglas:

1. Nunca re-cortar en medio de una release abierta.
2. Probar la imagen nueva en **SD aparte**; la interna solo después.
3. El re-corte rota `base-prev` (para poder volver) y cambia el `POCKNIX_BASE_SNAPSHOT`.
4. Anotar el id del snapshot en el `CHANGELOG.md` de la release.

## La herramienta

```bash
tools/check-base-health.sh              # informe
tools/check-base-health.sh --telegram   # + aviso si hay novedades o toca re-corte
tools/check-base-health.sh --lock <ruta>
```

Cruza `pocknix-base.lock` (889 paquetes con versión exacta) contra el tracker de seguridad de
Arch (`security.archlinux.org/issues/all.json`), quedándose solo con las incidencias **abiertas**
(`Vulnerable`/`Unknown`) que aún nos afectan por versión.

Salida:

- `0` — sano.
- `10` — toca actuar: CVE grave con parche, o snapshot de más de 90 días.
- `11` — hay CVEs abiertos **sin** parche publicado (seguimiento).
- `2` — falta el lockfile o `vercmp`.

Estado del último aviso: `~/.local/state/pocknix-base-health/last-avgs.txt`. Solo manda Telegram
cuando aparece una incidencia nueva, cuando toca re-corte o con `--force`.

Instalación del timer (usuario, en el PC de build):

```bash
# ~/.config/systemd/user/pocknix-base-health.{service,timer}
systemctl --user enable --now pocknix-base-health.timer
systemctl --user list-timers pocknix-base-health.timer
```

## Qué hacer según el informe

### Parche suelto (1–3 paquetes, sin re-cortar)

```bash
cd ~/pocknix-odin3-project/pocknix-os
echo 28021m | sudo -S -p '' env DEVICE=sm8750 make extend-base PKG="openssl"
make stage PKG="openssl" && make stage-check && make publish
```

`extend-base` hospeda la versión nueva en la base viva; el resto del snapshot no se toca.
Solo vale si el paquete no arrastra dependencias nuevas que no estén ya en la base.

### Re-corte (varios paquetes, o glibc/systemd/openssl)

```bash
cd ~/pocknix-odin3-project/pocknix-os
# 1) build SIN pin (usa ALARM en vivo)
grep -n POCKNIX_BASE_SNAPSHOT config/pocknix.conf     # vaciar el pin si está puesto
echo 28021m | sudo -S -p '' env DEVICE=sm8750 make build
echo 28021m | sudo -S -p '' env DEVICE=sm8750 make packages
# 2) congelar
make snapshot          # sube a r2:pocknix/base, escribe el lock y mueve el pin
# 3) imagen nueva pinneada + validación (arranque, suspensión, audio, wifi, decky, juegos)
echo 28021m | sudo -S -p '' env DEVICE=sm8750 make build
echo 28021m | sudo -S -p '' env DEVICE=sm8750 make sd-image
```

## Estado actual (2/11/2026)

- Snapshot **20260826.2**, **69 días** (3/11) → re-corte planificado: ver `docs/PLAN-CalvOS-1.4.md`
  (ventana 10–21 de noviembre). 16 CVEs abiertos, ninguno con parche (2 `High`: libxml2, pam).
- 16 incidencias abiertas nos afectan; **ninguna con parche publicado**. Las dos `High`:
  `libxml2` (AVG-2898, 4 CVEs) y `pam` (AVG-2901).
