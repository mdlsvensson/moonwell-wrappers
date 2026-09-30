import { join, resolve } from "@std/path";
import { diagnose, expectMarked, root, run, yue, yueOverride } from "./run.ts";

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
async function copyTree(from: string, to: string) {
  await Deno.mkdir(to, { recursive: true });
  for await (const entry of Deno.readDir(from)) {
    if (entry.isDirectory) await copyTree(join(from, entry.name), join(to, entry.name));
    else if (entry.isFile) await Deno.copyFile(join(from, entry.name), join(to, entry.name));
  }
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
const intended = await expectMarked("tests/editor-negative.lua", negative, "negative.lua", "Editor negative fixture");
console.log(`LuaLS: ${intended} intentional type errors detected at the expected lines`);
await Deno.remove(join(consumer, "lua/negative.lua"));

// The library's own files against Moonwell's native declarations: native names, argument counts and argument types.
// The consumer runs above never diagnose library files, and the planted fixture proves this check reports each kind.
const source = join(work, "source");
await copyTree("src/wrappers", join(source, "wrappers"));
await Deno.mkdir(join(source, "types"));
for (const name of ["natives.d.lua", "moonwell.d.lua"]) {
  await Deno.copyFile(join(consumer, ".moonwell/types", name), join(source, "types", name));
}
await Deno.copyFile("tests/natives-negative.lua", join(source, "natives-negative.lua"));
await Deno.writeTextFile(
  join(source, ".luarc.json"),
  JSON.stringify({
    "runtime.version": "Lua 5.3",
    "runtime.path": ["?.lua", "?/init.lua"],
    "runtime.builtin": { io: "disable", debug: "disable", package: "disable" },
    "workspace.library": ["types"],
    "workspace.useGitIgnore": false,
    "workspace.checkThirdParty": false,
  }),
);
const planted = await expectMarked(
  "tests/natives-negative.lua",
  await diagnose(source, "natives"),
  "natives-negative.lua",
  "Native-call check",
);
console.log(`LuaLS: src/wrappers is clean against Moonwell's natives; ${planted} planted mistakes detected`);

// Use a Unit-only entry to exercise reachability without an umbrella import.
await Deno.writeTextFile(
  join(consumer, "src/main.yue"),
  'import "wrappers.unit" as Unit\nimport "wrappers.player" as Player\n' +
    "u = Unit.create Player.fromIndex(0), 1751543663, 10, 20, 270\nu\\remove!\n",
);
await moonwell(["build"]);
const bundle = await Deno.readTextFile(join(consumer, "dist/stage/map.w3x/war3map.lua"));
for (
  const unused of [
    "effect",
    "trigger",
    "group",
    "timer",
    "destructable",
    "rect",
    "region",
    "force",
    "texttag",
    "sound",
    "lightning",
    "image",
    "ubersplat",
    "fogmodifier",
    "dialog",
    "multiboard",
    "leaderboard",
    "quest",
    "defeatcondition",
    "timerdialog",
    "frame",
  ]
) {
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

// A map importing just one module bundles only that module and the public modules it returns wrappers of.
const publicModules = [
  "unit",
  "player",
  "item",
  "destructable",
  "rect",
  "region",
  "force",
  "group",
  "timer",
  "effect",
  "trigger",
  "texttag",
  "sound",
  "lightning",
  "image",
  "ubersplat",
  "fogmodifier",
  "dialog",
  "multiboard",
  "leaderboard",
  "quest",
  "defeatcondition",
  "timerdialog",
  "frame",
];
const soloEntries: Record<string, { source: string; allowed: string[] }> = {
  trigger: { source: 'import "wrappers.trigger" as Trigger\nt = Trigger.create!\nt\\destroy!\n', allowed: [] },
  texttag: {
    source: 'import "wrappers.texttag" as TextTag\nt = TextTag.create!\nt\\destroy!\nTextTag.float "+1", 0, 0\n',
    allowed: [],
  },
  multiboard: {
    source: 'import "wrappers.multiboard" as Multiboard\nb = Multiboard.create 1, 1\nb\\destroy!\n',
    allowed: [],
  },
  dialog: { source: 'import "wrappers.dialog" as Dialog\nd = Dialog.create!\nd\\destroy!\n', allowed: ["player"] },
  frame: { source: 'import "wrappers.frame" as Frame\nFrame.hideOrigin false\n', allowed: ["player"] },
};
// "wrappers.timer" is a prefix of "wrappers.timerdialog"; match whole module names by the closing quote.
const bundles = (bundle: string, name: string) =>
  bundle.includes(`wrappers.${name}"`) || bundle.includes(`wrappers.${name}'`);
for (const [entry, { source, allowed }] of Object.entries(soloEntries)) {
  await Deno.writeTextFile(join(consumer, "src/main.yue"), source);
  await moonwell(["build"]);
  const soloBundle = await Deno.readTextFile(join(consumer, "dist/stage/map.w3x/war3map.lua"));
  // Guard the absence checks below: they would pass vacuously if the bundle held no wrapper module at all.
  if (!bundles(soloBundle, entry)) throw new Error(`${entry}-only bundle lacks wrappers.${entry}`);
  for (const name of allowed) {
    if (!bundles(soloBundle, name)) throw new Error(`${entry}-only bundle lacks wrappers.${name}`);
  }
  for (const unused of publicModules) {
    if (unused !== entry && !allowed.includes(unused) && bundles(soloBundle, unused)) {
      throw new Error(`${entry}-only bundle includes wrappers.${unused}`);
    }
  }
}
console.log("Moonwell: Trigger-, TextTag-, Multiboard-, Dialog- and Frame-only maps bundle only what they import");

await Deno.copyFile("examples/gate.yue", join(consumer, "src/main.yue"));
await moonwell(["check"]);
await moonwell(["build", "--minify"]);
await compileEditor();
const gate = await diagnose(consumer, "gate");
if (Object.values(gate).some((entries) => entries.length)) {
  throw new Error(`Gate example diagnostics: ${JSON.stringify(gate)}`);
}
console.log("Gate example: every module builds and editor diagnostics are clean; game execution remains manual");
