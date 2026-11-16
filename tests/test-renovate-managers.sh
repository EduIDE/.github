#!/usr/bin/env bash
# The regex custom managers in renovate-config.json, run against the lines they
# exist for. Renovate's own replace step is mimicked: every occurrence of
# currentValue inside the match becomes the new version. Extracted from the
# preset rather than restated, so the two cannot drift.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

node - "$ROOT/renovate-config.json" <<'EOF'
const fs = require('fs');
const managers = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')).customManagers;
let failed = 0;
const ok = (m) => console.log(`  PASS  ${m}`);
const bad = (m) => { console.log(`  FAIL  ${m}`); failed = 1; };

function managerFor(file) {
  return managers.find((m) => m.managerFilePatterns.some((p) => new RegExp(p.slice(1, -1)).test(file)));
}

// Renovate's matchStrings use RE2 syntax; these patterns are also valid JS regexes.
function bump(file, line, newVersion) {
  const m = managerFor(file);
  if (!m) return { error: 'no manager for file' };
  const match = new RegExp(m.matchStrings[0]).exec(line);
  if (!match) return { error: 'no match' };
  const g = match.groups;
  return { depName: g.depName, currentValue: g.currentValue, datasource: g.datasource || m.datasourceTemplate,
           result: line.replace(match[0], match[0].split(g.currentValue).join(newVersion)) };
}

const cases = [
  {
    file: 'images/base-ide/package.json.patch',
    line: '"data-bridge": "https://github.com/eduide/eduide-data-bridge/releases/download/v0.0.17/data-bridge-0.0.17.vsix",',
    version: '0.0.18',
    depName: 'eduide/eduide-data-bridge', currentValue: '0.0.17',
    want: '"data-bridge": "https://github.com/eduide/eduide-data-bridge/releases/download/v0.0.18/data-bridge-0.0.18.vsix",',
  },
  {
    file: 'images/base-ide/package.json.patch',
    line: '"theia-cloud-monitor": "https://github.com/EduIDE/EduIDE-Cloud/releases/download/v1.4.0/theia-cloud-monitor-1.4.0.vsix",',
    version: '2.0.0',
    depName: 'EduIDE/EduIDE-Cloud', currentValue: '1.4.0',
    want: '"theia-cloud-monitor": "https://github.com/EduIDE/EduIDE-Cloud/releases/download/v2.0.0/theia-cloud-monitor-2.0.0.vsix",',
  },
  {
    file: 'package.json',
    line: '"vscode-builtin-extensions": "https://github.com/eclipse-theia/vscode-builtin-extensions/releases/download/1.104.0/vscode-builtin-extensions-1.104.0.tar.gz",',
    version: '1.108.2',
    depName: 'eclipse-theia/vscode-builtin-extensions', currentValue: '1.104.0',
    want: '"vscode-builtin-extensions": "https://github.com/eclipse-theia/vscode-builtin-extensions/releases/download/1.108.2/vscode-builtin-extensions-1.108.2.tar.gz",',
  },
  {
    file: 'charts/eduide/values.yaml',
    line: '  cloud: "1.3.0" # renovate: datasource=github-releases depName=EduIDE/EduIDE-Cloud',
    version: '1.4.0',
    depName: 'EduIDE/EduIDE-Cloud', currentValue: '1.3.0', datasource: 'github-releases',
    want: '  cloud: "1.4.0" # renovate: datasource=github-releases depName=EduIDE/EduIDE-Cloud',
  },
];

console.log('=== bumps produce a consistent line ===');
for (const c of cases) {
  const r = bump(c.file, c.line, c.version);
  const label = `${c.file}: ${c.depName}`;
  if (r.error) { bad(`${label}: ${r.error}`); continue; }
  if (r.depName !== c.depName) bad(`${label}: depName ${r.depName}`);
  else if (r.currentValue !== c.currentValue) bad(`${label}: currentValue ${r.currentValue}`);
  else if (c.datasource && r.datasource !== c.datasource) bad(`${label}: datasource ${r.datasource}`);
  else if (r.result !== c.want) bad(`${label}: got ${r.result}`);
  else ok(label);
}

console.log('\n=== must not match ===');
for (const [file, line] of [
  ['charts/eduide/values.yaml', '  cloud: "1.3.0"'],
  ['charts/eduide/values.yaml', '  # renovate: datasource=github-releases depName=EduIDE/EduIDE-Cloud'],
  // Renovate matches against the whole file, so the annotation must not reach back to the previous line.
  ['charts/eduide/values.yaml', '  bridge: "0.0.17"\n  # renovate: datasource=github-releases depName=EduIDE/EduIDE-Cloud\n  cloud: "1.3.0"'],
  ['images/base-ide/package.json.patch', '"scorpio": "https://open-vsx.org/api/aet-tum/artemis-scorpio/2.1.1/file/aet-tum.artemis-scorpio-2.1.1.vsix",'],
]) {
  const r = bump(file, line, '9.9.9');
  const label = JSON.stringify(line.trim());
  r.error ? ok(`${file}: ${label}`) : bad(`${file}: should not match ${label}`);
}

process.exit(failed);
EOF
