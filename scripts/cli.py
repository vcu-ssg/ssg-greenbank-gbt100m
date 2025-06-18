import click
from scripts.extract_frames import extract_frames_from_file, extract_frames_from_folder, process_folder_with_convert, process_folder_with_convert_workers
from scripts import colmap_pipeline, openmvg_pipeline, convert_matches_g_to_dot, gsplat_pipeline

@click.group()
def cli():
    """GBT 3D Pipeline CLI"""
    pass

@cli.command()
@click.argument("video_path", type=click.Path(exists=True))
@click.option("--output-dir", default="data/frames", help="Output dir for extracted frames")
@click.option("--fps", type=float, default=1.0, help="Frames per second to extract")
@click.option("--skip", type=int, default=5, help="Skip first X seconds")
@click.option("--capture", type=int, default=None, help="Capture X seconds of video")
@click.option("--threads", type=int, default=8, help="FFMPEG threads to use")
@click.option("--quality", type=int, default=2, help="JPG quality 1/31")
@click.option("--tag", default="tag", help="filename tag")
@click.option("--format", default="png", help="Output file format (png/jpg)")
@click.option("--max_width", default="1600", help="max image width")
def extract_frames(video_path, output_dir,fps,skip,capture,threads,quality,tag,format,max_width):
    """Extract frames from video"""
    extract_frames_from_file(video_path, output_dir, fps=fps,skip_seconds=str(skip),
        threads=threads,quality=quality,capture_seconds=capture,tag=tag,format=format, max_width=max_width)


@cli.command()
@click.option("--frame-dir", default="data/frames", help="Dir with frames to process")
@click.option("--colmap-dir", default="data/colmap", help="COLMAP output dir")
@click.option("--output-format", default="ply", type=click.Choice(["ply", "obj"]), help="Output format")
def run_colmap(frame_dir, colmap_dir, output_format):
    """Run COLMAP pipeline"""
    colmap_pipeline.run_pipeline(frame_dir, colmap_dir, output_format)

@cli.command()
@click.option('--enable-texturing/--no-enable-texturing', is_flag=True, default=False, help='Enable/disable OpenMVS TextureMesh step.')
@click.option('--sfm-engine', type=click.Choice(['GLOBAL', 'INCREMENTAL'], case_sensitive=False), default='GLOBAL', help='SfM engine to use.')
@click.option('--matches-ratio', type=float, default=0.6, show_default=True, help='Feature matching ratio filter (lower = more matches).')
def run_openmvg_openmvs(enable_texturing, sfm_engine, matches_ratio):
    """Run OpenMVG + OpenMVS pipeline"""
    print("==== Pipeline configuration ====")
    print(f" SfM engine      : {sfm_engine}")
    print(f" Matches ratio   : {matches_ratio}")
    print(f" Texturing       : {'ENABLED' if enable_texturing else 'DISABLED'}")
    print("================================\n")    

    # Call run_pipeline with correct args:
    openmvg_pipeline.run_pipeline(
        enable_texturing=enable_texturing,
        sfm_engine=sfm_engine.upper(),
        matches_ratio=matches_ratio
    )
    
@cli.command()
@click.option(
    "--input", "-i", required=True, type=click.Path(exists=True, dir_okay=False),
    help="Path to matches.g.txt file"
)
@click.option(
    "--output", "-o", required=True, type=click.Path(dir_okay=False),
    help="Path to output DOT file"
)
def convert_matches_g(input, output):
    """Convert matches.g.txt (edge list) → DOT format for visualization."""
    click.echo(f"👉 Converting {input} → {output} ...")
    convert_matches_g_to_dot.convert_matches_g_to_dot(input, output)
    click.echo(f"✅ Done. DOT file written to: {output}")


@cli.command()
@click.argument('matches_file', type=click.Path(exists=True))
@click.option('--show-disconnected', is_flag=True, help='Print list of disconnected nodes.')
def analyze_graph(matches_file, show_disconnected):
    """ Analyze dot file """
    convert_matches_g_to_dot.analyze_graph(matches_file, show_disconnected)


@cli.command()
@click.option("--input-folder", required=True, type=click.Path(exists=True, file_okay=False), help="Input folder with JPG images")
@click.option("--output-folder", required=True, type=click.Path(file_okay=False), help="Output folder for processed images")
@click.option("--sharpen", default="0x1.0", show_default=True, help="Sharpen amount, e.g. 0x1.0")
@click.option("--contrast", default="5x50%", show_default=True, help="Sigmoidal contrast amount, e.g. 5x50%%")
@click.option("--greyscale/--no-greyscale", default=False, help="Convert to greyscale")
@click.option("--crop", default=None, help="Crop geometry, e.g. WxH+X+Y (optional)")
@click.option("--tag", default="filtered", help="tag for file name")
@click.option("--workers", default=8, help="Number of separate workers")
@click.option("--format", default="png", help="Input image format (png/jpg)")
def convert_images(input_folder, output_folder, sharpen, contrast, greyscale, crop, tag,workers,format ):
    """Run ImageMagick convert on all images in input folder."""
    click.echo(f"👉 Converting images in {input_folder} → {output_folder}")
    click.echo(f"  Format    : {format}")
    click.echo(f"  Sharpen   : {sharpen}")
    click.echo(f"  Contrast  : {contrast}")
    click.echo(f"  Greyscale : {'ON' if greyscale else 'OFF'}")
    click.echo(f"  Crop      : {crop if crop else 'None'}")
    click.echo(f"  Tag       : {tag}")

    process_folder_with_convert_workers(
        input_folder,
        output_folder,
        sharpen=sharpen,
        contrast=contrast,
        greyscale=greyscale,
        crop=crop,
        tag=tag,
        max_workers=workers,
        format=format
    )

    click.echo(f"✅ Done. Processed images in: {output_folder}")
    


@cli.command()
@click.argument("image_path", type=click.Path(exists=True, file_okay=False))
@click.argument("colmap_output_folder", type=click.Path())
def run_colmap_pipeline_cli(image_path, colmap_output_folder):
    """Run COLMAP pipeline on given image folder."""
    from scripts.colmap_pipeline import run_colmap_pipeline
    run_colmap_pipeline(image_path, colmap_output_folder)



@cli.command()
@click.option('--scene', required=True, help='Scene name, e.g. DJI_0145-FPS-1.60-original')
@click.option('--images-dir', required=True, type=click.Path(), help='Path to input images')
@click.option('--sparse-dir', required=True, type=click.Path(), help='Path to sparse COLMAP model (sparse/0)')
@click.option('--model-dir', required=True, type=click.Path(), help='Output directory for gsplat results')
@click.option('--iterations', required=True, help='Iterations to gsplat')
@click.option('--sh_degree', required=True, help='Spherical Harmonics degree. 0-none, 1-2 lower res, 3-4 higher res')
def gsplat(scene, images_dir, sparse_dir, model_dir,iterations,sh_degree):
    """Run Gaussian Splatting training for a specific scene with provided paths."""
    gsplat_pipeline.run_gsplat_training(scene, images_dir, sparse_dir, model_dir,iterations,sh_degree)


if __name__ == "__main__":
    cli()

