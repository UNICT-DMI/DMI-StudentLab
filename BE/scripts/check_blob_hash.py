"""Verifica come la libreria vercel.blob scarica i file privati.

Serve a chiudere il punto sulla verifica SHA-256 dei file grandi:
`verify_private_blob` usa `client.get(...)` e poi `result.content`.
Questo script mostra:
  1. la versione della libreria e la firma di `AsyncBlobClient.get`;
  2. se il risultato offre una lettura a blocchi (stream) oltre a `.content`;
  3. con un file reale: dimensione, tempo, memoria di picco e SHA-256.

Uso (dalla cartella BE, con il virtualenv attivo e BLOB_READ_WRITE_TOKEN
disponibile come nel backend):
    python scripts/check_blob_hash.py
    python scripts/check_blob_hash.py "percorso/del/blob.pdf"

Non modifica né cancella nulla: legge soltanto.
"""
import asyncio
import hashlib
import inspect
import sys
import time
import tracemalloc


def describe_library():
    try:
        import vercel
        from vercel.blob import AsyncBlobClient
    except Exception as error:  # pragma: no cover - diagnostica
        print(f"[ERRORE] libreria vercel non importabile: {error}")
        return None
    print(f"vercel: {getattr(vercel, '__version__', 'versione non indicata')}")
    print(f"modulo: {inspect.getfile(AsyncBlobClient)}")
    print(f"AsyncBlobClient.get{inspect.signature(AsyncBlobClient.get)}")
    methods = [name for name in dir(AsyncBlobClient) if not name.startswith('_')]
    print(f"metodi pubblici: {', '.join(methods)}")
    return AsyncBlobClient


async def measure(client_cls, stored_name: str):
    from core.config import settings

    if not settings.blob_read_write_token:
        print("[ERRORE] BLOB_READ_WRITE_TOKEN non configurato.")
        return
    tracemalloc.start()
    started = time.perf_counter()
    async with client_cls(token=settings.blob_read_write_token) as client:
        result = await client.get(stored_name, access="private")
    elapsed = time.perf_counter() - started
    if result is None or getattr(result, "status_code", 200) != 200:
        print(f"[ERRORE] blob non disponibile: {getattr(result, 'status_code', None)}")
        return
    attrs = [name for name in dir(result) if not name.startswith('_')]
    print(f"attributi del risultato: {', '.join(attrs)}")
    streaming = [name for name in attrs if any(k in name.lower() for k in ('stream', 'iter', 'chunk', 'read'))]
    print(f"possibile lettura a blocchi: {', '.join(streaming) if streaming else 'nessuna trovata'}")
    content = getattr(result, "content", None)
    if content is None:
        print("[ATTENZIONE] il risultato non ha .content")
        return
    digest = hashlib.sha256(content).hexdigest()
    _, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    print(f"dimensione: {len(content) / (1024 * 1024):.1f} MB")
    print(f"tempo di download: {elapsed:.1f} s")
    print(f"memoria Python di picco: {peak / (1024 * 1024):.1f} MB")
    print(f"sha256: {digest}")
    print("Se la memoria di picco è circa pari alla dimensione, il file è tutto in RAM.")


def main():
    client_cls = describe_library()
    if client_cls is None:
        sys.exit(1)
    if len(sys.argv) > 1:
        asyncio.run(measure(client_cls, sys.argv[1]))
    else:
        print("\nPer misurare un file reale: python scripts/check_blob_hash.py <stored_name>")


if __name__ == "__main__":
    main()
