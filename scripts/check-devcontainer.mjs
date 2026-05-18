#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const input = process.argv[2] ?? ".devcontainer/devcontainer.json";
const path = input.startsWith("/") ? input : join(root, input);

function fail(message) {
  console.error(message);
  process.exitCode = 1;
}

function readJson(file) {
  try {
    return JSON.parse(readFileSync(file, "utf8"));
  } catch (error) {
    fail(`Unable to parse ${file}: ${error.message}`);
    return {};
  }
}

function collectStrings(value, output = []) {
  if (typeof value === "string") {
    output.push(value);
  } else if (Array.isArray(value)) {
    for (const item of value) collectStrings(item, output);
  } else if (value && typeof value === "object") {
    for (const item of Object.values(value)) collectStrings(item, output);
  }
  return output;
}

const config = readJson(path);
const extensions = config.customizations?.vscode?.extensions ?? [];
const strings = collectStrings(config);
const warnings = [];

if (!extensions.includes("OpenAI.chatgpt")) {
  fail("Missing required VS Code extension: OpenAI.chatgpt");
}

if (config.remoteUser === "root" || config.containerUser === "root") {
  fail("Container uses root as the interactive user without an inline justification.");
}

if (config.privileged === true) {
  fail("Devcontainer enables privileged mode.");
}

if (config.networkMode === "host" || strings.some((value) => value.includes("--network=host"))) {
  fail("Devcontainer uses host networking.");
}

const mountText = strings.join("\n");
if (mountText.includes("/var/run/docker.sock")) {
  warnings.push("Docker socket mount found; prefer Docker-in-Docker unless the job documents why host Docker is required.");
}

if (/\.ssh|\.gnupg|\.aws|\.config\/gh|GITHUB_TOKEN|OPENAI_API_KEY/.test(mountText)) {
  fail("Potential host credentials or secret values are referenced in committed devcontainer config.");
}

if (Array.isArray(config.forwardPorts)) {
  for (const port of config.forwardPorts) {
    if (port === "0.0.0.0" || port === "*" || port === "1-65535") {
      fail(`Overbroad forwarded port entry: ${port}`);
    }
  }
}

for (const warning of warnings) {
  console.warn(`Warning: ${warning}`);
}

if (!process.exitCode) {
  console.log(`Devcontainer static checks passed: ${input}`);
}
