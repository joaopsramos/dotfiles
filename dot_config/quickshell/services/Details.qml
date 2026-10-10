pragma Singleton

import Quickshell

Singleton {
    readonly property SnapshotPoller system: SnapshotPoller {
        script: "bar/system/system.py"
        interval: 2000
        snapshot: ({
                cpu: {},
                memory: {},
                gpus: []
            })
    }
    readonly property SnapshotPoller storage: SnapshotPoller {
        script: "bar/storage/storage.py"
        interval: 5000
        snapshot: ({
                root: {},
                volumes: [],
                devices: []
            })
    }
    readonly property SnapshotPoller battery: SnapshotPoller {
        script: "bar/battery/battery.py"
        interval: 10000
        snapshot: ({
                battery: {},
                profiles: [],
                activeProfile: ""
            })
    }
}
