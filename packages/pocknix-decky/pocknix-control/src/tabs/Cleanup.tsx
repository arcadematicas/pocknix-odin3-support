import { ButtonItem, ConfirmModal, Field, PanelSection, PanelSectionRow, ToggleField, showModal } from "@decky/ui";
import { useEffect, useState } from "react";
import { cleanupBiggest, cleanupRun, cleanupScan } from "../backend";
import type { BiggestEntry, CleanupScan } from "../backend";

// Bytes -> texto corto (MB o GB), que es como se lee bien en el QAM.
const human = (bytes: number) => {
  if (bytes >= 1024 ** 3) return `${(bytes / 1024 ** 3).toFixed(2)} GB`;
  if (bytes >= 1024 ** 2) return `${(bytes / 1024 ** 2).toFixed(0)} MB`;
  if (bytes >= 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${bytes} B`;
};

export function Cleanup() {
  const [data, setData] = useState<CleanupScan | null>(null);
  const [selected, setSelected] = useState<Record<string, boolean>>({});
  const [biggest, setBiggest] = useState<BiggestEntry[]>([]);
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  const refresh = () => {
    cleanupScan()
      .then((next) => {
        setData(next);
        // Por defecto marcamos todo lo NO avanzado: es lo que se puede borrar sin
        // pensar. Lo avanzado (p.ej. la caché de pacman) se deja sin marcar.
        setSelected((current) => {
          const out: Record<string, boolean> = {};
          for (const item of next.items) out[item.id] = current[item.id] ?? !item.advanced;
          return out;
        });
      })
      .catch((err) => setError(String(err)));
  };

  useEffect(() => {
    refresh();
    cleanupBiggest().then(setBiggest).catch(() => {});
  }, []);

  const selectedIds = data ? data.items.filter((i) => selected[i.id]).map((i) => i.id) : [];
  const selectedSize = data ? data.items.filter((i) => selected[i.id]).reduce((a, i) => a + i.size, 0) : 0;

  const run = () => {
    if (!selectedIds.length) return;
    showModal(
      <ConfirmModal
        strTitle="Limpiar cachés"
        strDescription={`Se borrarán ${selectedIds.length} categoría(s), unos ${human(selectedSize)}. Solo son cachés y logs: se regeneran solos. No se tocan partidas ni configuraciones.`}
        strOKButtonText="Limpiar"
        strCancelButtonText="Cancelar"
        onOK={async () => {
          setBusy(true);
          setError("");
          setMessage("");
          try {
            const result = await cleanupRun(selectedIds);
            setMessage(
              result.errors.length
                ? `Liberado ${human(result.freed)}. ${result.errors.length} aviso(s): ${result.errors.slice(0, 2).join(" · ")}`
                : `Liberado ${human(result.freed)}.`
            );
            refresh();
            cleanupBiggest().then(setBiggest).catch(() => {});
          } catch (err) {
            setError(String(err));
          } finally {
            setBusy(false);
          }
        }}
      />
    );
  };

  const items = data?.items ?? [];
  const shown = items.filter((i) => showAdvanced || !i.advanced);

  return (
    <>
      <PanelSection title="ESPACIO">
        <PanelSectionRow>
          <Field
            label="Libre"
            description={
              data
                ? `${human(data.free)} libres de ${human(data.diskTotal)}${data.total ? ` · ${human(data.total)} en cachés` : ""}`
                : "…"
            }
          />
        </PanelSectionRow>
      </PanelSection>

      <PanelSection title="CACHÉS Y LOGS">
        {shown.map((item) => (
          <PanelSectionRow key={item.id}>
            <ToggleField
              label={`${item.label} — ${human(item.size)}`}
              description={item.description}
              checked={!!selected[item.id]}
              disabled={busy || item.size === 0}
              onChange={(value) => setSelected((cur) => ({ ...cur, [item.id]: value }))}
            />
          </PanelSectionRow>
        ))}
        {items.some((i) => i.advanced) && (
          <PanelSectionRow>
            <ToggleField
              label="Mostrar opciones avanzadas"
              description="Categorías que conviene borrar con cuidado (p. ej. la caché de paquetes)."
              checked={showAdvanced}
              onChange={setShowAdvanced}
            />
          </PanelSectionRow>
        )}
        <PanelSectionRow>
          <ButtonItem
            layout="below"
            disabled={busy || !selectedIds.length}
            description={
              busy
                ? "Limpiando…"
                : selectedIds.length
                  ? `Borrar ${selectedIds.length} categoría(s) · ${human(selectedSize)}`
                  : "Marca alguna categoría"
            }
            onClick={run}
          >
            Limpiar seleccionadas
          </ButtonItem>
        </PanelSectionRow>
        {message ? (
          <PanelSectionRow>
            <Field label="" description={message} />
          </PanelSectionRow>
        ) : null}
        {error ? (
          <PanelSectionRow>
            <Field label="Error" description={error} />
          </PanelSectionRow>
        ) : null}
      </PanelSection>

      {biggest.length > 0 && (
        <PanelSection title="QUÉ OCUPA MÁS">
          {biggest.map((entry) => (
            <PanelSectionRow key={entry.path}>
              <Field
                label={human(entry.size)}
                description={entry.path.replace(/^\/home\/[^/]+/, "~")}
              />
            </PanelSectionRow>
          ))}
        </PanelSection>
      )}
    </>
  );
}
