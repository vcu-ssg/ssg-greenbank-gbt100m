

#
# Helpful macros for parsing folder names
#

ELEM1 = $(word $2,$(subst -, ,$1))
ELEM2 = $(word $2,$(subst ., ,$(subst -, ,$1)))
ELEM3 = $(word $2,$(subst /, ,$(subst -, ,$1)))
ELEM4 = $(word $2,$(subst _, ,$1))
ELEM5 = $(word $2,$(subst /, ,$1))
words_3_to_n = $(subst $(space),_,$(wordlist 3, $(words $(subst _, ,$1)), $(subst _, ,$1)))

define MVS_PATH
$(call ELEM5,$(1),1)/$(call ELEM5,$(1),2)/mvs/$(call ELEM5,$(1),4)
endef

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


define recipe-colmap-feature-extracter
	echo "COLMAP feature extractor" ; \
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 colmap \
	colmap feature_extractor \
		--database_path /$(@)/db.db \
		--image_path /$(call ELEM5,$(@),1)/$(call ELEM5,$(@),2)/images \
		--ImageReader.single_camera  1 \
		--ImageReader.camera_model  PINHOLE \
		--SiftExtraction.use_gpu 0 \
		--SiftExtraction.num_threads   8 \
		--SiftExtraction.estimate_affine_shape  0 \
		--SiftExtraction.domain_size_pooling 0 \
		--SiftExtraction.max_image_size 3200 ;
endef

define recipe-colmap-feature-extracter-with-masks
	echo "COLMAP feature extractor with masks" ; \
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 colmap \
	colmap feature_extractor \
		--database_path /$(@)/db.db \
		--image_path /$(call ELEM5,$(@),1)/$(call ELEM5,$(@),2)/images \
		--ImageReader.mask_path /$(@)/masks \
		--ImageReader.single_camera  1 \
		--ImageReader.camera_model  PINHOLE \
		--SiftExtraction.use_gpu 0 \
		--SiftExtraction.num_threads   8 \
		--SiftExtraction.estimate_affine_shape  0 \
		--SiftExtraction.domain_size_pooling 0 \
		--SiftExtraction.max_image_size 3200 ;
endef

define recipe-colmap-feature-extracter-with-masks2
	echo "COLMAP feature extractor with masks" ; \
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 colmap \
	colmap feature_extractor \
		--database_path /$(@)/db.db \
		--image_path /$(call ELEM5,$(@),1)/$(call ELEM5,$(@),2)/images \
		--ImageReader.mask_path /$(@)/masks \
		--ImageReader.single_camera 1 \
		--ImageReader.camera_model PINHOLE \
		--SiftExtraction.use_gpu 0 \
		--SiftExtraction.num_threads 8 \
		--SiftExtraction.max_image_size 3200 \
		--SiftExtraction.max_num_features 65536 \
		--SiftExtraction.peak_threshold 0.002 \
		--SiftExtraction.edge_threshold 5 \
		--SiftExtraction.octave_resolution 4 ;
endef


define recipe-colmap-sequential-matcher
	echo "COLMAP sequential matcher" ; \
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 colmap \
	colmap sequential_matcher \
		--database_path /$(@)/db.db \
		--SiftMatching.use_gpu 0 \
		--SiftMatching.num_threads 8 \
		--SequentialMatching.overlap 10 ;
endef

define recipe-colmap-mapper
	echo "COLMAP mapper" ; \
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 colmap \
	colmap mapper \
		--database_path /$(@)/db.db \
		--image_path /$(call ELEM5,$(@),1)/$(call ELEM5,$(@),2)/images \
		--output_path /$(@) \
		--Mapper.num_threads 8 ;
endef

define recipe-colmap-model-converter
	echo "COLMAP model converter" ; \
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 colmap \
	colmap model_converter \
		--input_path /$(@)/0 \
		--output_path /$(@)/0/points3D.ply \
		--output_type PLY ;
endef


# $(@) -> projects/DJI_0145-png_1.00_1600_none/colmap/1
define recipe-colmap-model-1
	echo "-------------------------------------------------------------------"; \
	echo "COLMAP and Mask:  $(call ELEM5,$(@),4)"; \
	echo "Target: $(@)"; \
	echo "Depend: $(firstword $(^))"; \
	echo "-------------------------------------------------------------------"; \
	mkdir -p $(@) ; \
	$(recipe-colmap-feature-extracter) \
	$(recipe-colmap-sequential-matcher) \
	$(recipe-colmap-mapper) \
	$(recipe-colmap-model-converter) \
	mv $(@)/0 $(@)/sparse ;
