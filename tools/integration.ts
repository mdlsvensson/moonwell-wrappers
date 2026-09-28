import { join, resolve } from "@std/path";
import { diagnose, root, run, yue, yueOverride } from "./run.ts";

const repo = resolve(Deno.env.get("MOONWELL_REPO") ?? "../moonwell");
const cli = join(repo, "cli/src/main.ts");
await Deno.mkdir(".test-work", { recursive: true });
const work = await Deno.makeTempDir({ dir: resolve(".test-work"), prefix: "integration-" });
const consumer = join(work, "consumer");
await Deno.writeTextFile(".test-work/latest-integration.json", JSON.stringify({ work, consumer }));
console.log(`Consumer: ${consumer}`);
async function moonwell(args: string[], cwd = consumer) {
  const result = await run(Deno.execPath(), ["run", "-A", cli, ...args], cwd);
  console.log(result.output.trim());
}
async function compileEditor() {
  await run(yue, [
    "-l",
    "-c",
    "--target=5.3",
    "--path",
    join(consumer, ".moonwell/yue/?.lua").replaceAll("\\", "/"),
    "-o",
    "src/main.lua",
    "src/main.yue",
  ], consumer);
}
await moonwell(["init", "--link", consumer], root);
await Deno.writeTextFile(
  join(consumer, "moonwell.local.pkl"),
  'amends "moonwell.pkl"\n' +
    `libraries { ["wrappers"] { path = ${JSON.stringify(root.replaceAll("\\", "/"))}; dir = "src" } }\n` +
    (yueOverride ? `yue { path = ${JSON.stringify(yueOverride.replaceAll("\\", "/"))} }\n` : ""),
);
await Deno.copyFile("tests/editor-positive.yue", join(consumer, "src/main.yue"));
await moonwell(["check"]);
await moonwell(["build"]);
await moonwell(["build", "--minify"]);
await compileEditor();
await Deno.copyFile("tests/editor-positive.lua", join(consumer, "lua/positive.lua"));
const positive = await diagnose(consumer, "positive");
if (Object.values(positive).some((entries) => entries.length)) {
  throw new Error(`Positive editor diagnostics: ${JSON.stringify(positive, null, 2)}`);
}
console.log("LuaLS: positive Lua and compiled Yue fixtures clean");
await Deno.copyFile("tests/editor-negative.lua", join(consumer, "lua/negative.lua"));
const negative = await diagnose(consumer, "negative");
const expected = (await Deno.readTextFile("tests/editor-negative.lua")).split("\n")
  .flatMap((line, index) => {
    const code = line.match(/-- EXPECT ([\w-]+)/)?.[1];
    return code ? [`${index}:${code}`] : [];
  }).sort();
const actual = Object.entries(negative).flatMap(([file, diagnostics]) =>
  diagnostics.map((d) => {
    if (!file.endsWith("/negative.lua")) throw new Error(`Unexpected diagnostic in ${file}: ${d.message}`);
    return `${d.range.start.line}:${d.code}`;
  })
).sort();
if (JSON.stringify(expected) !== JSON.stringify(actual)) {
  throw new Error(`Editor negative fixture: expected ${expected}; got ${actual}\n${JSON.stringify(negative)}`);
}
console.log(`LuaLS: ${actual.length} intentional type errors detected at the expected lines`);
await Deno.remove(join(consumer, "lua/negative.lua"));

// Use a Unit-only entry to exercise reachability without an umbrella import.
await Deno.writeTextFile(
  join(consumer, "src/main.yue"),
  'import "wrappers.unit" as Unit\nimport "wrappers.player" as Player\n' +
    "u = Unit.create Player.fromIndex(0), 1751543663, 10, 20, 270\nu\\remove!\n",
);
await moonwell(["build"]);
const bundle = await Deno.readTextFile(join(consumer, "dist/stage/map.w3x/war3map.lua"));
for (const unused of ["effect", "trigger", "group", "timer"]) {
  if (bundle.includes(`wrappers.${unused}`)) throw new Error(`Unused wrapper bundled: ${unused}`);
}
// Run the actual bundled script with the Warcraft globals it uses during module loading.
const probe = join(work, "bundle-probe.lua");
await Deno.writeTextFile(
  probe,
  "bj_MAX_PLAYER_SLOTS = 28\nlocal p, u = {}, {}\nlocal removed = false\n" +
    "function Player(i) assert(i == 0); return p end\n" +
    "function CreateUnit(owner, id, x, y, facing)\n" +
    "assert(owner == p and id == 1751543663 and x == 10 and y == 20 and facing == 270); return u end\n" +
    "function RemoveUnit(value) assert(value == u); removed = true end\n" +
    bundle + '\nassert(removed, "bundled entry did not remove the unit")\nprint("BUNDLE PASSED")\n',
);
const runtime = await run(yue, ["-e", probe]);
if (!runtime.output.includes("BUNDLE PASSED")) throw new Error(runtime.output);
console.log("Moonwell: normal/minified builds, unused-module exclusion and bundled runtime passed");

await Deno.copyFile("examples/gate.yue", join(consumer, "src/main.yue"));
await moonwell(["check"]);
await moonwell(["build", "--minify"]);
await compileEditor();
const gate = await diagnose(consumer, "gate");
if (Object.values(gate).some((entries) => entries.length)) {
  throw new Error(`Gate example diagnostics: ${JSON.stringify(gate)}`);
}
console.log("Gate example: all six modules build and editor diagnostics are clean; game execution remains manual");
