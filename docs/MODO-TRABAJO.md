# Modo trabajo (`calvos-work-mode`)

**Qué es**: dejar la consola encendida, sin que se suspenda ni se apague, con la pantalla
apagada y en perfil de bajo consumo. Se usa cuando Fransis la deja descargando/cargando o
trabajando fuera.

```
sudo calvos-work-mode on       # guarda el perfil y el brillo, pone `bajo`, inhibe y apaga pantalla
sudo calvos-work-mode off      # para el inhibidor, RESTAURA el perfil y el brillo, enciende pantalla
calvos-work-mode status        # inhibidor, perfil y estado de pantalla
```

`--dry-run` con `on`/`off` imprime lo que haría sin tocar nada.

## Por qué existe

El 25/11 se entró a mano (perfil `bajo` + `systemd-inhibit` + `bl_power=1`) y al salir solo se
paró el inhibidor. **El perfil se quedó en `bajo`**: al día siguiente Wind Waker iba lento porque
el scheduler seguía en `bpfland powersave`, aunque el Panel de Control marcara “6 equilibrado”
(el Panel manda TDP; el perfil manda scheduler y topes).

Ahora el perfil y el brillo se guardan en `/var/lib/pocknix/work-{profile-saved,brightness}` y se
devuelven al salir. Los ficheros de marca se borran al terminar, así que dos `on` seguidos no
pisan el perfil guardado.

## Detalles

- Perfil al salir: el que hubiera antes (`medio` en el uso normal).
- Inhibidor: unidad transitoria `calvos-work-inhibit` (`idle:sleep:shutdown`, `block`).
- Pantalla: `bl_power=1` + `brightness=0`; al salir, `bl_power=0` y el brillo guardado.
- Los LEDs RGB no se tocan aquí (los gestiona el plugin cuando toca).
