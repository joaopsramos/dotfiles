#!/bin/bash

ASTRO="alsa_output.usb-Astro_Gaming_Astro_MixAmp_Pro-00.stereo-game"
SPEAKERS="alsa_output.pci-0000_09_00.4.analog-stereo"

CURRENT_SINK=$(pactl get-default-sink)

if [[ $CURRENT_SINK == $SPEAKERS  ]]; then
    SINK=$ASTRO
    ACTION="#sound-output.hook.0"
elif [[ $CURRENT_SINK == $ASTRO ]]; then
    SINK=$SPEAKERS
    ACTION="#sound-output.hook.1"
fi

pactl set-default-sink $SINK
polybar-msg action $ACTION
