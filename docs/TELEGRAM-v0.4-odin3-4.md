# Entrada para Telegram — calvOS / Pocknix 0.4 (Odin 3)

Texto listo para copiar y pegar (Telegram no renderiza tablas ni Markdown complejo: usar tal cual).

Grupo de releases: https://t.me/+Pz1kfKX8UZs0OWE0

---

🎮 **calvOS / Pocknix 0.4 — AYN Odin 3**
Build del 1 de noviembre de 2026 · SM8750

Imagen nueva del sistema con la **suspensión arreglada** y el consumo medido en `deep`: **0,14 %/h**
en una noche completa (13 h 31 min, 1,85 % de batería). Se graba en una microSD y arranca desde
ella: **la memoria interna no se toca**.

✅ **Qué cambia**
• Suspensión que ya no se cuelga: kernel 7.2.12-28 con los parches de GMU (se acaban los
  `a6xx_gmu_resume`, `GMU OOB` y `preemption timed out` al despertar).
• WiFi: hook del `ath12k` que saca el PCI al dormir y lo re-escanea al despertar (`wlan0` vuelve sola).
• `deep` por defecto (antes `s2idle`): 0,14 %/h frente a 0,44 %/h medidos.
• MangoHUD: porcentaje y tiempo de batería correctos (coulomb counter).
• Iris completo con `low_latency` (Remote Play / Moonlight) y 0 conflictos de parches.
• Tema Eclipse: se instala una vez y lo actualiza el Panel de Control (0.3.5).
• `baloofilerc` sin choque de paquetes, mesa 2:26.3.0, gamescope OGC con HDR de armada.

📦 **Ficheros** (misma carpeta, los 3 trozos):
• pocknix-sm8750-sd.7z.001 — 3,9 GB
• pocknix-sm8750-sd.7z.002 — 3,9 GB
• pocknix-sm8750-sd.7z.003 — 3,8 GB

🔐 SHA256 de los trozos:
317049c5a7109e2bb0ddddf1e166f23924bb77cb03652d714bead4c669375a4d
d34caf76e3c132d34120f1ba41d019e7d40e9f6a1d665d800fd61a423d15cbe7
e501fc94f464a0f3a6892d1db8bc1ceb7576aa63575b283c59678ca3cb5d62f9

🛠 **Cómo se abre** (7-Zip 23+, PeaZip…):
1. Doble clic en `.7z.001` → Extraer → sale `pocknix-sm8750-sd.img.zst` (se unen solos).
2. Doble clic en el `.zst` → Extraer → sale `pocknix-sm8750-sd.img` (24,5 GiB).

💾 **Grabar**: BalenaEtcher / Raspberry Pi Imager, o en Linux:
`sudo dd if=pocknix-sm8750-sd.img of=/dev/sdX bs=4M conv=fsync status=progress`
(comprobar el dispositivo con `lsblk` antes).

Usuario `deck` · root `pocknix` · SSH desactivado por defecto.

🙏 Gracias a **Jarvis (DaViDuSkY)** por las pruebas de suspensión y el hallazgo del `ath12k`, y a
quienes reportasteis los cuelgues del QAM y del resume.

---

## Versión corta (para el canal, 3-4 líneas)

🔥 **calvOS / Pocknix 0.4 para AYN Odin 3** — suspensión arreglada y **0,14 %/h** en reposo con
`deep`. Imagen nueva en 3 trozos 7-Zip (abrir `.001` y extraer). Se graba en microSD, la interna no
se toca. Cambios: kernel 7.2.12-28 (GMU), hook del ath12k al suspender, MangoHUD con batería real,
Eclipse por el Panel de Control. Gracias a Jarvis (DaViDuSkY) por las pruebas. 🙏
