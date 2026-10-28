# Moonlight + Sunshine en la Odin 3 (28/10/2026)

## Estado

- **Cliente**: `moonlight-qt 6.2.0` (repo `extra` de Arch ARM), lanzado desde Steam (atajo no-Steam
  añadido a `shortcuts.vdf` con Steam cerrado).
- **Host**: Sunshine en el PC de sobremesa (CachyOS, RX 6750 XT / Navi 22) como **servicio de usuario**.
- Emparejado y funcionando. Panel web de Sunshine: `https://<pc>:47990` (credenciales en
  `~/.config/sunshine/credentials.json` del PC).

## Ajustes aplicados en el host

- `encoder = vaapi` y `av1_mode = 0`: la RX 6750 XT **no codifica AV1** y Sunshine entraba en bucle
  creando `av1_vulkan` hasta fallar con "no se ha recibido vídeo".
- `hevc_mode = 3`. VAAPI expone **HEVC Main10** (`VAProfileHEVCMain10: EncSlice`).
- Backup: `~/.config/sunshine/sunshine.conf.bak-20261028`.

## HDR: no funciona (limitación del cliente)

- El decodificador **Iris** de la Odin (`/dev/video0`, `iris_driver`, mplane) **sí** acepta HEVC y
  ofrece **`P010` (10 bits)** entre sus formatos de captura.
- La sesión sí entra en HDR (`Display transition {"kind":"hdr","ok":true}`) y el panel anuncia 650 nits.
- Aun así, Moonlight avisa de que la GPU no soporta el códec y negocia `capture=NV12` (8 bits);
  Sunshine confirma `Color depth: 8-bit`. O sea: **HEVC 8-bit, SDR**.
- Reportado: **moonlight-stream/moonlight-qt#2081** con la evidencia (Iris + P010 + gamescope + VAAPI).

## Recomendaciones de uso

- **HDR desactivado** en Moonlight (no aporta y evita el aviso).
- Para rendimiento, usar la app **"Low Res Desktop"** de Sunshine si el monitor del PC es
  ultra-wide: nosotros vimos una captura de **3440×1440** para una pantalla de 1080p.
- Ratón: gestos del trackpad (un dedo mueve, toque = clic izq., mantener + segundo dedo = clic der.)
  o **mantener START** para el modo ratón del mando (sticks mueven, A/B clic).
- Salir de la emisión: **R1 + L1 + Select + Start**.
