import { definePlugin } from "@decky/api";
import { Content } from "./Content";
import { patchLibraryContextMenu } from "./lib/contextMenu";
import { registerQamTabWithRetry, unregisterQamTab } from "./qamTab";

const tabIcon = <div style={{ fontWeight: 700 }}>P</div>;

export default definePlugin(() => {
  const unpatchContextMenu = patchLibraryContextMenu();

  // Pestaña PROPIA en el QAM: Steam (13/10/2026) rompió el menú de Decky y la pestaña
  // normal de los plugins quedó inaccesible. Si el hook no está, no pasa nada: se usa la
  // de Decky como siempre.
  const cancelQamRetry = registerQamTabWithRetry(<Content />, tabIcon);

  return {
    name: "Pocknix Control",
    content: <Content />,
    icon: tabIcon,
    alwaysRender: true,
    onDismount() {
      cancelQamRetry();
      unregisterQamTab();
      unpatchContextMenu();
    },
  };
});
