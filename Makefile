# Makefile

# The gsplat pipeline is managed through judicious naming of projects and folders providing
# significant flexibility of use.

help:
	@echo ""

# Key targets:
# Images          : projects/<video>-<format>_<filter>_<fps>_<maxdim>  <filter>=base (DJI_0145-png_base_1.00_1600)  recipe-base-folder
# Filtered images : projects/<video>-<format>_<filter>_<fps>_<maxdim>  (filtered or greyscale)  recipe-<filter>-folder
# Base clouds     : projects/<project name>/colmap/sparse/0  recipe-colmap-folder
# Filtered clouds : projects/<project name>/colmap/sparse/<model>  (0_clean or 0_clean2, etc.) recipe-colmap-<model>-folder
# gSplats       : projects/<project name>/gsplat/<model>/<filter>  (point_cloud or filter1 or filter2, etc.)



# colmap/sparse/0 : images/  points3D.bin <-
# colmap/sparse/0_clean : colmap/sparse/0
# colmap/sparse/0_clean2 : colmap/sparse/0  0.ply <- points3D.bin

# gsplat/0/point_cloud : colmap/sparse/0    point_cloud.ply <- 0.ply
# gsplat/0/point_cloud/iteration_30000/point_cloud.ply : gsplat/0/point_cloud
# gsplat/0/point_cloud/iteration_30000/point_cloud.splat : gsplat/0/point_cloud/iteration_30000/point_cloud.ply

## Pattern for filtering point_cloud/iteration_30000/point_cloud.ply
# gsplat/0/filter1 : gsplat/0/point_cloud
# gsplat/0/filter2 : gsplat/0/point_cloud


# Tasks:
# - always create .splat from point_cloud.ply
# - copy files from point_cloud iteration_30000 folder except point_cloud.ply
# - then make splat from new point_cloud.ply




##-include ~/.makefilehelp

# Key Variables
# ----------------------
# Adjust video-roots to list source vidoes for the pipeline.
# They may NOT have a dash "-" in their name, use an underscore.
# Leave off the .MP4 extension (assumes CAPS for MP4)
# Videos must be stored in ./videos folder.  They will NOT be pushed to repo.
video-roots := DJI_0145 DJI_0146 DJI_0149 DJI_0150 small_example

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

# The pipeline will create either PNG or JPG.  JPG is smaller, but can 
# introduce artifacts into subsequent steps in the pipeline.
format-roots := jpg png

# Desired range of fps values.  0.20 -> 1 frame every 5 seconds.
fps-roots := 0.20 0.40 0.60 0.80 1.00 1.20 1.40 1.60 1.80 2.00 3.00 4.00 5.00

# Desired max width/height for images.  Will assume 16:9 or 9:16.
width-roots := 1600 1280 1024 800

# Filters to be applied to images after they're pulled from video.
# For each filter-roots there must be a corresponding recipe-filtered-folder recipe
# that converts images from "base" to "filtered"
filter-roots := none color greyscale

# Models are colmap models like ./sparse/0  ./sparse/0_clean ./sparse/1 etc.
# 0 is base/default model. Others 
model-roots := 0 0_filter1 0_filter2

# GSPLAT post processing folders  (point_cloud is unprocessed)

splat-filter-roots := point_cloud sf0 sf1

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
ELEM3 = $(word $2,$(subst /, ,$(subst -, ,$1)))
ELEM4 = $(word $2,$(subst _, ,$1))
ELEM5 = $(word $2,$(subst /, ,$1))
words_3_to_n = $(subst $(space),_,$(wordlist 3, $(words $(subst _, ,$1)), $(subst _, ,$1)))

define newline


endef

space := $(empty) $(empty)


