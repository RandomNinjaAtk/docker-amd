#!/usr/bin/with-contenv bash
export XDG_CONFIG_HOME="/config/deemix/xdg"
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
agent="automated-music-downloader ( https://github.com/RandomNinjaAtk/docker-amd )"

Configuration () {
	processstartid="$(ps -A -o pid,cmd|grep "start.bash" | grep -v grep | head -n 1 | awk '{print $1}')"
	processdownloadid="$(ps -A -o pid,cmd|grep "download.bash" | grep -v grep | head -n 1 | awk '{print $1}')"
	echo "To kill script, use the following command:"
	echo "kill -9 $processstartid"
	echo "kill -9 $processdownloadid"
	echo ""
	echo ""
	sleep 2.
	echo "############################################ $TITLE"
	echo "############################################ SCRIPT VERSION 1.5.10"
	echo "############################################ DOCKER VERSION $VERSION"
	echo "############################################ CONFIGURATION VERIFICATION"
	error=0

	if [ "$AUTOSTART" == "true" ]; then
		echo "$TITLESHORT Script Autostart: ENABLED"
		if [ -z "$SCRIPTINTERVAL" ]; then
			echo "WARNING: $TITLESHORT Script Interval not set! Using default..."
			SCRIPTINTERVAL="15m"
		fi
		echo "$TITLESHORT Script Interval: $SCRIPTINTERVAL"
	else
		echo "$TITLESHORT Script Autostart: DISABLED"
	fi

	# Verify Lidarr Connectivity
	lidarrtest=$(curl -s "$LidarrUrl/api/v1/system/status?apikey=${LidarrAPIkey}" | jq -r ".version")
	if [ ! -z "$lidarrtest" ]; then
		if [ "$lidarrtest" != "null" ]; then
			echo "Lidarr Connection Valid, version: $lidarrtest"
		else
			echo "ERROR: Cannot communicate with Lidarr, most likely a...."
			echo "ERROR: Invalid API Key: $LidarrAPIkey"
			error=1
		fi
	else
		echo "ERROR: Cannot communicate with Lidarr, no response"
		echo "ERROR: URL: $LidarrUrl"
		echo "ERROR: API Key: $LidarrAPIkey"
		error=1
	fi
	
	if [ ! -z "$LIDARRREMOTEPATH" ]; then
		echo "Lidarr Remote Path Mapping: ENABLED ($LIDARRREMOTEPATH)"		
		remotepath="true"
	else
		remotepath="false"
	fi

	# Verify Musicbrainz DB Connectivity
	musicbrainzdbtest=$(curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/artist/f59c5520-5f46-4d2c-b2c4-822eabf53419?fmt=json")
	musicbrainzdbtestname=$(echo "${musicbrainzdbtest}"| jq -r '.name?')
	if [ "$musicbrainzdbtestname" != "Linkin Park" ]; then
		echo "ERROR: Cannot communicate with Musicbrainz"
		echo "ERROR: Expected Response \"Linkin Park\", received response \"$musicbrainzdbtestname\""
		echo "ERROR: URL might be Invalid: $MBRAINZMIRROR"
		echo "ERROR: Remote Mirror may be throttling connection..."
		echo "ERROR: Link used for testing: ${MBRAINZMIRROR}/ws/2/artist/f59c5520-5f46-4d2c-b2c4-822eabf53419?fmt=json"
		echo "ERROR: Please correct error, consider using official Musicbrainz URL: https://musicbrainz.org"
		error=1
	else
		echo "Musicbrainz Mirror Valid: $MBRAINZMIRROR"
		if echo "$MBRAINZMIRROR" | grep -i "musicbrainz.org" | read; then
			if [ "$MBRATELIMIT" != 1 ]; then
				MBRATELIMIT="1.5"
			fi
			echo "Musicbrainz Rate Limit: $MBRATELIMIT (Queries Per Second)"
		else
			echo "Musicbrainz Rate Limit: $MBRATELIMIT (Queries Per Second)"
			MBRATELIMIT="0$(echo $(( 100 * 1 / $MBRATELIMIT )) | sed 's/..$/.&/')"
		fi
	fi

	# verify downloads location
	if [ -d "/downloads-amd" ]; then
		DOWNLOADS="/downloads-amd"
		echo "Downloads Location: $DOWNLOADS/amd/dlclient"
		echo "Import Location: $DOWNLOADS/amd/import"
	else
		if [ -d "$DOWNLOADS" ]; then
			echo "DOWNLOADS Location: $DOWNLOADS"
		else
			echo "ERROR: DOWNLOADS setting invalid, currently set to: $DOWNLOADS"
			echo "ERROR: DOWNLOADS Expected Valid Setting: /your/path/to/music/downloads"
			error=1
		fi
	fi

	if [ ! -z "$ARL_TOKEN" ]; then
		echo "ARL Token: Configured"
		if [ -f "$XDG_CONFIG_HOME/deemix/.arl" ]; then
			rm "$XDG_CONFIG_HOME/deemix/.arl"
		fi
		 if [ ! -f "$XDG_CONFIG_HOME/deemix/.arl" ]; then
			echo -n "$ARL_TOKEN" > "$XDG_CONFIG_HOME/deemix/.arl"
		fi
	else
		echo "ERROR: ARL_TOKEN setting invalid, currently set to: $ARL_TOKEN"
		error=1
	fi

	

	if [ ! -z "$Concurrency" ]; then
		echo "Audio: Concurrency: $Concurrency"
		sed -i "s%queueConcurrency\"] = 1%queueConcurrency\"] = $Concurrency%g" "/config/scripts/dlclient.py"
	else
		echo "WARNING: Concurrency setting invalid, defaulting to: 1"
		Concurrency="1"
	fi
	
	if [ ! -z "$FORMAT" ]; then
		echo "Audio: Download Format: $FORMAT"
		if [ "$FORMAT" = "ALAC" ]; then
			quality="FLAC"
			options="-c:a alac -movflags faststart"
			extension="m4a"
			echo "Audio: Download File Bitrate: lossless"
		elif [ "$FORMAT" = "FLAC" ]; then
			quality="FLAC"
			extension="flac"
			echo "Audio: Download File Bitrate: lossless"
		elif [ "$FORMAT" = "OPUS" ]; then
			quality="FLAC"
			options="-acodec libopus -ab ${BITRATE}k -application audio -vbr off"
		    extension="opus"
			echo "Audio: Download File Bitrate: $BITRATE"
		elif [ "$FORMAT" = "AAC" ]; then
			quality="FLAC"
			options="-c:a libfdk_aac -b:a ${BITRATE}k -movflags faststart"
			extension="m4a"
			echo "Audio: Download File Bitrate: $BITRATE"
		elif [ "$FORMAT" = "MP3" ]; then
			if [ "$BITRATE" = "320" ]; then
				quality="320"
				extension="mp3"
				echo "Audio: Download File Bitrate: $BITRATE"
			elif [ "$BITRATE" = "128" ]; then
				quality="128"
				extension="mp3"
				echo "Audio: Download File Bitrate: $BITRATE"
			else
				quality="FLAC"
				options="-acodec libmp3lame -ab ${BITRATE}k"
				extension="mp3"
				echo "Audio: Download File Bitrate: $BITRATE"
			fi
		else
			echo "ERROR: \"$FORMAT\" Does not match a required setting, check for trailing space..."
			error=1
		fi
	else
		if [ "$quality" == "FLAC" ]; then
			echo "Audio: Download Quality: FLAC"
			echo "Audio: Download Bitrate: lossless"
		elif [ "$quality" == "320" ]; then
			echo "Audio: Download Quality: MP3"
			echo "Audio: Download Bitrate: 320k"
		elif [ "$quality" == "128" ]; then
			echo "Audio: Download Quality: MP3"
			echo "Audio: Download Bitrate: 128k"
		else
			echo "Audio: Download Quality: FLAC"
			echo "Audio: Download Bitrate: lossless"
			quality="FLAC"
		fi
	fi
	
	if [ "$DOWNLOADMODE" == "artist" ]; then
		echo "Audio: Dowload Mode: $DOWNLOADMODE (Archives all albums by artist)"
		wantit=$(curl -s --header "X-Api-Key:"${LidarrAPIkey} --request GET  "$LidarrUrl/api/v1/rootFolder")
		path=($(echo "${wantit}" | jq -r ".[].path"))
		for id in ${!path[@]}; do
			pathprocess=$(( $id + 1 ))
			folder="${path[$id]}"
			if [ ! -d "$folder" ]; then
				echo "ERROR: \"$folder\" Path not found, add missing volume that matches Lidarr"
				error=1
				break
			else
				continue
			fi
		done
		
		if [ "$NOTIFYPLEX" == "true" ]; then
			echo "Audio: Plex Library Notification: ENABLED"
			plexlibraries="$(curl -s "$PLEXURL/library/sections?X-Plex-Token=$PLEXTOKEN" | xq .)"
			for id in ${!path[@]}; do
				pathprocess=$(( $id + 1 ))
				folder="${path[$id]%?}"
				if echo "$plexlibraries" | grep "$folder" | read; then
					plexlibrarykey="$(echo "$plexlibraries" | jq -r ".MediaContainer.Directory[] | select(.\"@title\"==\"$PLEXLIBRARYNAME\") | .\"@key\"" | head -n 1)"
					if [ -z "$plexlibrarykey" ]; then
						echo "ERROR: No Plex Library found named \"$PLEXLIBRARYNAME\""
						error=1
					fi
				else
					echo "ERROR: No Plex Library found containg path \"$folder\""
					echo "ERROR: Add \"$folder\" as a folder to a Plex Music Library or Disable NOTIFYPLEX"
					error=1
				fi
			done
		else
			echo "Audio : Plex Library Notification: DISABLED"
		fi
	fi
	if [ ! -z "$requirequality" ]; then
		if [ "$requirequality" == "true" ]; then
			echo "Audio: Require Quality: ENABLED"
		else
			echo "Audio: Require Quality: DISABLED"
		fi
	else
		echo "WARNING: requirequality setting invalid, defaulting to: false"
		requirequality="false"
	fi
	
	if [ "$DOWNLOADMODE" == "wanted" ]; then
		echo "Audio: Dowload Mode: $DOWNLOADMODE (Processes monitored albums)"
		if [ "$LIST" == "both" ]; then
			echo "Audio: Wanted List Type: Both (missing & cutoff)"
		elif [ "$LIST" == "missing" ]; then
			echo "Audio: Wanted List Type: Missing"
		elif [ "$LIST" == "cutoff" ]; then
			echo "Audio: Wanted List Type: Cutoff"
		else
			echo "WARNING: LIST type not selected, using default..."
			echo "Audio: Wanted List Type: Missing"
			LIST="missing"
		fi

		if [ "$SearchType" == "both" ]; then
			echo "Audio: Search Type: Artist Searching & Backup Fuzzy Searching"
		elif [ "$SearchType" == "artist" ]; then
			echo "Audio: Search Type: Artist Searching Only (Exception: Fuzzy search only for Various Artists)"
		elif [ "$SearchType" == "fuzzy" ]; then
			echo "Audio: Search Type: Fuzzy Searching Only"
		else
			echo "Audio: Search Type: Artist Searching & Backup Fuzzy Searching"
			SearchType="both"
		fi
	
		if [ ! -z "$MatchDistance" ]; then
			echo "Audio: Match Distance: $MatchDistance"
		else
			echo "WARNING: MatchDistance not set, using default..."
			MatchDistance="10"
			echo "Audio: Match Distance: $MatchDistance"
		fi
		
	fi

	if [ ! -z "$replaygain" ]; then
		if [ "$replaygain" == "true" ]; then
			echo "Audio: Replaygain Tagging: ENABLED"
		else
			echo "Audio: Replaygain Tagging: DISABLED"
		fi
	else
		echo "WARNING: replaygain setting invalid, defaulting to: true"
		replaygain="true"
	fi

	if [ ! -z "$FilePermissions" ]; then
		echo "Audio: File Permissions: $FilePermissions"
	else
		echo "WARNING: FilePermissions not set, using default..."
		FilePermissions="666"
		echo "Audio: File Permissions: $FilePermissions"
	fi

	if [ ! -z "$FolderPermissions" ]; then
		echo "Audio: Folder Permissions: $FolderPermissions"
	else
		echo "WARNING: FolderPermissions not set, using default..."
		FolderPermissions="766"
		echo "Audio: Folder Permissions: $FolderPermissions"
	fi

	if [ $error = 1 ]; then
		echo "Please correct errors before attempting to run script again..."
		echo "Exiting..."
		exit 1
	fi
	amount=1000000000
	sleep 2.5
}

Conversion () {
	converttrackcount=$(find  "$DOWNLOADS"/amd/dlclient/ -name "*.flac" | wc -l)
	if [ "${FORMAT}" != "FLAC" ]; then
		if find "$DOWNLOADS"/amd/dlclient/ -name "*.flac" | read; then
			echo "$logheader :: CONVERSION :: Converting: $converttrackcount Tracks (Target Format: $FORMAT (${BITRATE}))"
			for fname in "$DOWNLOADS"/amd/dlclient/*.flac; do
				filename="$(basename "${fname%.flac}")"
				if [ "${FORMAT}" == "OPUS" ]; then
					if opusenc --bitrate $BITRATE --vbr "$fname" "${fname%.flac}.temp.$extension"; then
						converterror=0
					else
						converterror=1
					fi
				else
					if ffmpeg -loglevel warning -hide_banner -nostats -i "$fname" -n -vn $options "${fname%.flac}.temp.$extension"; then
						converterror=0
					else
						converterror=1
					fi
				fi
				if [ "$converterror" == "1" ]; then
					echo "$logheader :: CONVERSION :: ERROR :: Coversion Failed: $filename, performing cleanup..."
					rm "${fname%.flac}.temp.$extension"
					continue
				elif [ -f "${fname%.flac}.temp.$extension" ]; then
					rm "$fname"
					sleep 0.1
					mv "${fname%.flac}.temp.$extension" "${fname%.flac}.$extension"
					echo "$logheader :: CONVERSION :: $filename :: Converted!"
				fi
			done
		fi
	fi
}

DownloadQualityCheck () {

	if [ "$requirequality" == "true" ]; then
		echo "$logheader :: DOWNLOAD :: Checking for unwanted files"
		if [ "$quality" == "FLAC" ]; then
			if find "$DOWNLOADS"/amd/dlclient -iname "*.mp3" | read; then
				echo "$logheader :: DOWNLOAD :: Unwanted files found!"
				echo "$logheader :: DOWNLOAD :: Performing cleanup..."
				rm "$DOWNLOADS"/amd/dlclient/*
			fi
		else
			if find "$DOWNLOADS"/amd/dlclient -iname "*.flac" | read; then
				echo "$logheader :: DOWNLOAD :: Unwanted files found!"
				echo "$logheader :: DOWNLOAD :: Performing cleanup..."
				rm "$DOWNLOADS"/amd/dlclient/*
			fi
		fi
	fi

}

AddReplaygainTags () {
	if [ "$replaygain" == "true" ]; then
		echo "$logheader :: DOWNLOAD :: Adding Replaygain Tags using r128gain"
		r128gain -r -a "$DOWNLOADS/amd/dlclient"
	fi
}

LidarrList () {
	if [ -f "temp-lidarr-missing.json" ]; then
		rm "/config/scripts/temp-lidarr-missing.json"
	fi

	if [ -f "/config/scripts/temp-lidarr-cutoff.json" ]; then
		rm "/config/scripts/temp-lidarr-cutoff.json"
	fi

	if [ -f "/config/scripts/lidarr-monitored-list.json" ]; then
		rm "/config/scripts/lidarr-monitored-list.json"
	fi

	if [[ "$LIST" == "missing" || "$LIST" == "both" ]]; then
		echo "Downloading missing list..."
		curl --header "X-Api-Key:"${LidarrAPIkey} --request GET  "$LidarrUrl/api/v1/wanted/missing/?page=1&pagesize=${amount}&includeArtist=true&monitored=true&sortDir=desc&sortKey=releaseDate" -o "/config/scripts/temp-lidarr-missing.json"
		missingtotal=$(cat "/config/scripts/temp-lidarr-missing.json" | jq -r '.records | .[] | .id' | wc -l)
		echo "FINDING MISSING ALBUMS: ${missingtotal} Found"
	fi

	if [[ "$LIST" == "cutoff" || "$LIST" == "both" ]]; then
		echo "Downloading cutoff list..."
		curl --header "X-Api-Key:"${LidarrAPIkey} --request GET  "$LidarrUrl/api/v1/wanted/cutoff/?page=1&pagesize=${amount}&includeArtist=true&monitored=true&sortDir=desc&sortKey=releaseDate" -o "/config/scripts/temp-lidarr-cutoff.json"
		cuttofftotal=$(cat "/config/scripts/temp-lidarr-cutoff.json" | jq -r '.records | .[] | .id' | wc -l)
		echo "FINDING CUTOFF ALBUMS: ${cuttofftotal} Found"
	fi
	jq -s '.[]' /config/scripts/temp-lidarr-*.json > "/config/scripts/lidarr-monitored-list.json"
	missinglistalbumids=($(cat "/config/scripts/lidarr-monitored-list.json" | jq -r '.records | .[] | .id'))
	missinglisttotal=$(cat "/config/scripts/lidarr-monitored-list.json" | jq -r '.records | .[] | .id' | wc -l)
	if [ -f "/config/scripts/temp-lidarr-missing.json" ]; then
		rm "/config/scripts/temp-lidarr-missing.json"
	fi

	if [ -f "/config/scripts/temp-lidarr-cutoff.json" ]; then
		rm "/config/scripts/temp-lidarr-cutoff.json"
	fi

	if [ -f "/config/scripts/lidarr-monitored-list.json" ]; then
		rm "/config/scripts/lidarr-monitored-list.json"
	fi
}

ArtistAlbumList () {

	if [ ! -f /config/cache/artists/$artistid/checked ]; then
		albumcount="$(python3 /config/scripts/artist_discograpy.py "$artistid" | sort -u | wc -l)"
		if [ -d /config/cache/artists/$artistid/albums ]; then
			cachecount=$(ls /config/cache/artists/$artistid/albums/* | wc -l)
		else
			cachecount=0
		fi
		
		if [ $albumcount != $cachecount ]; then
			log "$logheader :: Searching for All Albums...."
			log "$logheader :: $albumcount Albums found!"
			albumids=($(python3 /config/scripts/artist_discograpy.py "$artistid" | sort -u))
			if [ ! -d "/config/temp" ]; then
				mkdir "/config/temp"
			fi
			for id in ${!albumids[@]}; do
				currentprocess=$(( $id + 1 ))
				albumid="${albumids[$id]}"
				if [ ! -d /config/cache/artists/$artistid/albums ]; then
					mkdir -p /config/cache/artists/$artistid/albums
					chmod $FolderPermissions /config/cache/artists/$artistid
					chmod $FolderPermissions /config/cache/artists/$artistid/albums
					chown -R abc:abc /config/cache/artists/$artistid
				fi
				if [ ! -f /config/cache/artists/$artistid/albums/${albumid}.json ]; then
					if curl -sL --fail "https://api.deezer.com/album/${albumid}" -o "/config/temp/${albumid}.json"; then
						log "$logheader :: $currentprocess of $albumcount :: Downloading Album info..."
						mv /config/temp/${albumid}.json /config/cache/artists/$artistid/albums/${albumid}.json
						chmod $FilePermissions /config/cache/artists/$artistid/albums/${albumid}.json
					else
						log "$logheader :: $currentprocess of $albumcount :: Error getting album information"
					fi
				else
					log "$logheader :: $currentprocess of $albumcount :: Album info already downloaded"
				fi
			done
			touch /config/cache/artists/$artistid/checked
			chmod $FilePermissions /config/cache/artists/$artistid/checked
			chown -R abc:abc /config/cache/artists/$artistid
			if [ -d "/config/temp" ]; then
				rm -rf "/config/temp"
			fi
		else
			touch /config/cache/artists/$artistid/checked
			chmod $FilePermissions /config/cache/artists/$artistid/checked
			chown -R abc:abc /config/cache/artists/$artistid
		fi
	fi
}

ArtistMode () {
	echo "############################################ DOWNLOAD AUDIO (ARTIST MODE)"
	wantit=$(curl -s --header "X-Api-Key:"${LidarrAPIkey} --request GET  "$LidarrUrl/api/v1/Artist/")
	wantedtotal=$(echo "${wantit}"|jq -r '.[].sortName' | wc -l)
	MBArtistID=($(echo "${wantit}" | jq -r ".[].foreignArtistId"))
	for id in ${!MBArtistID[@]}; do
		artistnumber=$(( $id + 1 ))
		mbid="${MBArtistID[$id]}"
		albumartistmbzid="$mbid"
		albummbid=""
		albumreleasegroupmbzid=""
		LidArtistPath="$(echo "${wantit}" | jq -r ".[] | select(.foreignArtistId==\"${mbid}\") | .path")"
		pathbasename="$(dirname "$LidArtistPath")"
		LidArtistNameCap="$(echo "${wantit}" | jq -r ".[] | select(.foreignArtistId==\"${mbid}\") | .artistName")"
		albumartistname="$LidArtistNameCap"
		LidArtistNameCapClean="$(echo "${LidArtistNameCap}" | sed -e "s/[^A-Za-z0-9._()'\ ]//g" -e "s/  */ /g")"
		deezerartisturl=""
		deezerartisturl=($(echo "${wantit}" | jq -r ".[] | select(.foreignArtistId==\"${mbid}\") | .links | .[] | select(.name==\"deezer\") | .url"))
		deezerartisturlcount=$(echo "${wantit}" | jq -r ".[] | select(.foreignArtistId==\"${mbid}\") | .links | .[] | select(.name==\"deezer\") | .url" | wc -l)
		logheader=""
		logheader="$artistnumber of $wantedtotal :: $LidArtistNameCap"
		logheaderartiststart="$logheader"
		echo "$logheader"
		
		if [ -z "$deezerartisturl" ]; then
			echo "$logheader :: ERROR :: Deezer Artist ID not found..."
			continue
		fi
		
		if [ -f "/config/cache/$LidArtistNameCapClean-$mbid-artist-complete" ]; then
			echo "$logheader :: Already Archived, skipping..."
			continue
		fi
		
		for url in ${!deezerartisturl[@]}; do
			if [ ! -d "$pathbasename" ]; then
				echo "ERROR: Path not found, add missing volume that matches Lidarr"
				#continue
			fi
			urlnumber=$(( $url + 1 ))
			deezerid="${deezerartisturl[$url]}"
			DeezerArtistID=$(echo "${deezerid}" | grep -o '[[:digit:]]*')
			artistid="$DeezerArtistID"
			ArtistAlbumList
			albumlistdata=$(jq -s '.' /config/cache/artists/$artistid/albums/*.json)
			deezeralbumlistcount="$(echo "$albumlistdata" | jq -r "sort_by(.nb_tracks) | sort_by(.explicit_lyrics and .nb_tracks) | reverse | .[] | select(.artist.id==$artistid) | .id" | wc -l)"
			deezeralbumlistids=($(echo "$albumlistdata" | jq -r "sort_by(.nb_tracks) | sort_by(.explicit_lyrics and .nb_tracks) | reverse | .[] | select(.artist.id==$artistid) | .id"))
			logheader="$logheader :: $urlnumber of $deezerartisturlcount"
			logheaderstart="$logheader"
			echo "$logheader"
			
			for id in ${!deezeralbumlistids[@]}; do
				deezeralbumprocess=$(( $id + 1 ))
				deezeralbumid="${deezeralbumlistids[$id]}"
				deezeralbumdata="$(curl -s "https://api.deezer.com/album/$deezeralbumid")"
				deezeralbumurl="https://deezer.com/album/$deezeralbumid"
				deezeralbumtitle="$(echo "$deezeralbumdata" | jq -r ".title")"
				deezeralbumtitleclean="$(echo "$deezeralbumtitle" | sed -e "s/[^A-Za-z0-9._()'\ ]//g" -e "s/  */ /g")"
				deezeralbumartistid="$(echo "$deezeralbumdata" | jq -r ".artist.id" | head -n 1)"
				deezeralbumdate="$(echo "$deezeralbumdata" | jq -r ".release_date")"
				deezeralbumtype="$(echo "$deezeralbumdata" | jq -r ".record_type")"
				deezeralbumexplicit="$(echo "$deezeralbumdata" | jq -r ".explicit_lyrics")"
				if [ "$deezeralbumexplicit" == "true" ]; then 
					lyrictype="EXPLICIT"
				else
					lyrictype="CLEAN"
				fi
				deezeralbumyear="${deezeralbumdate:0:4}"
				albumfolder="$LidArtistNameCapClean - ${deezeralbumtype^^} - $deezeralbumyear - $deezeralbumtitleclean ($lyrictype) ($deezeralbumid)"
				logheader="$logheader :: $deezeralbumprocess of $deezeralbumlistcount :: PROCESSING :: ${deezeralbumtype^^} :: $deezeralbumyear :: $lyrictype :: $deezeralbumtitle"
				echo "$logheader"
				if [ $deezeralbumartistid != $DeezerArtistID ]; then
					echo "$logheader :: Arist ID does not match, skipping..."
					logheader="$logheaderstart"
					continue
				fi
				if [ -d "$LidArtistPath" ]; then
					if [ "${deezeralbumtype^^}" != "SINGLE" ]; then
						if [ "$deezeralbumexplicit" == "false" ]; then
							if find "$LidArtistPath" -iname "$LidArtistNameCapClean - ${deezeralbumtype^^} - * - $deezeralbumtitleclean (EXPLICIT) *" | read; then
								echo "$logheader :: Duplicate found..."
								logheader="$logheaderstart"
								continue
							fi
						fi
					fi
					if [ "${deezeralbumtype^^}" == "SINGLE" ]; then
						if [ "$deezeralbumexplicit" == "false" ]; then
							if find "$LidArtistPath" -iname "$LidArtistNameCapClean - ${deezeralbumtype^^} - * - $deezeralbumtitleclean (EXPLICIT) *" | read; then
								echo "$logheader :: Duplicate Explicit Album already downloaded, skipping..."
								logheader="$logheaderstart"
								continue
							fi
						fi
					fi
					if find "$LidArtistPath" -iname "* ($deezeralbumid)" | read; then
						echo "$logheader :: Alaready Downloaded..."
						logheader="$logheaderstart"
						continue
					fi
				fi
				logheader="$logheader :: DOWNLOAD"
				echo "$logheader :: Sending \"$deezeralbumurl\" to download client..."
				if python3 /config/scripts/dlclient.py -b $quality "$deezeralbumurl"; then
					sleep 0.5
					if find "$DOWNLOADS"/amd/dlclient -iregex ".*/.*\.\(flac\|mp3\)" | read; then
						DownloadQualityCheck
					fi
					if find "$DOWNLOADS"/amd/dlclient -iregex ".*/.*\.\(flac\|mp3\)" | read; then
						find "$DOWNLOADS"/amd/dlclient -type d -exec chmod $FolderPermissions {} \;
						find "$DOWNLOADS"/amd/dlclient -type f -exec chmod $FilePermissions {} \;
						chown -R abc:abc "$DOWNLOADS"/amd/dlclient
					else
						echo "$logheader :: DOWNLOAD :: ERROR :: No files found"
						continue
					fi
				fi
				TagFix
				Conversion
				AddReplaygainTags
				
				file=$(find "$DOWNLOADS"/amd/dlclient -iregex ".*/.*\.\(flac\|mp3\)" | head -n 1)
				if [ ! -z "$file" ]; then
					artwork="$(dirname "$file")/folder.jpg"
					if ffmpeg -y -i "$file" -c:v copy "$artwork" 2>/dev/null; then
						echo "$logheader :: Artwork Extracted"
					else
						echo "$logheader :: ERROR :: No artwork found"
					fi
				fi
				
				if [ ! -d "$LidArtistPath/$albumfolder" ]; then
					mkdir -p "$LidArtistPath/$albumfolder"
					chmod $FolderPermissions "$LidArtistPath/$albumfolder"
				fi
				mv "$DOWNLOADS"/amd/dlclient/* "$LidArtistPath/$albumfolder"/
				chmod $FilePermissions "$LidArtistPath/$albumfolder"/*
				chown -R abc:abc "$LidArtistPath/$albumfolder"
				PlexNotification
				logheader="$logheaderstart"
			done
			logheader="$logheaderartiststart"
		done
	touch "/config/cache/$LidArtistNameCapClean-$mbid-artist-complete"
	done
}

WantedMode () {
	echo "############################################ DOWNLOAD AUDIO (WANTED MODE)"
	LidarrList

	for id in ${!missinglistalbumids[@]}; do
		currentprocess=$(( $id + 1 ))
		lidarralbumid="${missinglistalbumids[$id]}"
		albumdeezerurl=""
		error=0
		lidarralbumdata=$(curl -s --header "X-Api-Key:"${LidarrAPIkey} --request GET  "$LidarrUrl/api/v1/album?albumIds=${lidarralbumid}")
		OLDIFS="$IFS"
		IFS=$'\n'
		lidarralbumdrecordids=($(echo "${lidarralbumdata}" | jq -r '.[] | .releases | .[] | .foreignReleaseId'))
		IFS="$OLDIFS"
		albumreleasegroupmbzid=$(echo "${lidarralbumdata}"| jq -r '.[] | .foreignAlbumId')
		releases=$(curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/release?release-group=$albumreleasegroupmbzid&inc=url-rels&fmt=json")
		albumreleaseid=($(echo "${releases}"| jq -r '.releases[] | select(.relations[].url.resource | contains("deezer")) | .id'))
		sleep $MBRATELIMIT
		lidarralbumtype="$(echo "${lidarralbumdata}"| jq -r '.[] | .albumType')"
		lidarralbumtypelower="$(echo ${lidarralbumtype,,})"
		albumtitle="$(echo "${lidarralbumdata}"| jq -r '.[] | .title')"
		albumreleasedate="$(echo "${lidarralbumdata}"| jq -r '.[] | .releaseDate')"
		albumreleaseyear="${albumreleasedate:0:4}"
		albumclean="$(echo "$albumtitle" | sed -e 's/[\\/:\*\?"”“<>\|\x01-\x1F\x7F]//g')"
		albumartistmbzid=$(echo "${lidarralbumdata}"| jq -r '.[].artist.foreignArtistId')
		albumartistname=$(echo "${lidarralbumdata}"| jq -r '.[].artist.artistName')
		logheader="$currentprocess of $missinglisttotal :: $albumartistname :: $albumreleaseyear :: $lidarralbumtype :: $albumtitle"
		filelogheader="$albumartistname :: $albumreleaseyear :: $lidarralbumtype :: $albumtitle"

		if [ ! -z "$albumreleaseid" ]; then
			for id in ${!albumreleaseid[@]}; do
				currentalbumprocess=$(( $id + 1 ))
				albummbid="${albumreleaseid[$id]}"
				releasedata=$(echo "$releases" | jq -r ".releases[] | select(.id==\"$albummbid\")")
				albumdeezerurl=$(echo "$releasedata" | jq -r '.relations[].url | select(.resource | contains("deezer")) | .resource')
				DeezerAlbumID="$(echo "$albumdeezerurl" | grep -o '[[:digit:]]*')"
				albumdeezerurl="https://api.deezer.com/album/$DeezerAlbumID"
				deezeralbumsearchdata=$(curl -s "${albumdeezerurl}")
				errocheck="$(echo "$deezeralbumsearchdata" | jq -r ".error.code")"
				if [ "$errocheck" != "null" ]; then
					echo "$logheader :: ERROR :: Provided URL is broken, fallback to artist search..."
					albumdeezerurl=""
					error=1
					continue
				else
					error=0
					albumdeezerurl="https://deezer.com/album/$DeezerAlbumID"
					deezeralbumtitle="$(echo "$deezeralbumsearchdata" | jq -r ".title")"
					deezeralbumtype="$(echo "$deezeralbumsearchdata" | jq -r ".record_type")"
					deezeralbumdate="$(echo "$deezeralbumsearchdata" | jq -r ".release_date")"
					deezeralbumyear="${deezeralbumdate:0:4}"
					explicit="$(echo "$deezeralbumsearchdata" | jq -r ".explicit_lyrics")"
					if [ "$explicit" == "true" ]; then
						break
					else
						albumdeezerurl=""
						continue
					fi
				fi
			done
			if [ -z "$albumdeezerurl" ]; then
				for id in ${!albumreleaseid[@]}; do
					currentalbumprocess=$(( $id + 1 ))
					albummbid="${albumreleaseid[$id]}"
					releasedata=$(echo "$releases" | jq -r ".releases[] | select(.id==\"$albummbid\")")
					albumdeezerurl=$(echo "$releasedata" | jq -r '.relations[].url | select(.resource | contains("deezer")) | .resource')
					DeezerAlbumID="$(echo "$albumdeezerurl" | grep -o '[[:digit:]]*')"
					albumdeezerurl="https://api.deezer.com/album/$DeezerAlbumID"
					deezeralbumsearchdata=$(curl -s "${albumdeezerurl}")
					errocheck="$(echo "$deezeralbumsearchdata" | jq -r ".error.code")"
					if [ "$errocheck" != "null" ]; then
						echo "$logheader :: ERROR :: Provided URL is broken, fallback to artist search..."
						albumdeezerurl=""
						albummbid=""
						error=1
						continue
					else
						error=0
						albumdeezerurl="https://deezer.com/album/$DeezerAlbumID"
						deezeralbumtitle="$(echo "$deezeralbumsearchdata" | jq -r ".title")"
						deezeralbumtype="$(echo "$deezeralbumsearchdata" | jq -r ".record_type")"
						deezeralbumdate="$(echo "$deezeralbumsearchdata" | jq -r ".release_date")"
						deezeralbumyear="${deezeralbumdate:0:4}"
						explicit="$(echo "$deezeralbumsearchdata" | jq -r ".explicit_lyrics")"
						break
					fi
				done
			fi
		else
			albummbid=""
			error=1
		fi

		if [[ -f "/config/logs/notfound.log" && $error == 1 ]]; then
			if cat "/config/logs/notfound.log" | grep -i ":: $albumreleasegroupmbzid ::" | read; then
				echo "$logheader :: PREVOUSLY NOT FOUND SKIPPING..."
				continue
			else
				echo "$logheader :: SEARCHING..."
				error=0
			fi
		else
			echo "$logheader :: SEARCHING..."
			error=0
		fi

		sanatizedartistname="$(echo "${albumartistname}" | sed -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]//g' -e 's/^\(nul\|prn\|con\|lpt[0-9]\|com[0-9]\|aux\)\(\.\|$\)//i' -e 's/^\.*$//' -e 's/^$/NONAME/')"
		albumartistlistlinkid=($(echo "${lidarralbumdata}"| jq -r '.[].artist | .links | .[] | select(.name=="deezer") | .url' | sort -u | grep -o '[[:digit:]]*'))
		if [ "$albumartistname" == "Korn" ]; then # Fix for online source naming convention...
			originalartistname="$albumartistname"
			albumartistname="KoЯn"
		else
			originalartistname=""
		fi
		artistclean="$(echo "$albumartistname" | sed -e 's/[^[:alnum:]\ ]//g' -e 's/[\\/:\*\?"”“<>\|\x01-\x1F\x7F]//g')"
		artistcleans="$(echo "$albumartistname" | sed -e 's/["”“]//g' -e 's/‐/ /g')"
		albumartistnamesearch="$(jq -R -r @uri <<<"${artistcleans}")"
		if [ ! -z "$originalartistname" ]; then # Fix for online source naming convention...
			albumartistname="$originalartistname"
		fi
		albumartistpath=$(echo "${lidarralbumdata}"| jq -r '.[].artist.path')
		albumbimportfolder="$DOWNLOADS/amd/import/$artistclean - $albumclean ($albumreleaseyear)-WEB-$lidarralbumtype-deemix"
		albumbimportfoldername="$(basename "$albumbimportfolder")"

		if [ -d "$albumbimportfolder" ]; then
			echo "$logheader :: Already Downloaded, skipping..."
			if [ "$remotepath" == "true" ]; then
				albumbimportfolder="$LIDARRREMOTEPATH/amd/import/$artistclean - $albumclean ($albumreleaseyear)-WEB-$lidarralbumtype-deemix"
				albumbimportfoldername="$(basename "$albumbimportfolder")"
			fi
			LidarrProcessIt=$(curl -s "$LidarrUrl/api/v1/command" --header "X-Api-Key:"${LidarrAPIkey} --data "{\"name\":\"DownloadedAlbumsScan\", \"path\":\"${albumbimportfolder}\"}")
			echo "$logheader :: LIDARR IMPORT NOTIFICATION SENT! :: $albumbimportfoldername"
			continue
		fi

		if [ -f "/config/logs/download.log" ]; then
			if cat "/config/logs/download.log" | grep -i "$albumreleasegroupmbzid :: $albumtitle :: $albumbimportfolder" | read; then
				echo "$logheader :: Already Downloaded"
				continue
			fi
		fi

		if [ -z "$albumdeezerurl" ]; then
			
			if [[ "$albumartistname" != "Various Artists" && "$SearchType" != "fuzzy" ]]; then
				if [ ! -z "${albumartistlistlinkid}" ]; then
					for id in ${!albumartistlistlinkid[@]}; do
						currentprocess=$(( $id + 1 ))
						deezerartistid="${albumartistlistlinkid[$id]}"
						artistid="$deezerartistid"
						ArtistAlbumList
						albumsdata=$(jq -s '.' /config/cache/artists/$artistid/albums/*.json)
						albumsdatalower=${albumsdata,,}

						for id in "${!lidarralbumdrecordids[@]}"; do
							ablumrecordreleaseid=${lidarralbumdrecordids[$id]}
							albummbid="$ablumrecordreleaseid"
							ablumrecordreleasedata=$(echo "${lidarralbumdata}" | jq -r ".[] | .releases | .[] | select(.foreignReleaseId==\"$ablumrecordreleaseid\")")
							albumtitle="$(echo "$ablumrecordreleasedata" | jq -r '.title')"
							albumtrackcount=$(echo "$ablumrecordreleasedata" | jq -r '.trackCount')
							first=${albumtitle%% *}
							firstlower=${first,,}
							echo "$logheader :: Filtering out Titles not containing \"$first\""
							DeezerArtistAlbumListSortTotal=$(echo "$albumsdatalower" | jq -r "sort_by(.nb_tracks) | sort_by(.explicit_lyrics and .nb_tracks) | reverse | .[] | select(.title | contains(\"$firstlower\")) | select(.nb_tracks==$albumtrackcount) | .id" | wc -l)
														
							if [ "$DeezerArtistAlbumListSortTotal" == "0" ]; then
								echo "$logheader :: ERROR :: No albums found..."
								albumdeezerurl=""
								continue
							fi
							DeezerArtistAlbumListAlbumID=($(echo "$albumsdatalower" | jq -r "sort_by(.nb_tracks) | sort_by(.explicit_lyrics and .nb_tracks) | reverse | .[] | select(.title | contains(\"$firstlower\")) | select(.nb_tracks==$albumtrackcount) | .id"))
							
							echo "$logheader :: Checking $DeezerArtistAlbumListSortTotal Albums for match ($albumtitle) with Max Distance Score of 2 or less"
							for id in ${!DeezerArtistAlbumListAlbumID[@]}; do
								currentprocess=$(( $id + 1 ))
								deezeralbumid="${DeezerArtistAlbumListAlbumID[$id]}"
								deezeralbumdata="$(echo "$albumsdata" | jq ".[] | select(.id==$deezeralbumid)")"
								deezeralbumtitle="$(echo "$deezeralbumdata" | jq -r ".title")"
								deezeralbumtype="$(echo "$deezeralbumdata" | jq -r ".record_type")"
								deezeralbumdate="$(echo "$deezeralbumdata" | jq -r ".release_date")"
								deezeralbumyear="${deezeralbumdate:0:4}"
								explicit="$(echo "$deezeralbumdata" | jq -r ".explicit_lyrics")"
								diff=$(levenshtein "${albumtitle,,}" "${deezeralbumtitle,,}")
								if [ "$diff" -le "2" ]; then
									echo "$logheader :: ${albumtitle,,} vs ${deezeralbumtitle,,} :: Distance = $diff :: $deezeralbumid :: MATCH"
									deezersearchalbumid="$deezeralbumid"
									break
								else
									deezersearchalbumid=""
									continue
								fi
							done
							if [ -z "$deezersearchalbumid" ]; then
								echo "$logheader :: $albumtitle :: ERROR :: NO MATCH FOUND"
								albumdeezerurl=""
								continue
							else
								albumdeezerurl="https://deezer.com/album/$deezersearchalbumid"
								break
							fi
						done

						if [ -z "$albumdeezerurl" ]; then
							for id in "${!lidarralbumdrecordids[@]}"; do
								ablumrecordreleaseid=${lidarralbumdrecordids[$id]}
								albummbid="$ablumrecordreleaseid"
								ablumrecordreleasedata=$(echo "${lidarralbumdata}" | jq -r ".[] | .releases | .[] | select(.foreignReleaseId==\"$ablumrecordreleaseid\")")
								albumtitle="$(echo "$ablumrecordreleasedata" | jq -r '.title')"
								albumtrackcount=$(echo "$ablumrecordreleasedata" | jq -r '.trackCount')								
								first=${albumtitle%% *}
								firstlower=${first,,}
								echo "$logheader :: Filtering out Titles not containing \"$first\""
								DeezerArtistAlbumListSortTotal=$(echo "$albumsdatalower" | jq -r "sort_by(.nb_tracks) | sort_by(.explicit_lyrics and .nb_tracks) | reverse | .[] | select(.title | contains(\"$firstlower\")) | select(.nb_tracks==$albumtrackcount) | .id" | wc -l)
															
								if [ "$DeezerArtistAlbumListSortTotal" == "0" ]; then
									echo "$logheader :: ERROR :: No albums found..."
									albumdeezerurl=""
									continue
								fi
								DeezerArtistAlbumListAlbumID=($(echo "$albumsdatalower" | jq -r "sort_by(.nb_tracks) | sort_by(.explicit_lyrics and .nb_tracks) | reverse | .[] | select(.title | contains(\"$firstlower\")) | select(.nb_tracks==$albumtrackcount) | .id"))
								echo "$logheader :: Checking $DeezerArtistAlbumListSortTotal Albums for match ($albumtitle) with Max Distance Score of $MatchDistance or less"
								for id in ${!DeezerArtistAlbumListAlbumID[@]}; do
									currentprocess=$(( $id + 1 ))
									deezeralbumid="${DeezerArtistAlbumListAlbumID[$id]}"
									deezeralbumdata="$(echo "$albumsdata" | jq ".[] | select(.id==$deezeralbumid)")"
									deezeralbumtitle="$(echo "$deezeralbumdata" | jq -r ".title")"
									deezeralbumtype="$(echo "$deezeralbumdata" | jq -r ".record_type")"
									deezeralbumdate="$(echo "$deezeralbumdata" | jq -r ".release_date")"
									deezeralbumyear="${deezeralbumdate:0:4}"
									explicit="$(echo "$deezeralbumdata" | jq -r ".explicit_lyrics")"
									diff=$(levenshtein "${albumtitle,,}" "${deezeralbumtitle,,}")
									if [ "$diff" -le "$MatchDistance" ]; then
										echo "$logheader :: ${albumtitle,,} vs ${deezeralbumtitle,,} :: Distance = $diff :: $deezeralbumid :: MATCH"
										deezersearchalbumid="$deezeralbumid"
										break
									else
										deezersearchalbumid=""
										continue
									fi
								done
								if [ -z "$deezersearchalbumid" ]; then
									echo "$logheader :: $albumtitle :: ERROR :: NO MATCH FOUND"
									albumdeezerurl=""
								else
									albumdeezerurl="https://deezer.com/album/$deezersearchalbumid"
									break
								fi
							done
						fi
					done

					if [ ! -z "$albumdeezerurl" ]; then
						albumreleaseyear="$deezeralbumyear"
						lidarralbumtype="$deezeralbumtype"
						albumclean="$(echo "$deezeralbumtitle" | sed -e 's/[\\/:\*\?"”“<>\|\x01-\x1F\x7F]//g')"
						albumdeezerurl="https://deezer.com/album/$deezersearchalbumid"
					fi
				else
					if ! [ -f "/config/logs/musicbrainzerror.log" ]; then
						touch "/config/logs/musicbrainzerror.log"
					fi
					if [ -f "/config/logs/musicbrainzerror.log" ]; then
						echo "$logheader :: ERROR: musicbrainz id: $albumartistmbzid is missing deezer link, see: \"/config/logs/musicbrainzerror.log\" for more detail..."
						if cat "/config/logs/musicbrainzerror.log" | grep "$albumartistmbzid" | read; then
							sleep 0
						else
							echo "Update Musicbrainz Relationship Page: https://musicbrainz.org/artist/$albumartistmbzid/relationships for \"${albumartistname}\" with Deezer Artist Link" >> "/config/logs/musicbrainzerror.log"
						fi
					fi
				fi
			fi

			if [[ "$SearchType" == "artist" && "$albumartistname" != "Various Artists" ]]; then
				if [ -z "$albumdeezerurl" ]; then
					echo "$logheader :: Skipping fuzzy search..."
					error=1
				fi
			elif [[ -z "$albumdeezerurl" && -z "$albumtidalurl" ]]; then
				echo "$logheader :: ERROR :: Fallback to fuzzy search..."
				echo "$logheader :: FUZZY SEARCHING..."
				for id in "${!lidarralbumdrecordids[@]}"; do
					recordtitle=${lidarralbumdrecordids[$id]}
					#recordtitle="$(echo "${lidarralbumdata}" | jq -r ".[] | .releases | .[] | select(.id==$recordid) | .title")"
					#recordmbrainzid=$(echo "${lidarralbumdata}" | jq -r ".[] | .releases | .[] | select(.id==$recordid) | .foreignReleaseId")
					albumtitle="$recordtitle"
					albumtitlecleans="$(echo "$albumtitle" | sed -e 's/["”“]//g' -e 's/‐/ /g')"
					albumclean="$(echo "$albumtitle" | sed -e 's/[^[:alnum:]\ ]//g' -e 's/[\\/:\*\?"”“<>\|\x01-\x1F\x7F]//g')"
					albumtitlesearch="$(jq -R -r @uri <<<"${albumtitlecleans}")"
					deezersearchalbumid=""
					deezeralbumtitle=""
					explicit="false"
					first=${albumtitle%% *}
					firstlower=${first,,}
					if [ "$albumartistname" != "Various Artists" ]; then
						echo "$logheader :: Searching using $albumartistname + $albumtitle"
						deezersearchurl="https://api.deezer.com/search?q=artist:%22${albumartistnamesearch}%22%20album:%22${albumtitlesearch}%22&limit=1000"
						deezeralbumsearchdata=$(curl -s "${deezersearchurl}")

					else
						echo "$logheader :: Searching using $albumtitle"
						deezersearchurl="https://api.deezer.com/search?q=album:%22${albumtitlesearch}%22&limit=1000"
						deezeralbumsearchdata=$(curl -s "${deezersearchurl}")
					fi

					deezersearchcount="$(echo "$deezeralbumsearchdata" | jq -r ".total")"
					if [ "$deezersearchcount" == "0" ]; then
						if [ "$albumartistname" !=	"Various Artists" ]; then
							echo "$logheader :: No results found, fallback search..."
							echo "$logheader :: Searching using $albumtitle"
							deezersearchurl="https://api.deezer.com/search?q=album:%22${albumtitlesearch}%22&limit=1000"
							deezeralbumsearchdata=$(curl -s "${deezersearchurl}")
							deezersearchcount="$(echo "$deezeralbumsearchdata" | jq -r ".total")"
							deezersearchdata="$(echo "$deezeralbumsearchdata" | jq -r ".data | .[]")"
							deezersearchdatalower=${deezersearchdata,,}
							searchdata=$(echo "$deezersearchdatalower" | jq -r "select(.album.title| contains (\"$firstlower\"))")
						else
							error=1
							continue
						fi
					else
						deezersearchdata="$(echo "$deezeralbumsearchdata" | jq -r ".data | .[]")"
						deezersearchdatalower=${deezersearchdata,,}
						searchdata=$(echo "$deezersearchdatalower" | jq -r "select(.album.title| contains (\"$firstlower\"))")
					fi
					echo "$logheader :: Filtering out Titles not containing \"$first\""
					deezersearchcount="$(echo "$searchdata" | jq -r ".album.id" | sort -u | wc -l)"
					echo "$logheader :: $deezersearchcount Albums Found"
					if [ "$deezersearchcount" == "0" ]; then
						echo "$logheader :: ERROR :: No albums found..."
						echo "$logheader :: Searching without filter..."
						searchdata=$(echo "$deezersearchdatalower")
						deezersearchcount="$(echo "$searchdata" | jq -r ".album.id" | sort -u | wc -l)"
					fi
					echo "$logheader :: $deezersearchcount Albums Found"
					if [ -z "$deezersearchalbumid" ]; then
						if [ ! -d "/config/scripts/temp" ]; then
							mkdir -p /config/scripts/temp
						else
							find /config/scripts/temp -type f -delete
						fi

						albumidlist=($(echo "$searchdata" | jq -r "select(.explicit_lyrics==true) |.album.id" | sort -u))
						albumidlistcount="$(echo "$searchdata" | jq -r "select(.explicit_lyrics==true) |.album.id" | sort -u | wc -l)"
						if [ ! -z "$albumidlist" ]; then
							echo "$logheader :: $albumidlistcount Explicit Albums Found"
							for id in ${!albumidlist[@]}; do
								albumid="${albumidlist[$id]}"

								if ! find /config/scripts/temp -type f -iname "*-$albumid" | read; then
									touch "/config/scripts/temp/explicit-$albumid"
								fi

							done
						fi

						albumidlist=($(echo "$searchdata" | jq -r "select(.explicit_lyrics==false) |.album.id" | sort -u))
						albumidlistcount="$(echo "$searchdata" | jq -r "select(.explicit_lyrics==false) |.album.id" | sort -u | wc -l)"
						if [ ! -z "$albumidlist" ]; then
							echo "$logheader :: $albumidlistcount Clean Albums Found"
							for id in ${!albumidlist[@]}; do
								albumid="${albumidlist[$id]}"
								if ! find /config/scripts/temp -type f -iname "*-$albumid" | read; then
									touch "/config/scripts/temp/clean-$albumid"
								fi
							done
						fi

						albumlistalbumid=($(ls /config/scripts/temp | sort -r | grep -o '[[:digit:]]*'))
						albumlistalbumidcount="$(ls /config/scripts/temp | sort -r | grep -o '[[:digit:]]*' | wc -l)"
						if [ -d "/config/scripts/temp" ]; then
							rm -rf /config/scripts/temp
						fi

						if [ -z "$deezersearchalbumid" ]; then
							echo "$logheader :: Searching $albumlistalbumidcount Albums for Matches with Max Distance Score of 1 or less"
							for id in "${!albumlistalbumid[@]}"; do
								deezerid=${albumlistalbumid[$id]}
								deezeralbumtitle="$(echo "$searchdata" | jq -r "select(.album.id==$deezerid) | .album.title" | head -n 1)"
								diff=$(levenshtein "${albumtitle,,}" "${deezeralbumtitle,,}")
								if [ "$diff" -le "1" ]; then
									echo "$logheader :: ${albumtitle,,} vs ${deezeralbumtitle,,} :: Distance = $diff :: $deezerid :: MATCH"
									deezersearchalbumid="$deezerid"
								else
									echo "$logheader :: ${albumtitle,,} vs ${deezeralbumtitle,,} :: Distance = $diff :: $deezerid :: ERROR :: NO MATCH FOUND"
									deezersearchalbumid=""
									continue
								fi

								deezeralbumdata=$(curl -s "https://api.deezer.com/album/$deezerid")
								deezeralbumtitle="$(echo "$deezeralbumdata" | jq -r ".title")"
								deezeralbumartist="$(echo "$deezeralbumdata" | jq -r ".artist.name")"
								deezeralbumtype="$(echo "$deezeralbumdata" | jq -r ".record_type")"
								deezeralbumdate="$(echo "$deezeralbumdata" | jq -r ".release_date")"
								deezeralbumyear="${deezeralbumdate:0:4}"
								explicit="$(echo "$deezeralbumdata" | jq -r ".explicit_lyrics")"
								if [[ "$deezeralbumtype" == "single" && "$lidarralbumtypelower" != "single" ]]; then
									echo "$logheader :: ERROR :: Album Type Did not Match"
									deezersearchalbumid=""
									continue
								elif [[ "$deezeralbumtype" != "single" && "$lidarralbumtypelower" == "single" ]]; then
									echo "$logheader :: ERROR :: Album Type Did not Match"
									deezersearchalbumid=""
									continue
								fi

								diff=$(levenshtein "${albumartistname,,}" "${deezeralbumartist,,}")
								if [ "$diff" -le "2" ]; then
									echo "$logheader :: ${albumartistname,,} vs ${deezeralbumartist,,} :: Distance = $diff :: Artist Name Match"
									deezersearchalbumid="$deezerid"
									break
								else
									echo "$logheader :: ${albumartistname,,} vs ${deezeralbumartist,,} :: Distance = $diff :: ERROR :: Artist Name did not match"
									deezersearchalbumid=""
									continue
								fi
							done
						fi
					fi

					if [ -z "$deezersearchalbumid" ]; then
						echo "$logheader :: Searching $albumlistalbumidcount Albums for Matches with Max Distance Score of $MatchDistance or less"
						for id in "${!albumlistalbumid[@]}"; do
							deezerid=${albumlistalbumid[$id]}
							deezeralbumtitle="$(echo "$searchdata" | jq -r "select(.album.id==$deezerid) | .album.title" | head -n 1)"
							diff=$(levenshtein "${albumtitle,,}" "${deezeralbumtitle,,}")
							if [ "$diff" -le "$MatchDistance" ]; then
								echo "$logheader :: ${albumtitle,,} vs ${deezeralbumtitle,,} :: Distance = $diff :: $deezerid :: MATCH"
								deezersearchalbumid="$deezerid"
							else
								echo "$logheader :: ${albumtitle,,} vs ${deezeralbumtitle,,} :: Distance = $diff :: $deezerid :: ERROR :: NO MATCH FOUND"
								deezersearchalbumid=""
								continue
							fi

							deezeralbumdata=$(curl -s "https://api.deezer.com/album/$deezerid")
							deezeralbumtitle="$(echo "$deezeralbumdata" | jq -r ".title")"
							deezeralbumartist="$(echo "$deezeralbumdata" | jq -r ".artist.name")"
							deezeralbumtype="$(echo "$deezeralbumdata" | jq -r ".record_type")"
							deezeralbumdate="$(echo "$deezeralbumdata" | jq -r ".release_date")"
							deezeralbumyear="${deezeralbumdate:0:4}"
							explicit="$(echo "$deezeralbumdata" | jq -r ".explicit_lyrics")"
							if [[ "$deezeralbumtype" == "single" && "$lidarralbumtypelower" != "single" ]]; then
								echo "$logheader :: ERROR :: Album Type Did not Match"
								deezersearchalbumid=""
								continue
							elif [[ "$deezeralbumtype" != "single" && "$lidarralbumtypelower" == "single" ]]; then
								echo "$logheader :: ERROR :: Album Type Did not Match"
								deezersearchalbumid=""
								continue
							fi

							diff=$(levenshtein "${albumartistname,,}" "${deezeralbumartist,,}")
							if [ "$diff" -le "2" ]; then
								echo "$logheader :: ${albumartistname,,} vs ${deezeralbumartist,,} :: Distance = $diff :: Artist Name Match"
								deezersearchalbumid="$deezerid"
								break
							else
								echo "$logheader :: ${albumartistname,,} vs ${deezeralbumartist,,} :: Distance = $diff :: ERROR :: Artist Name did not match"
								deezersearchalbumid=""
								continue
							fi
						done
					fi

					if [ ! -z "$deezersearchalbumid" ]; then
						albumdeezerurl="https://deezer.com/album/$deezersearchalbumid"
						albumreleaseyear="$deezeralbumyear"
						lidarralbumtype="$deezeralbumtype"
						albumclean="$(echo "$deezeralbumtitle" | sed -e 's/[\\/:\*\?"”“<>\|\x01-\x1F\x7F]//g')"
						error=0
						break
					else
						error=1
					fi
				done
			else
				error=0
			fi

		fi

		if [ $error == 1 ]; then
			echo "$logheader :: ERROR :: No deezer album url found"
			echo "$albumartistname :: $albumreleasegroupmbzid :: $albumtitle"  >> "/config/logs/notfound.log"
			continue
		fi

		if [ "$explicit" == "true" ]; then
			echo "$logheader :: Explicit Release Found"
		fi
	
		albumbimportfolder="$DOWNLOADS/amd/import/$artistclean - $albumclean ($albumreleaseyear)-WEB-$lidarralbumtype-deemix"
		albumbimportfoldername="$(basename "$albumbimportfolder")"
		
		if [ -f "/config/logs/download.log" ]; then
			if cat "/config/logs/download.log" | grep -i "$albumreleasegroupmbzid :: $albumtitle :: $albumbimportfolder" | read; then
				echo "$logheader :: Already Downloaded"
				continue
			fi
		fi

		if [ -z "$deezeralbumtitle" ]; then
			deezeralbumtitle="$albumtitle"
		fi

		if [ ! -d "$albumbimportfolder" ]; then
			echo "$logheader :: DOWNLOADING :: $deezeralbumtitle :: $albumdeezerurl..."
			if python3 /config/scripts/dlclient.py -b $quality "$albumdeezerurl"; then
				sleep 0.5
				if find "$DOWNLOADS"/amd/dlclient -iregex ".*/.*\.\(flac\|mp3\)" | read; then
					DownloadQualityCheck
				fi
				if find "$DOWNLOADS"/amd/dlclient -iregex ".*/.*\.\(flac\|mp3\)" | read; then
					chmod $FilePermissions "$DOWNLOADS"/amd/dlclient/*
					chown -R abc:abc "$DOWNLOADS"/amd/dlclient
					echo "$logheader :: DOWNLOAD :: success"
					echo "$filelogheader :: $albumdeezerurl :: $albumreleasegroupmbzid :: $albumtitle :: $albumbimportfolder"  >> "/config/logs/download.log"
				else
					echo "$logheader :: DOWNLOAD :: ERROR :: No files found"
					echo "$albumartistname :: $albumreleasegroupmbzid :: $albumtitle"  >> "/config/logs/notfound.log"
					echo "$filelogheader :: $albumdeezerurl :: $albumreleasegroupmbzid :: $albumtitle :: $albumbimportfolder"  >> "/config/logs/error.log"
					continue
				fi
			fi

			#file=$(find "$DOWNLOADS"/amd/dlclient -iregex ".*/.*\.\(flac\|mp3\)" | head -n 1)
			#if [ ! -z "$file" ]; then
			#	artwork="$(dirname "$file")/folder.jpg"
			#	if ffmpeg -y -i "$file" -c:v copy "$artwork" 2>/dev/null; then
			#		echo "$logheader :: DOWNLOAD :: Artwork Extracted"
			#	else
			#		echo "$logheader :: DOWNLOAD :: ERROR :: No artwork found"
			#	fi
			#fi
		else
			echo "$filelogheader :: $albumdeezerurl :: $albumreleasegroupmbzid :: $albumtitle :: $albumbimportfolder"  >> "/config/logs/download.log"
		fi

		TagFix
		Conversion
		AddReplaygainTags

		if [ ! -d "$DOWNLOADS/amd/import" ]; then
			mkdir -p "$DOWNLOADS/amd/import"
			chmod $FolderPermissions "$DOWNLOADS/amd/import"
			chown -R abc:abc "$DOWNLOADS/amd/import"
		fi

		if [ ! -d "$albumbimportfolder" ]; then
			mkdir -p "$albumbimportfolder"
			mv "$DOWNLOADS"/amd/dlclient/* "$albumbimportfolder"/
			chmod $FolderPermissions "$albumbimportfolder"
			chmod $FilePermissions "$albumbimportfolder"/*
			chown -R abc:abc "$albumbimportfolder"
		fi
		if [ "$remotepath" == "true" ]; then
			albumbimportfolder="$LIDARRREMOTEPATH/amd/import/$artistclean - $albumclean ($albumreleaseyear)-WEB-$lidarralbumtype-deemix"
			albumbimportfoldername="$(basename "$albumbimportfolder")"
		fi
		LidarrProcessIt=$(curl -s "$LidarrUrl/api/v1/command" --header "X-Api-Key:"${LidarrAPIkey} --data "{\"name\":\"DownloadedAlbumsScan\", \"path\":\"${albumbimportfolder}\"}")
		echo "$logheader :: LIDARR IMPORT NOTIFICATION SENT! :: $albumbimportfoldername"
	done
	echo "############################################ DOWNLOAD AUDIO COMPLETE"
}

CleanupFailedImports () {
	if [ -d "$DOWNLOADS/amd/import" ]; then
		if find "$DOWNLOADS"/amd/import -mindepth 1 -type d -mmin +480 | read; then
			find "$DOWNLOADS"/amd/import -mindepth 1 -type d -mmin +480 -exec rm -rf "{}" \; &> /dev/null
		fi
	fi
}

CreateDownloadFolders () {
	if [ ! -d "$DOWNLOADS/amd/import" ]; then
		mkdir -p "$DOWNLOADS/amd/import"
	fi

	if [ ! -d "$DOWNLOADS/amd/dlclient" ]; then
		mkdir -p "$DOWNLOADS/amd/dlclient"
	else
		rm "$DOWNLOADS"/amd/dlclient/* &> /dev/null
	fi
}

SetFolderPermissions () {
	if [ -d "$DOWNLOADS/amd/import" ]; then
		chmod $FolderPermissions "$DOWNLOADS/amd/import"
		chown -R abc:abc "$DOWNLOADS/amd/import"
	fi

	if [ -d "$DOWNLOADS/amd/dlclient" ]; then
		chmod $FolderPermissions "$DOWNLOADS/amd/dlclient"
		chown -R abc:abc "$DOWNLOADS/amd/dlclient"
	fi

	if [ -d "$DOWNLOADS/amd" ]; then
		chmod $FolderPermissions "$DOWNLOADS/amd"
		chown -R abc:abc "$DOWNLOADS/amd"
	fi
}

TagFix () {
	if find "$DOWNLOADS/amd/dlclient" -iname "*.flac" | read; then
		if ! [ -x "$(command -v metaflac)" ]; then
			echo "ERROR: FLAC verification utility not installed (ubuntu: apt-get install -y flac)"
		else
			for fname in "$DOWNLOADS"/amd/dlclient/*.flac; do
				filename="$(basename "$fname")"
				metaflac "$fname" --remove-tag=ALBUMARTIST
				metaflac "$fname" --set-tag=ALBUMARTIST="$albumartistname"
				metaflac "$fname" --set-tag=MUSICBRAINZ_ALBUMARTISTID="$albumartistmbzid"
				if [ ! -z "$albumreleasegroupmbzid" ]; then
					metaflac "$fname" --set-tag=MUSICBRAINZ_RELEASEGROUPID="$albumreleasegroupmbzid"
				fi
				if [ ! -z "$albummbid" ]; then
					metaflac "$fname" --set-tag=MUSICBRAINZ_ALBUMID="$albummbid"
				fi				
				echo "$logheader :: FIXING TAGS :: $filename fixed..."
			done
		fi
	fi
	if find "$DOWNLOADS/amd/dlclient" -iname "*.mp3" | read; then
		if ! [ -x "$(command -v eyeD3)" ]; then
			echo "eyed3 verification utility not installed (ubuntu: apt-get install -y eyed3)"
		else
			for fname in "$DOWNLOADS"/amd/dlclient/*.mp3; do
				filename="$(basename "$fname")"
				eyeD3 "$fname" -b "$albumartistname" &> /dev/null
				eyeD3 "$fname" --user-text-frame="MUSICBRAINZ_ALBUMARTISTID:$albumartistmbzid" &> /dev/null
				if [ ! -z "$albumreleasegroupmbzid" ]; then
					eyeD3 "$fname" --user-text-frame="MUSICBRAINZ_RELEASEGROUPID:$albumreleasegroupmbzid" &> /dev/null
				fi
				if [ ! -z "$albummbid" ]; then
					eyeD3 "$fname" --user-text-frame="MUSICBRAINZ_ALBUMID:$albummbid" &> /dev/null
				fi
				echo "$logheader :: FIXING TAGS :: $filename fixed..."
			done
		fi
	fi
}

function levenshtein {
	if (( $# != 2 )); then
		echo "Usage: $0 word1 word2" >&2
	elif (( ${#1} < ${#2} )); then
		levenshtein "$2" "$1"
	else
		local str1len=${#1}
		local str2len=${#2}
		local d

		for (( i = 0; i <= (str1len+1)*(str2len+1); i++ )); do
			d[i]=0
		done

		for (( i = 0; i <= str1len; i++ )); do
			d[i+0*str1len]=$i
		done

		for (( j = 0; j <= str2len; j++ )); do
			d[0+j*(str1len+1)]=$j
		done

		for (( j = 1; j <= str2len; j++ )); do
			for (( i = 1; i <= str1len; i++ )); do
				[ "${1:i-1:1}" = "${2:j-1:1}" ] && local cost=0 || local cost=1
				del=$(( d[(i-1)+str1len*j]+1 ))
				ins=$(( d[i+str1len*(j-1)]+1 ))
				alt=$(( d[(i-1)+str1len*(j-1)]+cost ))
				d[i+str1len*j]=$( echo -e "$del\n$ins\n$alt" | sort -n | head -1 )
			done
		done
		echo ${d[str1len+str1len*(str2len)]}
	fi
}

PlexNotification () {
	if [ "$NOTIFYPLEX" == "true" ]; then
		plexlibrarykey="$(echo "$plexlibraries" | jq -r ".MediaContainer.Directory[] | select(.Location.\"@path\"==\"$pathbasename\") | .\"@key\"" | head -n 1)"
		plexfolder="$LidArtistPath/$albumfolder"
		plexfolderencoded="$(jq -R -r @uri <<<"${plexfolder}")"
		curl -s "$PLEXURL/library/sections/$plexlibrarykey/refresh?path=$plexfolderencoded&X-Plex-Token=$PLEXTOKEN"
		echo "$logheader :: Plex Scan notification sent! ($albumfolder)"
	fi
}

log () {
    m_time=`date "+%F %T"`
    echo $m_time" "$1
}

Configuration
CreateDownloadFolders
SetFolderPermissions
CleanupFailedImports
if [ "$DOWNLOADMODE" == "artist" ]; then
	ArtistMode
fi
if [ "$DOWNLOADMODE" == "wanted" ]; then
	WantedMode
fi
echo "############################################ SCRIPT COMPLETE"
if [ "$AUTOSTART" == "true" ]; then
	echo "############################################ SCRIPT SLEEPING FOR $SCRIPTINTERVAL"
fi

exit 0
