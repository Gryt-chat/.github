// Checks Gryt webhook payloads against the server's own zod schema, read from Gryt-chat/server main.
// GRYT_SERVER_SRC points it at a local server src/ instead, to try a change there first.

import { mkdtempSync, readFileSync, rmSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { pathToFileURL } from "node:url";

const SOURCE = process.env.GRYT_SERVER_SRC ?? "https://raw.githubusercontent.com/Gryt-chat/server/main/src";
const FILES = ["routes/webhookSchemas.ts", "utils/messageLimits.ts"];

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error("usage: check-gryt-payloads.mjs <payload.json>...");
  process.exit(2);
}

async function read(file) {
  if (!SOURCE.startsWith("http")) return readFileSync(join(SOURCE, file), "utf8");
  const res = await fetch(`${SOURCE}/${file}`);
  if (!res.ok) throw new Error(`${SOURCE}/${file} answered ${res.status}`);
  return res.text();
}

// Inside test/, so the schema's own `import "zod"` finds test/node_modules.
const dir = mkdtempSync(join(import.meta.dirname, ".server-"));
let refused = 0;
try {
  for (const file of FILES) {
    const source = (await read(file)).replace(/from "(\.{1,2}\/[^"]+?)(\.ts)?"/g, 'from "$1.ts"');
    mkdirSync(dirname(join(dir, file)), { recursive: true });
    writeFileSync(join(dir, file), source);
  }
  const { webhookMessageSchema, problemsFrom } = await import(pathToFileURL(join(dir, FILES[0])).href);

  for (const file of files) {
    const result = webhookMessageSchema.safeParse(JSON.parse(readFileSync(file, "utf8")));
    if (!result.success) {
      refused++;
      console.error(`refused: ${file}\n  ${JSON.stringify(problemsFrom(result.error))}`);
    }
  }
} finally {
  rmSync(dir, { recursive: true, force: true });
}

if (refused > 0) {
  console.error(`The server would refuse ${refused} of ${files.length} payloads.`);
  process.exit(1);
}
console.log(`The server's schema accepts all ${files.length} payloads.`);
