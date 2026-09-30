"""Repair SBX's generated Codex MCP fields inside the sandbox only."""

import pathlib
import re
import shutil
import tomllib

config = pathlib.Path('/home/agent/.codex/config.toml')
original = config.read_text()
before = tomllib.loads(original)
gateway = before.get('mcp_servers', {}).get('mcp-gateway', {})
if 'headers' in gateway and 'http_headers' in gateway:
    raise SystemExit('Both header fields exist; refusing to overwrite either.')

lines = []
in_gateway = False
for line in original.splitlines(keepends=True):
    section = line.strip()
    if section.startswith('['):
        in_gateway = section == '[mcp_servers.mcp-gateway]'
        if section == '[mcp_servers.mcp-gateway.headers]':
            line = line.replace('.headers]', '.http_headers]')
    elif in_gateway:
        if re.match(r'^\s*type\s*=', line):
            continue
        line = re.sub(r'^(\s*)headers(\s*=)', r'\1http_headers\2', line)
    lines.append(line)

updated = ''.join(lines)
expected = dict(gateway)
expected.pop('type', None)
if 'headers' in expected:
    expected['http_headers'] = expected.pop('headers')
after = tomllib.loads(updated)
assert after['mcp_servers']['mcp-gateway'] == expected
before['mcp_servers']['mcp-gateway'] = expected
assert before == after, 'Unexpected configuration change'
if updated != original:
    backup = config.with_name('config.toml.before-mcp-fix')
    if not backup.exists():
        shutil.copy2(config, backup)
    config.write_text(updated)
    print('Corrected MCP gateway fields; preserved all header values.')
else:
    print('MCP gateway configuration already uses supported fields.')
