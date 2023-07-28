#!/bin/bash
if [ "$(playerctl status >>/dev/null 2>&1; echo $?)" == "1" ]
then
	echo "Player: Not Active"
	exit 0
fi
if [ "$(playerctl status)" == "Playing" ]
then
	title=$(playerctl metadata xesam:title)
	artist=$(playerctl metadata xesam:artist)
	echo "Playing:  $title | $artist"
else
	echo "Music Stopped"
fi

if [ ! -z "$1" ]; then
	playerctl play-pause
fi

if [ "$(playerctl status)" == "Playing" ]
then
	polybar-msg hook playpause 2
fi	
if [ "$(playerctl status)" == "Paused" ]
then
	polybar-msg hook playpause 3
fi
