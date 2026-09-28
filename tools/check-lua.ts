import { join, resolve } from "@std/path";
import { run } from "./run.ts";

const luac = Deno.env.get("MOONWELL_LUAC") ?? "luac";
const version = await run(luac, ["-v"]);
if (!version.output.includes("Lua 5.3.6")) throw new Error("Lua 5.3.6 luac is required");
let count = 0;
async function check(dir: string) {
  for await (const entry of Deno.readDir(dir)) {
    const file = join(dir, entry.name);
    if (entry.isDirectory) await check(file);
    else if (entry.isFile && file.endsWith(".lua")) {
      await run(luac, ["-p", resolve(file)]);
      count++;
    }
  }
}
await check("src");
await check("tests");
// Prove the selected parser rejects a construct valid only in Lua 5.4.
await Deno.mkdir(".test-work", { recursive: true });
const probe = resolve(".test-work/lua54-syntax.lua");
await Deno.writeTextFile(probe, "local x <const> = 1\nreturn x\n");
const rejected = await run(luac, ["-p", probe], undefined, true);
if (rejected.code === 0) throw new Error("Lua 5.4 syntax was unexpectedly accepted");
console.log(`Lua 5.3.6 syntax: ${count} files passed; Lua 5.4-only syntax rejected`);
