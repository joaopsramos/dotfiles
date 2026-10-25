//@ pragma UseQApplication
//@ pragma Env QT_QPA_PLATFORMTHEME = gtk3

import Quickshell
import qs.bar
import qs.notifications
import qs.session
import qs.overlays
import qs.downloads
import qs.pomodoro

Scope {
    Bar { notifications: notifications }
    Notifications { id: notifications }
    PowerMenu {}
    Overlays {}
    Downloads {}
    Pomodoro {}
}
