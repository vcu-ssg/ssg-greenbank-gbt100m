
-include ~/.makefilehelp

.PHONY: init-folders extract-frames colmap-pipeline openmvg-openmvs-pipeline clean build-and-test

# Macros

ELEM1 = $(word $2,$(subst -, ,$1))
ELEM2 = $(word $2,$(subst ., ,$(subst -, ,$1)))
ELEM3 = $(word $2, $(subst /, ,$(subst -, ,$1)))

define newline


endef



init-folders:
	mkdir -p data/videos data/frames data/colmap data/openmvg data/openmvs data/outputs
	touch data/videos/.gitkeep
	touch data/frames/.gitkeep
	touch data/colmap/.gitkeep
	touch data/openmvg/.gitkeep
	touch data/openmvs/.gitkeep
	touch data/outputs/.gitkeep

FPS = 0.50
RATIO = 0.70
ENGINE = INCREMENTAL


## Extract frames block

extract-frames.title = Extract frames from one or more videos.

video-roots := DJI_0145 DJI_0146 DJI_0150
fps-roots := 1.20 1.00 0.80 0.60 0.40

video-folder = data/videos
frame-folder = data/frames
poetry-base = poetry run python scripts/cli.py
extract-options = --threads=16 --quality=2

DJI_0145.skip = 20
DJI_0146.skip = 60
DJI_0150.skip = 30

# expects targets like:  data/frames/DJI_0145/FPS-1.00-original
define recipe-fps-folder
	$(poetry-base) extract-frames $(video-folder)/$(call ELEM3,$(@),3).MP4 --output-dir=$(frame-folder)/$(call ELEM3,$(@),3)/FPS-$(call ELEM3,$(@),5)-$(call ELEM3,$(@),6) --skip=$($(call ELEM3,$(@),3).skip) --fps=$(call ELEM3,$(@),5) --tag=$(call ELEM3,$(@),6) $(extract-options)
endef


# expects targets like:  data/frames/DJI_0145/FPS-1.00-filtered
define recipe-filtered-folder
	$(poetry-base) convert-images --input-folder=$(call ELEM1,$(@),1)-$(call ELEM1,$(@),2)-original --output-folder=$(@) --tag=$(call ELEM1,$(@),3) --workers=8
endef

# expects targets like:  data/frames/DJI_0145/FPS-1.00-filtered
define recipe-greyscale-folder
	$(poetry-base) convert-images --input-folder=$(call ELEM1,$(@),1)-$(call ELEM1,$(@),2)-original --output-folder=$(@) --tag=$(call ELEM1,$(@),3) --workers=8 --greyscale
endef

original-targets := $(foreach video,$(video-roots),$(foreach fps,$(fps-roots),$(frame-folder)/$(video)/FPS-$(fps)-original))
filtered-targets := $(foreach video,$(video-roots),$(foreach fps,$(fps-roots),$(frame-folder)/$(video)/FPS-$(fps)-filtered))
greyscale-targets := $(foreach video,$(video-roots),$(foreach fps,$(fps-roots),$(frame-folder)/$(video)/FPS-$(fps)-greyscale))
$(original-targets) : ; $(recipe-fps-folder)
$(foreach video,$(video-roots),$(foreach fps,$(fps-roots),$(eval $(frame-folder)/$(video)/FPS-$(fps)-filtered : $(frame-folder)/$(video)/FPS-$(fps)-original ; $$(recipe-filtered-folder)$(newline))) )
$(foreach video,$(video-roots),$(foreach fps,$(fps-roots),$(eval $(frame-folder)/$(video)/FPS-$(fps)-greyscale : $(frame-folder)/$(video)/FPS-$(fps)-original ; $$(recipe-greyscale-folder)$(newline))) )

extract-frames : $(greyscale-targets) $(filtered-targets)


## COLMAP pipeline block (greyscale, filtered, original)
# assumes: data/colmap-tuning/DJI_0145-FPS-1.00-greyscale
define recipe-colmap-folder
	$(poetry-base) run-colmap-pipeline-cli data/frames/$(call ELEM3,$(@),4)/FPS-$(call ELEM3,$(@),6)-$(call ELEM3,$(@),7) $(@)
endef

# GREYSCALE
colmap-greyscale-targets := $(foreach video,$(video-roots),$(foreach fps,$(fps-roots),data/colmap-tuning/$(video)-FPS-$(fps)-greyscale))

$(foreach video,$(video-roots),$(foreach fps,$(fps-roots),$(eval data/colmap-tuning/$(video)-FPS-$(fps)-greyscale : data/frames/$(video)/FPS-$(fps)-greyscale ; $$(recipe-colmap-folder)$(newline))))

colmap-pipeline-greyscale : $(colmap-greyscale-targets)

# FILTERED
colmap-filtered-targets := $(foreach video,$(video-roots),$(foreach fps,$(fps-roots),data/colmap-tuning/$(video)-FPS-$(fps)-filtered))

$(foreach video,$(video-roots),$(foreach fps,$(fps-roots),$(eval data/colmap-tuning/$(video)-FPS-$(fps)-filtered : data/frames/$(video)/FPS-$(fps)-filtered ; $$(recipe-colmap-folder)$(newline))))

colmap-pipeline-filtered : $(colmap-filtered-targets)

# ORIGINAL
colmap-original-targets := $(foreach video,$(video-roots),$(foreach fps,$(fps-roots),data/colmap-tuning/$(video)-FPS-$(fps)-original))

$(foreach video,$(video-roots),$(foreach fps,$(fps-roots),$(eval data/colmap-tuning/$(video)-FPS-$(fps)-original : data/frames/$(video)/FPS-$(fps)-original ; $$(recipe-colmap-folder)$(newline))))

colmap-pipeline-original : $(colmap-original-targets)


openmvg-openmvs-pipeline:
	poetry run python scripts/cli.py run-openmvg-openmvs \
		--sfm-engine=$(ENGINE) \
		--matches-ratio=$(RATIO) \
		--enable-texturing

clean-frames:
	rm -rf data/frames/*

clean:
	rm -rf data/colmap/*
	rm -rf data/openmvg/*
	rm -rf data/openmvs/*
	rm -rf data/outputs/*
	rm -rf data/visuals/*


build-and-test:
	cd docker && docker compose build
	cd docker && docker compose run --rm colmap nvidia-smi
	cd docker && docker compose run --rm openmvg nvidia-smi
	cd docker && docker compose run --rm openmvs nvidia-smi

init-nvidia-configuration:
	sudo mkdir -p /etc/nvidia-container-runtime
	sudo touch /etc/nvidia-container-runtime/config.toml

## Interactive shell targets for debugging

colmap-shell:
	docker compose -f ./docker/docker-compose.yml run --rm colmap bash

openmvg-shell:
	docker compose -f ./docker/docker-compose.yml run --rm openmvg bash

openmvs-shell:
	docker compose -f ./docker/docker-compose.yml run --rm openmvs bash


build-colmap:
	docker compose -f ./docker/docker-compose.yml build colmap

build-colmap-cuda:
	docker compose -f ./docker/docker-compose.yml build colmap-cuda