# Novedades de upstream — 22/11/2026

Barrido de los repos que seguimos. Ventana: desde el **19/11** (cierre de la tanda 2) hacia atrás
hasta la última release de cada proyecto. **No se ha tocado nada**: esto es solo el inventario
para decidir qué entra en la tanda 4.

---

## armada-os/armada — el que más se ha movido

Última release: **`20261109`** (9/11). Todo lo de abajo va **después** de esa release, así que no
está en ningún binario publicado: hay que portarlo a mano.

| Fecha | Commit / PR | Qué es | Nos interesa |
|---|---|---|---|
| 22/11 | `a237508` #932 | decky: empaquetar solo releases **stable** del loader | 🟡 Sí: nosotros empaquetamos Decky (73). Evita betas |
| 21/11 | `08e4571` #929 | kernel: corrige **voltaje flotante pm8150b** y fija corriente de carga | 🔴 Sí: carga de batería en Odin 3 |
| 20/11 | `8c0326d` #926 | deps: **fex-emu 2611.1** | 🔴 Sí: vamos por `2611.20261105` |
| 20/11 | `0510a9a` #568 | tests: correr tests de Python en CI | ⚪ No |
| 20/11 | `4d99872` #887 | dependabot: cosign-installer 4.1 | ⚪ No |
| 16/11 | `aac73ec` #906 | rebase de **kwin y powerdevil sobre Plasma 6.8.3** | 🟡 Sí: nuestro escritorio es KDE |
| 16/11 | `f9263fb` #896 | añade `pipewire-utils` | 🟡 Ver si nos falta algo de eso |
| 16/11 | `297c39a` #669 | **apagado por batería baja** | 🟢 Ya lo teníamos como candidato; **mergeado** |
| 15/11 | `db5e0d1` #897 | mesa: **Turnip** vuelve a tratar las cargas de descriptor como especulables | 🔴 Sí: rendimiento en juegos Vulkan |
| 15/11 | `ee2b490` #903 | audio: **Odin 2** sin pasar de 0 dB en el ampli de auriculares | 🟡 Solo Odin 2, pero es el mismo codec |
| 15/11 | `426ff3a` #902 | **SoundWire**: periodo SSP para auriculares **Odin 3** + reinicio en suspend + fix del IRQ del WCD RX | 🔴 Sí: era nuestro bloque de audio de la tanda 4 |
| 15/11 | `567e1b3` #876 | wcd939x: **class-H** | 🟡 Audio, mismo codec |
| 15/11 | `78d2156` #858 | **Odin 3 DisplayPort HBR3** | 🟡 Dock/monitor externo |
| 14/11 | `ffdb10c` #895 | mesa: los juegos GL respetan el **frame limiter de Steam** | 🟢 Ya lo teníamos apuntado; **mergeado** |

**Lectura**: los tres PRs que teníamos en la tanda 4 (#902/#903/#669) **ya están mergeados**, así que
se pueden portar sin esperar a nadie. Lo nuevo y caliente es **pm8150b (carga)** y **fex 2611.1**.

---

## FEX-Emu/FEX

- Última release: **`FEX-2611.1`** (11/11). Armada la adoptó el 20/11.
- Nuestro árbol empaqueta `2611.20261105` → **una release por detrás**.
- Movimiento reciente en `main` (21-22/11): `WOW64: Enable AVX support` (`5009290`, ojo: afecta a
  juegos x86 de 32 bits), limpieza de plantillas y tests de AVX.

## shuuri-labs/pocknix-os (nuestro upstream)

- Última release: **`v0.5.0`** (10/11).
- **Sin commits desde el 12/11**: upstream está tranquilo. Lo último fue limpieza de comentarios,
  botones de Plasma Mobile, `wlroots0.20`/`libliftoff` junto a gamescope y `openabl: shared kit`.
- Ojo: `openabl-shared` (11/11) es relevante porque **ya usamos OpenABL**.

## ROCKNIX/distribution

- Release **`20261101`**; commits hasta el 20/11 (kernel config, emulationstation, duo lite DTS,
  dsperate v3.5.0). Nada que nos bloquee; vigilar el kernel config por si trae algo del SM8750.

## stshunz/deckstation-arm

- 15/11: **`openbor: AnyBOR libretro (0.2.33)` + sistema ES-DE** → candidato para la capa de emulación.
- Antes: `hakuX-lr` (Vulkan) para Xbox (8/11) y `openrom 3.9.5` (2/11).

## suyu-emu/suyu

- La API no deja consultarlo (repositorio inexistente/renombrado/privado). Nuestro paquete
  `suyu-libretro 0.0.4-2` sigue publicado y con el parche del guard de ensamblador.

---

## Qué haría con esto (propuesta para la tanda 4)

1. **Audio Odin 3** (#902 + #903 + #876): es lo que más se nota y ya está mergeado. Portar los
   parches de kernel/UCM con pruebas de auriculares y de suspensión.
2. **Carga de batería** (#929 pm8150b): toca kernel; medir corriente de carga antes/después.
3. **Turnip `tu-speculation`** (#897): prueba de rendimiento en 2-3 juegos Vulkan.
4. **FEX 2611.1**: bump del paquete; probar un juego x86 de 32 bits (AVX de WOW64).
5. **Decky stable** (#932) y **Plasma 6.8.3** (#906): cosmético/escritorio, al final.
6. **#669 apagado por batería baja**: decidir si lo queremos tal cual (política de apagado).

---

## Nota de estado del repo (22/11)

- `origin/master` está limpio y al día en GitHub.
- Existe **1 commit local sin subir** en la rama `fix/desktop-layout`
  (`4a10917 calvos control: recupera "Añadir juego externo a Steam"`, 16/11). No lo he tocado:
  decide si se sube, se descarta o ya está cubierto por otra rama.
