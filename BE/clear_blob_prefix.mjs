import { del, list } from '@vercel/blob';

const rawPrefix = process.argv[2];
const confirm = process.argv.includes('--confirm');

if (!rawPrefix) {
  console.error(
    'Uso: node clear_blob_prefix.mjs <prefix|all> [--confirm]',
  );
  process.exit(1);
}

const prefix =
  rawPrefix === 'all'
    ? undefined
    : rawPrefix;

const token =
  process.env.StudentLab_READ_WRITE_TOKEN ??
  process.env.BLOB_READ_WRITE_TOKEN;

if (!token) {
  console.error('Token Blob non configurato.');
  process.exit(1);
}

let cursor;
let totalFound = 0;
let totalDeleted = 0;

do {
  const result = await list({
    ...(prefix ? { prefix } : {}),
    cursor,
    limit: 1000,
    token,
  });

  totalFound += result.blobs.length;

  for (const blob of result.blobs) {
    console.log(
      confirm
        ? `[DELETE] ${blob.pathname}`
        : `[DRY RUN] ${blob.pathname}`,
    );
  }

  if (confirm && result.blobs.length > 0) {
    await del(
      result.blobs.map((blob) => blob.url),
      { token },
    );

    totalDeleted += result.blobs.length;
  }

  cursor = result.cursor;
} while (cursor);

if (!confirm) {
  console.log(
    `\nDry run: ${totalFound} blob trovati ${
      prefix
        ? `sotto "${prefix}"`
        : 'nell’intero store'
    }.`,
  );
  console.log('Nessun file eliminato.');
} else {
  console.log(
    `\nEliminati ${totalDeleted} blob ${
      prefix
        ? `sotto "${prefix}"`
        : 'dall’intero store'
    }.`,
  );
}
