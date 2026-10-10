pragma Singleton

import Quickshell

Singleton {
    readonly property date date: clock.date
    readonly property int year: date.getFullYear()
    readonly property int month: date.getMonth()
    readonly property int day: date.getDate()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
