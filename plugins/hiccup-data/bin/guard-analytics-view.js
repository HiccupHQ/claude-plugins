// PreToolUse guard for the hiccup-data tools. Refuses a query on a *Analytics view that would read
// the whole source collection. Each view starts with a $set that removes personal data; Mongo puts the
// query's stages after it, so a sort or a filter on a field the view rewrites cannot use an index.
// Measured on 2026-10-20: OrdersAnalytics sorted on createdOn with no filter read 1,601,934 orders in
// 118 s; the same query with a createdOn window read 342 orders in 4 ms.
// A filter on a field the view does not rewrite (createdOn, orderId, status, salesChannel) is pushed in
// front of the $set and uses the source collection's indexes.

const viewRewrittenFields = [
  'customer', 'billingAddress', 'shippingAddress', 'senderAddress', 'fromOrgBillingAddress',
  'recipient', 'billing',
];

const advice =
  'Add a date window, for example {createdOn: {$gte: <date>}}, or an id filter (orderId, uid). '
  + 'Ask for the latest order with a window of the last day, and widen it only when it returns nothing. '
  + 'A filter on customer or address fields cannot use an index: combine it with a createdOn window.';

function isAnalyticsView(collection) {
  return typeof collection === 'string' && collection.endsWith('Analytics');
}

function topLevelField(key) {
  return key.split('.')[0];
}

// The field names a filter tests, through $and, $or and $nor.
function filterFields(filter) {
  if (!filter || typeof filter !== 'object') return [];
  const fields = [];
  for (const [key, value] of Object.entries(filter)) {
    if (key === '$and' || key === '$or' || key === '$nor') {
      for (const part of Array.isArray(value) ? value : []) fields.push(...filterFields(part));
    } else if (!key.startsWith('$')) {
      fields.push(topLevelField(key));
    }
  }
  return fields;
}

// Why the filter cannot narrow the read, or null when it can.
function unboundedReason(filter) {
  const fields = filterFields(filter);
  if (fields.length === 0) return 'the query has no filter, so it reads every document of the source collection';
  if (fields.every((field) => viewRewrittenFields.includes(field))) {
    return `the filter tests only ${[...new Set(fields)].join(', ')}, which the view rewrites, so no index can serve it`;
  }
  return null;
}

// An aggregation is bounded when a $match comes before any stage other than $sort and $match.
function pipelineFilter(pipeline) {
  const merged = {};
  for (const stage of Array.isArray(pipeline) ? pipeline : []) {
    const name = Object.keys(stage || {})[0];
    if (name === '$match') Object.assign(merged, stage.$match);
    else if (name !== '$sort') break;
  }
  return merged;
}

function reasonFor(toolName, input) {
  const method = toolName.split('__').pop();
  if (method === 'find') return unboundedReason(input.filter);
  if (method === 'count') return unboundedReason(input.query);
  if (method === 'aggregate') return unboundedReason(pipelineFilter(input.pipeline));
  if (method === 'export') {
    for (const target of Array.isArray(input.exportTarget) ? input.exportTarget : []) {
      const args = target.arguments || {};
      const reason = target.name === 'aggregate'
        ? unboundedReason(pipelineFilter(args.pipeline))
        : unboundedReason(args.filter);
      if (reason) return reason;
    }
  }
  return null;
}

let raw = '';
process.stdin.on('data', (chunk) => { raw += chunk; });
process.stdin.on('end', () => {
  let event;
  try { event = JSON.parse(raw); } catch { process.exit(0); }
  const input = event.tool_input || {};
  if (!isAnalyticsView(input.collection)) process.exit(0);
  const reason = reasonFor(event.tool_name || '', input);
  if (!reason) process.exit(0);
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason:
        `${input.collection} is a view: ${reason}. Such a query on OrdersAnalytics took 118 s on 2026-10-20. ${advice}`,
    },
  }));
});
