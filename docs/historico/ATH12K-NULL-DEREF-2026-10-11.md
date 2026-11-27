# ath12k: NULL-deref de `ar->scan.arvif` en el Odin 3 (bucle de arranque) — 11/10/2026

## Sintoma
El dispositivo entra en **bucle de arranque**: cada arranque dura ~10 s y reinicia. El cmdline
lleva `oops=panic panic=5`, asi que un oops provoca panic y reboot inmediato.

## Secuencia observada (journal de la propia SD)
```
wlan0: authentication with b4:20:46:29:0f:86 timed out      <- el AP no contesta
ath12k_wifi7_pci 0000:01:00.0: failed to send WMI_11D_SCAN_STOP_CMDID: -108   <- FW caido (ESHUTDOWN)
ath12k_wifi7_pci 0000:01:00.0: failed to stopt 11d scan vdev 0 ret: -108
ath12k_wifi7_pci 0000:01:00.0: failed to submit WMI_VDEV_DELETE_CMDID
arm-smmu 15000000.iommu: Unhandled context fault: fsr=0x402, iova=..., cbfrsynra=0x1401, cb=11
ath12k_wifi7_pci 0000:01:00.0: failed to assign chanctx for vif 00:03:7f:38:61:21 link id 0 link vif is already started
mhi mhi0: Requested to power ON
mhi mhi0: Power on setup success
Unable to handle kernel paging request at virtual address 0000000000001508
  EC = 0x25: DABT (current EL) ; FSC = 0x04: level 0 translation fault   (LECTURA)
Internal error: Oops: 0000000096000004 [#1] SMP
```

## Identificacion exacta del fallo (con el `.ko` real del build)
1. **BTF/pahole** sobre `ath12k.ko` (build 7.2.9): el **unico** campo a offset **5384 = 0x1508** de
   todo el modulo es
   `struct ath12k { ... struct { ...; struct ath12k_link_vif *arvif; /* 5384 */ } scan; }`
   -> el acceso que falla es **`ar->scan.arvif` con `ar == NULL`**.
2. **objdump** (`aarch64-linux-gnu-objdump -d ath12k.ko`) buscando `#5384`: solo 7 funciones tocan ese
   offset. El fallo fue **lectura** (`WnR=0`), luego las candidatas son:
   `ath12k_mac_op_cancel_hw_scan`, `ath12k_mac_op_unassign_vif_chanctx`,
   `ath12k_mac_op_remove_interface` (y `ath12k_mac_op_hw_scan` /
   `ath12k_get_ar_on_scan_state`, que si llevan guarda).
3. El patron comun: en esas ops, `ar = arvif->ar` (o `arvif->ar->...` directo) **sin comprobar
   `arvif->ar`**. Con `arvif->is_created == true` pero `arvif->ar` ya anulado -> `ar == NULL` ->
   lectura de `ar->scan.arvif` (0x1508) -> Oops.

## Por que ocurre ahi
- La caida del firmware (`-108`) aborta el scan; mac80211 desmonta los vifs y llama a
  `cancel_hw_scan()` / `unassign_vif_chanctx()` / `remove_interface()`.
- El trigger de la caida del firmware es externo: el AP no completa la autenticacion
  (`authentication timed out`) — en el caso observado, un AP en **canal DFS (116)** con regdom
  `country 00`.
- No es corrupcion de la SD ni del rootfs: btrfs sano, `KERNEL` con md5 correcto, sin unidades
  systemd fallidas en el ultimo arranque bueno (que duro 36 h antes de la primera caida).

## Arreglo defensivo (0041b)
`kernel/patches/20-sm8750/0041b-wifi-ath12k-guard-NULL-ar-in-scan-vif-teardown.patch`:
no desreferenciar `arvif->ar` si es NULL en las tres ops anteriores.
Es **defensivo**: el fix "de verdad" es entender por que `arvif->ar` puede ser NULL con
`is_created == true` y cerrar esa ventana. Ninguno de nuestros parches previos (0039, 0040, 0041,
0041a, 0501) toca esas funciones: es codigo stock de ath12k.

## Notas de campo
- Diagnostico original en la SD de 1 TB (`/flash/pocknix-diag.txt` de la consola, 10/10).
- El apagon/reboot en caliente no limpia el estado del chip WiFi: el fallo se repite en cada
  arranque (~21 s de tiempo monotono).
- Relacionado: `docs/ATH12K-ODIN3.md` (regla DMA-FQ de Valve; NO aplicada en la 1 TB).
