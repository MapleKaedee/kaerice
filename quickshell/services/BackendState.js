.pragma library

// topics after one line from kaericed, or null when the line is not an object
function merge(topics, line) {
    let message;
    try { message = JSON.parse(line); } catch (e) { return null; }
    if (message === null || typeof message !== "object" || Array.isArray(message)) return null;
    return Object.assign({}, topics, message);
}
