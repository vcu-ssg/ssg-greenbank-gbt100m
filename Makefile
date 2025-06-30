# Makefile

# The gsplat pipeline is managed through judicious naming of projects and folders providing
# significant flexibility of use.

-include Recipes.mak


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

# The pipeline will create either PNG or JPG.  JPG is smaller, but can 
# introduce artifacts into subsequent steps in the pipeline.
format-roots := jpg png

# Desired range of fps values.  0.20 -> 1 frame every 5 seconds.
fps-roots := 0.20 0.40 0.60 0.80 1.00 1.20 1.40 1.60 1.80 2.00 3.00 4.00 5.00

# Desired max width/height for images.  Will assume 16:9 or 9:16.
width-roots := 1600 1280 1024 800 3200

# Filters to be applied to images after they're pulled from video.
# For each filter-roots there must be a corresponding recipe-filtered-folder recipe
# that converts images from "base" to "filtered"
filter-roots := none color greyscale

# Models are colmap models like ./sparse/0  ./sparse/0_clean ./sparse/1 etc.
# 0 is base/default model. Others 
model-roots := 0 0_filter1 0_filter2 1 2 3

# GSPLAT post processing folders  (point_cloud is unprocessed)

splat-filter-roots := point_cloud sf0 sf1

# ----------------------

videos-folder = ./videos
projects-folder = ./projects
thumbvids-folder = ./docs/data/thumbvids

poetry-base = poetry run python scripts/cli.py
#poetry-base = echo
extract-options = --threads=16



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



# COLMAP FILTERED SPARSE MODEL
# projects/DJI_0150-png_0.60_800_none/colmap/0
# projects/DJI_0150-png_0.60_800_none/colmap/0_filter1
# projects/DJI_0150-png_0.60_800_none/colmap/0_filter2
#


colmap-sparse-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(projects-folder)/$(video)-$(base)/colmap/$(model))))
#$(info $(colmap-sparse-targets))
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(eval $(projects-folder)/$(video)-$(base)/colmap/$(model) : $(projects-folder)/$(video)-$(base)/$(if $(filter 0,$(model)),images,colmap/0) ; $$(recipe-colmap-folder)$(newline)))))
#$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(colmap-filters)),$(eval $(projects-folder)/$(video)-$(base)/colmap/$(model) : $(projects-folder)/$(video)-$(base)/colmap ; $$(recipe-colmap-folder)$(newline)))))

# Not really necessary unless you want to rebuild ALL stats, for example, if you change formats.
# projects/DJI_0150-png_base_0.60_1600/colmap/stats/model_analyzer-sparse-0_clean.json
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(eval $(projects-folder)/$(video)-$(base)/colmap/stats/model_analyzer-sparse-$(model).json : $(projects-folder)/$(video)-$(base)/colmap/sparse/$(model) ; $$(recipe-colmap-analyzer-folder)$(newline)))))


# GUASSIAN SPLAT the COLMAP models
# projects/DJI_0150-png_1.00_1600_none/gsplat/0
# projects/DJI_0150-png_1.00_1600_none/gsplat/0/point_cloud
# projects/DJI_0150-png_1.00_1600_none/gsplat/0_filter2/point_cloud


gsplat-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(projects-folder)/$(video)-$(base)/gsplat/$(model))))
# projects/DJI_0145-base_png_1.00_900/gsplat : projects/DJI_0145-base_png_1.00_900/colmap/sparse/0 ; $(recipe-gsplat-folder)
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots), \
	$(eval $(projects-folder)/$(video)-$(base)/gsplat/$(model) : \
	$(projects-folder)/$(video)-$(base)/gsplat/$(model)/point_cloud ; $(newline)))))


# FILTER THE SPLATS
# projects/DJI_0150-png_0.60_1600_none/gsplat/0/point_cloud : projects/DJI_0150-png_0.60_1600_none/gsplat/0
# projects/DJI_0150-png_0.60_1600_none/gsplat/0/sfilt1 : projects/DJI_0150-png_0.60_1600_none/gsplat/0
# projects/DJI_0150-png_0.60_1600_none/gsplat/0_clean/sfilt2 : projects/DJI_0150-png_0.60_1600_none/gsplat/0/ iteration_30000/point_cloud.ply

