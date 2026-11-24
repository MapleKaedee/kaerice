import QtQuick
import qs.services
import qs.components.base

// Output and input device (WirePlumber remembers them), volume step, visualizer.
Column {
    spacing: 12

    SettingRow { label: "Output" }
    DeviceList { nodes: Audio.sinks; current: Audio.sink; glyph: 0xf028; onPicked: node => Audio.useSink(node) } // speaker
    Item { width: 1; height: 4 }
    SettingRow { label: "Input" }
    DeviceList { nodes: Audio.sources; current: Audio.source; glyph: 0xf130; onPicked: node => Audio.useSource(node) } // microphone
    Item { width: 1; height: 4 }

    SettingRow {
        label: "Volume step"
        hint: "Per key press or scroll"
        Stepper {
            values: [1, 2, 3, 4, 5, 10]
            value: Settings.get("sound.volumeStep")
            format: v => v + "%"
            onPicked: v => Settings.set("sound.volumeStep", v)
        }
    }
    SettingRow {
        label: "Visualizer"
        hint: "Spectrum behind the bar while music plays"
        Choice {
            value: Settings.get("sound.visualizer")
            onPicked: v => Settings.set("sound.visualizer", v)
        }
    }
}