endef


define recipe-colmap-model-2
	echo "-------------------------------------------------------------------"; \
	echo "COLMAP and Mask:  $(call ELEM5,$(@),4)"; \
	echo "Target: $(@)"; \
	echo "Depend: $(firstword $(^))"; \
	echo "-------------------------------------------------------------------"; \
	mkdir -p $(@) ; \
	poetry run python scripts/cli.py generate-masks \
	--images-dir=$(call ELEM5,$(@),1)/$(call ELEM5,$(@),2)/images \
	--output-mask-dir=$(@)/masks ; \
	$(recipe-colmap-feature-extracter-with-masks) \
	$(recipe-colmap-sequential-matcher) \
	$(recipe-colmap-mapper) \
	$(recipe-colmap-model-converter) \
	mv $(@)/0 $(@)/sparse ;
endef

define recipe-colmap-model-3
	echo "-------------------------------------------------------------------"; \
	echo "COLMAP and Mask:  $(call ELEM5,$(@),4)"; \
	echo "Target: $(@)"; \
	echo "Depend: $(firstword $(^))"; \
	echo "-------------------------------------------------------------------"; \
	mkdir -p $(@) ; \
	poetry run python scripts/cli.py generate-masks \
	--images-dir=$(call ELEM5,$(@),1)/$(call ELEM5,$(@),2)/images \
	--output-mask-dir=$(@)/masks ; \
	$(recipe-colmap-feature-extracter-with-masks2) \
	$(recipe-colmap-sequential-matcher) \
	$(recipe-colmap-mapper) \
	$(recipe-colmap-model-converter) \
	mv $(@)/0 $(@)/sparse ;
endef

#  projects/DJI_0145-png_1.00_900_none/colmap/0 : projects/DJI_0145-png_1.00_900_none/images 
#  projects/DJI_0145-png_1.00_900_NONE/colmap/0_filter1 : projects/DJI_0145-png_1.00_900/colmap/0 

