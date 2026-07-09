pragma Singleton

import QtQuick

QtObject {
    // ===== Base =====
    readonly property color rosewater: "#f4dbd6"
    readonly property color flamingo: "#f0c6c6"
    readonly property color pink: "#f5bde6"
    readonly property color mauve: "#c6a0f6"
    readonly property color red: "#ed8796"
    readonly property color maroon: "#ee99a0"
    readonly property color peach: "#f5a97f"
    readonly property color yellow: "#eed49f"
    readonly property color green: "#a6da95"
    readonly property color teal: "#8bd5ca"
    readonly property color sky: "#91d7e3"
    readonly property color sapphire: "#7dc4e4"
    readonly property color blue: "#8aadf4"
    readonly property color lavender: "#b7bdf8"
    readonly property color transparent: "transparent"

    // ===== Text =====
    readonly property color text: "#cad3f5"
    readonly property color subtext1: "#b8c0e0"
    readonly property color subtext0: "#a5adcb"

    // ===== Overlays =====
    readonly property color overlay2: "#939ab7"
    readonly property color overlay1: "#8087a2"
    readonly property color overlay0: "#6e738d"

    // ===== Surface =====
    readonly property color surface2: "#5b6078"
    readonly property color surface1: "#494d64"
    readonly property color surface0: "#363a4f"

    // ===== Background =====
    readonly property color base: "#24273a"
    readonly property color mantle: "#1e2030"
    readonly property color crust: "#181926"

    // ===== Semantic aliases =====
    readonly property color background: base
    readonly property color backgroundAlt: mantle
    readonly property color foreground: text
    readonly property color accent: blue
    readonly property color success: green
    readonly property color warning: yellow
    readonly property color error: red

    // ===== Sizing =====
    readonly property int radius: 8
    readonly property int borderWidth: 1
    readonly property int spacing: 8
    readonly property int padding: 10
    readonly property int barHeight: 36

    // ===== Font =====
    readonly property string fontFamily: "Hack Nerd Font"
    readonly property int fontSize: 13
}
