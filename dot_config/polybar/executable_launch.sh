#!/usr/bin/env bash

# Terminate already running bar instances
# If all your bars have ipc enabled, you can use 
polybar-msg cmd quit
# Otherwise you can use the nuclear option:
# killall -q polybar

# Launch bar
echo "---" | tee -a /tmp/polybar1.log
# polybar bar1 2>&1 | tee -a /tmp/polybar1.log & disown

for m in $(polybar --list-monitors | cut -d":" -f1); do
  MONITOR=$m polybar --reload bar1 &
done

echo "Bars launched..."