# expects targets like:  projects/DJI_0145-png_1.00_600_none/images
# -> format_fps_width_filter
define recipe-base-folder
	@echo -------------------------------------------------------------------
	@echo Extracting images: $(call ELEM5,$(@),2)
	@echo -------------------------------------------------------------------
	@if true; then \
	$(poetry-base) extract-frames $(videos-folder)/$(call ELEM3,$(@),2).MP4 \
		--output-dir=$(@) \
		--skip=$(or $($(call ELEM3,$(@),2).skip),0) \
		--tag=$(call ELEM5,$(@),2) \
		--format=$(call ELEM4,$(call ELEM3,$(@),3),1) \
		--fps=$(call ELEM4,$(call ELEM3,$(@),3),2) \
		--max_width=$(call ELEM4,$(call ELEM3,$(@),3),3) \
		$(extract-options) ; \
	fi
	@if [ "$(call ELEM4,$(call ELEM3,$(@),3),4)" != "none" ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Applying filters: $(call ELEM4,$(call ELEM3,$(@),3),4)"; \
		echo "-------------------------------------------------------------------"; \
	fi
	@if [ "$(call ELEM4,$(call ELEM3,$(@),3),4)" = "color" ]; then \
		$(poetry-base) convert-images \
		--input-folder=$(@) \
		--output-folder=$(@) \
		--format=$(call ELEM4,$(call ELEM3,$(@),3),1) \
		--tag=$(call ELEM5,$(@),2) --workers=8 \
		--sharpen="0x1.0" \
		--contrast="5x50%" \
		--no-greyscale ; \
	elif [ "$(call ELEM4,$(call ELEM3,$(@),3),4)" = "greyscale" ]; then \
		$(poetry-base) convert-images \
		--input-folder=$(@) \
		--output-folder=$(@) \
		--format=$(call ELEM4,$(call ELEM3,$(@),3),1) \
		--tag=$(call ELEM5,$(@),2) --workers=8 \
		--sharpen="0x1.0" \
		--contrast="5x50%" \
		--greyscale ; \
	fi
endef



# Apply colmap to transform images folder to colmap pointcloud folder
#  projects/DJI_0145-base_png_1.00_900/colmap : projects/DJI_0145-base_png_1.00_900/images ; $(recipe-colmap-folder)
## COLMAP will create this model in the sparse/0
define recipe-colmap-folder
	@if [ true ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Running COLMAP $(call ELEM5,$(@),2)"; \
		echo "-------------------------------------------------------------------"; \
	fi
	$(poetry-base) run-colmap-pipeline-cli $(firstword $(^)) $(@)
endef

#  projects/DJI_0145-base_png_1.00_900/colmap/sparse/0_clean : projects/DJI_0145-base_png_1.00_900/colmap ; $(recipe-colmap-clean-folder)

define recipe-colmap-filters-folder
	@if [ "$(call ELEM5,$(@),5)" != "0" ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Running applying COLMAP filter:  $(call ELEM5,$(@),5)"; \
		echo "-------------------------------------------------------------------"; \
	fi
	@if [ "$(call ELEM5,$(@),5)" = "0_filter1" ]; then \
		$(poetry-base) colmap-model-cleaner \
		--input-model-folder=$(firstword $(^))/sparse/0 \
		--output-model-folder=$(@) \
		--min-track-len=5 \
		--max-reproj-error=1.0 \
		--min-tri-angle=5.0	; \
	elif [ "$(call ELEM5,$(@),5)" = "0_filter2" ]; then \
		poetry run python scripts/cli.py colmap-model-cleaner \
		--input-model-folder=$(firstword $(^))/sparse/0 \
		--output-model-folder=$(@) \
		--min-track-len=3 \
		--max-reproj-error=2.0 \
		--min-tri-angle=3.0 ; \
	fi	
endef


#  projects/DJI_0145-png_base_1.00_1600/colmap/stats/model_analyzer-sparse-0.json : projects/DJI_0145-png_base_1.00_1600/colmap/sparse/0 ; $(recipe-colmap-analyzer-folder)
define recipe-colmap-analyzer-folder
	$(poetry-base) run-colmap-model-analyzer \
	--input-model-folder=$(firstword $(^))  \
	--output-stats-folder=$(@)
endef

# Apply gsplat to transform colmap folder to gsplat folder
#   projects/DJI_0150-png_base_0.60_1600/gsplat : projects/DJI_0150-png_base_0.60_1600/colmap ; $(recipe-gsplat-folder)
define recipe-gsplat-folder
	@if [ true ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Running GSPLAT: $(call ELEM5,$(@),2)"; \
		echo "-------------------------------------------------------------------"; \
	fi
	$(poetry-base) run-gsplat-pipeline \
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
	@if [ true ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Running GSPLAT filter: $(@)"; \
		echo "-------------------------------------------------------------------"; \
	fi
	$(poetry-base) run-gsplat-pipeline \
	--scene=$(call ELEM5,$(@),2) \
	--images-dir=$(call ELEM5,$(@),1)/$(call ELEM5,$(@),2)/images \
	--sparse-dir=$(firstword $(^)) \
	--model-dir=$(@) \
	--iterations=30000 \
	--sh_degree=3
endef



define recipe-gsplat-post-filter
	@if [ true ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Running GSPLAT filter: $(@)"; \
		echo "-------------------------------------------------------------------"; \
	fi
	@echo "Input folder  : $(firstword $(^))/point_cloud/iterations_30000/point_cloud.ply"
	@echo "Output folder : $(@)/iterations_30000/point_cloud.ply"
endef


# projects/thumbvids/DJI_0150-thumb.MP4 : videos/DJI_0150.MP4
define recipe-thumbvid-folder
	@if [ true ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Creating thumbvids"; \
		echo "-------------------------------------------------------------------"; \
	fi
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

# the base roots:  png_0.60_900_none
base-roots := $(foreach format,$(format-roots),$(foreach fps,$(fps-roots),$(foreach width,$(width-roots),$(foreach filter,$(filter-roots),$(format)_$(fps)_$(width)_$(filter)))))
#$(info $(base-roots))

# Using roots above, these create folder names and wires the recipes and dependencies
# projects/DJI_0150-png_base_0.60_900/images
images-targets := $(foreach video,$(video-roots),$(projects-folder)/$(foreach base,$(base-roots),$(video)-$(base)/images))
#$(info $(base-targets))

## THUMBNAIL VIDEOS
# Use ffmpeg to create folder of images.  No dependencies, just to id.
# projects/DJI_0150-png_base_0.60_900/images : videos/DJI_0150.MP4 ; $(recipe-base-folder)
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(eval $(projects-folder)/$(video)-$(base)/images : $(videos-folder)/$(video).MP4 ; $$(recipe-base-folder))))


# COLMAP SPARSE MODEL 
# projects/DJI_0150-base_png_0.60_800/colmap
colmap-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(projects-folder)/$(video)-$(base)/colmap))
#$(info $(colmap-targets))
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(eval $(projects-folder)/$(video)-$(base)/colmap : $(projects-folder)/$(video)-$(base)/images ; $$(recipe-colmap-folder)$(newline))))


# COLMAP FILTERED SPARSE MODEL
# projects/DJI_0150-base_png_0.60_800/colmap/sparse/0
# projects/DJI_0150-base_png_0.60_800/colmap/sparse/0_filter1
# projects/DJI_0150-base_png_0.60_800/colmap/sparse/0_filter2
#
colmap-sparse-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(projects-folder)/$(video)-$(base)/colmap/sparse/$(model))))
#$(info $(colmap-sparse-targets))
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(eval $(projects-folder)/$(video)-$(base)/colmap/sparse/$(model) : $(projects-folder)/$(video)-$(base)/colmap ; $$(recipe-colmap-filters-folder)$(newline)))))

