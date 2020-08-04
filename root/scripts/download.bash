#!/usr/bin/with-contenv bash
export XDG_CONFIG_HOME="/xdg"
agent="automated-music-downloader ( https://github.com/RandomNinjaAtk/docker-amd )"
Configuration () {
	processstartid="$(ps -A -o pid,cmd|grep "start.bash" | grep -v grep | head -n 1 | awk '{print $1}')"
	processdownloadid="$(ps -A -o pid,cmd|grep "download.bash" | grep -v grep | head -n 1 | awk '{print $1}')"
	echo "To kill script, use the following command:"
	echo "kill -9 $processstartid"
	echo "kill -9 $processdownloadid"
	echo ""
	echo ""
	sleep 5

	echo "######################################### CONFIGURATION VERIFICATION #########################################"
	error=0

	if [ "$AUTOSTART" = "true" ]; then
        echo "Automatic Start: ENABLED"
    else
        echo "Automatic Start: DISABLED"
    fi
    
    # Verify Musicbrainz DB Connectivity
	musicbrainzdbtest=$(curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/artist/f59c5520-5f46-4d2c-b2c4-822eabf53419?fmt=json")
	musicbrainzdbtestname=$(echo "${musicbrainzdbtest}"| jq -r '.name')
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
				MBRATELIMIT="1"
			fi
			echo "Musicbrainz Rate Limit: $MBRATELIMIT (Queries Per Second)"
		else
			echo "Musicbrainz Rate Limit: $MBRATELIMIT (Queries Per Second)"
			MBRATELIMIT="0$(echo $(( 100 * 1 / $MBRATELIMIT )) | sed 's/..$/.&/')"
		fi
	fi

	# verify LIBRARY
	if [ -d "$DOWNLOADS" ]; then
		echo "DOWNLOADS Location: $DOWNLOADS"
		if [ ! -f "$DOWNLOADS/amd/dlclient" ]; then
			mkdir -p "$DOWNLOADS/amd/dlclient"
			chmod 0777 -R "$DOWNLOADS/amd/dlclient"
		fi
        sed -i "s%/downloadfolder%$DOWNLOADS/amd/dlclient%g" "/xdg/deemix/config.json"
	else
		echo "ERROR: LIBRARY setting invalid, currently set to: $DOWNLOADS"
		echo "ERROR: LIBRARY Expected Valid Setting: /your/path/to/music/downloads"
		error=1
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

	if [ ! -z "$FilePermissions" ]; then
        echo "Audio: File Permissions: $FilePermissions"
	else
		echo "ERROR: FilePermissions not set, using default..."
		FilePermissions="666"
		echo "Audio: File Permissions: $FilePermissions"
	fi

	if [ ! -z "$FolderPermissions" ]; then
        echo "Audio: Folder Permissions: $FolderPermissions"
	else
		echo "ERROR: FolderPermissions not set, using default..."
		FolderPermissions="766"
		echo "Audio: Folder Permissions: $FolderPermissions"
	fi

	if [ $error = 1 ]; then
		echo "Please correct errors before attempting to run script again..."
		echo "Exiting..."
		exit 1
	fi
	amount=1000000000
	sleep 5
}

CacheEngine () {
	echo "######################################### STARTING CACHE ENGINE #########################################"
	wantit=$(curl -s --header "X-Api-Key:"${LidarrAPIkey} --request GET  "$LidarrUrl/api/v1/Artist/")
	wantedtotal=$(echo "${wantit}"| jq -r '.[].sortName' | wc -l)
	MBArtistID=($(echo "${wantit}" | jq -r ".[].foreignArtistId"))

	if [ -d "/config/temp" ]; then
		rm -rf "/config/temp"
	fi
	for id in ${!MBArtistID[@]}; do
        artistnumber=$(( $id + 1 ))
		mbid="${MBArtistID[$id]}"
        LidArtistNameCap="$(echo "${wantit}" | jq -r ".[] | select(.foreignArtistId==\"${mbid}\") | .artistName")"
        sanatizedartistname="$(echo "${LidArtistNameCap}" | sed -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]//g' -e 's/^\(nul\|prn\|con\|lpt[0-9]\|com[0-9]\|aux\)\(\.\|$\)//i' -e 's/^\.*$//' -e 's/^$/NONAME/')"
		if [ "$LidArtistNameCap" ==	"Various Artists" ]; then
			continue
		fi

		if [ -f "/config/cache/$sanatizedartistname-$mbid-cache-complete" ]; then
			if ! [[ $(find "/config/cache/$sanatizedartistname-$mbid-cache-complete" -mtime +7 -print) ]]; then
				echo "${artistnumber} of ${wantedtotal} :: MBZDB CACHE :: $LidArtistNameCap :: Skipping until cache expires..."
				continue
			fi
		fi

        mbrainzurlcount=$(curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/artist/$mbid?inc=url-rels&fmt=json" | jq -r ".relations | .[] | .url | .resource" | wc -l)
	
		if [ -f "/config/cache/$sanatizedartistname-$mbid-info.json" ]; then
			cachedurlcount=$(cat "/config/cache/$sanatizedartistname-$mbid-info.json" | jq -r ".relations | .[] | .url | .resource" | wc -l)
			if [ "$mbrainzurlcount" -ne "$cachedurlcount" ]; then
				rm "/config/cache/$sanatizedartistname-$mbid-info.json"
			fi
		fi

		if [ ! -f "/config/cache/$sanatizedartistname-$mbid-info.json" ]; then
			echo "${artistnumber} of ${wantedtotal} :: MBZDB CACHE :: $LidArtistNameCap :: Caching Musicbrainz Artist Info..."
			curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/artist/$mbid?inc=url-rels+genres&fmt=json" -o "/config/cache/$sanatizedartistname-$mbid-info.json"
			sleep $MBRATELIMIT
		else 
			echo "${artistnumber} of ${wantedtotal} :: MBZDB CACHE :: $LidArtistNameCap :: Musicbrainz Artist Info Cache Valid..."
		fi
		
		records=$(curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/recording?artist=$mbid&limit=1&offset=0&fmt=json")
		sleep $MBRATELIMIT
		
		
		newrecordingcount=$(echo "${records}"| jq -r '."recording-count"')

				
		if [ ! -f "/config/cache/$sanatizedartistname-$mbid-recording-count.json" ]; then
			curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/recording?artist=$mbid&limit=1&offset=0&fmt=json" -o "/config/cache/$sanatizedartistname-$mbid-recording-count.json"
			sleep $MBRATELIMIT
		fi

		recordingcount=$(cat "/config/cache/$sanatizedartistname-$mbid-recording-count.json" | jq -r '."recording-count"')

		if [ $newrecordingcount != $recordingcount ]; then
			echo "$artistnumber of $wantedtotal :: MBZDB CACHE :: $LidArtistNameCap :: Cache needs update, cleaning..."
		
			if [ -f "/config/cache/$sanatizedartistname-$mbid-recordings.json" ]; then
				rm "/config/cache/$sanatizedartistname-$mbid-recordings.json"
			fi
		
			if [ -f "/config/cache/$sanatizedartistname-$mbid-recording-count.json" ]; then
				rm "/config/cache/$sanatizedartistname-$mbid-recording-count.json"
			fi
		
			if [ -f "/config/cache/$sanatizedartistname-$mbid-video-recordings.json" ]; then
				rm "/config/cache/$sanatizedartistname-$mbid-video-recordings.json"
			fi
		
			if [ ! -f "/config/cache/$sanatizedartistname-$mbid-recording-count.json" ]; then
				curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/recording?artist=$mbid&limit=1&offset=0&fmt=json" -o "/config/cache/$sanatizedartistname-$mbid-recording-count.json"
				sleep $MBRATELIMIT
			fi
		else
			if [ ! -f "/config/cache/$sanatizedartistname-$mbid-recordings.json" ]; then
				echo "$artistnumber of $wantedtotal :: MBZDB CACHE :: $LidArtistNameCap :: Caching MBZDB $recordingcount Recordings..."
			else
				echo "$artistnumber of $wantedtotal :: MBZDB CACHE :: $LidArtistNameCap :: MBZDB Recording Cache Is Valid..."
			fi
		fi

		if [ ! -f "/config/cache/$sanatizedartistname-$mbid-recordings.json" ]; then
			if [ ! -d "/config/temp" ]; then
				mkdir "/config/temp"
				sleep 0.1
			fi	
		
			offsetcount=$(( $recordingcount / 100 ))
			for ((i=0;i<=$offsetcount;i++)); do
				if [ ! -f "recording-page-$i.json" ]; then
					if [ $i != 0 ]; then
						offset=$(( $i * 100 ))
						dlnumber=$(( $offset + 100))
					else
						offset=0
						dlnumber=$(( $offset + 100))
					fi
	
					echo "$artistnumber of $wantedtotal :: MBZDB CACHE :: $LidArtistNameCap :: Downloading page $i... ($offset - $dlnumber Results)"
					curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/recording?artist=$mbid&inc=url-rels&limit=100&offset=$offset&fmt=json" -o "/config/temp/$mbid-recording-page-$i.json"
					sleep $MBRATELIMIT
				fi
			done

			if [ ! -f "/config/cache/$sanatizedartistname-recordings.json" ]; then
				jq -s '.' /config/temp/$mbid-recording-page-*.json > "/config/cache/$sanatizedartistname-$mbid-recordings.json"
			fi

			if [ -f "/config/cache/$sanatizedartistname-$mbid-recordings.json" ]; then
				rm /config/temp/$mbid-recording-page-*.json
				sleep .01
			fi

			if [ -d "/config/temp" ]; then
				sleep 0.1
				rm -rf "/config/temp"
			fi
		fi

		releases=$(curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/release?artist=$mbid&inc=genres+recordings+url-rels+release-groups&limit=1&offset=0&fmt=json")
		sleep $MBRATELIMIT
		newreleasecount=$(echo "${releases}"| jq -r '."release-count"')
				
		if [ ! -f "/config/cache/$sanatizedartistname-$mbid-releases.json" ]; then
			releasecount=$(echo "${releases}"| jq -r '."release-count"')
		else
			releasecount=$(cat "/config/cache/$sanatizedartistname-$mbid-releases.json" | jq -r '.[] | ."release-count"' | head -n 1)
		fi
			
		if [ $newreleasecount != $releasecount ]; then
			echo "$artistnumber of $wantedtotal :: MBZDB CACHE :: $LidArtistNameCap :: Cache needs update, cleaning..."
			if [ -f "/config/cache/$sanatizedartistname-$mbid-releases.json" ]; then
				rm "/config/cache/$sanatizedartistname-$mbid-releases.json"
			fi
		fi

		if [ ! -f "/config/cache/$sanatizedartistname-$mbid-releases.json" ]; then
			echo "$artistnumber of $wantedtotal :: MBZDB CACHE :: $LidArtistNameCap :: Caching $releasecount releases..."
		else
			echo "$artistnumber of $wantedtotal :: MBZDB CACHE :: $LidArtistNameCap :: Releases Cache Is Valid..."
		fi

		if [ ! -f "/config/cache/$sanatizedartistname-$mbid-releases.json" ]; then
			if [ ! -d "/config/temp" ]; then
				mkdir "/config/temp"
				sleep 0.1
			fi	
	
			offsetcount=$(( $releasecount / 100 ))
			for ((i=0;i<=$offsetcount;i++)); do
				if [ ! -f "release-page-$i.json" ]; then
					if [ $i != 0 ]; then
						offset=$(( $i * 100 ))
						dlnumber=$(( $offset + 100))
					else
						offset=0
						dlnumber=$(( $offset + 100))
					fi
					echo "$artistnumber of $wantedtotal :: MBZDB CACHE :: $LidArtistNameCap :: Downloading Releases page $i... ($offset - $dlnumber Results)"
					curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/release?artist=$mbid&inc=genres+recordings+url-rels+release-groups&limit=100&offset=$offset&fmt=json" -o "/config/temp/$mbid-releases-page-$i.json"
					sleep $MBRATELIMIT
				fi
			done


			if [ ! -f "/config/cache/$sanatizedartistname-releases.json" ]; then
				jq -s '.' /config/temp/$mbid-releases-page-*.json > "/config/cache/$sanatizedartistname-$mbid-releases.json"
			fi

			if [ -f "/config/cache/$sanatizedartistname-$mbid-releases.json" ]; then
				rm /config/temp/$mbid-releases-page-*.json
				sleep .01
			fi

			if [ -d "/config/temp" ]; then
				sleep 0.1
				rm -rf "/config/temp"
			fi
		fi

		mbzartistinfo="$(cat "/config/cache/$sanatizedartistname-$mbid-info.json")"
		deezerurl="$(echo "$mbzartistinfo" | jq -r ".relations | .[] | .url | select(.resource | contains(\"deezer\")) | .resource")"
		if [ ! -z "$deezerurl" ]; then
			echo "$deezerurl"
        fi
		touch "/config/cache/$sanatizedartistname-$mbid-cache-complete"
    done
}

WantedMode () {
	echo "######################################### DOWNLOAD AUDIO (WANTED MODE) #########################################"
	missinglist=$(curl -s --header "X-Api-Key:"${LidarrAPIkey} --request GET  "$LidarrUrl/api/v1/wanted/missing/?page=1&pagesize=${amount}&includeArtist=true&monitored=true&sortDir=desc&sortKey=releaseDate")
	missinglisttotal=$(echo "$missinglist" | jq -r '.records | .[] | .id' | wc -l)
	missinglistalbumids=($(echo "$missinglist"| jq -r '.records | .[] | .id'))

	for id in ${!missinglistalbumids[@]}; do
		currentprocess=$(( $id + 1 ))
		lidarralbumid="${missinglistalbumids[$id]}"
		albumdeezerurl=""
		error=0
		lidarralbumdata=$(curl -s --header "X-Api-Key:"${LidarrAPIkey} --request GET  "$LidarrUrl/api/v1/album?albumIds=${lidarralbumid}")
		lidarralbumdrecordids=($(echo "${lidarralbumdata}" | jq '.[] | .releases | .[] | .id'))
		albumreleasegroupmbzid=$(echo "${lidarralbumdata}"| jq -r '.[] | .foreignAlbumId')
		albumtitle="$(echo "${lidarralbumdata}"| jq -r '.[] | .title')"
		albumclean="$(echo "$albumtitle" | sed -e 's/[^[:alnum:]\ ]//g' -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]//g')"
		albumtitlesearch="$(jq -R -r @uri <<<"${albumclean}")"
		albumartistmbzid=$(echo "${lidarralbumdata}"| jq -r '.[].artist.foreignArtistId')
		albumartistname=$(echo "${lidarralbumdata}"| jq -r '.[].artist.artistName')
		artistclean="$(echo "$albumartistname" | sed -e 's/[^[:alnum:]\ ]//g' -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]//g')"
		albumartistnamesearch="$(jq -R -r @uri <<<"${artistclean}")"
		albumartistpath=$(echo "${lidarralbumdata}"| jq -r '.[].artist.path')
		logheader="$currentprocess of $missinglisttotal :: $albumartistname :: $albumtitle"
		if [ -f "/config/logs/notfound.log" ]; then
			if cat "/config/logs/notfound.log" | grep -i "$albumreleasegroupmbzid" | read; then
				echo "$logheader :: PREVOUSLY NOT FOUND SKIPPING..."
				continue
			else
				echo "$logheader :: SEARCHING..."
			fi
		else
			echo "$logheader :: SEARCHING..."
		fi
		if [ "$albumartistname" !=	"Various Artists" ]; then
			albuartistreleasedata=$(find "/config/cache" -type f -iname "*-$albumartistmbzid-releases.json" -exec cat {} \;)
			albumdeezerurl="$(echo "$albuartistreleasedata" | jq -r " .[].releases | .[] | select(.\"release-group\".id==\"$albumreleasegroupmbzid\") | .relations | .[].url | select(.resource | contains(\"deezer\")).resource")"
			albumtidalurl="$(echo "$albuartistreleasedata" | jq -r " .[].releases | .[] | select(.\"release-group\".id==\"$albumreleasegroupmbzid\") | .relations | .[].url | select(.resource | contains(\"tidal\")).resource")"
		else
			albumartistname="$(echo "$albumartistname" | sed 's/ (USA)//g')"
			albumartistnamesearch="$(echo "$albumartistname" | sed 's/\ /%20/g')"
		fi
		if [[ -z "$albumdeezerurl" && -z "$albumtidalurl" ]]; then
			echo "$logheader :: FUZZY SEARCHING..."
			for id in "${!lidarralbumdrecordids[@]}"; do
				recordid=${lidarralbumdrecordids[$id]}
				recordtitle="$(echo "${lidarralbumdata}" | jq -r ".[] | .releases | .[] | select(.id==$recordid) | .title")"
				recordmbrainzid=$(echo "${lidarralbumdata}" | jq -r ".[] | .releases | .[] | select(.id==$recordid) | .foreignReleaseId")
				albumtitle="$recordtitle"
				albumclean="$(echo "$albumtitle" | sed -e 's/[^[:alnum:]\ ]//g' -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]//g')"
				albumtitlesearch="$(jq -R -r @uri <<<"${albumclean}")"
				if [ "$albumartistname" !=	"Various Artists" ]; then
					deezersearchurl="https://api.deezer.com/search?q=artist:%22${albumartistnamesearch}%22%20album:%22${albumtitlesearch}%22"
					deezeralbumsearchdata=$(curl -s "${deezersearchurl}")
				else
					deezersearchurl="https://api.deezer.com/search?q=album:%22${albumtitlesearch}%22"
					deezeralbumsearchdata=$(curl -s "${deezersearchurl}")
				fi
				deezersearchalbumid="$(echo "$deezeralbumsearchdata" | jq -r '.data[].album.id' | head -n 1)"
				if [ ! -z "$deezersearchalbumid" ]; then
					albumdeezerurl="https://deezer.com/album/$deezersearchalbumid"
					break
				else
					error=1
				fi
			done
		else
			error=0
		fi
		if [ $error == 1 ]; then
			echo "$logheader :: ERROR :: No deezer album url found"
			echo "$albumartistname :: $albumreleasegroupmbzid :: $albumtitle"  >> "/config/logs/notfound.log"
			continue
		fi

		if [ -f "/config/logs/download.log" ]; then
			if cat "/config/logs/download.log" | grep -i "$albumdeezerurl" | read; then
				echo "$logheader :: Already Downloaded"
				continue
			fi
		fi

		deezeralbumid="$(echo "${albumdeezerurl}" | grep -o '[[:digit:]]*')"
		albumbimportfolder="$DOWNLOADS/amd/import/$artistclean - $albumclean (WEB)-$deezeralbumid-deemix"

		if [ ! -d "$albumbimportfolder" ]; then
			chmod 0777 -R "${PathToDLClient}"
			currentpwd="$(pwd)"
			echo "$logheader :: DOWNLOADING :: $albumdeezerurl"
			if cd "${PathToDLClient}" && python3 -m deemix -b $quality "$albumdeezerurl" &> /dev/null && cd "${currentpwd}"; then
				echo "$logheader :: DOWNLOAD :: success"
				echo "$albumdeezerurl"  >> "/config/logs/download.log"
			fi

			file=$(find "$DOWNLOADS/amd/dlclient" -iregex ".*/.*\.\(flac\|mp3\|opus\|m4a\)" | head -n 1)
			if [ ! -z "$file" ]; then
				artwork="$(dirname "$file")/folder.jpg"
				if ffmpeg -y -i "$file" -c:v copy "$artwork" 2>/dev/null; then
					echo "$logheader :: DOWNLOAD :: Artwork Extracted"
				else
					echo "$logheader :: DOWNLOAD :: ERROR :: No artwork found"
				fi
			fi
		else
			echo "$albumdeezerurl"  >> "/config/logs/download.log"
		fi

		if [ ! -d "$DOWNLOADS/amd/import" ]; then
			mkdir -p "$DOWNLOADS/amd/import"
			chmod 0777 -R "$DOWNLOADS/amd/import"
		fi

		if [ ! -d "$albumbimportfolder" ]; then
			mkdir -p "$albumbimportfolder"
			mv "$DOWNLOADS"/amd/dlclient/* "$albumbimportfolder"/
			chmod $FolderPermissions "$albumbimportfolder"
			chmod $FilePermissions "$albumbimportfolder"/*
		fi
		importalbumfolder="$albumbimportfolder"
		LidarrProcessIt=$(curl -s "$LidarrUrl/api/v1/command" --header "X-Api-Key:"${LidarrAPIkey} --data "{\"name\":\"DownloadedAlbumsScan\", \"path\":\"${importalbumfolder}\"}")
		echo "$logheader :: LIDARR IMPORT NOTIFICATION SENT! :: $albumbimportfolder"
	done
}

Configuration
CacheEngine
WantedMode

exit 0