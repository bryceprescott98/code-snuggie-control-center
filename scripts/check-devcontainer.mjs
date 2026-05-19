#!/usr/bin/env node
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const args = process.argv.slice(2);
const requireRestrictedEgress =
  args.includes("--require-restricted-egress") ||
  process.env.CODE_SNUGGIE_REQUIRE_RESTRICTED_EGRESS === "1";
const input = args.find((arg) => !arg.startsWith("--")) ?? ".devcontainer/devcontainer.json";
const path = input.startsWith("/") ? input : join(root, input);
const devcontainerDir = dirname(path);

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

function asArray(value) {
  if (Array.isArray(value)) return value;
  if (typeof value === "string") return [value];
  return [];
}

function readText(file) {
  try {
    return readFileSync(file, "utf8");
  } catch (error) {
    fail(`Unable to read ${file}: ${error.message}`);
    return "";
  }
}

function requireText(text, needle, context) {
  if (!text.includes(needle)) {
    fail(`${context} must include ${needle}`);
  }
}

function stripComments(text) {
  return text
    .split(/\r?\n/)
    .map((line) => line.replace(/#.*/, ""))
    .join("\n");
}

function parseSquidAcls(text) {
  const acls = new Map();
  const lines = stripComments(text).split(/\r?\n/);

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index].trim();
    const match = line.match(/^acl\s+(\S+)\s+dstdomain\s*(.*)$/);
    if (!match) continue;

    const [, name, firstRest] = match;
    const domains = [];
    let rest = firstRest.trim();

    while (true) {
      const continued = rest.endsWith("\\");
      const fragment = continued ? rest.slice(0, -1).trim() : rest;
      domains.push(...fragment.split(/\s+/).filter(Boolean));
      if (!continued) break;
      index += 1;
      rest = (lines[index] ?? "").trim();
    }

    acls.set(name, domains);
  }

  return acls;
}

function domainConflictsWithinAcl(domains) {
  const conflicts = [];
  const normalized = domains.map((domain) => domain.toLowerCase());

  for (let leftIndex = 0; leftIndex < normalized.length; leftIndex += 1) {
    for (let rightIndex = leftIndex + 1; rightIndex < normalized.length; rightIndex += 1) {
      const left = normalized[leftIndex];
      const right = normalized[rightIndex];
      const leftBase = left.startsWith(".") ? left.slice(1) : left;
      const rightBase = right.startsWith(".") ? right.slice(1) : right;
      const hasWildcardParent = left.startsWith(".") || right.startsWith(".");

      if (hasWildcardParent && (
        leftBase === rightBase ||
        leftBase.endsWith(`.${rightBase}`) ||
        rightBase.endsWith(`.${leftBase}`)
      )) {
        conflicts.push(`${domains[leftIndex]} <-> ${domains[rightIndex]}`);
      }
    }
  }

  return conflicts;
}

function composeServiceBlock(text, serviceName) {
  const lines = text.split(/\r?\n/);
  const servicePattern = new RegExp(`^(\\s*)${serviceName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}:\\s*$`);
  let start = -1;
  let indent = 0;

  for (let index = 0; index < lines.length; index += 1) {
    const match = lines[index].match(servicePattern);
    if (match) {
      start = index;
      indent = match[1].length;
      break;
    }
  }

  if (start === -1) return "";

  const block = [lines[start]];
  for (let index = start + 1; index < lines.length; index += 1) {
    const line = lines[index];
    const trimmed = line.trim();
    if (trimmed && line.search(/\S/) <= indent) break;
    block.push(line);
  }
  return block.join("\n");
}

const config = readJson(path);
const extensions = config.customizations?.vscode?.extensions ?? [];
const strings = collectStrings(config);
const warnings = [];
const allowedCodespacesWritePermissions = new Set(["contents", "pull_requests"]);
const requiredSquidDomains = [
  "github.com",
  "api.github.com",
  ".githubusercontent.com",
  "registry.npmjs.org",
  "pypi.org",
  "files.pythonhosted.org",
  "marketplace.visualstudio.com",
  "update.code.visualstudio.com",
  "api.openai.com",
  "chatgpt.com",
  ".chatgpt.com",
  "auth.openai.com",
  ".auth.openai.com",
  ".openai.com",
  ".oaiusercontent.com",
];
const configuredDockerfiles = asArray(config.build?.dockerfile);
const devcontainerSupportFiles = [
  ...configuredDockerfiles.map((dockerfile) =>
    dockerfile.startsWith("/") ? dockerfile : join(devcontainerDir, dockerfile)
  ),
  join(devcontainerDir, "Dockerfile"),
  ...asArray(config.dockerComposeFile).map((composeFile) =>
    composeFile.startsWith("/") ? composeFile : join(devcontainerDir, composeFile)
  ),
].filter((file, index, files) => files.indexOf(file) === index);
const devcontainerToolText = [
  JSON.stringify(config),
  ...devcontainerSupportFiles
    .filter((file) => existsSync(file))
    .map((file) => readText(file)),
].join("\n").toLowerCase();

for (const tool of ["ripgrep", "jq"]) {
  if (!new RegExp(`\\b${tool}\\b`).test(devcontainerToolText)) {
    fail(`Devcontainer must explicitly install ${tool} for Codex navigation.`);
  }
}

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

if (strings.some((value) => /ubuntu\/squid:(latest|edge)\b/.test(value))) {
  fail("Squid proxy image must use a pinned version tag, not latest or edge.");
}

const mountText = strings.join("\n");
if (mountText.includes("/var/run/docker.sock")) {
  warnings.push("Docker socket mount found; prefer Docker-in-Docker unless the job documents why host Docker is required.");
}

