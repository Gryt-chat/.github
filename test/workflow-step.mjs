// Prints one step's run script from a workflow, so a test can run it outside Actions.
// Usage: node workflow-step.mjs <workflow.yml> <job> <step id>

import { readFileSync } from "node:fs";
import { parse } from "yaml";

const [file, job, id] = process.argv.slice(2);
const step = parse(readFileSync(file, "utf8")).jobs?.[job]?.steps?.find((s) => s.id === id);
if (!step?.run) {
  console.error(`${file} has no step "${id}" with a run script in job "${job}"`);
  process.exit(1);
}
process.stdout.write(step.run);
