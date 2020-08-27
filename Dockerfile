FROM lsiobase/ubuntu:focal
LABEL maintainer="RandomNinjaAtk"

ENV TITLE="Automated Music Downloader"
ENV VERSION="1.0.7"
ENV MBRAINZMIRROR="https://musicbrainz.org"
ENV XDG_CONFIG_HOME="/config/deemix/xdg"

RUN \
	echo "************ install dependencies ************" && \
	echo "************ install packages ************" && \
	apt-get update -y && \
	apt-get upgrade -y && \
	apt-get install -y --no-install-recommends \
		jq \
		mp3val \
		flac \
		opus-tools \
		eyed3 \
		ffmpeg \
		python3 \
		python3-pip && \
	rm -rf \
		/tmp/* \
		/var/lib/apt/lists/* \
		/var/tmp/* && \
	echo "************ install python packages ************" && \
	python3 -m pip install --no-cache-dir -U \
		mutagen \
		r128gain \
		deemix && \
	echo "************ setup dl client config directory ************" && \
	echo "************ make directory ************" && \
	mkdir -p "${XDG_CONFIG_HOME}/deemix"
	
WORKDIR /

# copy local files
COPY root/ /

# ports and volumes
VOLUME /config /downloads-amd