if (/\.ssh|\.gnupg|\.aws|\.config\/gh|GITHUB_TOKEN|OPENAI_API_KEY/.test(mountText)) {
  fail("Potential host credentials or secret values are referenced in committed devcontainer config.");
}

const repositoryAccess = config.customizations?.codespaces?.repositories;
if (repositoryAccess && typeof repositoryAccess === "object" && !Array.isArray(repositoryAccess)) {
  for (const [repository, access] of Object.entries(repositoryAccess)) {
    if (!/^[^/\s]+\/[^/\s]+$/.test(repository)) {
      fail(`Codespaces repository access must use an exact owner/repo name: ${repository}`);
    }

    const permissions = access?.permissions;
    if (!permissions || typeof permissions !== "object" || Array.isArray(permissions)) {
      fail(`Codespaces repository access for ${repository} must declare explicit permissions.`);
      continue;
    }

    for (const [permission, level] of Object.entries(permissions)) {
      if (level === "write" && !allowedCodespacesWritePermissions.has(permission)) {
        fail(`Overbroad Codespaces repository permission for ${repository}: ${permission}: write`);
      }
    }
  }
}

if (Array.isArray(config.forwardPorts)) {
  for (const port of config.forwardPorts) {
    if (port === "0.0.0.0" || port === "*" || port === "1-65535") {
      fail(`Overbroad forwarded port entry: ${port}`);
    }
  }
}

const portAttributes = config.portsAttributes;
if (portAttributes && typeof portAttributes === "object" && !Array.isArray(portAttributes)) {
  for (const [port, attributes] of Object.entries(portAttributes)) {
    if (attributes?.onAutoForward === "openBrowser") {
      warnings.push(`Port ${port} auto-opens a browser; prefer onAutoForward: "notify" unless the user explicitly requested automatic launch.`);
    }
  }
}

if (requireRestrictedEgress) {
  const composeFiles = asArray(config.dockerComposeFile);
  if (composeFiles.length === 0 || !config.service) {
    fail("Restricted egress requires dockerComposeFile plus service in devcontainer.json.");
  }

  const composeTexts = composeFiles.map((composeFile) => {
    const composePath = composeFile.startsWith("/") ? composeFile : join(devcontainerDir, composeFile);
    if (!existsSync(composePath)) {
      fail(`Restricted egress compose file is missing: ${composePath}`);
      return "";
    }
    return readText(composePath);
  });
  const composeText = composeTexts.join("\n");
  const devServiceBlock = composeServiceBlock(composeText, config.service);
  const proxyServiceBlock = composeServiceBlock(composeText, "egress-proxy");

  requireText(composeText, "egress-proxy:", "Restricted egress compose file");
  requireText(composeText, "internal: true", "Restricted egress compose file");
  requireText(composeText, "/etc/squid/squid.conf:ro", "Restricted egress compose file");

  if (!devServiceBlock) {
    fail(`Restricted egress compose file must define the devcontainer service: ${config.service}`);
  } else {
    requireText(devServiceBlock, "HTTP_PROXY: http://egress-proxy:3128", "Restricted egress devcontainer service");
    requireText(devServiceBlock, "HTTPS_PROXY: http://egress-proxy:3128", "Restricted egress devcontainer service");
    requireText(devServiceBlock, "devnet", "Restricted egress devcontainer service");
    if (/\boutbound\b/.test(devServiceBlock)) {
      fail("Restricted egress devcontainer service must not join the outbound network directly.");
    }
  }

  if (!proxyServiceBlock) {
    fail("Restricted egress compose file must define an egress-proxy service.");
  } else {
    requireText(proxyServiceBlock, "devnet", "Restricted egress proxy service");
    requireText(proxyServiceBlock, "outbound", "Restricted egress proxy service");
    requireText(proxyServiceBlock, "squid", "Restricted egress proxy service");
    requireText(proxyServiceBlock, "-N", "Restricted egress proxy service");
    requireText(proxyServiceBlock, "/etc/squid/squid.conf", "Restricted egress proxy service");
  }

  if (!/image:\s*ubuntu\/squid:[^\s#]+/.test(composeText)) {
    fail("Restricted egress compose file must use the ubuntu/squid proxy image with a pinned tag.");
  }

  if (/image:\s*ubuntu\/squid:(latest|edge)\b/.test(composeText)) {
    fail("Restricted egress compose file must not use ubuntu/squid:latest or ubuntu/squid:edge.");
  }

  const squidPath = join(devcontainerDir, "squid.conf");
  if (!existsSync(squidPath)) {
    fail(`Restricted egress requires a Squid allowlist file: ${squidPath}`);
  } else {
    const squidText = readText(squidPath);
    requireText(squidText, "acl allowed_domains dstdomain", "Squid allowlist");
    requireText(squidText, "http_port 3128", "Squid allowlist");
    requireText(squidText, "http_access allow allowed_domains", "Squid allowlist");
    requireText(squidText, "http_access deny all", "Squid allowlist");

    for (const domain of requiredSquidDomains) {
      requireText(squidText, domain, "Squid allowlist");
    }

    const squidAcls = parseSquidAcls(squidText);
    for (const [name, domains] of squidAcls.entries()) {
      const conflicts = domainConflictsWithinAcl(domains);
      if (conflicts.length > 0) {
        fail(`Squid ACL ${name} has parent/subdomain conflicts: ${conflicts.join(", ")}`);
      }
    }
  }
}

for (const warning of warnings) {
  console.warn(`Warning: ${warning}`);
}

if (!process.exitCode) {
  console.log(`Devcontainer static checks passed: ${input}`);
}
