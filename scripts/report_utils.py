

from pathlib import Path

def build_folder_tree_with_files(root_path):
    """
    Builds a nested dictionary representing the folder structure,
    including files listed under '__files__' in each directory.
    """
    root = Path(root_path)
    if not root.is_dir():
        raise ValueError(f"{root_path} is not a directory")

    def walk(directory):
        tree = {}
        files = []
        for item in directory.iterdir():
            if item.is_dir():
                tree[item.name] = walk(item)
            elif item.is_file():
                files.append(item.name)
        if files:
            tree['__files__'] = files
        return tree

    return {item.name: walk(item) for item in root.iterdir() if item.is_dir()}


def write_index_qmd(tree, destination_folder, data_folder):
    """
    Given the 'tree' dictionary (from build_folder_tree_with_files) and a destination folder,
    writes an index.qmd file listing all projects with links to their individual QMD files.
    """
    dest = Path(destination_folder)
    dest.mkdir(parents=True, exist_ok=True)

    lines = []
    lines.append("---")
    lines.append("title: \"Project Index\"")
    lines.append("---\n")

    lines.append("# Project Index\n")

    for project in sorted(tree.keys()):
        lines.append(f"## [{project}]({project}.html)")
        lines.append(f"- This links to `{project}.qmd` rendered as HTML.\n")

    index_file = dest / "index.qmd"
    index_file.write_text("\n".join(lines))
    print(f"✅ Wrote: {index_file}")


def write_project_qmd(project, tree, destination_folder, data_folder):
    """
    Given a project name, the full tree, and a destination folder,
    writes a QMD file for that project.
    """
    dest = Path(destination_folder)
    dest.mkdir(parents=True, exist_ok=True)

    contents = tree[project]

    lines = []
    lines.append(f"---\ntitle: \"{project}\"\nformat: html\n---\n")
    lines.append(f"# Project: {project}\n")
    
    for folder_name, subtree in contents.items():
        if folder_name == '__files__':
            continue
        lines.append(f"## Folder: {folder_name}")
        
        subfolders = [k for k in subtree.keys() if k != '__files__']
        if subfolders:
            lines.append(f"- Subfolders: {', '.join(subfolders)}")
        
        files = subtree.get('__files__', [])
        if files:
            lines.append(f"- Files: {', '.join(files)}")
        
        lines.append("")  # blank line
    
    root_files = contents.get('__files__', [])
    if root_files:
        lines.append("## Files at project root")
        lines.append(", ".join(root_files))
    
    out_file = dest / f"{project}.qmd"
    out_file.write_text("\n".join(lines))
    print(f"✅ Wrote: {out_file}")
    

def write_qmds_from_tree(tree, destination_folder, data_folder ):
    """
    Given a tree (from build_folder_tree_with_files) and a destination folder,
    writes a QMD file for each top-level project.
    """
    dest = Path(destination_folder)
    dest.mkdir(parents=True, exist_ok=True)


    write_index_qmd( tree, destination_folder, data_folder )
    
    for project in tree:
        if not project.startswith("DJI"):
            continue
        write_project_qmd(project, tree, destination_folder, data_folder)