gsplat-filter-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(foreach filter,$(splat-filter-roots),$(projects-folder)/$(video)-$(base)/gsplat/$(model)/$(filter)))))
#gsplat-filter-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(projects-folder)/$(video)-$(base)/gsplat))
#$(info $(gsplat-filter-targets))
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(foreach filter,$(splat-filter-roots), \
	$(eval $(projects-folder)/$(video)-$(base)/gsplat/$(model)/$(filter) : \
	$(projects-folder)/$(video)-$(base)/colmap/$(model) ; \
	$$(recipe-gsplat-folder)$(newline) )))))
	

	
# MVS from COLMAP models
# projects/DJI_0150-png_0.60_1600_none/mvs
# projects/DJI_0150-png_0.60_1600_none/mvs/0
# projects/DJI_0150-png_0.60_1600_none/mvs/0/0_filter1
mvs-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(projects-folder)/$(video)-$(base)/mvs))
# projects/DJI_0145-base_png_1.00_900/gsplat : projects/DJI_0145-base_png_1.00_900/colmap/sparse/0 ; $(recipe-gsplat-folder)
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(eval $(projects-folder)/$(video)-$(base)/mvs : $(projects-folder)/$(video)-$(base)/mvs/0 ; $(newline))))
#
mvs-targets-2 := $(foreach model,$(model-roots),$(foreach video,$(video-roots),$(foreach tag,$(base-roots) $(tag-roots),$(projects-folder)/$(video)-$(tag)/mvs/$(model))))
# projects/DJI_0145-base_png_1.00_900/mvs/0_clean : projects/DJI_0145-base_png_1.00_900/colmap/sparse/0_clean ; $(recipe-openmvs-folder)
$(foreach model,$(model-roots),$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(eval \
	$(projects-folder)/$(video)-$(base)/mvs/$(model) : \
	$(projects-folder)/$(video)-$(base)/colmap/$(model) ; \
	$$(recipe-openmvs2-folder)$(newline)))))


# FILTER THE SPLATS
# projects/DJI_0150-png_0.60_1600_none/gsplat/0/point_cloud : projects/DJI_0150-png_0.60_1600_none/gsplat/0
# projects/DJI_0150-png_0.60_1600_none/gsplat/0/sfilt1 : projects/DJI_0150-png_0.60_1600_none/gsplat/0
# projects/DJI_0150-png_0.60_1600_none/gsplat/0_clean/sfilt2 : projects/DJI_0150-png_0.60_1600_none/gsplat/0/ iteration_30000/point_cloud.ply

mvs-filter-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(foreach filter,$(splat-filter-roots),$(projects-folder)/$(video)-$(base)/mvs/$(model)/$(filter)))))
#gsplat-filter-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(projects-folder)/$(video)-$(base)/gsplat))
#$(info $(gsplat-filter-targets))
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(foreach filter,$(splat-filter-roots), \
	$(eval $(projects-folder)/$(video)-$(base)/mvs/$(model)/$(filter) : \
	$(projects-folder)/$(video)-$(base)/mvs/$(model) ; \
	$$(recipe-mvs-post-filter)$(newline) )))))



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


source-images := $(foreach video,$(video-roots),$(projects-folder)/$(video)-png_1.00_1600_none/images/)
#$(info $(source-images))
combined-folder := projects/combined-png_1.00_1600_none/images
combine-images:
	mkdir -p $(combined-folder)
	@for dir in $(source-images); do \
		cp -Ru $$dir* $(combined-folder)/; \
	done

scenex := projects/DJI_0145-png_1.00_1600_none/mvs/0
clean-dense-mesh:
	poetry run python scripts/cli.py clean-dense-mesh \
		--input-file=$(scenex)/scene_dense_mesh.ply \
		--output-file=$(scenex)/scene_dense_mesh_cleaned.ply \
		--min-component-diag=0.5 \
		--k-neighbors=12 \
		--recompute-normals \
		--remove-duplicates \
		--remove-unref \
		--remove-zero-area \
		--binary

build-reports: thumbvids
	poetry run python scripts/cli.py \
	generate-project-reports \
	--projects-root=projects \
	--report-qmds=reports/prj \
	--report-data=docs/data
	cd reports && poetry run quarto render

scene := projects/DJI_0145-png_1.00_1600_none

# projects/DJI_0145-png_1.00_1600_none/mvs/0_filter1-0/ : projects/DJI_0145-png_1.00_1600_none/colmap/0_filter1

projects/DJI_0145-png_1.00_1600_none/mvs/0_filter1-0 : ; $(recipe-openmvs-folder)

test : projects/DJI_0145-png_1.00_1600_none/mvs/0_filter1-0
