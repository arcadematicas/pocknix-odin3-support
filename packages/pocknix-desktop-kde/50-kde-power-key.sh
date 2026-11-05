#!/bin/bash
# KDE reads global shortcuts only at session start, and Plasma Mobile binds the power key to
# "Turn Off Screen" while powerdevil's "PowerOff" action (which applies PowerButtonAction) stays
# unbound, so a press does nothing useful. Rebind once per user, only where defaults are untouched.
case ":${XDG_CURRENT_DESKTOP:-}:" in *:KDE:*) ;; *) exit 0 ;; esac
command -v kreadconfig6 >/dev/null 2>&1 && command -v kwriteconfig6 >/dev/null 2>&1 || exit 0

stamp="${XDG_CONFIG_HOME:-${HOME}/.config}/pocknix/kde-power-key-seeded"
[ -e "${stamp}" ] && exit 0

rc=kglobalshortcutsrc
grp=org_kde_powerdevil
case "$(kreadconfig6 --file "${rc}" --group "${grp}" --key PowerOff)" in
  ""|none,none,*)
    kwriteconfig6 --file "${rc}" --group "${grp}" --key PowerOff "Power Off,none,Power Off" ;;
esac
case "$(kreadconfig6 --file "${rc}" --group "${grp}" --key "Turn Off Screen")" in
  ""|"Power Off,Power Off,"*)
    kwriteconfig6 --file "${rc}" --group "${grp}" --key "Turn Off Screen" \
      "none,Power Off,Turn Off Screen" ;;
esac

mkdir -p "$(dirname "${stamp}")" && touch "${stamp}"
