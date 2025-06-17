
-include ~/.makefilehelp

.PHONY: init-folders extract-frames colmap-pipeline openmvg-openmvs-pipeline clean build-and-test


## Extract frames block

# ----------------------
video-roots := DJI_0145 DJI_0146 DJI_0149 DJI_0150
fps-roots := 0.20 0.40 0.60 0.80 1.00 1.20 1.40 1.60 1.80
format-roots := jpg png
width-roots := 1600 1280 1024 800
filter-roots := filtered greyscale
# ----------------------

videos-folder = ./videos
projects-folder = ./projects

images-folder = ./data
colmap-folder = data/colmap


poetry-base = poetry run python scripts/cli.py
#poetry-base = echo
extract-options = --threads=16

DJI_0145.skip = 20
DJI_0146.skip = 60
DJI_0149.skip = 10
DJI_0150.skip = 30


ELEM1 = $(word $2,$(subst -, ,$1))
ELEM2 = $(word $2,$(subst ., ,$(subst -, ,$1)))
ELEM3 = $(word $2, $(subst /, ,$(subst -, ,$1)))
ELEM4 = $(word $2,$(subst _, ,$1))
ELEM5 = $(word $2,$(subst /, ,$1))
words_3_to_n = $(subst $(space),_,$(wordlist 3, $(words $(subst _, ,$1)), $(subst _, ,$1)))

define newline


endef

space := $(empty) $(empty)


# expects targets like:  projects/DJI_0145-png_base_1.00_600/images
# filter_format_fps_width
define recipe-base-folder
	$(poetry-base) extract-frames $(videos-folder)/$(call ELEM3,$(@),2).MP4 \
		--output-dir=$(@) \
		--skip=$($(call ELEM3,$(@),2).skip) \
		--tag=$(call ELEM5,$(@),2) \
		--format=$(call ELEM4,$(call ELEM3,$(@),3),1) \
		--fps=$(call ELEM4,$(call ELEM3,$(@),3),3) \
		--max_width=$(call ELEM4,$(call ELEM3,$(@),3),4) \
		$(extract-options)
endef


# expects targets like: projects/DJI_0145-png_filtered_1.00_600/images
define recipe-filtered-folder
	$(poetry-base) convert-images \
	--input-folder=$(firstword $(^)) \
	--output-folder=$(@) \
	--format=$(call ELEM4,$(call ELEM3,$(@),3),1) \
	--tag=$(call ELEM5,$(@),2) --workers=8
endef

# expects targets like:  data/frames/DJI_0145/png-1.00-greyscale
define recipe-greyscale-folder
	$(poetry-base) convert-images \
	--input-folder=$(firstword $(^)) \
	--output-folder=$(@) \
	--format=$(call ELEM4,$(call ELEM3,$(@),3),1) \
	--greyscale \
	--tag=$(call ELEM5,$(@),2) --workers=8
endef

# png_base_0.60_900
base-roots := $(foreach filter,base,$(foreach format,$(format-roots),$(foreach fps,$(fps-roots),$(foreach width,$(width-roots),$(format)_$(filter)_$(fps)_$(width)))))
#$(info $(base-roots))
# png_filtered_0.60_1024
tag-roots := $(foreach filter,$(filter-roots),$(foreach format,$(format-roots),$(foreach fps,$(fps-roots),$(foreach width,$(width-roots),$(format)_$(filter)_$(fps)_$(width)))))
#$(info $(tag-roots))

# projects/DJI_0150-png_base_0.60_900/images
base-targets := $(foreach video,$(video-roots),$(projects-folder)/$(foreach base,$(base-roots),$(video)-$(base)/images))
#$(info $(base-targets))
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(eval $(projects-folder)/$(video)-$(base)/images : ; $$(recipe-base-folder))))

