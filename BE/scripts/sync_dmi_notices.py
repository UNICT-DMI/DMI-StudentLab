"""Sincronizza news UNICT e avvisi dei corsi L-31, L-35 e L-13 ogni ora."""

import os
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from services.dmi_notice_scraper import URLS, remove_duplicates, scrape_source  # noqa: E402


def main() -> int:
    endpoint = os.getenv("STUDENTLAB_NOTICE_API_URL", "").strip()
    token = os.getenv("STUDENTLAB_NOTICE_SYNC_TOKEN", "").strip()
    if not endpoint.startswith("https://") or not endpoint.endswith("/institutional-notices/sync") or not token:
        print("Imposta STUDENTLAB_NOTICE_API_URL (HTTPS) e STUDENTLAB_NOTICE_SYNC_TOKEN.", file=sys.stderr)
        return 2

    totals = {"received": 0, "inserted": 0, "updated": 0}
    failed = []
    empty = []
    for source, url in URLS.items():
        try:
            notices = [item for item in remove_duplicates(scrape_source(source, url))
                       if item.get("titolo", "").strip() and item.get("testo", "").strip()]
        except Exception as exc:
            failed.append(source)
            print(f"Fonte {source} non disponibile: {exc}", file=sys.stderr)
            continue
        print(f"Fonte {source}: {len(notices)} avvisi validi; elenco {url}.")
        if not notices:
            empty.append(source)
            continue
        # Una fonte difettosa non deve bloccare l'importazione delle altre.
        for index in range(0, len(notices), 50):
            try:
                response = requests.post(
                    endpoint,
                    json={"notices": notices[index:index + 50]},
                    headers={"X-StudentLab-Sync-Token": token},
                    timeout=45,
                )
                response.raise_for_status()
                result = response.json()
            except requests.RequestException as exc:
                failed.append(source)
                status = getattr(getattr(exc, "response", None), "status_code", None)
                print(f"Fonte {source}: sincronizzazione fallita "
                      f"(HTTP {status or 'rete'}, blocco {index // 50 + 1}).", file=sys.stderr)
                break
            for key in totals:
                totals[key] += int(result.get(key, 0))
    print(f"Sincronizzati {totals['received']} avvisi; nuovi {totals['inserted']}; aggiornati {totals['updated']}.")
    if failed:
        print(f"Fonti non sincronizzate: {', '.join(dict.fromkeys(failed))}", file=sys.stderr)
    if empty:
        print(f"Fonti senza avvisi validi: {', '.join(empty)}", file=sys.stderr)
    return 1 if failed or totals['received'] == 0 else 0


if __name__ == "__main__":
    sys.exit(main())
