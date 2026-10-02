# Fase 0 HECHA — el micro del Odin 3 va por el WCD, no por el VA macro

**Fecha**: 02/10/2026
**Método**: Android stock del AYN por `adb` (depuración inalámbrica), solo lectura.
**Resultado**: ⚠️ **corrige** la conclusión principal de [`../MICROFONO-INVESTIGACION.md`](../MICROFONO-INVESTIGACION.md) §2.C.

---

## 1. Cómo se hizo

Android del Odin 3 + depuración inalámbrica:

```
adb pair  <ip>:<puerto-de-emparejar> <codigo>
adb connect <ip>:<puerto-de-conectar>
```

⚠️ **Truco aprendido a golpes**: `adb shell` **se come el stdin**. Si el script se le pasa por
tubería (`bash -s`), adb se traga el resto del script y parece que "se para" a mitad. Ejecutarlo
siempre como fichero, y en el propio script `exec </dev/null` al principio.

Lo que se trajo (a `/home/fransis/odin3-android-audio/` en el PC): `/vendor/etc/audio/` completo
(48 ficheros, 1,9 MB) y los volcados `dumpsys media.audio_flinger` / `media.audio_policy`.

Datos del aparato: `product: sun` (= SM8750), `qti/sun/sun:15/…` (Android 15).

## 2. La evidencia

**`/vendor/etc/audio/sku_sun/mixer_paths_sun_mtp.xml`** — el enrutado real del HAL:

```
<!-- WCD939x enable PCM path by default -->
<ctl name="TX DEC0 MUX"   value="SWR_MIC"  />
<ctl name="TX SMIC MUX0"  value="SWR_MIC5" />
<path name="dmic1"> <ctl name="TX DMIC MUX2" value="DMIC0" /> …
<path name="dmic4"> <ctl name="TX DMIC MUX2" value="DMIC3" /> …
```

**`/vendor/etc/audio/audio_module_config_primary.xml`** — qué se puede pedir y a dónde va:

```
<devicePort tagName="built_in_mic"      deviceType="IN_MICROPHONE"      address="bottom" defaultDevice="true">
<devicePort tagName="built_in_back_mic" deviceType="IN_MICROPHONE_BACK" address="back">
...
<route type="mix" sink="primary_in"    sources="built_in_mic,built_in_back_mic,..." />
<route type="mix" sink="hotword_input" sources="built_in_mic,built_in_back_mic,..." />
```

**Y el VA macro solo asoma en su propia ruta**, la de activación por voz:

```
<path name="va-mic-mono">  <ctl name="VA DMIC MUX0" value="DMIC2" /> …
```

## 3. Conclusión

| | Antes (MICROFONO-INVESTIGACION §2.C) | Ahora (medido) |
|---|---|---|
| Dónde está el micro interno | LPASS **VA macro** (DMIC de 1 bit) | Códec **WCD939x** (`primary_in` → SWR_MIC / TX DMIC MUX) |
| Bloqueador principal | **B5**: falta `VA_CODEC_DMA_TX_0` en la topología | **no aplica** |
| Hace falta recompilar kernel | sí (Fase 2: DTS del va-macro) | **no** |
| Camino | Fases 1+2+3 | **el del Odin 2** (WCD): UCM + mixer + reloj DMIC |

El Odin 3 tiene **dos** micrófonos internos (`built_in_mic` abajo, `built_in_back_mic` detrás) y
ambos entran por `primary_in`. El VA macro existe en el SoC y en el mixer, pero para el caso de
**activación por voz** (`va-mic-mono`), no para grabar.

Esto confirma además el patrón que salió en [`05-analisis-topologias.md`](05-analisis-topologias.md):
los handhelds de AYN con micro funcionando (Odin 2) lo llevan en el WCD, y las topologías con
micrófono VA son de cacharros con altavoz WSA.

## 4. Qué queda por hacer (mucho menos de lo que creíamos)

1. **En Linux, ver qué ofrece ya el WCD**: `arecord -l`, `amixer -c 0 controls | grep -i -E "dmic|swr|adc"`,
   `lsmod | grep -E "wcd|swr|soundwire"`, y si el driver del WCD939x está cargado.
2. **Aplicar el camino del Odin 2**: [`03-servicio-mic-route.md`](03-servicio-mic-route.md),
   sección *"Si resulta que el micro está en el WCD"* → sección UCM + servicio de routing.
3. **Si no aparece captura**: mirar el **reloj DMIC del WCD** (§8.4 del documento principal), que era
   la sospecha cuando el micro se creía del WCD.
4. **Ya NO hacen falta**: la Fase 1 (topología) ni la Fase 2 (DTS + recompilar kernel).

## 5. Datos guardados (en el PC, `~/odin3-android-audio/`)

- `vendor-audio/` — `/vendor/etc/audio/` entero (incluye `sku_sun/`, que es nuestro SoC)
- `audio_flinger.txt`, `audio_policy.txt` — volcados del HAL en marcha