# Not really necessary unless you want to rebuild ALL stats, for example, if you change formats.
# projects/DJI_0150-png_base_0.60_1600/colmap/stats/model_analyzer-sparse-0_clean.json
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(eval $(projects-folder)/$(video)-$(base)/colmap/stats/model_analyzer-sparse-$(model).json : $(projects-folder)/$(video)-$(base)/colmap/sparse/$(model) ; $$(recipe-colmap-analyzer-folder)$(newline)))))


# GUASSIAN SPLAT the COLMAP models
# projects/DJI_0150-png_base_0.60_1600/gsplat
# projects/DJI_0150-png_base_0.60_1600/gsplat/0
# projects/DJI_0150-png_base_0.60_1600/gsplat/0_filter1
gsplat-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(projects-folder)/$(video)-$(base)/gsplat))
# projects/DJI_0145-base_png_1.00_900/gsplat : projects/DJI_0145-base_png_1.00_900/colmap/sparse/0 ; $(recipe-gsplat-folder)
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(eval $(projects-folder)/$(video)-$(base)/gsplat : $(projects-folder)/$(video)-$(base)/gsplat/0 ; $(newline))))
#
gsplat-targets-2 := $(foreach model,$(model-roots),$(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(projects-folder)/$(video)-$(tag)/gsplat/$(model))))
# projects/DJI_0145-base_png_1.00_900/gsplat/0_clean : projects/DJI_0145-base_png_1.00_900/colmap/sparse/0_clean ; $(recipe-gsplat-folder2)
$(foreach model,$(model-roots),$(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(eval $(projects-folder)/$(video)-$(tag)/gsplat/$(model) : $(projects-folder)/$(video)-$(tag)/colmap/sparse/$(model) ; $$(recipe-gsplat-folder2)$(newline)))))