define recipe-colmap-folder
	@if [ "$(call ELEM5,$(@),4)" != "0" ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Running applying COLMAP filter:  $(call ELEM5,$(@),4)"; \
		echo "-------------------------------------------------------------------"; \
	else \
		echo "-------------------------------------------------------------------"; \
		echo "Running COLMAP $(call ELEM5,$(@),2)"; \
		echo "-------------------------------------------------------------------"; \
	fi
	@if [ "$(call ELEM5,$(@),4)" = "0" ]; then \
		$(poetry-base) run-colmap-pipeline-cli --image-path=$(firstword $(^)) --output-model-path=$(@); \
	elif [ "$(call ELEM5,$(@),4)" = "1" ]; then \
		$(recipe-colmap-model-1) \
	elif [ "$(call ELEM5,$(@),4)" = "2" ]; then \
		$(recipe-colmap-model-2) \
	elif [ "$(call ELEM5,$(@),4)" = "3" ]; then \
		$(recipe-colmap-model-3) \
	elif [ "$(call ELEM5,$(@),4)" = "0_filter1" ]; then \
		$(poetry-base) colmap-model-cleaner \
		--input-model-folder=$(firstword $(^))/sparse \
		--output-model-folder=$(@)/sparse/0 \
		--min-track-len=5 \
		--max-reproj-error=1.0 \
		--min-tri-angle=5.0	; \
	elif [ "$(call ELEM5,$(@),4)" = "0_filter2" ]; then \
		poetry run python scripts/cli.py colmap-model-cleaner \
		--input-model-folder=$(firstword $(^))/sparse \
		--output-model-folder=$(@)/sparse/0 \
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
#   projects/DJI_0150-png_base_0.60_1600/gsplat/0/point_cloud : projects/DJI_0150-png_base_0.60_1600/colmap/0 ; $(recipe-gsplat-folder)
define recipe-gsplat-folder
	@if [ true ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Running GSPLAT: $(call ELEM5,$(@),2)"; \
		echo " target: $(@)"; \
		echo " Dependent: $(firstword $(^))"; \
		echo "-------------------------------------------------------------------"; \
	fi
	@if [ "1" = "1" ]; then \
	$(poetry-base) run-gsplat-pipeline \
	--scene=$(call ELEM5,$(@),2) \
	--images-dir=$(call ELEM5,$(@),1)/$(call ELEM5,$(@),2)/images \
	--sparse-dir=$(firstword $(^))/sparse \
	--model-dir=$(@) \
	--iterations=30000 \
	--sh_degree=3; \
	fi
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

# projects/DJI_0145-png_1.00_1600_none/mvs/0 : projects/DJI_0145-png_1.00_1600_none/colmap/0
define recipe-openmvs-folderxxx
# output-folder: projects/DJI_0145-png_1.00_1600_none/mvs/0
# sparse-model-folder: projects/DJI_0145-png_1.00_1600_none/colmap/0
# image-folder: projects/DJI_0145-png_1.00_1600_none/images
	@if [ "1" = "1" ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Running MVS: $(call ELEM5,$(@),2)"; \
		echo " Target: $(@)"; \
		echo " Dependent: $(firstword $(^))"; \
		echo "-------------------------------------------------------------------"; \
	fi
	@if [ "1" = "1" ]; then \
		$(poetry-base) run-openmvs-pipeline \
		--image-folder $(call ELEM5,$(@),1)/$(call ELEM5,$(@),2)/images \
		--sparse-model-folder $(firstword $(^)) \
		--mvs-output-folder $(@) ; \
	fi
endef



define recipe-openmvs-folder 
	# step1:
	@if [ "1" = "1" ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Running MVS: $(@)"; \
		echo " MVSPATH: $(call MVS_PATH,$(@))"; \
		echo " Dependent: $(firstword $(^))"; \
		echo "-------------------------------------------------------------------"; \
	fi
	@echo "----------------------------------------------------------------------"
	@echo "InterfaceCOLMAP"
	@echo "----------------------------------------------------------------------"
	mkdir -p $(call MVS_PATH,$(@))/work
	chmod -R u+w $(call MVS_PATH,$(@))/work
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	InterfaceCOLMAP \
	-i /$(call MVS_PATH,$(@))/../../colmap/0 \
	-o /$(call MVS_PATH,$(@))/scene.mvs \
	-w /$(call MVS_PATH,$(@))/work \
	--image-folder ../../../images \
	--max-threads 0 \
	--binary 1 \
	--normalize 0 \
	--force-points 1 \
	--no-points 0 \
	--common-intrinsics 0
	@echo "----------------------------------------------------------------------"
	@echo "DensifyPointCloud"
	@echo "----------------------------------------------------------------------"
	# step2:
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	DensifyPointCloud \
	-i /$(call MVS_PATH,$(@))/scene.mvs \
	-o /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 \
	--max-threads 0 \
	--resolution-level 1 \
	--max-resolution 1600 \
	--min-resolution 640 \
	--iters 4 \
	--geometric-iters 2 \
	--estimate-colors 2 \
	--estimate-normals 2 \
	--number-views 8 \
	--number-views-fuse 2 \
	--fusion-mode 0 \
	--fusion-filter 2 \
	--postprocess-dmaps 1 \
	--estimate-roi 2 \
	--crop-to-roi 1 \
	--roi-border 10
	@echo "----------------------------------------------------------------------"
	@echo "ReconstructMesh"
	@echo "----------------------------------------------------------------------"
	# step3:
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	ReconstructMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh.ply \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 \
	--max-threads 0 \
	--min-point-distance 1.5 \
	--remove-spurious 20 \
	--remove-spikes 1 \
	--close-holes 30 \
	--smooth 2 \
	--decimate 1 \
	--edge-length 0 \
	--free-space-support 0 \
	--quality-factor 1 \
	--thickness-factor 1 \
	--crop-to-roi 1
	@echo "----------------------------------------------------------------------"
	@echo "RefineMesh"
	@echo "----------------------------------------------------------------------"
	# step4:
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	RefineMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-m /$(call MVS_PATH,$(@))/scene_dense_mesh.ply \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh_refined.ply \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 \
	--resolution-level 1 \
	--close-holes 30 \
	--decimate 0.25 \
	--ensure-edge-size 1 \
	--max-views 8 \
	--regularity-weight 0.2 \
	--scales 2 \
	--scale-step 0.5
	@echo "----------------------------------------------------------------------"
	@echo "TextureMesh"
	@echo "----------------------------------------------------------------------"
	# step 5
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	TextureMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-m /$(call MVS_PATH,$(@))/scene_dense_mesh_refined.ply \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh_texture.glb \
	-w /$(call MVS_PATH,$(@))/work \
	--verbosity 2 \
	--cuda-device -1 \
	--export-type glb \
	--max-threads 0 \
	--decimate 1 \
	--close-holes 30 \
	--resolution-level 0 \
	--min-resolution 640 \
	--outlier-threshold 0.06 \
	--cost-smoothness-ratio 0.1 \
	--virtual-face-images 3 \
	--global-seam-leveling 1 \
	--local-seam-leveling 1 \
	--texture-size-multiple 0 \
	--patch-packing-heuristic 3 \
	--empty-color 16777215 \
	--sharpness-weight 0.5 \
	--max-texture-size 8192
	@if [ "1" = "1" ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Done with MVS: $(@)"; \
		echo "MVSPATH: $(call MVS_PATH,$(@))"; \
		echo "Dependent: $(firstword $(^))"; \
		echo "-------------------------------------------------------------------"; \
	fi
endef


define recipe-openmvsx-folder 
	# step1:
	@if [ "1" = "1" ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Running MVS: $(@)"; \
		echo " MVSPATH: $(call MVS_PATH,$(@))"; \
		echo " Dependent: $(firstword $(^))"; \
		echo "-------------------------------------------------------------------"; \
	fi
	@echo "----------------------------------------------------------------------"
	@echo "InterfaceCOLMAP"
	@echo "----------------------------------------------------------------------"
	mkdir -p $(call MVS_PATH,$(@))/work
	chmod -R u+w $(call MVS_PATH,$(@))/work
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	InterfaceCOLMAP \
	-i /$(call MVS_PATH,$(@))/../../colmap/0 \
	-o /$(call MVS_PATH,$(@))/scene.mvs \
	-w /$(call MVS_PATH,$(@))/work \
	--image-folder ../../../images \
	--max-threads 0 \
	--binary 1 \
	--normalize 0 \
	--force-points 1 \
	--no-points 0 \
	--common-intrinsics 0
	@echo "----------------------------------------------------------------------"
	@echo "DensifyPointCloud"
	@echo "----------------------------------------------------------------------"
	# step2:
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	DensifyPointCloud \
	-i /$(call MVS_PATH,$(@))/scene.mvs \
	-o /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 \
	--max-threads 12 \
	--resolution-level 0 \
	--max-resolution 3200 \
	--min-resolution 640 \
	--iters 4 \
	--geometric-iters 6 \
	--estimate-colors 2 \
	--estimate-normals 2 \
	--number-views 12 \
	--number-views-fuse 4 \
	--fusion-mode 0 \
	--fusion-filter 2 \
	--postprocess-dmaps 1 \
	--estimate-roi 2 \
	--crop-to-roi 1 \
	--roi-border 10
	@echo "----------------------------------------------------------------------"
	@echo "ReconstructMesh"
	@echo "----------------------------------------------------------------------"
	# step3:
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	ReconstructMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh.ply \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 \
	--max-threads 0 \
	--min-point-distance 0.2 \
	--remove-spurious 20 \
	--remove-spikes 1 \
	--close-holes 10 \
	--smooth 2 \
	--decimate 1 \
	--edge-length 0 \
	--free-space-support 0 \
	--quality-factor 1 \
	--thickness-factor 1 \
	--crop-to-roi 1
	@echo "----------------------------------------------------------------------"
	@echo "RefineMesh"
	@echo "----------------------------------------------------------------------"
	# step4:
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	RefineMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-m /$(call MVS_PATH,$(@))/scene_dense_mesh.ply \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh_refined.ply \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 \
	--resolution-level 1 \
	--close-holes 10 \
	--decimate 1.0 \
	--ensure-edge-size 1 \
	--max-views 8 \
	--regularity-weight 0.2 \
	--scales 2 \
	--scale-step 0.5
	@echo "----------------------------------------------------------------------"
	@echo "TextureMesh"
	@echo "----------------------------------------------------------------------"
	# step 5
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	TextureMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-m /$(call MVS_PATH,$(@))/scene_dense_mesh_refined.ply \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh_texture.glb \
	-w /$(call MVS_PATH,$(@))/work \
	--verbosity 2 \
	--cuda-device -1 \
	--export-type glb \
	--max-threads 0 \
	--decimate 1 \
	--close-holes 30 \
	--resolution-level 0 \
	--min-resolution 640 \
	--outlier-threshold 0.06 \
	--cost-smoothness-ratio 0.1 \
	--virtual-face-images 3 \
	--global-seam-leveling 1 \
	--local-seam-leveling 1 \
	--texture-size-multiple 0 \
	--patch-packing-heuristic 3 \
	--empty-color 16777215 \
	--sharpness-weight 0.5 \
	--max-texture-size 8192
	@if [ "1" = "1" ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Done with MVS: $(@)"; \
		echo "MVSPATH: $(call MVS_PATH,$(@))"; \
		echo "Dependent: $(firstword $(^))"; \
		echo "-------------------------------------------------------------------"; \
	fi
endef


define recipe-openmvs2-folderxx 
	@if [ "1" = "1" ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Running MVS: $(@)"; \
		echo " MVSPATH: $(call MVS_PATH,$(@))"; \
		echo " Dependent: $(firstword $(^))"; \
		echo "-------------------------------------------------------------------"; \
	fi

	@echo "----------------------------------------------------------------------"
	@echo "InterfaceCOLMAP"
	@echo "----------------------------------------------------------------------"
	mkdir -p $(call MVS_PATH,$(@))/work
	chmod -R u+w $(call MVS_PATH,$(@))/work
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	InterfaceCOLMAP \
	-i /$(call MVS_PATH,$(@))/../../colmap/0 \
	-o /$(call MVS_PATH,$(@))/scene.mvs \
	-w /$(call MVS_PATH,$(@))/work \
	--image-folder ../../../images \
	--max-threads 0 \
	--binary 1 \
	--normalize 0 \
	--force-points 1 \
	--no-points 0 \
	--common-intrinsics 0

	@echo "----------------------------------------------------------------------"
	@echo "DensifyPointCloud"
	@echo "----------------------------------------------------------------------"
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	DensifyPointCloud \
	-i /$(call MVS_PATH,$(@))/scene.mvs \
	-o /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 \
	--max-threads 8 \
	--resolution-level 1 \
	--max-resolution 2400 \
	--min-resolution 800 \
	--iters 4 \
	--geometric-iters 6 \
	--estimate-colors 2 \
	--estimate-normals 2 \
	--number-views 10 \
	--number-views-fuse 2 \
	--fusion-mode 0 \
	--fusion-filter 2 \
	--postprocess-dmaps 1 \
	--estimate-roi 2 \
	--crop-to-roi 1 \
	--roi-border 8

	@echo "----------------------------------------------------------------------"
	@echo "ReconstructMesh"
	@echo "----------------------------------------------------------------------"
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	ReconstructMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh.ply \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 \
	--max-threads 8 \
	--min-point-distance 0.2 \
	--remove-spurious 20 \
	--remove-spikes 1 \
	--close-holes 8 \
	--smooth 2 \
	--decimate 1 \
	--edge-length 0 \
	--free-space-support 0 \
	--quality-factor 1 \
	--thickness-factor 1 \
	--crop-to-roi 1

	@echo "----------------------------------------------------------------------"
	@echo "RefineMesh"
	@echo "----------------------------------------------------------------------"
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	RefineMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-m /$(call MVS_PATH,$(@))/scene_dense_mesh.ply \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh_refined.ply \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 \
	--resolution-level 1 \
	--close-holes 8 \
	--decimate 1.0 \
	--ensure-edge-size 1 \
	--max-views 8 \
	--regularity-weight 0.2 \
	--scales 2 \
	--scale-step 0.5

	@echo "----------------------------------------------------------------------"
	@echo "TextureMesh"
	@echo "----------------------------------------------------------------------"
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	TextureMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-m /$(call MVS_PATH,$(@))/scene_dense_mesh_refined.ply \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh_texture.glb \
	-w /$(call MVS_PATH,$(@))/work \
	--verbosity 2 \
	--cuda-device -1 \
	--export-type glb \
	--max-threads 8 \
	--decimate 1 \
	--close-holes 15 \
	--resolution-level 0 \
	--min-resolution 640 \
	--outlier-threshold 0.05 \
	--cost-smoothness-ratio 0.1 \
	--virtual-face-images 3 \
	--global-seam-leveling 1 \
	--local-seam-leveling 1 \
	--texture-size-multiple 0 \
	--patch-packing-heuristic 3 \
	--empty-color 16777215 \
	--sharpness-weight 0.5 \
	--max-texture-size 8192

	@if [ "1" = "1" ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Done with MVS: $(@)"; \
		echo "MVSPATH: $(call MVS_PATH,$(@))"; \
		echo "Dependent: $(firstword $(^))"; \
		echo "-------------------------------------------------------------------"; \
	fi
endef


define recipe-openmvs2-folder 
	@if [ "1" = "1" ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Running MVS: $(@)"; \
		echo " MVSPATH: $(call MVS_PATH,$(@))"; \
		echo " Dependent: $(firstword $(^))"; \
		echo "-------------------------------------------------------------------"; \
	fi

	@echo "----------------------------------------------------------------------"
	@echo "InterfaceCOLMAP"
	@echo "----------------------------------------------------------------------"
	mkdir -p $(call MVS_PATH,$(@))/work
	chmod -R u+w $(call MVS_PATH,$(@))/work
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	InterfaceCOLMAP \
	-i /$(call MVS_PATH,$(@))/../../colmap/0 \
	-o /$(call MVS_PATH,$(@))/scene.mvs \
	-w /$(call MVS_PATH,$(@))/work \
	--image-folder ../../../images \
	--max-threads 20 \
	--binary 1 \
	--normalize 0 \
	--force-points 1 \
	--no-points 0 \
	--common-intrinsics 0

	@echo "----------------------------------------------------------------------"
	@echo "DensifyPointCloud"
	@echo "----------------------------------------------------------------------"
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	DensifyPointCloud \
	-i /$(call MVS_PATH,$(@))/scene.mvs \
	-o /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 \
	--max-threads 20 \
	--resolution-level 1 \
	--max-resolution 2400 \
	--min-resolution 800 \
	--iters 4 \
	--geometric-iters 6 \
	--estimate-colors 2 \
	--estimate-normals 2 \
	--number-views 10 \
	--number-views-fuse 2 \
	--fusion-mode 0 \
	--fusion-filter 2 \
	--postprocess-dmaps 1 \
	--estimate-roi 2 \
	--crop-to-roi 1 \
	--roi-border 8

	@echo "----------------------------------------------------------------------"
	@echo "ReconstructMesh"
	@echo "----------------------------------------------------------------------"
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	ReconstructMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh.ply \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 \
	--max-threads 20 \
	--min-point-distance 0.2 \
	--remove-spurious 20 \
	--remove-spikes 1 \
	--close-holes 8 \
	--smooth 2 \
	--decimate 1 \
	--edge-length 0 \
	--free-space-support 0 \
	--quality-factor 1 \
	--thickness-factor 1 \
	--crop-to-roi 1

	@echo "----------------------------------------------------------------------"
	@echo "RefineMesh"
	@echo "----------------------------------------------------------------------"
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	RefineMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-m /$(call MVS_PATH,$(@))/scene_dense_mesh.ply \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh_refined.ply \
	-w /$(call MVS_PATH,$(@))/work \
	--cuda-device -1 \
	--max-threads 20 \
	--resolution-level 1 \
	--close-holes 8 \
	--decimate 1.0 \
	--ensure-edge-size 1 \
	--max-views 8 \
	--regularity-weight 0.2 \
	--scales 2 \
	--scale-step 0.5

	@echo "----------------------------------------------------------------------"
	@echo "TextureMesh"
	@echo "----------------------------------------------------------------------"
	docker compose -f ./docker/docker-compose.yml \
	run --rm --user 1000:1000 openmvs \
	TextureMesh \
	-i /$(call MVS_PATH,$(@))/scene_dense.mvs \
	-m /$(call MVS_PATH,$(@))/scene_dense_mesh_refined.ply \
	-o /$(call MVS_PATH,$(@))/scene_dense_mesh_texture.glb \
	-w /$(call MVS_PATH,$(@))/work \
	--verbosity 2 \
	--cuda-device -1 \
	--export-type glb \
	--max-threads 20 \
	--decimate 1 \
	--close-holes 8 \
	--resolution-level 0 \
	--min-resolution 640 \
	--outlier-threshold 0.05 \
	--cost-smoothness-ratio 0.1 \
	--virtual-face-images 1 \
	--global-seam-leveling 0 \
	--local-seam-leveling 1 \
	--texture-size-multiple 0 \
	--patch-packing-heuristic 3 \
	--empty-color 16777215 \
	--sharpness-weight 0.5 \
	--max-texture-size 4096

	@if [ "1" = "1" ]; then \
		echo "-------------------------------------------------------------------"; \
		echo "Done with MVS: $(@)"; \
		echo "MVSPATH: $(call MVS_PATH,$(@))"; \
		echo "Dependent: $(firstword $(^))"; \
		echo "-------------------------------------------------------------------"; \
	fi
endef
