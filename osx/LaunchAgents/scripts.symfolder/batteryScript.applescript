
set Cap to (do shell script "ioreg -w0 -l | grep ExternalChargeCapable")
set curVolume to output volume of (get volume settings)
set shouldResumeiTunes to no
tell Cap to set {wallPower} to {last word of paragraph 1}

if wallPower = "Yes" or wallPower = "YES" then
	set Cap to (do shell script "ioreg -wO -l | grep Capacity")
	tell Cap to set {Available, Max} to {last word of paragraph 2, last word of paragraph 1}
	set Pct to round (100 * Available / Max)
	
	if Pct ³ 99 then
		tell application "System Events"
			set iTunesRunning to count (every process whose name is "iTunes")
			
			if iTunesRunning > 0 then
				tell application "iTunes"
					if player state is playing then
						pause
						
						tell Cap to set {shouldResumeiTunes} to {yes}
					end if
				end tell
			end if
		end tell
	end if
else
	set Cap to (do shell script "ioreg -wO -l | grep Capacity")
	tell Cap to set {Available, Max} to {last word of paragraph 2, last word of paragraph 1}
	set Pct to round (100 * Available / Max)
	
	if Pct ² 30 then
		tell application "System Events"
			set iTunesRunning to count (every process whose name is "iTunes")
			
			if iTunesRunning > 0 then
				tell application "iTunes"
					if player state is playing then
						pause
						
						tell Cap to set {shouldResumeiTunes} to {yes}
					end if
				end tell
			end if
		end tell
		
		set volume 80
		do shell script "say -v \"Zarvox\" \"LOW BATTERY\" "
		if Pct ² 5 then
			beep 5
			do shell script "say -v \"Zarvox\" \"PLUG ME IN NOW!!\""
		end if
		set volume output volume curVolume
		
		if iTunesRunning > 0 and shouldResumeiTunes then
			tell application "iTunes"
				play
			end tell
		end if
	end if
end if