# FILTER THE SPLATS
# projects/DJI_0150-png_0.60_1600_none/gsplat/0/point_cloud : projects/DJI_0150-png_0.60_1600_none/gsplat/0
# projects/DJI_0150-png_0.60_1600_none/gsplat/0/sfilt1 : projects/DJI_0150-png_0.60_1600_none/gsplat/0
# projects/DJI_0150-png_0.60_1600_none/gsplat/0_clean/sfilt2 : projects/DJI_0150-png_0.60_1600_none/gsplat/0/ iteration_30000/point_cloud.ply

gsplat-filter-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(foreach filter,$(splat-filter-roots),$(projects-folder)/$(video)-$(base)/gsplat/$(model)/$(filter)))))
#gsplat-filter-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(projects-folder)/$(video)-$(base)/gsplat))
#$(info $(gsplat-filter-targets))
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(foreach filter,$(splat-filter-roots), \
	$(eval $(projects-folder)/$(video)-$(base)/gsplat/$(model)/$(filter) : \
	$(projects-folder)/$(video)-$(base)/gsplat/$(model) ; \
	$$(recipe-gsplat-post-filter)$(newline) )))))
	

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

keepers := $(foreach video,$(video-roots),$(foreach model,$(model-roots),$(foreach filter,$(splat-filter-roots),$(projects-folder)/$(video)-png_1.00_1600_none/gsplat/$(model)/$(filter))))
#$(info $(keepers))

all-keepers: $(keepers)

show-point-clouds :
	find projects -mindepth 4 -maxdepth 7 -type f -path "*/gsplat/*/*/point_cloud.ply"

# DJI_0145-png_1.00_1600_none-0-point_cloud.qmd
define recipe-qmd-builder
	cp reports/_splat_template.qmd reports/gsp/$(@)
	sed -i "s|replace_qmd_name_here|$(call ELEM3,$(@),1)-$(call ELEM3,$(@),2)/gsplat/$(call ELEM3,$(@),3)/$(call ELEM2,$(call ELEM3,$(@),4),1)|g" reports/gsp/$@
endef

keeper-qmds := $(foreach video,$(video-roots),$(foreach model,0,$(foreach filter,point_cloud,$(video)-png_1.00_1600_none-$(model)-$(filter).qmd)))
#$(info $(keeper-qmds))
$(foreach video,$(video-roots),$(foreach model,0,$(foreach filter,point_cloud,$(eval $(video)-png_1.00_1600_none-$(model)-$(filter).qmd : $(projects-folder)/$(video)-png_1.00_1600_none/gsplat/$(model)/$(filter) ; $$(recipe-qmd-builder)$(newline)))))

all-keeper-qmds : $(keeper-qmds)

build-reports: all-keeper-qmds
	cd reports && poetry run quarto render

.PHONY : test0 relaxed
test1 : test1 ; $(recipe-test-recipe)
test2 : test1 ; $(recipe-test-recipe)

define recipe-test-recipe
	@if [ "$(firstword $(^))" = "" ]; then \
		echo "Building base / test1"; \
	else \
		echo "Building $(firstword $^)"; \
	fi
	@echo second
	@echo third
endef

