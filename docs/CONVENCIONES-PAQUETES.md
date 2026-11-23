# Convenciones de nombres de paquetes

## Regla (23/11/2026)
- **Paquete nuevo, nuestro → `calvos-*`**. Siempre, desde el primer commit.
  - Ejemplo: `calvos-appman` (AppMan 10.7 embebido para la seccion AppImages).
- **Paquete heredado de upstream → conserva `pocknix-*`**. No se renombra: los identificadores
  (rutas, servicios, imports, `PACKNIX_*`) no se tocan.
  - Ejemplos: `pocknix-store` (fork de la tienda upstream), `pocknix-ui`, `pocknix-bsp-sm8750`.
- Rebranding visible (textos, titulos, descripciones) sigue aplicandose siempre a CalvOS;
  lo que no se renombra son los *nombres de paquete heredados* ni los identificadores.

## Por que
Renombrar un paquete heredado rompe dependencias, hooks y unidades systemd que lo referencian,
y complica los merges con upstream. Los paquetes propios, en cambio, deben ser reconocibles como
nuestros desde el nombre y no ocupar el espacio de nombres de upstream.
