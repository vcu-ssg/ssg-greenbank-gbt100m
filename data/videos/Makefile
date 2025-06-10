

-include ~/.makefilehelp

SRC1 = gdrive-jdleonard:2025_6_GreenBankObservatory/100MEDIA
SRC1_FILE_IDS := 0142 0143 0144 0145 0146 0147 0148 0149 0150 0151 0152 0153 0154 0155 0156
SRC1_FILES := $(foreach ID,$(SRC1_FILE_IDS),DJI_$(ID).MP4)

SRC2 = gdrive-jdleonard:2025_6_GreenBankObservatory
SRC2_FILE_IDS := 0136 0137 0138
SRC2_FILES := $(foreach ID,$(SRC2_FILE_IDS),DJI_$(ID).MP4)

DEST = .

$(SRC1_FILES) :
	rclone copy $(SRC1)/$(@) $(DEST) --drive-shared-with-me --progress

$(SRC2_FILES) :
	rclone copy $(SRC2)/$(@) $(DEST) --drive-shared-with-me --progress

local-mp4-files : $(SRC1_FILES) $(SRC2_FILES)

clean:
	rm -f *.MP4
	rm -f *.DNG
	rm -f *.JPG


