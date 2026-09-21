import { ToggleField } from "@decky/ui";
import { useEffect, useState } from "react";
import { makoStatus } from "../backend";
import { makoEnabledIn, readLaunchOptions, syncMakoLaunchOption } from "../lib/launchOptions";

/** Per-game MAKO (Lossless Scaling frame generation) switch.
 *
 *  MAKO keeps no config blob of its own here: it activates entirely through the game's launch
 *  options, which Steam owns. The switch therefore reads the string back instead of holding a
 *  shadow copy the two UIs could disagree about. It stays hidden until the wrapper exists, so
 *  it is never offered on a device where the Renderer was not installed.
 */
export function MakoToggle({ appid }: { appid: string }) {
  const [installed, setInstalled] = useState(false);
  const [on, setOn] = useState(false);
  useEffect(() => {
    let cancelled = false;
    setInstalled(false);
    setOn(false);
    makoStatus()
      .then((status) => {
        if (!cancelled) setInstalled(status.installed);
      })
      .catch(() => {});
    readLaunchOptions(appid)
      .then((options) => {
        if (!cancelled) setOn(options ? makoEnabledIn(options) : false);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [appid]);
  if (!installed) return null;
  return (
    <ToggleField
      label="MAKO (Lossless Scaling frame gen)"
      checked={on}
      onChange={(next) => {
        setOn(next);
        // Steam owns the string, so roll the toggle back if the write is refused.
        syncMakoLaunchOption(appid, next).catch(() => setOn(!next));
      }}
    />
  );
}
