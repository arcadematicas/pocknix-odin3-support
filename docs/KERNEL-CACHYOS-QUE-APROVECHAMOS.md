# Qué merece la pena de CachyOS en nuestro kernel (19/11/2026)

Nuestro `linux-pocknix-sm8750 7.2.15-4` **ya lleva lo principal** que CachyOS usa para
jugones. Esto es lo que hay, lo que falta y cómo decidirlo sin fe.

## Ya lo tenemos (verificado en la Odin)

| Ajuste | Estado |
|---|---|
| `sched_ext` (`CONFIG_SCHED_CLASS_EXT=y`) + **scx_lavd 1.1.3** cargado | ✅ vía `pocknix-scx.service` (lavd/bpfland/rusty) |
| **BBR** como congestión TCP (`net.ipv4.tcp_congestion_control=bbr`) | ✅ |
| **NTSYNC** (`CONFIG_NTSYNC=y`) para Wine/Proton | ✅ |
| **zram** activo (11 GB, `lzo-rle`, MULTI_COMP, writeback) + `vm.swappiness=180`, `page-cluster=0` | ✅ |
| `PREEMPT` completo, `HZ=250`, `-O2` (`CC_OPTIMIZE_FOR_PERFORMANCE`), `NO_HZ_IDLE`, `schedutil` | ✅ |

Traducción: CachyOS "de titular" (scx, BBR, NTSYNC, zram) aquí ya está. Lo que queda es afinar.

## Lo que falta y podría aportar

| Cambio | Tipo | Ganancia esperada | Riesgo |
|---|---|---|---|
| `CONFIG_UCLAMP_TASK` (+`_GROUP`) | config | Colocación/boost en big.LITTLE vía EAS. **Con sched_ext cargado parte del efecto se pierde** | Bajo |
| `CONFIG_PREEMPT_DYNAMIC` | config | Poder elegir `preempt=full\|lazy\|voluntary` en el arranque sin recompilar | Bajo |
| `CONFIG_PREEMPT_LAZY` | config | Menos latencia de planificación con menos overhead | Bajo-medio |
| `HZ=1000` (vs 250) | config | Menos jitter de frametime; **más consumo en reposo** | Medio (medir) |
| **BBRv3** (si nuestro bbr es v1) | parche | Mejor caudal en wifi con pérdidas | Medio |
| `LTO` (ThinLTO con clang) | build | ~1-3 % global | Alto (toolchain, build largo) |

## Lo que NO copiaría

- **MuQSS/BFQ**: MuQSS está muerto y choca con EEVDF; BFQ no aporta en UFS/eMMC.
- **Parches x86** de CachyOS (`amd-pstate`, AES-NI, Clear Linux): no aplican a aarch64.
- **PREEMPT_RT**: no es para jugar.

## Cómo decidirlo (A/B, un cambio por build)

1. **Frametime**: MangoHUD en 3 escenas fijas (Wario, Wind Waker, un x86 por WProton),
   2 minutos cada una, TDP fijo (Panel en manual) para que no varíe.
2. **Reposo**: 30 min en escritorio, batería al 100 %, medir % consumido.
3. **Suspensión**: 5 ciclos suspender/despertar (audio, wifi, mando).
4. Solo se queda el cambio si mejora frametime **sin** empeorar reposo más de ~3 %.

## Prioridad

1. `PREEMPT_DYNAMIC` (permite probar lazy/full sin recompilar cada vez).
2. `UCLAMP_TASK` (barato; comprobar si ayuda con y sin sched_ext).
3. A/B de `HZ` (250 vs 1000).
4. BBRv3 solo si el wifi se nota; LTO solo si sobra tiempo.

Todo esto es **tanda 6** (kernel), después del resto.
