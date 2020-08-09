#!/usr/bin/with-contenv bash
export XDG_CONFIG_HOME="/xdg"
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
	sleep 2.5
	echo "############################################ SCRIPT VERSION 1.3.2"
	echo "############################################ DOCKER VERSION $VERSION"
	echo "############################################ CONFIGURATION VERIFICATION"
	error=0

	if [ "$AUTOSTART" = "true" ]; then
		echo "Automatic Start: ENABLED"
	else
		echo "Automatic Start: DISABLED"
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

	# verify downloads location
	if [ -d "/downloads-amd" ]; then
		DOWNLOADS="/downloads-amd"
		echo "Downloads Location: $DOWNLOADS/amd/dlclient"
		echo "Import Location: $DOWNLOADS/amd/import"
		sed -i "s%/downloadfolder%/downloads-amd/amd/dlclient%g" "/xdg/deemix/config.json"
	else
		if [ -d "$DOWNLOADS" ]; then
			echo "DOWNLOADS Location: $DOWNLOADS"
			sed -i "s%/downloadfolder%$DOWNLOADS/amd/dlclient%g" "/xdg/deemix/config.json"
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
	
	if [ "$LIST" == "both" ]; then
		echo "Audio: Wanted List Type: Both (missing & cutoff)"
	elif [ "$LIST" == "missing" ]; then
		echo "Audio: Wanted List Type: Missing"
	elif [ "$LIST" == "cutoff" ]; then
		echo "Audio: Wanted List Type: Cutoff"
	else
		echo "ERROR: LIST type not selected, using default..."
		echo "Audio: Wanted List Type: Missing"
		LIST="missing"
	fi
	
	if [ -z "$SkipFuzzy" ]; then
		SkipFuzzy="true"
		echo "ERROR: SkipFuzzy not set, setting to default"
	fi
	
	if [ "$SkipFuzzy" == "true" ]; then
		echo "Audio: Skip Fuzzy Searching: ENABLED (does not apply to Varoius Artists)"
	else
		echo "Audio: Skip Fuzzy Searching: DISABLE"
	fi	

	if [ ! -z "$Concurrency" ]; then
		echo "Audio: Concurrency: $Concurrency"
		sed -i "s%\"queueConcurrency\": 3%\"queueConcurrency\": $Concurrency%g" "/xdg/deemix/config.json"
	else
		echo "ERROR: Concurrency setting invalid, defaulting to: 1"
		Concurrency="1"
		sed -i "s%\"queueConcurrency\": 3%\"queueConcurrency\": $Concurrency%g" "/xdg/deemix/config.json"
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

	if [ "$ExplicitPreferred" == "true" ]; then
		echo "Audio: Explicit Preferred: ENABLED"
	else
		echo "Audio: Explicit Preferred: DISABLED"
	fi

	if [ ! -z "$MatchDistance" ]; then
		echo "Audio: Match Distance: $MatchDistance"
	else
		echo "ERROR: MatchDistance not set, using default..."
		MatchDistance="10"
		echo "Audio: Match Distance: $MatchDistance"
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
	sleep 2.5
}

CacheEngine () {
	echo "############################################ STARTING CACHE ENGINE"
	wantit=$(curl -s --header "X-Api-Key:"${LidarrAPIkey} --request GET  "$LidarrUrl/api/v1/Artist/")
	wantedtotal=$(echo "${wantit}"| jq -r '.[].sortName' | wc -l)
	MBArtistID=($(echo "${wantit}" | jq -r ".[].foreignArtistId"))

	if [ -d "/config/temp" ]; then
		rm -rf "/config/temp"
	fi

	N=$Concurrency
	(
		for id in ${!MBArtistID[@]}; do
			((i=i%N)); ((i++==0)) && wait
			artistnumber=$(( $id + 1 ))
			ParallelCache "${MBArtistID[$id]}" &
		done
		wait
	)
	wait

	echo "Sleep 15 seconds to allow processes to complete"
	sleep 15
	if [ -d "/config/temp" ]; then
		rm -rf "/config/temp"
	fi
}

