// hiccup-data: preloaded into the MongoDB MCP server (node --import) by mongodb-mcp.sh. Ends the server with its client.
// When the client leaves while the server starts, the server's first answer fails with EPIPE, the MCP SDK then pauses
// stdin, and the server's own "end of stdin" shutdown never runs: it ran for ever. So the server ends here when its
// parent dies (it is moved to another parent, usually PID 1), when stdin ends, or when stdout fails.
const parent = process.ppid;
let ending = false;
const end = () => {
  if (ending) return;
  ending = true;
  setTimeout(() => process.exit(0), 3000).unref(); // the server's own shutdown gets 3 s to flush its log
  process.kill(process.pid, 'SIGTERM');
};
setInterval(() => { if (process.ppid !== parent) end(); }, 1000).unref();
process.stdin.once('end', end);
process.stdout.on('error', end);
