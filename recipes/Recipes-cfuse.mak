

# ---------------------------
# PatchMatchStereo options
# ---------------------------
define cfuse-patchmatch-default
	--PatchMatchStereo.geom_consistency true \
	--PatchMatchStereo.num_samples 15 \
	--PatchMatchStereo.num_iterations 5 \
	--PatchMatchStereo.window_radius 5
endef

define cfuse-patchmatch-fast
	--PatchMatchStereo.geom_consistency false \
	--PatchMatchStereo.num_samples 7 \
	--PatchMatchStereo.num_iterations 3 \
	--PatchMatchStereo.window_radius 3
endef

define cfuse-patchmatch-highquality
	--PatchMatchStereo.geom_consistency true \
	--PatchMatchStereo.num_samples 20 \
	--PatchMatchStereo.num_iterations 7 \
	--PatchMatchStereo.window_radius 7
endef


# ---------------------------
# StereoFusion options
# ---------------------------
define cfuse-fusion-default
	--StereoFusion.min_num_pixels 3 \
	--StereoFusion.max_reproj_error 2 \
	--StereoFusion.max_depth_error 0.01 \
	--StereoFusion.max_normal_error 10
endef

define cfuse-fusion-robust
	--StereoFusion.min_num_pixels 5 \
	--StereoFusion.max_reproj_error 1.5 \
	--StereoFusion.max_depth_error 0.005 \
	--StereoFusion.max_normal_error 5
endef

define cfuse-fusion-fast
	--StereoFusion.min_num_pixels 2 \
	--StereoFusion.max_reproj_error 3 \
	--StereoFusion.max_depth_error 0.02 \
	--StereoFusion.max_normal_error 15
endef


# ---------------------------
# Dynamic master recipe
# ---------------------------
define recipe-cfuse-model
	@echo "==================================================================="; \
	echo "COLMAP CFUSE MODEL: $(call ELEM5,$(@),4)"; \
	echo "Dependent: $(firstword $(^))"; \
	echo "Features: $(cfuse-model-$(call ELEM5,$(@),4))"; \
	echo "==================================================================="; \
	if [ -n "$(call ELEM5,$(@),4)" ]; then \
		mkdir -p $(@); \
		{ \
		QUALITY_STR="$(cfuse-model-$(call ELEM5,$(@),4))"; \
		if echo "$$QUALITY_STR" | grep -q "patchmatch=fast"; then \
			PATCHMATCH_OPTS="$(cfuse-patchmatch-fast)"; \
		elif echo "$$QUALITY_STR" | grep -q "patchmatch=highquality"; then \
			PATCHMATCH_OPTS="$(cfuse-patchmatch-highquality)"; \
		else \
			PATCHMATCH_OPTS="$(cfuse-patchmatch-default)"; \
		fi; \
		if echo "$$QUALITY_STR" | grep -q "fusion=robust"; then \
			FUSION_OPTS="$(cfuse-fusion-robust)"; \
		elif echo "$$QUALITY_STR" | grep -q "fusion=fast"; then \
			FUSION_OPTS="$(cfuse-fusion-fast)"; \
		else \
			FUSION_OPTS="$(cfuse-fusion-default)"; \
		fi; \
		echo "PatchMatchStereo options: $$PATCHMATCH_OPTS"; \
		echo "StereoFusion options: $$FUSION_OPTS"; \
		docker compose -f ./docker/docker-compose.yml \
		run --rm --user 1000:1000 colmap \
		colmap image_undistorter \
			--image_path /$(call ELEM5,$(@),1)/$(call ELEM5,$(@),2)/images \
			--input_path /$(@)/sparse \
			--output_path /$(@)/dense; \
		docker compose -f ./docker/docker-compose.yml \
		run --rm --user 1000:1000 colmap \
		colmap patch_match_stereo \
			--workspace_path /$(@)/dense \
			--workspace_format COLMAP \
			$$PATCHMATCH_OPTS; \
		docker compose -f ./docker/docker-compose.yml \
		run --rm --user 1000:1000 colmap \
		colmap stereo_fusion \
			--workspace_path /$(@)/dense \
			--workspace_format COLMAP \
			--output_path /$(@)/dense/fused.ply \
			$$FUSION_OPTS; \
		}; \
	else \
		echo "Invalid model: $(call ELEM5,$(@),4)"; \
		exit 1; \
	fi; \
	echo "==================================================================="; \
	echo "FINISHED COLMAP CFUSE MODEL: $(call ELEM5,$(@),4)"
endef


