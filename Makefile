
-include ~/.makefilehelp

.PHONY: init-folders extract-frames colmap-pipeline openmvg-openmvs-pipeline clean build-and-test

# Macros

ELEM1 = $(word $2,$(subst -, ,$1))
ELEM2 = $(word $2,$(subst ., ,$(subst -, ,$1)))
ELEM3 = $(word $2, $(subst /, ,$(subst -, ,$1)))
ELEM4 = $(word $2,$(subst _, ,$1))

define newline


endef



init-folders:
	mkdir -p data/videos data/frames data/colmap data/openmvg data/openmvs data/outputs
	touch data/videos/.gitkeep
	touch data/frames/.gitkeep
	touch data/colmap/.gitkeep
	touch data/colmap-tuning/.gitkeep
	touch data/openmvg/.gitkeep
	touch data/openmvs/.gitkeep
	touch data/outputs/.gitkeep


## Extract frames block

extract-frames.title = Extract frames from one or more videos.

# ----------------------
video-roots := DJI_0145 DJI_0146 DJI_0149 DJI_0150
fps-roots := 0.20 0.40 0.60 0.80 1.00 1.20 1.40 1.60 1.80
format-roots := jpg png
width-roots := 1600 1280 1024 800
filter-roots := filtered greyscale
# ----------------------

video-folder = data/videos
frame-folder = data/frames
colmap-folder = data/colmap

poetry-base = poetry run python scripts/cli.py
#poetry-base = echo
extract-options = --threads=16

DJI_0145.skip = 20
DJI_0146.skip = 60
DJI_0149.skip = 10
DJI_0150.skip = 30

# expects targets like:  data/frames/DJI_0145/base_png_1.00_600
# filter_format_fps_width
define recipe-base-folder
	$(poetry-base) extract-frames $(video-folder)/$(call ELEM3,$(@),3).MP4 \
		--output-dir=$(frame-folder)/$(call ELEM3,$(@),3)/$(call ELEM3,$(@),4) \
		--skip=$($(call ELEM3,$(@),3).skip) \
		--tag=$(call ELEM3,$(@),3)-$(call ELEM3,$(@),4) \
		--format=$(call ELEM4,$(call ELEM3,$(@),4),2) \
		--fps=$(call ELEM4,$(call ELEM3,$(@),4),3) \
		--max_width=$(call ELEM4,$(call ELEM3,$(@),4),4) \
		$(extract-options)
endef


# expects targets like:  data/frames/DJI_0145/filtered_png_1.00_600
define recipe-filtered-folder
	$(poetry-base) convert-images \
	--input-folder=$(call ELEM3,$(@),1)/$(call ELEM3,$(@),2)/$(call ELEM3,$(@),3)/base_$(subst $(word 1,$(subst _, ,$(call ELEM3,$(@),4)))_,,$(call ELEM3,$(@),4)) \
	--output-folder=$(@) \
	--tag=$(call ELEM3,$(@),3)-$(call ELEM3,$(@),4) --workers=8
endef

# expects targets like:  data/frames/DJI_0145/png-1.00-greyscale
define recipe-greyscale-folder
	$(poetry-base) convert-images \
	--input-folder=$(call ELEM3,$(@),1)/$(call ELEM3,$(@),2)/$(call ELEM3,$(@),3)/base_$(subst $(word 1,$(subst _, ,$(call ELEM3,$(@),4)))_,,$(call ELEM3,$(@),4)) \
	--output-folder=$(@) \
	--greyscale \
	--tag=$(call ELEM3,$(@),3)-$(call ELEM3,$(@),4) --workers=8
endef

# base_png_0.60_900
base-roots := $(foreach filter,base,$(foreach format,$(format-roots),$(foreach fps,$(fps-roots),$(foreach width,$(width-roots),$(filter)_$(format)_$(fps)_$(width)))))
tag-roots := $(foreach filter,$(filter-roots),$(foreach format,$(format-roots),$(foreach fps,$(fps-roots),$(foreach width,$(width-roots),$(filter)_$(format)_$(fps)_$(width)))))
#$(info $(base-roots))

# data/frames/DJI_0150/base_png_0.60_900
base-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(frame-folder)/$(video)/$(base)))
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(eval $(frame-folder)/$(video)/$(base) : ; $$(recipe-base-folder))))
filtered-targets := $(foreach video,$(video-roots),$(foreach tag,$(tag-roots),$(frame-folder)/$(video)/$(tag)))
$(foreach video,$(video-roots),$(foreach tag,$(tag-roots),$(eval $(frame-folder)/$(video)/$(tag) : $(frame-folder)/$(video)/base_$(subst $(word 1,$(subst _, ,$(tag)))_,,$(tag)) ; $$(recipe-$(call ELEM4,$(tag),1)-folder))))



## COLMAP pipeline block (greyscale, filtered, original)
# assumes: data/colmap/DJI_0145/base_png_1.00_900
define recipe-colmap-folder
	$(poetry-base) run-colmap-pipeline-cli data/frames/$(call ELEM3,$(@),3)/$(call ELEM3,$(@),4) $(@)
endef

# data/colmap/DJI_0150-base_png_0.60_800
colmap-targets := $(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(colmap-folder)/$(video)-$(tag)))
#$(info $(colmap-targets))
$(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(eval $(colmap-folder)/$(video)-$(tag) : data/frames/$(video)/$(tag) ; $$(recipe-colmap-folder)$(newline))))



openmvg-openmvs-pipeline:
	poetry run python scripts/cli.py run-openmvg-openmvs \
		--sfm-engine=$(ENGINE) \
		--matches-ratio=$(RATIO) \
		--enable-texturing

clean-frames:
	rm -rf data/frames/*

clean:
	rm -rf data/colmap/*
	rm -rf data/colmap/*
	rm -rf data/openmvg/*
	rm -rf data/openmvs/*
	rm -rf data/outputs/*
	rm -rf data/gsplat/*
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

build-gsplat:
	docker compose -f ./docker/docker-compose.yml build gsplat

shell-gsplat:
	docker compose -f ./docker/docker-compose.yml run --rm gsplat bash

shell-gsplat2:
	docker compose -f ./docker/docker-compose.yml run --rm gsplat2 bash


.PHONY: rebuild-gsplat2


build-gsplat2:
	@echo "🐳 Rebuilding Docker image using docker-compose in ./docker..."
	docker compose -f ./docker/docker-compose.yml build gsplat2
	@echo "✅ Done: gsplat2 rebuilt with fresh environment and SM_90 support"

rebuild-gsplat2:
	@echo "🧹 Pruning Docker builder cache and old gsplat2 image..."
	docker builder prune --all --force
	-docker rmi -f gsplat2 || true
	make build-gsplat2

cuda-test:
	docker compose -f ./docker/docker-compose.yml run --rm gsplat2 bash -c \
		'echo $$TORCH_CUDA_ARCH_LIST && python -c "import torch; print(torch.version.cuda, torch.cuda.get_device_properties(0))"'




test: data/colmap/DJI_0150-base_png_0.60_800
	poetry run python scripts/cli.py gsplat2 \
	--scene=DJI_0150-base_png_0.60_800 \
	--frames-dir=data/frames/DJI_0150/base_png_0.60_800 \
	--sparse-dir=data/colmap/DJI_0150-base_png_0.60_800 \
	--output-dir=data/gsplat/DJI_0150-base_png_0.60_800
