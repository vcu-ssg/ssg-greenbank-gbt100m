# Makefile

# The gsplat pipeline is managed through judicious naming of projects and folders providing
# significant flexibility of use.

-include ~/.makefilehelp

# Key Variables
# ----------------------
# Adjust video-roots to list source vidoes for the pipeline.
# They may NOT have a dash "-" in their name, use an underscore.
# Leave off the .MP4 extension (assumes CAPS for MP4)
# Videos must be stored in ./videos folder.  They will NOT be pushed to repo.
video-roots := DJI_0145 DJI_0146 DJI_0149 DJI_0150

# For every video listed in video-roots, there should be a .skip variable as shown below.
# This represents how many seconds to skip from the front of the video prior to pulling frames.
# if not found, the skip value will default to 0.

DJI_0145.skip = 20
DJI_0146.skip = 60
DJI_0149.skip = 10
DJI_0150.skip = 30
small_example.skip = 0

DJI_0145.rotate = 0
DJI_0146.rotate = 0
DJI_0149.rotate = 90
DJI_0150.rotate = 90
small_example.rotate = -90


# Desired range of fps values.  0.20 -> 1 frame every 5 seconds.
fps-roots := 0.20 0.40 0.60 0.80 1.00 1.20 1.40 1.60 1.80 2.00 3.00 4.00 5.00

# Desired max width/height for images.  Will assume 16:9 or 9:16.
width-roots := 1600 1280 1024 800

# The pipeline will create either PNG or JPG.  JPG is smaller, but can 
# introduce artifacts into subsequent steps in the pipeline.
format-roots := jpg png

# Filters to be applied to images after they're pulled from video.
# For each filter-roots there must be a corresponding recipe-filtered-folder recipe
# that converts images from "base" to "filtered"
filter-roots := filtered greyscale

# ----------------------

videos-folder = ./videos
projects-folder = ./projects
thumbvids-folder = ./projects/thumbvids

poetry-base = poetry run python scripts/cli.py
#poetry-base = echo
extract-options = --threads=16


#
# Helpful macros for parsing folder names
#

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
		--skip=$(or $($(call ELEM3,$(@),2).skip),0) \
		--tag=$(call ELEM5,$(@),2) \
		--format=$(call ELEM4,$(call ELEM3,$(@),3),1) \
		--fps=$(call ELEM4,$(call ELEM3,$(@),3),3) \
		--max_width=$(call ELEM4,$(call ELEM3,$(@),3),4) \
		$(extract-options)
endef


# expects targets like:  projects/DJI_0145-png_filtered_1.00_600/images
define recipe-filtered-folder
	$(poetry-base) convert-images \
	--input-folder=$(firstword $(^)) \
	--output-folder=$(@) \
	--format=$(call ELEM4,$(call ELEM3,$(@),3),1) \
	--tag=$(call ELEM5,$(@),2) --workers=8
endef


# expects targets like:  projects/DJI_0145-png_greyscale_1.00_600/images
define recipe-greyscale-folder
	$(poetry-base) convert-images \
	--input-folder=$(firstword $(^)) \
	--output-folder=$(@) \
	--format=$(call ELEM4,$(call ELEM3,$(@),3),1) \
	--greyscale \
	--tag=$(call ELEM5,$(@),2) --workers=8
endef

# Apply colmap to transform images folder to colmap pointcloud folder
#  projects/DJI_0145-base_png_1.00_900/colmap : projects/DJI_0145-base_png_1.00_900/images ; $(recipe-colmap-folder)
define recipe-colmap-folder
	$(poetry-base) run-colmap-pipeline-cli $(firstword $(^)) $(@)
endef

#  projects/DJI_0145-base_png_1.00_900/colmap/sparse/0_clean : projects/DJI_0145-base_png_1.00_900/colmap ; $(recipe-colmap-clean-folder)
define recipe-colmap-clean-folder
	poetry run python scripts/cli.py colmap-model-cleaner \
	--input-model-folder=$(firstword $(^))/sparse/0 \
	--output-model-folder=$(@) \
	--min-track-len=5 \
	--max-reproj-error=1.0 \
	--min-tri-angle=5.0
