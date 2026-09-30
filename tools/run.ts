import { dirname, resolve } from "@std/path";

export const root = resolve(".");
const configuredYue = Deno.env.get("MOONWELL_YUE");
export const yueOverride = configuredYue ? resolve(configuredYue) : undefined;
export const yue = yueOverride ?? "yue";
export const luals = Deno.env.get("MOONWELL_LUALS") ?? "lua-language-server";
const pkl = Deno.env.get("MOONWELL_PKL");
export const env: Record<string, string> = pkl
  ? { PATH: dirname(resolve(pkl)) + (Deno.build.os === "windows" ? ";" : ":") + Deno.env.get("PATH") }
  : {};

export async function run(binary: string, args: string[], cwd = root, allowFailure = false) {
  const result = await new Deno.Command(binary, { args, cwd, env, stdout: "piped", stderr: "piped" }).output();
  const output = new TextDecoder().decode(result.stdout) + new TextDecoder().decode(result.stderr);
  if (!result.success && !allowFailure) throw new Error(`${binary} ${args.join(" ")}\n${output}`);
  return { code: result.code, output };
}

export interface Diagnostic {
  code: string;
  message: string;
  range: { start: { line: number; character: number } };
}

export async function diagnose(project: string, name: string): Promise<Record<string, Diagnostic[]>> {
  const version = await run(luals, ["--version"]);
  if (!version.output.includes("3.19.1")) throw new Error("LuaLS 3.19.1 is required");
  const report = resolve(project, `../${name}.json`);
  const result = await run(
    luals,
    [
      `--check=${project}`,
      "--checklevel=Hint",
      "--check_format=json",
      `--check_out_path=${report}`,
      `--logpath=${resolve(project, `../${name}-logs`)}`,
      `--metapath=${resolve(project, "../luals-meta")}`,
    ],
    root,
    true,
  );
  await Deno.writeTextFile(resolve(project, `../${name}.log`), result.output);
  try {
    return JSON.parse(await Deno.readTextFile(report));
  } catch {
    throw new Error(`LuaLS did not write a valid report (exit ${result.code}): ${result.output}`);
  }
}

/**
 * Compares a LuaLS report with the `-- EXPECT <code>` markers of a fixture reported as `reportedName`. A diagnostic in
 * any other file fails, so the rest of the checked project must be clean. Returns the number of expected diagnostics.
 */
export async function expectMarked(
  fixture: string,
  report: Record<string, Diagnostic[]>,
  reportedName: string,
  label: string,
): Promise<number> {
  const expected = (await Deno.readTextFile(fixture)).split("\n")
    .flatMap((line, index) => {
      const code = line.match(/-- EXPECT ([\w-]+)/)?.[1];
      return code ? [`${index}:${code}`] : [];
    }).sort();
  const actual = Object.entries(report).flatMap(([file, diagnostics]) =>
    diagnostics.map((d) => {
      if (!file.endsWith(`/${reportedName}`)) throw new Error(`Unexpected diagnostic in ${file}: ${d.message}`);
      return `${d.range.start.line}:${d.code}`;
    })
  ).sort();
  if (JSON.stringify(expected) !== JSON.stringify(actual)) {
    throw new Error(`${label}: expected ${expected}; got ${actual}\n${JSON.stringify(report)}`);
  }
  return actual.length;
}
