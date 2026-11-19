# Decisión (16/11/2026): Plasma **Mobile** fuera de build y publish

**Estado:** aplicado · **SoC:** `sm8750` · **Árbol:** `pocknix-os` (`odin3-sm8750`)

## Qué se decidió

`plasma-mobile` y `pocknix-desktop-plasma-mobile` **no se compilan** (se saltan en
`scripts/build-packages.sh` con `POCKNIX_PLASMA_MOBILE_PKGS`) y **no se publican**
(`make stage` sólo sustituye lo que se nombra, así que el artefacto que está LIVE
se queda intacto: no se republica nada viejo ni se rompe un repo en uso).

## Por qué

- `plasma-mobile` es el rebuild de Arch **6.7.4-1** contra el Qt del snapshot viejo
  (6.11.2). Con el Qt **6.12** de la base actual **no compila** (`Qt6Qml`), y no hay
  rebuild sin portar el shell de Plasma 6.12 completo. No es un fix de una noche.
- La Odin 3 usa **Plasma de escritorio** (`pocknix-desktop-kde`), no Plasma Mobile:
  el sabor Mobile no aporta nada a la imagen que se distribuye.
- El artefacto LIVE (`plasma-mobile-6.7.4-4`) sigue disponible para quien lo tenga
  instalado; simplemente **no se reconstruye ni se vuelve a subir**.

## Consecuencias / notas

- `pocknix-desktop-full` sigue declarando `pocknix-desktop-plasma-mobile`: la imagen
  continúa instalando el artefacto existente (no se toca la composición del sabor
  esta noche). Si algún día se quiere quitar del todo, hay que retirar también
  `pocknix-desktop-full`/`pocknix-homescreen` (dependen de la familia Mobile) o
  repuntar `pocknix-desktop-full` al sabor `pocknix-desktop-plasma`.
- El `stage-check` no ve nada raro porque no se hace `DROP`: los paquetes siguen
  LIVE y el delta de la publicación es sólo lo nombrado.

## Cómo reintentarlo

```sh
POCKNIX_PLASMA_MOBILE=1 sudo -A DEVICE=sm8750 make packages PKG="plasma-mobile pocknix-desktop-plasma-mobile"
```

(Requiere portar el shell a Qt 6.12/Plasma 6.12: el PKGBUILD por sí solo no basta.)
