# Plan CalvOS 1.4 — re-corte de base (mediados de noviembre 2026)

> Estado a 3/11/2026. Complementa `docs/BASE-HEALTH.md` (cadencia y comandos); aquí está el
> alcance concreto y la lista de comprobación de esta release.

## Por qué ahora

- Snapshot actual **`20260826.2`** (889 paquetes): **69 días** al 3/11. La política es re-cortar
  cada 2–3 meses → ventana objetivo **10–21 de noviembre**.
- `check-base-health`: **16 CVEs abiertos**, ninguno con parche todavía. Dos `High`:
  `libxml2` (AVG-2898) y `pam` (AVG-2901). Si alguno recibe parche antes, se adelanta el re-corte.
- No hay release abierta: 1.3 está publicada y el lote 1.3.1 es pequeño (ver abajo), así que se
  puede cerrar 1.3.1 y afrontar 1.4 sin mezclar.

## Qué entra en 1.4 (además del re-corte)

| Cambio | Estado | Notas |
|---|---|---|
| LED de carga (DTS `pm8550_pwm` + `odin3-charge-led`) | hecho, en kernel 29 / bsp 43 | validado en hardware el 2/11 |
| Decky **arm64 nativo** (PluginLoader-arm64 v3.3.1, sin FEX) | hecho, en `pocknix-decky` 65 | **pendiente de probar en consola** |
| OpenROM 3.9.5 (`deckstation-arm` 18) | hecho, instalado a mano en la Odin | pendiente validar GUI |
| Parche Turnip ir3 (`ir3_array_to_ssa`: seguir cadenas de phi) | **pendiente**: nuestro Mesa es `26.3.0-devel aa35464` y **no lo trae** | ver abajo; un fichero |
| Micrófono interno | **no entra** | sigue abierto; requiere instrumentación kernel/SoundWire |
| Kernel: fixes de resume de la GPU (a6xx/a8xx) | **añadidos** (`2124`, `2125`), pendientes de compilar | uso-después-de-liberar de OPP + retornos de `pm_runtime_resume_and_get` sin comprobar; afectan a suspender/reanudar en la Odin |

### Parche Turnip pendiente

Origen: `armada-os/armada` → `packages/mesa/patches/0015-ir3-array-to-ssa-resolve-trivial-phi-chains.patch`
(fix del reportero para mesa#16676; evita crashes de Turnip compilando shaders, p. ej. Enshrouded/Onimusha).
Nuestro snapshot `aa35464ee50c1311eb6cebb9882d02738642b692` tiene el `lookup_value()` antiguo, así que
**aplicaría limpio**. Para meterlo en 1.4:

1. Copiar el parche a `packages/soc/mesa/patches/` (hoy no existe el directorio).
2. Añadirlo a `source=()` y aplicarlo en `prepare()` con `patch -Np1 -i`.
3. Subir `pkgrel` de mesa y **compilar aparte** (mesa bajo qemu son horas): no hacerlo en la misma
   tanda que un build pequeño, porque editar el paquete fuerza su rebuild.
4. Validar GPU: arranque, Steam, un juego DXVK/Vulkan y otro OpenGL; mirar `dmesg` por GPU faults.

## Pendiente inmediato (4/11/2026)

1. **Recompilar kernel** con los backports de resume de GPU (`2124`, `2125`): `make kernel` + paquete
   (`pkgrel` 30 → 31) y validar suspender/reanudar varias veces.
2. **Probar el fix del ACD** (`docs/HOLODOR-HALLAZGOS.md`): `msm.disable_acd=1` en el cmdline,
   `pocknix-build-bootimg`, medir GPU y temperaturas. Si va bien, parche propio (2126) para quitar
   `qcom,opp-acd-level` del dtb.
3. **Panel de Control (Hooandee)**: vendido `panel-de-control-v0.76.0`, upstream **v0.82.1**
   (2026-11-03). Revisar el changelog y sembrar la nueva versión en el BSP.
4. **Seguimiento Holodor**: ya integrado en `tools/check-upstream-daily.sh` (release, issues y último
   commit). Revisar sus issues nuevos cada día; su #3 (ACD) es el que nos afecta.

## Secuencia del re-corte (comandos de `BASE-HEALTH.md`)

```bash
cd ~/pocknix-odin3-project/pocknix-os
# 1) build SIN pin (usa ALARM en vivo)
grep -n POCKNIX_BASE_SNAPSHOT config/pocknix.conf     # vaciar el pin si está puesto
echo 28021m | sudo -S -p '' env DEVICE=sm8750 make build
echo 28021m | sudo -S -p '' env DEVICE=sm8750 make packages
# 2) congelar (sube a r2:pocknix/base, escribe lock y mueve el pin)
make snapshot
# 3) imagen nueva pinneada + validación
echo 28021m | sudo -S -p '' env DEVICE=sm8750 make build
echo 28021m | sudo -S -p '' env DEVICE=sm8750 make sd-image
```

Reglas que no se saltan: **probar en SD aparte** antes de la interna; el re-corte rota `base-prev`
(vuelta atrás); anotar el id del snapshot en `CHANGELOG.md`; no re-cortar en medio de una release.

## Checklist de validación (SD, antes de tocar la interna)

- [ ] Arranque + OOBE + splash; sin `.rej` en el kernel (`tools/check-kernel-patches.sh`).
- [ ] WiFi, Bluetooth, suspensión (botón corto) y reanudación.
- [ ] Audio: altavoz, auriculares (jack), **LED de carga** (rojo/verde).
- [ ] GPU: juego DXVK (Savage Wind/BotW) y uno OpenGL; sin GPU faults en `dmesg`.
- [ ] **Decky arm64**: loader arranca, QAM responde, panel de control y plugins cargan.
- [ ] OpenROM (Updater → reinstalar) y una conversión de prueba.
- [ ] Batería/carga y consumo en reposo (comparar con 1.3).
- [ ] `pocknix-kernel-guard` en OK y sin reinicios espurios.

## Cierre

- Publicar paquetes con `make stage` / `stage-check` / `publish` (y `-shared` si toca).
- Changelog público numerado **1.4**, tag `calvos-1.4`, y texto de Telegram como en 1.3.
- Actualizar `docs/BASE-HEALTH.md` con el snapshot nuevo y la fecha del siguiente re-corte.
