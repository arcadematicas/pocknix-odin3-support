# 🆘 Petición de ayuda: Odin 3 no carga la batería en Linux (Pocknix)

**Hola comunidad AYN / Armada** 👋

Tengo una **AYN Odin 3** (Snapdragon 8 Elite / SM8750) con **Pocknix** (Arch Linux ARM, estilo SteamOS) instalado. El sistema funciona genial (Steam, juegos, GPU, mandos...), pero hay **UN problema que no consigo resolver**: **la batería no carga en Linux**.

## El problema

- **Pocknix (Linux)**: la batería **NO carga**. Se descarga aunque el cargador esté enchufado.
- **ROCKNIX (otro Linux)**: en el **mismo hardware**, la batería **SÍ carga perfectamente** (verificado en vivo).
- **Android**: también carga bien (el sistema original).

Es decir: el hardware carga, pero **solo Pocknix no consigue que cargue**.

## Síntomas técnicos (medidos en vivo)

| | ROCKNIX (carga ✅) | Pocknix (no carga ❌) |
|---|---|---|
| Estado batería | `Charging` (+198mA) | `Discharging` (-500mA) |
| Negociación PD | **9V / 3A** | Se queda en **5V** |
| `qcom-battmgr-usb online` | 1 | **0 siempre** |
| `ucsi` ve el cargador | Sí | Sí (1.25A entrando) |
| ¿La batería sube? | Sí | **No** (la energía no llega a la batería) |

**Lo curioso**: en Pocknix el sistema SÍ ve el cargador (el UCSI reporta 1.25A entrando), pero el firmware del ADSP **nunca dirige esa energía a la batería**. La negociación PD no se completa (se queda en 5V en vez de subir a 9V).

## Lo que ya he probado (todo descartado)

- ✅ Config del kernel comparada con ROCKNIX (casi idéntica)
- ✅ Kernel 7.2.0 y 7.2.4 (el más reciente) — ambos sin carga
- ✅ Kernel compilado SIN nuestros parches (idéntico a ROCKNIX) — sin carga
- ✅ Firmware ADSP de ROCKNIX (adsp.mbn) probado en Pocknix — no arregla
- ✅ battmgr.jsn idéntico byte a byte
- ✅ Compilador GCC 15.2 (el exacto de ROCKNIX) — sin carga
- ✅ Módulo battmgr stock y parcheado — sin carga
- ✅ ABL/bootloader (el mismo en todas las distros)
- ✅ Sin scripts de userspace de carga en ROCKNIX (todo es kernel/firmware)

## Mi hipótesis restante

La diferencia está en **cómo el entorno de arranque inicializa el `pmic-glink`** (el canal de comunicación entre el kernel y el firmware del ADSP que gestiona la carga). ROCKNIX y Pocknix arrancan el mismo kernel de forma distinta (initramfs / orden de carga de módulos), y eso podría hacer que el firmware nunca reciba/responda el mensaje correcto.

## ¿Alguien puede ayudar?

Si alguien tiene experiencia con:
1. **UCSI que no completa la negociación PD** (`ucsi voltage_max=0`) en dispositivos Qualcomm
2. **qcom_battmgr** que no recibe el `charging_source=USB` del firmware
3. **Orden de carga de módulos** del pmic-glink vs ucsi en el arranque
4. O simplemente tiene una **Odin 3 con Linux** y le pasa lo mismo (o no)

...agradecería muchísimo cualquier pista. 🙏

📄 **Detalle completo de la investigación**: https://github.com/arcadematicas/pocknix-odin3-support/blob/master/BATTERY-ISSUE.md