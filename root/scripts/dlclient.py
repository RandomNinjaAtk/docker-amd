import re
import sys
from deemix.__main__ import download
from deemix.settings import save as saveSettings


newsettings = {
	"downloadLocation": "/downloads-amd/amd/dlclient",
	"tracknameTemplate": "%discnumber%%tracknumber% - %title% %explicit%",
	"albumTracknameTemplate": "%discnumber%%tracknumber% - %title% %explicit%",
	"artistNameTemplate": "%artist% (%artist_id%)",
	"albumNameTemplate": "%artist% - %type% - %year% - %album_id% - %album% %explicit%",
	"createCDFolder": False,
	"createAlbumFolder": False,
	"saveArtworkArtist": True,
	"queueConcurrency": CONCURRENT_DOWNLOADS,
	"jpegImageQuality": EMBEDDED_COVER_QUALITY,
	"embeddedArtworkSize": 1200,
	"localArtworkSize": 1200,
	"removeAlbumVersion": True,
	"syncedLyrics": True,
	"coverImageTemplate": "folder",
	"tags": {
		"trackTotal": True,
		"discTotal": True,
		"explicit": True,
		"length": False,
		"lyrics": True,
		"syncedLyrics": True,
		"involvedPeople": True,
		"copyright": True,
		"composer": True,
		"savePlaylistAsCompilation": True,
		"removeDuplicateArtists": True,
		"featuredToTitle": "0",
		"saveID3v1": False,
		"multiArtistSeparator": "andFeat",
		"singleAlbumArtist": True
	}
}

if __name__ == '__main__':
    sys.argv[0] = re.sub(r'(-script\.pyw|\.exe)?$', '', sys.argv[0])
    saveSettings(newsettings)
    download()
