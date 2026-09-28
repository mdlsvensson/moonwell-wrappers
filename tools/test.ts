// Warcraft natives exist only in the game. Run real modules with boundary doubles in a fresh VM per suite.
const yue = Deno.env.get("MOONWELL_YUE") ?? "yue";
const version = await new Deno.Command(yue, { args: ["-v"], stdout: "piped" }).output();
if (!new TextDecoder().decode(version.stdout).includes("0.34.2")) throw new Error("YueScript 0.34.2 is required");
const suites = Deno.args.length ? Deno.args : [...Deno.readDirSync("tests")]
  .map((entry) => entry.name.match(/^([a-z]+)\.lua$/)?.[1])
  .filter((name): name is string => name !== undefined && name !== "support")
  .sort();
await Deno.mkdir(".test-work", { recursive: true });
let failures = 0;
for (const suite of suites) {
  if (!/^[a-z]+$/.test(suite)) throw new Error("Invalid test suite name");
  const script = `package.path = './src/?.lua;./tests/?.lua;' .. package.path\n` +
    `require('support')\nrequire('${suite}')\nfinish()\n`;
  const file = `.test-work/${suite}.lua`;
  await Deno.writeTextFile(file, script);
  const result = await new Deno.Command(yue, { args: ["-e", file], stdout: "piped", stderr: "piped" }).output();
  const output = new TextDecoder().decode(result.stdout) + new TextDecoder().decode(result.stderr);
  console.log(`${suite}: ${output.trim()}`);
  if (!result.success || !output.includes("SUITE PASSED")) failures++;
}
if (failures) Deno.exit(1);
