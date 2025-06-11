import click
from scripts import extract_frames, colmap_pipeline, openmvg_pipeline

@click.group()
def cli():
    """GBT 3D Pipeline CLI"""
    pass

@cli.command()
@click.argument("video_path", type=click.Path(exists=True))
@click.option("--output-dir", default="data/frames", help="Output dir for extracted frames")
@click.option("--fps", default=1, help="Frames per second to extract")
def extract(video_path, output_dir, fps):
    """Extract frames from video"""
    extract_frames.extract_frames(video_path, output_dir, fps)

@cli.command()
@click.option("--frame-dir", default="data/frames", help="Dir with frames to process")
@click.option("--colmap-dir", default="data/colmap", help="COLMAP output dir")
@click.option("--output-format", default="ply", type=click.Choice(["ply", "obj"]), help="Output format")
def run_colmap(frame_dir, colmap_dir, output_format):
    """Run COLMAP pipeline"""
    colmap_pipeline.run_pipeline(frame_dir, colmap_dir, output_format)

@cli.command()
@click.option("--frame-dir", default="data/frames", help="Dir with frames to process")
@click.option("--openmvg-dir", default="data/openmvg", help="OpenMVG working dir")
@click.option("--openmvs-dir", default="data/openmvs", help="OpenMVS output dir")
def run_openmvg_openmvs(frame_dir, openmvg_dir, openmvs_dir):
    """Run OpenMVG + OpenMVS pipeline"""
    openmvg_pipeline.run_pipeline(frame_dir, openmvg_dir, openmvs_dir)

if __name__ == "__main__":
    cli()
