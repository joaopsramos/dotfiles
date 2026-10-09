//@ pragma UseQApplication
//@ pragma Env QT_QPA_PLATFORMTHEME = gtk3

import Quickshell
import qs.bar
import qs.notifications
import qs.session

Scope {
    Bar {}
    Notifications {}
    PowerMenu {}
}
