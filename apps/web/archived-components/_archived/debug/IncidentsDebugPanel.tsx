"use client";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  clearResolvedIncidents,
  downloadIncidentBundle,
  INCIDENT_KIND_LABELS,
  resolveIncident,
  scanAndPersistIncidents,
} from "@/lib/validation/incidents";
import { formatEntryDate } from "@/lib/utils";
import type { IncidentBundle } from "@/types/validation-phase";

export function IncidentsDebugPanel({
  bundle,
  onRefresh,
}: {
  bundle: IncidentBundle;
  onRefresh: () => void;
}) {
  return (
    <div className="space-y-6">
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Incident summary</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3 text-sm text-zinc-400">
          <p>{bundle.openCount} open · {bundle.incidentCount} total recorded</p>
          <div className="flex flex-wrap gap-2">
            <Button
              type="button"
              size="sm"
              variant="secondary"
              onClick={() => {
                void scanAndPersistIncidents().then(onRefresh);
              }}
            >
              Scan and record
            </Button>
            <Button type="button" size="sm" variant="secondary" onClick={() => downloadIncidentBundle(bundle)}>
              Export incident bundle
            </Button>
            <Button
              type="button"
              size="sm"
              variant="ghost"
              onClick={() => {
                clearResolvedIncidents();
                onRefresh();
              }}
            >
              Clear resolved
            </Button>
          </div>
        </CardContent>
      </Card>

      {bundle.liveScan.length > 0 ? (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Live scan</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2">
              {bundle.liveScan.map((row) => (
                <li key={row.id} className="rounded-lg bg-white/[0.03] px-3 py-2 text-sm text-zinc-400">
                  <p className="text-amber-200/90">{INCIDENT_KIND_LABELS[row.kind]}</p>
                  <p className="mt-1">{row.detail}</p>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ) : null}

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Recorded incidents</CardTitle>
        </CardHeader>
        <CardContent>
          {bundle.incidents.length === 0 ? (
            <p className="text-sm text-zinc-500">No incidents recorded yet.</p>
          ) : (
            <ul className="space-y-3">
              {bundle.incidents.map((row) => (
                <li
                  key={row.id}
                  className={`rounded-xl px-3 py-3 text-sm ${
                    row.resolved ? "bg-white/[0.02] text-zinc-600" : "bg-white/[0.03] text-zinc-400"
                  }`}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className={row.resolved ? "text-zinc-500" : "text-rose-200/90"}>
                        {INCIDENT_KIND_LABELS[row.kind]}
                        {row.resolved ? " · resolved" : ""}
                      </p>
                      <p className="mt-1">{row.detail}</p>
                      <p className="mt-2 text-xs text-zinc-600">{formatEntryDate(row.detectedAt)}</p>
                    </div>
                    {!row.resolved ? (
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        className="shrink-0 text-[11px]"
                        onClick={() => {
                          resolveIncident(row.id);
                          onRefresh();
                        }}
                      >
                        Resolve
                      </Button>
                    ) : null}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
