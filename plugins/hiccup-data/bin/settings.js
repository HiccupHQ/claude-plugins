// hiccup-data: allows the read-only hx commands in Claude Code and removes what the Mongo MCP server left (0.12.0 and older).
// JavaScript for Automation (osascript -l JavaScript), because every Mac has it and not every Mac has node.
// Argument: the home folder. A file that does not parse is left as it is.
ObjC.import('Foundation');

const OLD_TOOLS = 'mcp__plugin_hiccup-data_hiccup-data';
const HX_READS = ['describe', 'search', 'aggregate'];
const HX_RULES = HX_READS.flatMap(command => ['', '--env dev ', '--env prod '].map(env => `Bash(hx ${env}${command}:*)`));

function read(path) {
  const text = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  if (text.isNil()) return { found: false, value: {} };
  try { return { found: true, value: JSON.parse(text.js) }; } catch (error) { return { found: true, value: null }; }
}

function write(path, value) {
  $.NSFileManager.defaultManager.createDirectoryAtPathWithIntermediateDirectoriesAttributesError($(path).stringByDeletingLastPathComponent, true, $(), null);
  $(JSON.stringify(value, null, 2)).writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
}

function allowHx(path) {
  const settings = read(path);
  if (settings.value === null) return;
  const permissions = settings.value.permissions = settings.value.permissions || {};
  const before = permissions.allow || [];
  const kept = before.filter(rule => !rule.startsWith(OLD_TOOLS));
  const after = kept.concat(HX_RULES.filter(rule => !kept.includes(rule)));
  if (JSON.stringify(after) === JSON.stringify(before)) return;
  permissions.allow = after;
  write(path, settings.value);
}

function removeDesktopServer(path) {
  const config = read(path);
  if (!config.found || config.value === null || !config.value.mcpServers || !config.value.mcpServers['hiccup-data']) return;
  delete config.value.mcpServers['hiccup-data'];
  write(path, config.value);
  console.log('hiccup-data: removed the old data server from the Claude desktop app. Use Claude Code for Hiccup data.');
}

function run(argv) {
  const home = argv[0];
  allowHx(`${home}/.claude/settings.json`);
  removeDesktopServer(`${home}/Library/Application Support/Claude/claude_desktop_config.json`);
}
