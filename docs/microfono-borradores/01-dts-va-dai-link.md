# BORRADOR — Fase 2: habilitar el path del VA macro en el DTS

> ⚠️ **NO APLICADO.** Este parche resuelve **B1, B2, B3 y B4**. **Por sí solo NO hace funcionar el
> micrófono**: sin la Fase 1 (topología con `VA_CODEC_DMA_TX_0`) el PCM 3 quedará sin ruta en el
> DSP → silencio o `Input/output error`.
>
> Fichero a tocar: **uno solo** —
> `kernel/dts/cq8725s-ayn-common.dtsi` (en el repo `pocknix-odin3-support`).

## Aplicar

```bash
cd pocknix-odin3-support
git stash                       # si hay cambios del otro subagente en el dtsi
patch -p1 -i docs/microfono-borradores/01-dts-va-dai-link.patch
```

Si el contexto no cuadra (el `.dtsi` lo está editando otro subagente), aplicar a mano: son **tres
ediciones** muy localizadas, marcadas abajo con `<<< EDITAR 1/2/3 >>>`.

---

## Cambio 1 — `va-dai-link` al FINAL del nodo `sound` (`<<< EDITAR 1 >>>`)

Referencia upstream: `sm8750-mtp.dts:186-198`.

> ⚠️ **Va al final, obligatoriamente**: el orden de los dai-links en el DT determina la numeración
> de los PCM. Añadirlo en medio renumeraría `wcd-capture-dai-link` y rompería el UCM actual
> (`hw:${CardId},2` = WCD capture).

Anclar: el cierre del dai-link `wcd-capture-dai-link`, justo antes de la llave que cierra el nodo
`sound` (después del bloque `sound-dai = <&q6apm>;` de ese link).

```dts
		va-dai-link {
			link-name = "VA Capture";

			codec {
				sound-dai = <&lpass_vamacro 0>;
			};

			cpu {
				sound-dai = <&q6apmbedai VA_CODEC_DMA_TX_0>;
			};

			platform {
				sound-dai = <&q6apm>;
			};
		};
```

→ Resultado: **PCM 3** de captura (`hw:${CardId},3`), igual que en el UCM del MTP.

---

## Cambio 2 — `&lpass_vamacro` completo (`<<< EDITAR 2 >>>`)

Sustituir el bloque actual (que solo pone la sample-rate):

```dts
&lpass_vamacro {
	status = "okay";

	pinctrl-0 = <&dmic01_default>, <&dmic23_default>;
	pinctrl-names = "default";

	vdd-micb-supply = <&vreg_l1b_1p8>;
	qcom,dmic-sample-rate = <4800000>;
};

&lpass_tlmm {
	status = "okay";
};
```

Referencias:
- `sm8750.dtsi:2605-2618` (`lpass_vamacro`, sin `status` → disabled)
- `sm8750.dtsi:2620+` (`lpass_tlmm`, sin `status` → disabled)
- `sm8750-mtp.dts:978-984` (el bloque de referencia)
- `sm8750.dtsi:2669-2700` (`dmic01_default`, `dmic23_default`)
- `cq8725s-ayn-common.dtsi:376` (`vreg_l1b_1p8`, ya declarado → el phandle es válido tal cual)

**Por qué `lpass_tlmm` necesita su propio `status`**: el pinmux DMIC vive en ese nodo. Sin
`status = "okay"` los drivers `pinctrl-lpass-lpi` no se enlazan y los pines gpio6-9 no se
configuran como `dmic1_clk/data`, `dmic2_clk/data`. El MTP sí lo enciende (el `status = "okay"`
que precede a `&lpass_vamacro` en `sm8750-mtp.dts:976` pertenece a `lpass_tlmm`).

⚠️ **Fallo en tiempo de compilación si falta algo**: si se olvida `vdd-micb-supply`, el driver
`lpass-va-macro.c:1141` (`SND_SOC_DAPM_REGULATOR_SUPPLY("vdd-micb", 0, 0)`) registra el widget como
dummy → **no da error, pero no hay alimentación**. Sin error visible: hay que comprobarlo con
`amixer -D hw:0 cget name='vdd-micb'` después.

---

## Cambio 3 — (opcional, recomendado) comentario de por qué