endef

#  projects/DJI_0145-base_png_1.00_900/colmap/sparse/0_clean2 : projects/DJI_0145-base_png_1.00_900/colmap ; $(recipe-colmap-clean2-folder)
define recipe-colmap-clean2-folder
	poetry run python scripts/cli.py colmap-model-cleaner \
	--input-model-folder=$(firstword $(^))/sparse/0 \
	--output-model-folder=$(@) \
	--min-track-len=3 \
	--max-reproj-error=2.0 \
	--min-tri-angle=3.0
endef

#  projects/DJI_0145-png_base_1.00_1600/colmap/stats/model_analyzer-sparse-0.json : projects/DJI_0145-png_base_1.00_1600/colmap/sparse/0 ; $(recipe-colmap-analyzer-folder)
define recipe-colmap-analyzer-folder
	poetry run python scripts/cli.py run-colmap-model-analyzer \
	--input-model-folder=$(firstword $(^))  \
	--output-stats-folder=$(@)
endef

# Apply gsplat to transform colmap folder to gsplat folder
#   projects/DJI_0150-png_base_0.60_1600/gsplat : projects/DJI_0150-png_base_0.60_1600/colmap ; $(recipe-gsplat-folder)
define recipe-gsplat-folder
	poetry run python scripts/cli.py gsplat \
	--scene=$(call ELEM5,$(@),2) \
	--images-dir=$(dir $(@))images \
	--sparse-dir=$(firstword $(^)) \
	--model-dir=$(@) \
	--iterations=30000 \
	--sh_degree=3
endef

# Apply gsplat to transform colmap folder to gsplat folder
#   projects/DJI_0150-png_base_0.60_1600/gsplat/0_clean : projects/DJI_0150-png_base_0.60_1600/colmap/sparse/0_clean ; $(recipe-gsplat-folder2)
define recipe-gsplat-folder2
	poetry run python scripts/cli.py gsplat \
	--scene=$(call ELEM5,$(@),2) \
	--images-dir=$(call ELEM5,$(@),1)/$(call ELEM5,$(@),2)/images \
	--sparse-dir=$(firstword $(^)) \
	--model-dir=$(@) \
	--iterations=30000 \
	--sh_degree=3
endef


# projects/thumbvids/DJI_0150-thumb.MP4 : videos/DJI_0150.MP4
define recipe-thumbvid-folder
	mkdir -p $(thumbvids-folder)

	# Set ROT := the .rotate value (if any)
	$(eval ROT := $(or $($(call ELEM3,$(@),3).rotate),0))

	ffmpeg  \
		-ss $(or $($(call ELEM3,$(@),3).skip),0) \
		-display_rotation $(ROT) \
		-i $(firstword $(^)) \
		-vf "scale=iw/10:ih/10,setpts=PTS/4" \
		-an -c:v libx264 \
		-preset slow -crf 28 -b:v 500k \
		-threads 16 \
		$(@)
endef


# Key macros - this is where all the folder wiring happens!

thumbvids : $(foreach video,$(video-roots),$(thumbvids-folder)/$(video)-thumb.MP4)
$(foreach video,$(video-roots),$(eval $(thumbvids-folder)/$(video)-thumb.MP4 : $(videos-folder)/$(video).MP4 ; $$(recipe-thumbvid-folder)))

# the base roots:  png_base_0.60_900
base-roots := $(foreach filter,base,$(foreach format,$(format-roots),$(foreach fps,$(fps-roots),$(foreach width,$(width-roots),$(format)_$(filter)_$(fps)_$(width)))))
#$(info $(base-roots))
# the roots for any filtered images: png_filtered_0.60_1024
tag-roots := $(foreach filter,$(filter-roots),$(foreach format,$(format-roots),$(foreach fps,$(fps-roots),$(foreach width,$(width-roots),$(format)_$(filter)_$(fps)_$(width)))))
#$(info $(tag-roots))

