# Makefile

# The gsplat pipeline is managed through judicious naming of projects and folders providing
# significant flexibility of use.

help:
	@echo Help goes here

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

#| Concept       | Values                                     | Meaning / What it controls                                                                                                                    | Independent from...                |
#| ------------- | ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
#| **Extractor** | `default`, `adaptive`, `highres`           | Controls **feature extraction parameters**:<br>• `max_image_size`<br>• optional DSP / octave settings<br>• GPU/threads always on              | matcher, mapper, masking, cleaning |
#| **Matcher**   | `default`, `fast`, `loop`, `guided`        | Controls **sequential matcher strategy**, e.g.:<br>• overlap<br>• loop detection<br>• guided matching                                         | extractor, mapper, masking, clean  |
#| **Mapper**    | `default`, `fast`, `robust`, `highquality` | Controls **mapper reconstruction parameters**:<br>• triangulation angles<br>• local BA iterations<br>• min track length<br>• other thresholds | extractor, matcher, masking, clean |
#| **Mask**      | `open`, `mask1`, `mask2`, ...              | Controls **type of masking filter to generate / apply**. Any value besides `open` becomes `--filter=<mask>`.                                  | extractor, matcher, mapper, clean  |
#| **Mask Mode** | `extractor`, `direct`                      | • `extractor` uses masks only during `feature_extractor`<br>• `direct` creates new masked images — affects **all following steps**            | extractor, matcher, mapper, clean  |
#| **Filtering** | `raw`, `clean`                             | Whether to run the **cleaner strategy** after matching (e.g. track length / reprojection error filters).                                      | all above                          |

model-roots := 0 1 2 3

# default, fast options
colmap-model-0 := mask=open extract=default match=fast mapper=fast
# apply mask to images, fast options
colmap-model-1 := mask=default mode=direct extract=default match=fast mapper=fast

# sharper edges around trusses, "2" with mask only during feature detection, "3" with masked images
colmap-model-2 := mask=default mode=extractor extract=highres match=loop mapper=robust
colmap-model-3 := mask=default mode=direct    extract=highres match=loop mapper=robust

# GSPLAT post processing folders  (point_cloud is unprocessed)

gsplat-model-0 := quality=default
gsplat-model-1 := quality=default

openmvs-model-0 := densify=fast mesh=fast refine=fast texture=fast
openmvs-model-1 := densify=highquality mesh=sharp refine=high texture=crisp


cfuse-model-0 := patchmatch=fast fusion=fast
cfuse-model-1 := patchmatch=highquality fusion=robust
cfuse-model-2 := patchmatch=default fusion=default

# ----------------------

videos-folder = ./videos
projects-folder = ./projects
thumbvids-folder = ./docs/data/thumbvids

poetry-base = poetry run python scripts/cli.py
#poetry-base = echo
extract-options = --threads=16


# ----------------------------------------
include recipes/Recipes-utils.mak
include recipes/Recipes-images.mak
include recipes/Recipes-colmap.mak
include recipes/Recipes-gsplat.mak
include recipes/Recipes-openmvs.mak
include recipes/Recipes-cfuse.mak
# ----------------------------------------

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

# Use ffmpeg to create folder of images.  No dependencies, just to id.
# projects/DJI_0150-png_base_0.60_900/images : videos/DJI_0150.MP4 ; $(recipe-base-folder)
$(foreach video,$(video-roots),\
	$(foreach base,$(base-roots), \
		$(eval $(projects-folder)/$(video)-$(base)/images : \
		$(videos-folder)/$(video).MP4 ; \
		$$(recipe-images-folder) \
		)))


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
$(foreach video,$(video-roots), \
	$(foreach base,$(base-roots), \
		$(foreach model,$(model-roots), \
			$(eval $(projects-folder)/$(video)-$(base)/colmap/$(model) : \
			$(projects-folder)/$(video)-$(base)/images ; \
			$$(recipe-colmap-model)$(newline) \
			))))

#$(projects-folder)/$(video)-$(base)/$(if $(filter 0,$(model)),images,colmap/0) ;

#$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(colmap-filters)),$(eval $(projects-folder)/$(video)-$(base)/colmap/$(model) : $(projects-folder)/$(video)-$(base)/colmap ; $$(recipe-colmap-folder)$(newline)))))

# Not really necessary unless you want to rebuild ALL stats, for example, if you change formats.
# projects/DJI_0150-png_base_0.60_1600/colmap/stats/model_analyzer-sparse-0_clean.json
$(foreach video,$(video-roots), \
	$(foreach base,$(base-roots), \
		$(foreach model,$(model-roots), \
			$(eval $(projects-folder)/$(video)-$(base)/colmap/stats/model_analyzer-sparse-$(model).json : \
			$(projects-folder)/$(video)-$(base)/colmap/sparse/$(model) ; \
			$$(recipe-colmap-analyzer-folder)$(newline) \
			))))


