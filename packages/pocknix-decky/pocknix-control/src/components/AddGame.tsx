import { openFilePicker, toaster } from "@decky/api";
import { ButtonItem, ConfirmModal, PanelSection, PanelSectionRow, TextField, ToggleField, showModal } from "@decky/ui";
import { useState } from "react";
import { addShortcut, defaultShortcutName, isWindowsExe } from "../lib/shortcuts";

function AddGameModal({ path, closeModal }: { path: string; closeModal?: () => void }) {
  const [name, setName] = useState(defaultShortcutName(path));
  const [proton, setProton] = useState(isWindowsExe(path));
  const [busy, setBusy] = useState(false);
  const submit = async () => {
    if (busy || !name.trim()) return;
    setBusy(true);
    try {
      await addShortcut(name.trim(), path, proton);
      toaster.toast({ title: "Añadido a la biblioteca", body: name.trim() });
      closeModal?.();
    } catch (error) {
      toaster.toast({ title: "No se pudo añadir el juego", body: String(error) });
      setBusy(false);
    }
  };
  return (
    <ConfirmModal
      strTitle="Añadir juego externo"
      strDescription={path}
      strOKButtonText={busy ? "Añadiendo…" : "Añadir a la biblioteca"}
      bOKDisabled={busy || !name.trim()}
      onCancel={() => closeModal?.()}
      onOK={submit}
    >
      <TextField label="Nombre" value={name} disabled={busy} onChange={(event) => setName(event.target.value)} />
      <ToggleField
        label="Lanzar con Proton"
        description="Necesario para juegos de Windows (.exe)"
        checked={proton}
        disabled={busy}
        onChange={setProton}
      />
    </ConfirmModal>
  );
}

export function AddGameSection() {
  const pick = async () => {
    try {
      // 0 = FileSelectionType.FILE (const enum in @decky/api typings, no runtime export).
      const result = await openFilePicker(0, "/home/deck", true, true);
      if (result?.path) showModal(<AddGameModal path={result.path} />);
    } catch (error) {
      // Picker closed without a selection.
    }
  };
  return (
    <PanelSection title="BIBLIOTECA">
      <PanelSectionRow>
        <ButtonItem layout="below" onClick={pick}>Añadir juego externo a Steam</ButtonItem>
      </PanelSectionRow>
      <div className="pocknix-note">Elige un ejecutable para añadirlo a tu biblioteca de Steam.</div>
    </PanelSection>
  );
}