# Using roots above, these create folder names and wires the recipes and dependencies
# projects/DJI_0150-png_base_0.60_900/images
base-targets := $(foreach video,$(video-roots),$(projects-folder)/$(foreach base,$(base-roots),$(video)-$(base)/images))
#$(info $(base-targets))

# Use ffmpeg to create folder of images.  No dependencies, just to id.
# projects/DJI_0150-png_base_0.60_900/images : videos/DJI_0150.MP4 ; $(recipe-base-folder)
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(eval $(projects-folder)/$(video)-$(base)/images : $(videos-folder)/$(video).MP4 ; $$(recipe-base-folder))))

filtered-targets := $(foreach video,$(video-roots),$(foreach tag,$(tag-roots),$(projects-folder)/$(video)-$(tag)/images))
#$(info $(filtered-targets))

# projects/DJI_0150-png_filtered_0.60_900/images : projects/DJI_0150-png_base_0.60_900/images ; $(recipe-filtered-folder)
$(foreach video,$(video-roots),$(foreach tag,$(tag-roots),$(eval $(projects-folder)/$(video)-$(tag)/images : $(projects-folder)/$(video)-$(word 1,$(subst _, ,$(tag)))_base_$(call words_3_to_n,$(tag))/images ; $$(recipe-$(call ELEM4,$(tag),2)-folder))))
#$(info $(call words_3_to_n,png_base_0.50_1500))

## COLMAP pipeline block (greyscale, filtered, original)
# projects/DJI_0145-base_png_1.00_900/colmap : projects/DJI_0145-base_png_1.00_900/images ; $(recipe-colmap-folder)
define recipe-colmap-folder
	$(poetry-base) run-colmap-pipeline-cli $(firstword $(^)) $(@)
endef

# projects/DJI_0150-base_png_0.60_800/colmap
colmap-targets := $(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(projects-folder)/$(video)-$(tag)/colmap))
#$(info $(colmap-targets))
$(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(eval $(projects-folder)/$(video)-$(tag)/colmap : $(projects-folder)/$(video)-$(tag)/images ; $$(recipe-colmap-folder)$(newline))))


# projects/DJI_0150-base_png_0.60_800/colmap/sparse/0
colmap-targets := $(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(projects-folder)/$(video)-$(tag)/colmap/sparse/0))
#$(info $(colmap-targets))
$(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(eval $(projects-folder)/$(video)-$(tag)/colmap/sparse/0 : $(projects-folder)/$(video)-$(tag)/colmap ; $(newline))))


# projects/DJI_0150-base_png_0.60_800/colmap/sparse/0_clean
colmap-clean-targets := $(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(projects-folder)/$(video)-$(tag)/colmap/sparse/0_clean))
#$(info $(colmap-clean-targets))
$(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(eval $(projects-folder)/$(video)-$(tag)/colmap/sparse/0_clean : $(projects-folder)/$(video)-$(tag)/colmap ; $$(recipe-colmap-clean-folder)$(newline) )))

# projects/DJI_0150-base_png_0.60_800/colmap/sparse/0_clean2
colmap-clean2-targets := $(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(projects-folder)/$(video)-$(tag)/colmap/sparse/0_clean2))
#$(info $(colmap-clean2-targets))
$(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(eval $(projects-folder)/$(video)-$(tag)/colmap/sparse/0_clean2 : $(projects-folder)/$(video)-$(tag)/colmap ; $$(recipe-colmap-clean-folder)$(newline) )))


# projects/DJI_0150-png_base_0.60_1600/gsplat
gsplat-targets := $(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(projects-folder)/$(video)-$(tag)/gsplat))
# projects/DJI_0145-base_png_1.00_900/gsplat : projects/DJI_0145-base_png_1.00_900/colmap/sparse/0_clean2 ; $(recipe-gsplat-folder)
$(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(eval $(projects-folder)/$(video)-$(tag)/gsplat : $(projects-folder)/$(video)-$(tag)/colmap/sparse/0_clean2 ; $$(recipe-gsplat-folder)$(newline))))

model-roots := 0 0_clean 0_clean2