# GUASSIAN SPLAT the COLMAP models
# projects/DJI_0150-png_1.00_1600_none/gsplat/0
# projects/DJI_0150-png_1.00_1600_none/gsplat/0/point_cloud
# projects/DJI_0150-png_1.00_1600_none/gsplat/0_filter2/point_cloud


# FILTER THE SPLATS
# projects/DJI_0150-png_0.60_1600_none/gsplat/0/point_cloud : projects/DJI_0150-png_0.60_1600_none/gsplat/0
# projects/DJI_0150-png_0.60_1600_none/gsplat/0/sfilt1 : projects/DJI_0150-png_0.60_1600_none/gsplat/0
# projects/DJI_0150-png_0.60_1600_none/gsplat/0_clean/sfilt2 : projects/DJI_0150-png_0.60_1600_none/gsplat/0/ iteration_30000/point_cloud.ply

gsplat-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(projects-folder)/$(video)-$(base)/gsplat/$(model))))
#gsplat-filter-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(projects-folder)/$(video)-$(base)/gsplat))
#$(info $(gsplat-filter-targets))
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots), \
	$(eval $(projects-folder)/$(video)-$(base)/gsplat/$(model) : \
	$(projects-folder)/$(video)-$(base)/colmap/$(model) ; \
	$$(recipe-gsplat-model)$(newline) ))))
	

	
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
	$$(recipe-openmvs-model)$(newline)))))


# FILTER THE SPLATS
# projects/DJI_0150-png_0.60_1600_none/gsplat/0/point_cloud : projects/DJI_0150-png_0.60_1600_none/gsplat/0
# projects/DJI_0150-png_0.60_1600_none/gsplat/0/sfilt1 : projects/DJI_0150-png_0.60_1600_none/gsplat/0
# projects/DJI_0150-png_0.60_1600_none/gsplat/0_clean/sfilt2 : projects/DJI_0150-png_0.60_1600_none/gsplat/0/ iteration_30000/point_cloud.ply

mvs-filter-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(projects-folder)/$(video)-$(base)/mvs/$(model))))
#gsplat-filter-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(projects-folder)/$(video)-$(base)/gsplat))
#$(info $(gsplat-filter-targets))
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(foreach filter,$(splat-filter-roots), \
	$(eval $(projects-folder)/$(video)-$(base)/mvs/$(model)/$(filter) : \
	$(projects-folder)/$(video)-$(base)/mvs/$(model) ; \
	$$(recipe-mvs-post-filter)$(newline) )))))


cfuse-targets := $(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots),$(projects-folder)/$(video)-$(base)/cfuse/$(model))))
$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots), \
	$(eval $(projects-folder)/$(video)-$(base)/cfuse/$(model) : \
	$(projects-folder)/$(video)-$(base)/colmap/$(model) ; \
	$$(recipe-cfuse-model)$(newline) ))))

##
## Build all three
## projects/DJI_0146-png_1.00_1600_none/all/0  -> gsplat/0 + mvs/0 + cfuse/0  -> colmap/0

$(foreach video,$(video-roots),$(foreach base,$(base-roots),$(foreach model,$(model-roots), \
	$(eval $(projects-folder)/$(video)-$(base)/all/$(model) : \
	$(projects-folder)/$(video)-$(base)/gsplat/$(model) \
	$(projects-folder)/$(video)-$(base)/mvs/$(model) \
	$(projects-folder)/$(video)-$(base)/cfuse/$(model) ; \
	))))



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
	rm -f reports/prj/*.*
	poetry run python scripts/cli.py \
	generate-project-reports \
	--projects-root=projects \
	--report-qmds=reports/prj \
	--report-data=docs/data
	cd reports && poetry run quarto render

preview : build-reports
	cd reports && poetry run quarto preview

scene := projects/DJI_0145-png_1.00_1600_none

# projects/DJI_0145-png_1.00_1600_none/mvs/0_filter1-0/ : projects/DJI_0145-png_1.00_1600_none/colmap/0_filter1

projects/DJI_0145-png_1.00_1600_none/mvs/0_filter1-0 : ; $(recipe-openmvs-folder)


dep := projects/DJI_0145-png_1.00_800_none/images
tar := projects/DJI_0145-png_1.00_800_none/colmap/4
test : 
	@echo "----------------------------------------------------------------------"
	poetry run python scripts/cli.py \
	generate-masks \
	--images-dir $(dep) \
	--output-mask-dir $(tar)/masks \
	--output-masked-image-dir $(tar)/images

