.pragma library

// the answer to "session.check"
function warnings(code, data) {
    if (code !== "" || typeof data?.packages !== "boolean" || typeof data.downloads !== "boolean")
        return ["Could not check for package updates or downloads."];
    return [
        data.packages ? "A package manager is running: stopping now can break the update." : "",
        data.downloads ? "Downloads are in progress." : ""
    ].filter(w => w);
}