filtered-targets := $(foreach video,$(video-roots),$(foreach tag,$(tag-roots),$(projects-folder)/$(video)-$(tag)/images))
#$(info $(filtered-targets))
$(foreach video,$(video-roots),$(foreach tag,$(tag-roots),$(eval $(projects-folder)/$(video)-$(tag)/images : $(projects-folder)/$(video)-$(word 1,$(subst _, ,$(tag)))_base_$(call words_3_to_n,$(tag))/images ; $$(recipe-$(call ELEM4,$(tag),2)-folder))))
#$(info $(call words_3_to_n,png_base_0.50_1500))

## COLMAP pipeline block (greyscale, filtered, original)
# assumes: projects/DJI_0145-base_png_1.00_900/colmap
define recipe-colmap-folder
	$(poetry-base) run-colmap-pipeline-cli $(firstword $(^)) $(@)
endef

# projects/DJI_0150-base_png_0.60_800/colmap
colmap-targets := $(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(projects-folder)/$(video)-$(tag)/colmap))
#$(info $(colmap-targets))
$(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(eval $(projects-folder)/$(video)-$(tag)/colmap : $(projects-folder)/$(video)-$(tag)/images ; $$(recipe-colmap-folder)$(newline))))

# projects/DJI_0150-png_base_0.60_1600/gsplat

define recipe-gsplat-folder
	poetry run python scripts/cli.py gsplat \
	--scene=$(call ELEM5,$(@),2) \
	--images-dir=$(call ELEM5,$(@),1)/$(call ELEM5,$(@),2)/images \
	--sparse-dir=$(firstword $(^)) \
	--model-dir=$(@)
endef

gsplat-targets := $(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(projects-folder)/$(video)-$(tag)/gsplat))
$(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(eval $(projects-folder)/$(video)-$(tag)/gsplat : $(projects-folder)/$(video)-$(tag)/colmap ; $$(recipe-gsplat-folder)$(newline))))

test: projects/DJI_0150-png_base_0.60_1600/colmap
	poetry run python scripts/cli.py gsplat \
	--scene=DJI_0150-png_base_0.60_1600 \
	--images-dir=projects/DJI_0150-png_base_0.60_1600/images \
	--sparse-dir=projects/DJI_0150-png_base_0.60_1600/colmap \
	--model-dir=projects/DJI_0150-png_base_0.60_1600/gsplat



openmvg-openmvs-pipeline:
	poetry run python scripts/cli.py run-openmvg-openmvs \
		--sfm-engine=$(ENGINE) \
		--matches-ratio=$(RATIO) \
		--enable-texturing


clean:
	rm -rf projects/*


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
	 COMPOSE_BAKE=true docker compose -f ./docker/docker-compose.yml build colmap

rebuild-colmap:
	@echo "🧹 Pruning Docker builder cache and old colmap image..."
	docker builder prune --all --force
	docker rmi -f colmap || true
	make build-colmap


build-colmap-cuda:
	docker compose -f ./docker/docker-compose.yml build colmap-cuda

shell-gsplat:
	docker compose -f ./docker/docker-compose.yml run --rm gsplat bash


.PHONY: rebuild-gsplat


build-gsplat:
	@echo "🐳 Rebuilding Docker image using docker-compose in ./docker..."
	COMPOSE_BAKE=true docker compose -f ./docker/docker-compose.yml build gsplat
	@echo "✅ Done: gsplat rebuilt with fresh environment and SM_120 support"

rebuild-gsplat:
	@echo "🧹 Pruning Docker builder cache and old gsplat image..."
	docker builder prune --all --force
	docker rmi -f gsplat || true
	make build-gsplat

cuda-test:
	docker compose -f ./docker/docker-compose.yml run --rm gsplat bash -c \
		'echo $$TORCH_CUDA_ARCH_LIST && python -c "import torch; print(torch.version.cuda, torch.cuda.get_device_properties(0))"'

build-sibr:
	COMPOSE_BAKE=true docker compose -f ./docker/docker-compose.yml build sibr

rebuild-sibr:
	@echo "🧹 Pruning Docker builder cache and old sibr image..."
	docker builder prune --all --force
	docker rmi -f sibr || true
	make build-sibr


