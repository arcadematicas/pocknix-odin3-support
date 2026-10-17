import * as DUI from "@decky/ui";
import type { ReactElement } from "react";

/**
 * PESTAÑA PROPIA EN EL QAM (independiente del menú de Decky).
 *
 * POR QUE EXISTE
 *   El cliente de Steam del 13/10/2026 partió el CSS del QAM: el `TitleView` del menú de
 *   Decky busca `staticClasses.Title`, ya no existe, lanza
 *       TypeError: Cannot read properties of undefined (reading 'Title')
 *   y la pestaña de Decky deja de renderizarse. Un plugin normal (`definePlugin({content})`)
 *   vive DENTRO de esa pestaña -> queda INACCESIBLE (le pasó a PocknixControl).
 *
 *   Solución (la misma que usa el plugin "Panel de Control" de Hooandee): registrarnos en la
 *   tabla de pestañas del QAM (`window.__TABS_HOOK_INSTANCE`, la misma que usa Decky) con
 *   NUESTRO propio título. Así nuestros ajustes salen siempre en el QAM, aunque el menú de
 *   Decky esté roto.
 *
 *   ⚠️ `staticClasses?.Title` con optional chaining: si Steam vuelve a cambiar el CSS, el
 *   className queda `undefined` (la pestaña sigue saliendo), en vez de lanzar un TypeError
 *   que impediría el registro. Es exactamente el fallo de hoy, así que no lo quitamos.
 *
 *   Si el hook no existe (versión de Decky distinta) NO se rompe nada: se avisa por consola
 *   y el plugin sigue funcionando con su pestaña normal de Decky.
 */

const TAB_ID = 0x504b43; // "PKC"
const OWNER = "pocknix-control";

type QamTab = {
  id: number;
  title?: unknown;
  content?: unknown;
  icon?: unknown;
  __pkcOwner?: string;
};

type TabsHook = {
  tabs: QamTab[];
  add: (tab: QamTab) => void;
  removeById: (id: number) => void;
};

function tabsHook(): TabsHook | null {
  try {
    const hook = (window as any).__TABS_HOOK_INSTANCE;
    if (
      !hook ||
      !Array.isArray(hook.tabs) ||
      typeof hook.add !== "function" ||
      typeof hook.removeById !== "function"
    ) {
      return null;
    }
    return hook as TabsHook;
  } catch {
    return null;
  }
}

function ownedTabs(hook: TabsHook): QamTab[] {
  return hook.tabs.filter(
    (tab) => tab && tab.id === TAB_ID && tab.__pkcOwner === OWNER,
  );
}

/** Registra (o re-registra) nuestra pestaña. Devuelve true si quedó registrada. */
export function registerQamTab(
  content: ReactElement,
  icon: ReactElement,
): boolean {
  try {
    const hook = tabsHook();
    if (!hook) return false;
    // Quita SOLO la nuestra (idempotente); no toca las de otros plugins.
    for (const _tab of ownedTabs(hook)) {
      try {
        hook.removeById(TAB_ID);
      } catch {
        /* ignore */
      }
    }
    const staticClasses = (DUI as any)?.staticClasses;
    hook.add({
      id: TAB_ID,
      title: <div className={staticClasses?.Title}>Pocknix Control</div>,
      content,
      icon,
      __pkcOwner: OWNER,
    });
    return hook.tabs.some((tab) => tab?.id === TAB_ID);
  } catch (e) {
    console.warn("[PocknixControl] pestaña propia del QAM no disponible:", e);
    return false;
  }
}

/** Quita nuestra pestaña (al descargar el plugin). */
export function unregisterQamTab(): void {
  try {
    const hook = tabsHook();
    if (!hook) return;
    for (const _tab of ownedTabs(hook)) {
      try {
        hook.removeById(TAB_ID);
      } catch {
        /* ignore */
      }
    }
  } catch {
    /* ignore */
  }
}

/**
 * Al cargar el plugin el hook puede no existir todavía, y además Decky **recrea** el
 * `TabsHook` en algunos momentos (`window.__TABS_HOOK_INSTANCE?.deinit(); ... = this`), con
 * lo que nuestra pestaña se pierde. Por eso no basta con registrar una vez: un vigilante
 * comprueba cada 2 s que siga estando y la vuelve a añadir si falta.
 * Devuelve una función para pararlo.
 */
export function startQamTabWatchdog(
  content: ReactElement,
  icon: ReactElement,
): () => void {
  let cancelled = false;

  const tick = () => {
    if (cancelled) return;
    try {
      const hook = tabsHook();
      if (!hook) return; // Decky aún no tiene el hook: se reintenta en el siguiente tick
      const present = hook.tabs.some(
        (tab) => tab && tab.id === TAB_ID && tab.__pkcOwner === OWNER,
      );
      if (present) return;
      if (registerQamTab(content, icon)) {
        console.log("[PocknixControl] pestaña propia del QAM (re)registrada");
      }
    } catch {
      /* nunca romper el plugin por esto */
    }
  };

  tick();
  const interval = window.setInterval(tick, 2000);

  return () => {
    cancelled = true;
    window.clearInterval(interval);
  };
}
