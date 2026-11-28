#!/bin/sh
# Started by the greeter's Mango (mango.conf). The user "greeter" cannot read the home of who logs in:
# the theme comes from /var/lib/kaerice-greeter (greeter-sync.sh), qs keeps its own state in /var/cache/kaerice-greeter.
dir=$(dirname "$(readlink -f "$0")")
export XDG_CONFIG_HOME=/var/lib/kaerice-greeter
export XDG_STATE_HOME=/var/cache/kaerice-greeter XDG_CACHE_HOME=/var/cache/kaerice-greeter
# nobody is logged in to answer a crash dialog
export QS_DISABLE_CRASH_HANDLER=1 MALLOC_CONF=narenas:1

qs -p "$dir/quickshell/greeter.qml"

# also after a crash: greetd starts the greeter again only once this Mango is gone
mmsg dispatch quit