Añadir en `sound`, junto al `audio-routing`, una nota de que **no** hay entradas DMIC porque
**no hacen falta** (el path DMIC del VA macro no pasa por el WCD, y los DMIC del WCD son internos
al códec). Esto evita que alguien "arregle" el routing en el futuro y rompa algo.

---

## NO cambiar

| No tocar | Por qué |
|---|---|
| `audio-routing` | Los DMIC del VA macro y los DMIC del WCD9395 **no** son widgets de entrada DAPM. Añadir entradas DMIC ahí no hace nada (y el `audio-routing` actual es idéntico al del **Odin 2**, donde el micro **sí** funciona). |
| Orden de los dai-links existentes | Determina los PCM 0/1/2 ya usados por el UCM. |
| `qcom,micbias*-microvolt` del `wcd939x` | Ya están (`:36-39`). |
| `sm8750.dtsi` | Es de upstream; **no se parchea**, se sobreescribe desde nuestro `.dtsi`. |

---

## Build, deploy y prueba

```bash
# 1) kernel (desde el centro)
cd pocknix-odin3-project/pocknix-odin3-support
tools/sync-to-os.sh && tools/check-sync.sh

# 2) compilar  (en pc-local)
cd ~/pocknix-odin3-project/pocknix-os
JOBS=14 DEVICE=sm8750 ./scripts/build-kernel.sh

# 3) desplegar en la Odin (⚠️ backup del KERNEL actual primero)
cp /flash/KERNEL /flash/KERNEL.bak-$(date +%Y%m%d-%H%M)
cp build/image/sm8750/KERNEL  /flash/KERNEL
# módulos, si cambiaron:
cp build/kernel/sm8750/out/modroot/lib/modules/7.2.0/* /lib/modules/7.2.0/
depmod -a 7.2.0
reboot
```

### Secuencia de verificación (en la Odin, en este orden)

```bash
# 1) ¿se cargó el módulo del VA macro?  (si no: B2 falló)
lsmod | grep va-macro

# 2) ¿aparece el platform device?  (si no: B2 o B4)
ls /sys/bus/platform/drivers/va_macro/
cat /proc/device-tree/*/pinctrl@7760000/status 2>/dev/null || echo "sin nodo"

# 3) ¿aparece el PCM nuevo?
arecord -l
# esperado: "card 0: SM8750AYN ... device 3: MultiMedia4 Capture"

# 4) ¿el mic-bias se puede encender?
amixer -D hw:0 cget name='vdd-micb'
amixer -D hw:0 controls | grep -iE 'vdd-micb|DMIC|DEC'

# 5) ¿lee?  (sin Fase 1 esto falla: es lo esperado)
arecord -D hw:0,3 -f S16_LE -r 48000 -c 2 -d 5 -v /tmp/mic.raw

# 6) ¿el altavoz sigue vivo?  (regresión crítica)
speaker-test -D hw:0,0 -c 2 -t sine -l 1
```

### Interpretación

| Síntoma | Significado |
|---|---|
| `lsmod \| grep va-macro` vacío | B2 no aplicado, o el nodo no|matchea (comprobar `compatible`) |
| `arecord -l` sin device 3 | B1 no aplicado, o el dai-link no parsea (mirar `dmesg \| grep -i snd_soc`) |
| device 3 existe pero `amixer` no lista `vdd-micb` | B3 (supply) — pero ojo: sin supply el widget **no aparece**, es el síntoma |
| device 3 existe y lee → **cero bytes / EIO** | Falta la **Fase 1** (topología). Es el resultado esperado si solo se hizo Fase 2. |
| Altavoz mudo tras el cambio | **Rollback inmediato.** Probablemente se coló el dai-link en medio y renumeró los PCM. |

---

## Rollback

```bash
cd pocknix-odin3-project/pocknix-odin3-support
git checkout kernel/dts/cq8725s-ayn-common.dtsi
# recompilar + reinstalar, o bien, más rápido:
#   cp /flash/KERNEL.bak-<fecha> /flash/KERNEL && reboot
```

Si solo se quiere revertir en caliente sin reinstalar kernel: no hay forma (el dai-link se fija en
el DTB embebido). **Reiniciar con el `KERNEL` anterior es obligatorio.**