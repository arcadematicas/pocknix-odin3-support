# El firmware del SM8750 como PAQUETE (`pocknix-firmware-sm8750`)

**Qué es**: el firmware del SoC (familia SM8750: AYN Odin 3 + KONKR Pocket FIT Elite) pasa de
`rsync` en `build-image.sh` a un **paquete** que se instala desde el localrepo como cualquier
otro. Modelo: `devices/sm8550/packages/pocknix-firmware-sm8550`.

- Paquete: `packages/pocknix-firmware-sm8750/` (centro) → `devices/sm8750/packages/` (OS)
- Manifest: `./paths`, **37 rutas**
- Destino en el dispositivo: **`/usr/lib/firmware/updates/`**

## Por qué existe (los dos bugs que cierra)

1. **Un clon limpio podía no cargar.** El par ADSP del cargador solo llegaba a la imagen por el
   `rsync` de `build-image.sh`, así que un dispositivo ya instalado **no podía actualizar su
   firmware sin reflashear**.
2. **Una regresión silenciosa de `-Syu`.** Upstream linux-firmware **sí** trae las rutas desnudas
   `qcom/sm8750/{adsp,adsp_dtb}.mbn`, y `linux-firmware-qcom` de ALARM pone ahí sus copias
   stock. Nuestro `adsp_dtb.mbn` (el que lleva la **autenticación de batería**) se escribía en esa
   **misma ruta desnuda**, así que cualquier transacción de linux-firmware lo revertía: el ADSP
   del cargador no puede autenticar la batería, cae en **TEST MODE (state 9)** y **la batería deja
   de cargar sin ningún error en ningún log**.

**El contrato de `updates/`**: el kernel busca `updates/` **antes** de `/usr/lib/firmware/`
(`fw_path[]` en `drivers/base/firmware_loader/main.c`) y **ningún paquete posee ese directorio**,
así que una copia ahí no se puede revertir. `pocknix-bsp-sm8750` lo lleva en `depends=`, así que
viaja por esa arista de dependencia y llega con `-Syu`.

## De dónde sale cada blob

| # | raíz | qué aporta | ¿en git? |
|---|---|---|---|
| 1 | `devices/sm8750/firmware/` | **solo** el par del cargador (`qcom/sm8750/adsp.mbn`, `adsp_dtb.mbn`) — 22 MB | **sí** (md5 `6cfcbbb8…` / `d88d7ecb…`) |
| 2 | `vendor/rocknix-extra-firmware/SM8750/` | WiFi ath12k WCN7860, CDSP, topologías de audio (`.tplg`+`.jsn`), VPU, BT | no (`vendor/` gitignored, pin `30c56e2`, `make sync`) |

**Ningún binario nuevo en git.** `scripts/build-packages.sh` stagea cada entrada de `./paths`
desde esas raíces (en ese orden) y muere con error claro si alguna no aparece.

## Compilar

En el **host de build** (el PC), dentro del árbol del OS:

```sh
# ⚠️ sudo hace env_reset y borra DEVICE → hay que pasarlo así
sudo -A DEVICE=sm8750 make packages PKG=pocknix-firmware-sm8750
# ...y el BSP, para que exista la arista de dependencia:
sudo -A DEVICE=sm8750 make packages PKG=pocknix-bsp-sm8750
```

## Verificar / revertir

```sh
pacman -Q pocknix-firmware-sm8750 pocknix-bsp-sm8750
find /usr/lib/firmware/updates -type f | wc -l              # 37
pacman -Qo /usr/lib/firmware/updates/qcom/sm8750/adsp_dtb.mbn
#   → pocknix-firmware-sm8750
pacman -Ql linux-firmware-qcom | grep -c updates           # 0

# revertir
sudo pacman -R pocknix-firmware-sm8750
```
Los blobs buenos siguen en `/usr/lib/firmware/qcom/sm8750/`, así que el revertir no deja el
dispositivo sin cargador. Además el hook de pocknix crea un **snapshot btrfs** antes de cada
transacción.

## Resultado medido — AYN Odin 3, 03/10/2026

**Verificado**:
- build: `pocknix-firmware-sm8750-0.1.0-1-any.pkg.tar.xz`, **27,7 MB**, **37 rutas** bajo
  `usr/lib/firmware/updates/`; staging: 0 rutas sin origen
- `pacman -U` + **reinicio**: `updates/` = 37 ficheros, md5 del par del cargador **idénticos**
- `pacman -Qo` → `pocknix-firmware-sm8750`; `linux-firmware-qcom` no lista nada de `updates/`
- WiFi: `ath12k` cargado, `wlan0` UP, **HTTP 200**
- Batería: `Charging` (y `ucsi-source: Charging`), **sin "Test mode"** en dmesg
- Arranque limpio, **0 unidades `systemd` caídas**
- BSP: `pocknix-bsp-sm8750 0.2.0-6` con `depends … pocknix-firmware-sm8750` registrado

**No verificado / pendiente**:
- **No publicado** en el repo de releases (`make stage` / `publish`): hoy está instalado a mano en
  la Odin; un dispositivo cualquiera aún no lo recibiría por internet.
- No probado en el KONKR Pocket FIT Elite (los blobs `konkr/pfe/` van en el paquete, sin probar).

## Reportado

Comentario en el **PR #81 de `shuuri-labs/pocknix-os`**:
<https://github.com/shuuri-labs/pocknix-os/pull/81#issuecomment-5971918567>
