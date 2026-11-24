import Quickshell.Wayland
import qs.config
import qs.services

// ext-session-lock: one LockSurface per screen while Lock.locked.
// reloadableId keeps the lock across a config reload.
WlSessionLock {
    id: lock
    reloadableId: "kaerice-lock"
    locked: Lock.locked
    onSecureStateChanged: Lock.secure = lock.secure

    WlSessionLockSurface {
        color: Theme.ink
        LockSurface {}
    }
}
