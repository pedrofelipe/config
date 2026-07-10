#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const check = process.argv.includes("--check");
const permissionsPath = join(root, "scripts/permissions.json");
const { groups } = JSON.parse(readFileSync(permissionsPath, "utf8"));

// Keep the two generated configs from silently diverging: Claude only handles
// allow/ask here, and repeated patterns become duplicate JSONC keys.
const seenPatterns = new Set();
for (const group of groups) {
  for (const rule of group.rules) {
    if (rule.action !== "allow" && rule.action !== "ask") {
      console.error(
        `unsupported action "${rule.action}" for pattern "${rule.pattern}" in scripts/permissions.json`,
      );
      process.exit(1);
    }

    if (seenPatterns.has(rule.pattern)) {
      console.error(
        `duplicate pattern "${rule.pattern}" in scripts/permissions.json`,
      );
      process.exit(1);
    }

    seenPatterns.add(rule.pattern);
  }
}

const generatedRules = (action) =>
  groups.flatMap((group) =>
    group.rules
      .filter((rule) => rule.action === action)
      .map((rule) => `Bash(${rule.pattern})`),
  );

const claudePath = join(root, ".claude/settings.json");
const claude = JSON.parse(readFileSync(claudePath, "utf8"));
const keepNonBashRules = (rules = []) =>
  rules.filter((rule) => !rule.startsWith("Bash("));

claude.permissions.allow = [
  ...keepNonBashRules(claude.permissions.allow),
  ...generatedRules("allow"),
];
claude.permissions.ask = [
  ...keepNonBashRules(claude.permissions.ask),
  ...generatedRules("ask"),
];
const claudeOutput = JSON.stringify(claude, null, 2) + "\n";

const opencodePath = join(root, ".config/opencode/opencode.jsonc");
const opencodeText = readFileSync(opencodePath, "utf8");
const beginMarker = "      // BEGIN generated permissions (scripts/generate-permissions.mjs)";
const endMarker = "      // END generated permissions";
const beginIndex = opencodeText.indexOf(beginMarker);
const endIndex = opencodeText.indexOf(endMarker);

if (beginIndex === -1 || endIndex === -1 || endIndex < beginIndex) {
  console.error("markers missing or out of order in .config/opencode/opencode.jsonc");
  process.exit(1);
}

// OpenCode resolves permissions by LAST matching rule, so ask rules must be
// emitted after all allows rather than relying on source group order.
const opencodeSection = (action) =>
  groups.flatMap((group) => {
    const rules = group.rules.filter((rule) => rule.action === action);
    if (rules.length === 0) return [];

    return [
      `      // ${group.comment} (${action})`,
      ...rules.map(
        (rule) =>
          `      ${JSON.stringify(rule.pattern)}: ${JSON.stringify(rule.action)},`,
      ),
    ];
  });

const opencodeLines = [...opencodeSection("allow"), ...opencodeSection("ask")];

if (opencodeLines.length > 0) {
  opencodeLines[opencodeLines.length - 1] = opencodeLines[opencodeLines.length - 1].replace(/,$/, "");
}

const opencodeOutput =
  opencodeText.slice(0, beginIndex + beginMarker.length) +
  "\n" +
  opencodeLines.join("\n") +
  "\n" +
  opencodeText.slice(endIndex);

let dirty = false;

for (const [filePath, output] of [
  [claudePath, claudeOutput],
  [opencodePath, opencodeOutput],
]) {
  if (readFileSync(filePath, "utf8") === output) {
    continue;
  }

  dirty = true;

  if (check) {
    console.error(`out of sync: ${filePath}`);
  } else {
    writeFileSync(filePath, output);
    console.log(`wrote ${filePath}`);
  }
}

process.exit(check && dirty ? 1 : 0);