ParallelCache () {

		mbid="$1"
		LidArtistNameCap="$(echo "${wantit}" | jq -r ".[] | select(.foreignArtistId==\"${mbid}\") | .artistName")"
		sanatizedartistname="$(echo "${LidArtistNameCap}" | sed -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]//g' -e 's/^\(nul\|prn\|con\|lpt[0-9]\|com[0-9]\|aux\)\(\.\|$\)//i' -e 's/^\.*$//' -e 's/^$/NONAME/')"
		if [ "$LidArtistNameCap" ==	"Various Artists" ]; then
			exit
		fi

		if [ -f "/config/cache/$sanatizedartistname-$mbid-cache-complete" ]; then
			if ! [[ $(find "/config/cache/$sanatizedartistname-$mbid-cache-complete" -mtime +7 -print) ]]; then
				echo "${artistnumber} of ${wantedtotal} :: MBZDB CACHE :: $LidArtistNameCap :: Skipping until cache expires..."
				exit
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
			fi

		fi

		mbzartistinfo="$(cat "/config/cache/$sanatizedartistname-$mbid-info.json")"
		deezerurl="$(echo "$mbzartistinfo" | jq -r ".relations | .[] | .url | select(.resource | contains(\"deezer\")) | .resource")"
		touch "/config/cache/$sanatizedartistname-$mbid-cache-complete"

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
		lidarralbumdrecordids=($(echo "${lidarralbumdata}" | jq -r '.[] | .releases | .[] | .title' | sort -u))
		IFS="$OLDIFS"
		albumreleasegroupmbzid=$(echo "${lidarralbumdata}"| jq -r '.[] | .foreignAlbumId')
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
		if [ -f "/config/logs/notfound.log" ]; then
			if cat "/config/logs/notfound.log" | grep -i ":: $albumreleasegroupmbzid ::" | read; then
				echo "$logheader :: PREVOUSLY NOT FOUND SKIPPING..."
				continue
			else
				echo "$logheader :: SEARCHING..."
			fi
		else
			echo "$logheader :: SEARCHING..."
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

		if [ "$albumartistname" != "Various Artists" ]; then
			albuartistreleasedata=$(find "/config/cache" -type f -iname "*-$albumartistmbzid-releases.json" -exec cat {} \;)
			albumdeezerurl="$(echo "$albuartistreleasedata" | jq -r " .[].releases | .[] | select(.\"release-group\".id==\"$albumreleasegroupmbzid\") | .relations | .[].url | select(.resource | contains(\"deezer\")).resource" | head -n 1)"
			# albumtidalurl="$(echo "$albuartistreleasedata" | jq -r " .[].releases | .[] | select(.\"release-group\".id==\"$albumreleasegroupmbzid\") | .relations | .[].url | select(.resource | contains(\"tidal\")).resource" | head -n 1)"
		fi
		if [ ! -z "$albumdeezerurl" ]; then
			deezeralbumsearchdata=$(curl -s "${albumdeezerurl}")
			errocheck="$(echo "$deezeralbumsearchdata" | jq -r ".error.code")"
			if [ "$errocheck" != "null" ]; then
				echo "$logheader :: ERROR :: Provided URL is broken, fallback to artist search..."
				albumdeezerurl=""
			fi
		fi
		
		if [ "$albumartistname" != "Various Artists" ]; then
			if [ ! -z "${albumartistlistlinkid}" ]; then	
				for id in ${!albumartistlistlinkid[@]}; do
					currentprocess=$(( $id + 1 ))
					deezerartistid="${albumartistlistlinkid[$id]}"
					if [ ! -f "/config/cache/$sanatizedartistname-$albumartistmbzid-$deezerartistid-albums.json" ]; then
						curl -s "https://api.deezer.com/artist/$deezerartistid/albums&limit=1000" -o "/config/cache/$sanatizedartistname-$albumartistmbzid-$deezerartistid-albums.json"
						echo "$logheader :: Downloading Artist Albums List"
					fi
					first=${albumtitle%% *}
					firstlower=${first,,}
					albumsdata=$(cat "/config/cache/$sanatizedartistname-$albumartistmbzid-$deezerartistid-albums.json")
					albumsdatalower=${albumsdata,,}
					echo "$logheader :: Filtering out Titles not containing \"$first\""
					if  [ "$lidarralbumtypelower" != "single" ]; then
						DeezerArtistAlbumListSortTotal=$(echo "$albumsdatalower" | jq ".data | sort_by(.explicit_lyrics, .nb_tracks) | reverse | .[] | select(.title | contains(\"$firstlower\")) | select(.record_type!=\"single\") | .id" | wc -l)
						DeezerArtistAlbumListAlbumID=($(echo "$albumsdatalower" | jq ".data | sort_by(.explicit_lyrics, .nb_tracks) | reverse | .[] | select(.title | contains(\"$firstlower\")) | select(.record_type!=\"single\") | .id"))	
					else
						DeezerArtistAlbumListSortTotal=$(echo "$albumsdatalower" | jq ".data | sort_by(.explicit_lyrics, .nb_tracks) | reverse | .[] | select(.title | contains(\"$firstlower\")) | select(.record_type==\"single\") | .id" | wc -l)
						DeezerArtistAlbumListAlbumID=($(echo "$albumsdatalower" | jq ".data | sort_by(.explicit_lyrics, .nb_tracks) | reverse | .[] | select(.title | contains(\"$firstlower\")) | select(.record_type==\"single\") | .id"))	
					fi

					if [ "$DeezerArtistAlbumListSortTotal" == "0" ]; then
						echo "$logheader :: ERROR :: No albums found..."
						albumdeezerurl=""
						continue
					fi

					for id in "${!lidarralbumdrecordids[@]}"; do
						recordtitle=${lidarralbumdrecordids[$id]}
						albumtitle="$recordtitle"
						echo "$logheader :: Checking $DeezerArtistAlbumListSortTotal Albums for match ($albumtitle) with Max Distance Score of 2 or less"
						for id in ${!DeezerArtistAlbumListAlbumID[@]}; do
							currentprocess=$(( $id + 1 ))
							deezeralbumid="${DeezerArtistAlbumListAlbumID[$id]}"
							deezeralbumdata="$(cat "/config/cache/$sanatizedartistname-$albumartistmbzid-$deezerartistid-albums.json" | jq ".data | .[] | select(.id==$deezeralbumid)")"
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
					if cat "musicbrainzerror.log" | grep "$albumartistmbzid" | read; then
						sleep 0
					else
						echo "Update Musicbrainz Relationship Page: https://musicbrainz.org/artist/$albumartistmbzid/relationships for \"${albumartistname}\" with Deezer Artist Link" >> "/config/logs/musicbrainzerror.log"
					fi
				fi
			fi
		fi
		
		if [[ "$SkipFuzzy" == "true" && "$albumartistname" != "Various Artists" ]]; then
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
				if [ "$albumartistname" !=	"Various Artists" ]; then
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
						searchdata="$(echo "$deezeralbumsearchdata" | jq -r ".data | .[]")"
					else
						error=1
						continue
					fi
				else
					searchdata="$(echo "$deezeralbumsearchdata" | jq -r ".data | .[]")"
				fi
				deezersearchcount="$(echo "$searchdata" | jq -r ".album.id" | sort -u | wc -l)"
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
				

				if [ "$explicit" == "true" ]; then
					echo "$logheader :: Explicit Release Found"
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

		if [ $error == 1 ]; then
			echo "$logheader :: ERROR :: No deezer album url found"
			echo "$albumartistname :: $albumreleasegroupmbzid :: $albumtitle"  >> "/config/logs/notfound.log"
			continue
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
			chmod 0777 -R "${PathToDLClient}"
			currentpwd="$(pwd)"
			echo "$logheader :: DOWNLOADING :: $deezeralbumtitle :: $albumdeezerurl..."
			if cd "${PathToDLClient}" && python3 -m deemix -b $quality "$albumdeezerurl" && cd "${currentpwd}"; then
				sleep 0.5
				if find "$DOWNLOADS"/amd/dlclient -iregex ".*/.*\.\(flac\|mp3\)" | read; then
					chmod $FilePermissions "$DOWNLOADS"/amd/dlclient/*
					chown -R abc:abc "$DOWNLOADS"/amd/dlclient
					echo "$logheader :: DOWNLOAD :: success"
					echo "$albumartistname :: $albumreleasegroupmbzid :: $albumtitle"  >> "/config/logs/notfound.log"
					echo "$filelogheader :: $albumdeezerurl :: $albumreleasegroupmbzid :: $albumtitle :: $albumbimportfolder"  >> "/config/logs/download.log"
				else
					echo "$logheader :: DOWNLOAD :: ERROR :: No files found"
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
				eyeD3 "$fname" --user-text-frame="MusicBrainz Album Artist Id:$albumartistmbzid" &> /dev/null
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

Configuration
CreateDownloadFolders
SetFolderPermissions
CleanupFailedImports
CacheEngine
WantedMode

exit 0
