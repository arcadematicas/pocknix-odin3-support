# Análisis de las topologías (tplg) disponibles

**Fecha**: 02/10/2026
**Complementa a**: [`../MICROFONO-INVESTIGACION.md`](../MICROFONO-INVESTIGACION.md)
**Pregunta que responde**: para la Fase 1, ¿existe ya una topología con `VA_CODEC_DMA_TX_0`
(la ruta del micro, B5) **y** `SECONDARY_MI2S` (el altavoz del Odin 3)?

---

## El censo (ficheros, no de oídas)

Buscado sobre todo lo que hay en el árbol de compilación (`vendor/rocknix-extra-firmware/`,
`devices/sm8750/firmware/`, `build/…/usr/lib/firmware/qcom/`):

| Fichero | SoC | Tamaño | VA (micro) | SEC (altavoz Odin 3) | PRI (altavoz Odin 2) | MultiMedia4 |
|---|---|---|---|---|---|---|
| `SM8750-AYN-tplg.bin` | SM8750 | 18.236 | ✗ | **✓** | ✗ | ✗ |
| `SM8750-KONKR-tplg.bin` | SM8750 | 18.236 | ✗ | **✓** | ✗ | ✗ |
| `SM8550-APS-tplg.bin` | SM8550 | 26.780 | **✓** | ✗ | ✗ | **✓** |
| `SM8650-APS2-tplg.bin` | SM8650 | 27.100 | **✓** | ✗ | ✗ | **✓** |
| `AYN-Odin2-tplg.bin` | SM8550 | 19.960 | ✗ | ✗ | **✓** | ✗ |
| `AYN-Thor-tplg.bin` | SM8550 | 18 (symlink) | ✗ | ✗ | ✓ | ✗ |
| `AnbernicRG55G1-tplg.bin` | SM4450 | 18.680 | ✗ | ✗ | ✗ | ✗ |
| `RetroidPocketClassic-tplg.bin` | SM4450 | 18.680 | ✗ | ✗ | ✗ | ✗ |

**Ninguna combina las dos cosas.** La conclusión de §B5 queda confirmada con ficheros.

## Lo que aprendemos de esto

1. **El micro del VA macro y un altavoz por MI2S casi nunca van juntos.** Las dos únicas topologías
   que traen `VA_CODEC_DMA_TX_0` (APS en SM8550 y SM8650) **no tienen ninguna MI2S**: su altavoz es
   un **WSA** (`WSA_CODEC_DMA_RX_0`). Por eso no hay ninguna que nos sirva tal cual.

2. **El Odin 2 (SM8550) NO usa el VA macro.** Su topología tiene Primary MI2S (el altavoz) y **cero**
   `VA_CODEC_DMA_TX_0`. Y el micrófono del Odin 2 **funciona en Linux** (es el caso del PR
   ArmadaOS #432). → **Su micro está en el WCD**, no en el LPASS VA macro.

3. **El KONKR es un segundo handheld SM8750** con topología propia: mismo tamaño que la del AYN pero
   **md5 distinto** (`325174b5…` vs `7232e0b8…`). Repite el patrón del AYN: Secondary MI2S y **sin
   VA**. Otro dato a favor de que en esta familia el micro no va por el VA macro.

4. Las topologías de SM4450 (Anbernic RG55G1, Retroid Pocket Classic) no usan ninguno de estos
   nombres de ruta.

## Consecuencia para el plan

- **La Fase 0 sigue mandando**: hasta saber el `MicPMID` del micro interno del Odin 3
  (`0x1001` = VA macro, frente a `0x0C20`/`0x0Cxx` = DMIC del WCD) no se puede elegir camino.
- **Indicio nuevo y bastante fuerte**: los handhelds de AYN que conocemos con micro funcionando lo
  tienen en el **WCD**. Si el Odin 3 es igual, el camino **no** es la Fase 1/2 (VA macro + recompilar
  kernel), sino el del Odin 2 (`03-servicio-mic-route.md`, sección del WCD) — y **B5 dejaría de ser
  el bloqueador**, porque no haría falta tocar la topología.
- **Lo que lo cierra en cinco minutos**: el `audio_platform.xml` del Android del AYN.
  Script listo: [`00-fase0-extraer-android.sh`](00-fase0-extraer-android.sh).

## Cómo se sacó el censo

```bash
# VA (micro), SEC/PRI (altavoces), MultiMedia4
for f in *tplg.bin; do
  echo "$(basename $f)  VA=$(grep -ac VA_CODEC_DMA_TX_0 "$f")  SEC=$(grep -ac SECONDARY_MI2S "$f")"
done
```
