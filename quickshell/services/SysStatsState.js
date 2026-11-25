.pragma library

const GB = 1073741824;

// data: what "stats.read" gave back; undefined when it failed
function view(data) {
    const mem = data?.mem, disk = data?.disk;
    if (!(mem?.total > 0 && disk?.total > 0))
        return { mem: -1, memUsedGb: 0, memTotalGb: 0, disk: -1, diskUsedGb: 0, diskTotalGb: 0, uptime: 0 };
    return {
        mem: 1 - mem.available / mem.total,
        memUsedGb: (mem.total - mem.available) / GB,
        memTotalGb: mem.total / GB,
        disk: Math.ceil(100 * disk.used / (disk.used + disk.available)) / 100, // like df
        diskUsedGb: disk.used / GB,
        diskTotalGb: disk.total / GB,
        uptime: data.uptime
    };
}

// two samples of data.cpu to 0..1, or -1
function cpu(before, now) {
    const total = now?.total - before?.total;
    return total > 0 ? 1 - (now.idle - before.idle) / total : -1;
}