# projects/DJI_0150-png_base_0.60_1600/colmap/stats/model_analyzer-sparse-0_clean.json
$(foreach model,$(model-roots),$(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(eval $(projects-folder)/$(video)-$(tag)/colmap/stats/model_analyzer-sparse-$(model).json : $(projects-folder)/$(video)-$(tag)/colmap/sparse/$(model) ; $$(recipe-colmap-analyzer-folder)$(newline)))))


# projects/DJI_0150-png_base_0.60_1600/gsplat/0_clean
gsplat-targets-2 := $(foreach model,$(model-roots),$(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(projects-folder)/$(video)-$(tag)/gsplat/$(model))))
# projects/DJI_0145-base_png_1.00_900/gsplat/0_clean : projects/DJI_0145-base_png_1.00_900/colmap/sparse/0_clean ; $(recipe-gsplat-folder2)
$(foreach model,$(model-roots),$(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(eval $(projects-folder)/$(video)-$(tag)/gsplat/$(model) : $(projects-folder)/$(video)-$(tag)/colmap/sparse/$(model) ; $$(recipe-gsplat-folder2)$(newline)))))


# Targets for cleaning folders

step-roots := images colmap gsplat openmvg openmvs

realclean : ; find ./projects -mindepth 1 -type d -exec rm -rf {} +
$(foreach step,$(step-roots),$(eval clean-$(step) : ; $$(recipe-remove-folders)))
define recipe-remove-folders
	@matches=$$(find projects -mindepth 2 -maxdepth 2 -type d -name $(call ELEM1,$(@),2)); \
	if [ -z "$$matches" ]; then \
		echo "No matching folders named '$(call ELEM1,$(@),2)' found in following projects:"; \
		find projects -mindepth 1 -maxdepth 1 -type d; \
	else \
		echo "Deleting the following folders:"; \
		echo "$$matches"; \
		rm -rf $$matches; \
	fi
endef

clean-thumbvids :
	rm $(thumbvids-folder)/*.MP4

clean-stats :
	find projects -mindepth 3 -maxdepth 3 -type d -name stats -exec rm -rf {} +

refresh-stats:
	@for d in $(shell find projects -mindepth 4 -maxdepth 4 -type d -path "*/colmap/sparse/*"); do \
		base=$$(dirname $$d); \
		suffix=$$(basename $$d); \
		target=$${base%/sparse}/stats/model_analyzer-sparse-$$suffix.json; \
		if [ ! -f "$$target" ]; then \
			echo "Building $$target"; \
			$(MAKE) "$$target"; \
		else \
			echo "Skipping $$target (already exists)"; \
		fi; \
	done


## Interactive shell targets for debugging

container-roots := colmap gsplat openmvg openmvs

# rebuild containers - clean old image prune layers
$(foreach container,$(container-roots),rebuild-$(container)) :
	docker builder prune --all --force
	docker rmi -f $(call ELEM1,$(@),2) || true
	make build-$(call ELEM1,$(@),2)

# build containers
$(foreach container,$(container-roots),build-$(container)) :
	 COMPOSE_BAKE=true docker compose -f ./docker/docker-compose.yml build $(call ELEM1,$(@),2)

# open shell inside container
$(foreach container,$(container-roots),shell-$(container)) :
	docker compose -f ./docker/docker-compose.yml run --rm $(call ELEM1,$(@),2) bash


cuda-test:
	docker compose -f ./docker/docker-compose.yml run --rm gsplat bash -c \
		'echo $$TORCH_CUDA_ARCH_LIST && python -c "import torch; print(torch.version.cuda, torch.cuda.get_device_properties(0))"'


all-clean-colmaps : $(foreach video,DJI_0145,$(foreach tag,$(base-roots) $(tag-roots),$(projects-folder)/$(video)-$(tag)/colmap/sparse/0_clean2))

keepers := $(foreach video,$(video-roots),$(projects-folder)/$(video)-png_base_1.00_1600/gsplat/0_clean2)
$(info $(keepers))

all-keepers: $(keepers)