import click
from scripts.extract_frames import extract_frames_from_file, extract_frames_from_folder
from scripts import colmap_pipeline, openmvg_pipeline, convert_matches_g_to_dot

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
def extract_frames(video_path, output_dir,fps,skip,capture,threads,quality):
    """Extract frames from video"""
    extract_frames_from_file(video_path, output_dir, fps=fps,skip_seconds=str(skip),
        threads=threads,quality=quality,capture_seconds=capture)


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

    
    
if __name__ == "__main__":
    cli()
