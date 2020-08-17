# AMD - Automated Music Downloader 

[RandomNinjaAtk/amd](https://github.com/RandomNinjaAtk/docker-amd) is a Lidarr companion script to automatically download music for Lidarr 

[![RandomNinjaAtk/amd](https://raw.githubusercontent.com/RandomNinjaAtk/unraid-templates/master/randomninjaatk/img/amd.png)](https://github.com/RandomNinjaAtk/docker-amd)

### Audio ([AMD](https://github.com/RandomNinjaAtk/docker-amd)) + Video ([AMVD](https://github.com/RandomNinjaAtk/docker-amvd)) (Plex Example)
![](https://raw.githubusercontent.com/RandomNinjaAtk/Scripts/master/images/plex-musicvideos.png)

## Features
* Downloading **Music** using online sources for use in popular applications (Plex/Kodi/Emby/Jellyfin): 
  * Searches for downloads based on Lidarr's album wanted list
  * Downloads using a third party download client automatically
  * FLAC / MP3 (320/120) Download Quality
  * Notifies Lidarr to automatically import downloaded files
  * Music is properly tagged and includes coverart before Lidarr Receives them (Third Party Download Client handles it)

## Supported Architectures

The architectures supported by this image are:

| Architecture | Tag |
| :----: | --- |
| x86-64 | latest |

## Version Tags

| Tag | Description |
| :----: | --- |
| latest | Newest release code |


## Parameters

Container images are configured using parameters passed at runtime (such as those above). These parameters are separated by a colon and indicate `<external>:<internal>` respectively. For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container. See the [wiki](https://github.com/RandomNinjaAtk/docker-amd/wiki) to understand how it works.

| Parameter | Function |
| --- | --- |
| `-v /config` | Configuration files for Lidarr. |
| `-v /downloads-amd` | Path to your download folder location. (<strong>DO NOT DELETE, this is a required path</strong>) :: <strong>!!!IMPORTANT!!!</strong> Map this exact volume mount to your Lidarr Container for everything to work properly!!! |
| `-e PUID=1000` | for UserID - see below for explanation |
| `-e PGID=1000` | for GroupID - see below for explanation |
| `-e AUTOSTART=true` | true = Enabled :: Runs script automatically on startup |
| `-e LIST=both` | both or missing or cutoff :: both = missing + cutoff :: missng = lidarr missing list :: cutoff = lidarr cutoff list |
| `-e SearchType=both` | both or artist or fuzzy :: both = artist + fuzzy searching :: artist = only artist searching :: fuzzy = only fuzzy searching (Various Artist is always fuzzy searched, regardless of setting) |
| `-e Concurrency=1` | Number of concurrent processes (downloads and caching threads) |
| `-e quality=FLAC` | FLAC or 320 or 128 :: 320/128 are MP3 downloads, FLAC is lossless... |
| `-e MatchDistance=10` | Set as an integer, the higher the number, the more lienet it is. Example: A match score of 0 is a perfect match :: For more information, this score is produced using this function: [Algorithm Implementation/Strings/Levenshtein distance](https://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Levenshtein_distance) |
| `-e FolderPermissions=766` | Based on chmod linux permissions |
| `-e FilePermissions=666` | Based on chmod linux permissions |
| `-e MBRAINZMIRROR=https://musicbrainz.org` | OPTIONAL :: Only change if using a different mirror |
| `-e MBRATELIMIT=1` | OPTIONAL: musicbrainz rate limit, musicbrainz allows only 1 connection per second, max setting is 10 :: Set to 101 to disable limit |
| `-e LidarrUrl=http://127.0.0.1:8686` | Set domain or IP to your Lidarr instance including port. If using reverse proxy, do not use a trailing slash. Ensure you specify http/s. |
| `-e LidarrAPIkey=08d108d108d108d108d108d108d108d1` | Lidarr API key. |
| `-e ARL_TOKEN=08d108d108d108d108d108d108d108d1` | User token for dl client, for instructions to obtain token: https://notabug.org/RemixDevs/DeezloaderRemix/wiki/Login+via+userToken |

## Usage

Here are some example snippets to help you get started creating a container.

### docker

```
docker create \
  --name=radarr \
  -v /path/to/config/files:/config \
  -v /path/to/downloads:/downloads-amd \
  -e PUID=1000 \
  -e PGID=1000 \
  -e AUTOSTART=true \
  -e LIST=both \
  -e SearchType=both \
  -e Concurrency=1 \
  -e quality=FLAC \
  -e MatchDistance=10 \
  -e FolderPermissions=766 \
  -e FilePermissions=666 \
  -e MBRAINZMIRROR=https://musicbrainz.org \
  -e MBRATELIMIT=1 \
  -e LidarrUrl=http://127.0.0.1:8686 \
  -e LidarrAPIkey=08d108d108d108d108d108d108d108d1 \
  -e ARL_TOKEN=08d108d108d108d108d108d108d108d1	\
  --restart unless-stopped \
  randomninjaatk/amd 
```


### docker-compose

Compatible with docker-compose v2 schemas.

```
---
version: "2.1"
services:
  amd:
    image: randomninjaatk/amd 
    container_name: amd
    volumes:
      - /path/to/config/files:/config
      - /path/to/downloads:/downloads-amd
    environment:
      - PUID=1000
      - PGID=1000
      - AUTOSTART=true
      - LIST=both
      - SearchType=both
      - Concurrency=1
      - quality=FLAC
      - MatchDistance=10
      - FolderPermissions=766
      - FilePermissions=666
      - MBRAINZMIRROR=https://musicbrainz.org
      - MBRATELIMIT=1
      - LidarrUrl=http://127.0.0.1:8686
      - LidarrAPIkey=08d108d108d108d108d108d108d108d1
      - ARL_TOKEN=08d108d108d108d108d108d108d108d1
    restart: unless-stopped
```


# Script Information
* Script will automatically run when enabled, if disabled, you will need to manually execute with the following command:
  * From Host CLI: `docker exec -it amd /bin/bash -c 'bash /config/scripts/download.bash'`
  * From Docker CLI: `bash /config/scripts/download.bash`
  
## Directories:
* <strong>/config/scripts</strong>
  * Contains the scripts that are run
* <strong>/config/logs</strong>
  * Contains the log output from the script
* <strong>/config/cache</strong>
  * Contains the artist data cache to speed up processes

<br />

# Lidarr Configuration Recommendations

## Media Management Settings:
* Disable Track Naming
  * Disabling track renaming enables synced lyrics that are imported as extras to be utilized by media players that support using them

#### Track Naming:

* Artist Folder: `{Artist Name}{ (Artist Disambiguation)}`
* Album Folder: `{Artist Name}{ - ALBUM TYPE}{ - Release Year} - {Album Title}{ ( Album Disambiguation)}`

#### Importing:
* Enable Import Extra Files
  * `lrc,jpg,png`

#### File Management
* Change File Date: Album Release Date
 
#### Permissions
* Enable Set Permissions
<br />
<br />
<br />
<br /> 


# Credits
- [Original Idea based on lidarr-download-automation by Migz93](https://github.com/Migz93/lidarr-download-automation)
- [Deemix download client](https://deemix.app/)
- [Musicbrainz](https://musicbrainz.org/)
- [Lidarr](https://lidarr.audio/)
- [Algorithm Implementation/Strings/Levenshtein distance](https://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Levenshtein_distance)
- Icons made by <a href="http://www.freepik.com/" title="Freepik">Freepik</a> from <a href="https://www.flaticon.com/" title="Flaticon"> www.flaticon.com</a>
