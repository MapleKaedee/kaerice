.pragma library

// the object in one line from kaericed, or null
function parse(line) {
    let message;
    try { message = JSON.parse(line); } catch (e) { return null; }
    return message !== null && typeof message === "object" && !Array.isArray(message) ? message : null;
}

// to a call; everything else is a topic
function isAnswer(message) {
    return "id" in message;
}

// of an answer: "" is success
function code(message) {
    return message.ok ? "" : message.error || "Failed";
}

function merge(topics, message) {
    return Object.assign({}, topics, message);
}
