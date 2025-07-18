#!/bin/sh

SIGNAL=3

SINKS=$(pactl list short sinks | awk -v OFS='\t' '{print $2}')
CURRENT_SINK=$(pactl get-default-sink)

SINK_ICONS=("Astro:" "bluez:")
DEFAULT_ICON="蓼"

CURRENT_SINK_IDX=0
CURRENT_SINK_ICON=$DEFAULT_ICON
FOUND_CURRENT_SINK=""

for sink_data in ${SINK_ICONS[@]}; do
  IFS=':' read -r sink_alias sink_icon <<< $sink_data
  if [[ "$CURRENT_SINK" == *"$sink_alias"* ]]; then
    CURRENT_SINK_ICON=$sink_icon
    FOUND_CURRENT_SINK=true
    break 2
  fi
  CURRENT_SINK_IDX=$((CURRENT_SINK_IDX + 1))
done

NEXT_SINK_ICON=$DEFAULT_ICON
NEXT_SINK=$(grep -Ev "$(echo ${SINK_ICONS[@]}|tr ":" "|"|tr " " "|")" <<< "$SINKS" | head -n 1)
# Current sink is the default
if [[ -z $FOUND_CURRENT_SINK ]]; then
  for sink_data in ${SINK_ICONS[@]}; do
    while IFS= read -r available_sink; do

      IFS=':' read -r sink_alias sink_icon <<< $sink_data
      if [[ "$available_sink" == *"$sink_alias"* ]]; then
        NEXT_SINK=$available_sink
        NEXT_SINK_ICON=$sink_icon
        break 2
      fi
    done <<< "$SINKS"
  done
# Current sink is other than the default and next sink is not the default
elif [[ $((CURRENT_SINK_IDX + 1)) < "${#SINK_ICONS[@]}" ]]; then
  IFS=':' read -r next_sink_alias next_sink_icon <<< ${SINK_ICONS[$((CURRENT_SINK_IDX + 1))]}

  while IFS= read -r available_sink; do
    if [[ $available_sink == *"$next_sink_alias"* ]]; then
      NEXT_SINK_ICON=$next_sink_icon
      NEXT_SINK=$available_sink
    fi
  done <<< "$SINKS"
fi

if [[ "$1" == "--icon" ]]; then
  echo $CURRENT_SINK_ICON
  exit 0
fi

if [[ "$CURRENT_SINK" == "$NEXT_SINK" ]]; then
  notify-send -u normal "   Sound control: No other available sinks!"
fi

pactl set-default-sink $NEXT_SINK
pkill -RTMIN+$SIGNAL waybar
