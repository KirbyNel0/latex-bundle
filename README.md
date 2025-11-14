# LaTeX Bundle Scripts

The scripts found in this repository can be used to "install" LaTeX files (called "bundles") on your machine. The scripts basically copy/remove the files to dedicated places in your user files so your LaTeX distribution can find them properly.

## Quick start

If you have a configuration file for an existing bundle, named `texbundle.json` for example, choose the script the script of your liking:

- For users of Python 3.5 or higher, the `setup.py` script should be preferred.

- For Windows users without Python, the `setup.ps1` script may be used. This script does support Linux and MacOs as well.

Simply download the script and put it into the directory where the `texbundle.json` is located.

### Installation

To install a bundle, open a terminal in the directory where the script and the `texbundle.json` are located and run:

|             | setup.py                       | setup.ps1                                                 |
| ----------- | ------------------------------ | --------------------------------------------------------- |
| Linux/MacOS | `python3 setup.py --install`   | `pwsh setup.ps1 -Install`                                 |
| Windows     | `py .\setup.py --install`      | `powershell -ExecutionPolicy ByPass .\setup.ps1 -Install` |

This will put all files of that bundle into your user's home directory so that LaTeX can find them.

### Remove an installed bundle

To remove a bundle which got installed by the script previously, open a terminal where the script and the `texbundle.json` are located and run:

|             | setup.py                         | setup.ps1                                                   |
| ----------- | -------------------------------- | ----------------------------------------------------------- |
| Linux/MacOs | `python3 setup.py --uninstall`   | `pwsh setup.ps1 -Uninstall`                                 |
| Windows     | `py .\setup.py --uninstall`      | `powershell -ExecutionPolicy ByPass .\setup.ps1 -Uninstall` |

This will remove all files previouly created by the script. Note that directories created by the script will not be removed and may still exist empty after this step.



## What is a bundle?

A bundle is a bunch of files that LaTeX should find automatically. Usually, this includes LaTeX packages (`.sty`-files) and LaTeX classes (`.cls`-files).

After installation, LaTeX will be able to find the files included in the bundle easily. For example, if you install a bundle containing a `foo.sty` file, the following would be possible in any LaTeX document you compile:

```latex
\usepackage{foo}
```

The same applies to `.cls` files and `\documentclass`.

A bundle may optionally contain resource files, like images. which will allow commands like `\includegraphics` to find your images even if they are not located in the same directory as your main document.

A bundle may also optionally include autocompletion files for [TeXStudio](https://www.texstudio.org/), which use the `cwl` file format described in the [TeXStudio documentation](https://texstudio-org.github.io/background.html#cwl-file-format). These files will get copied to a location where TeXStudio can find them.



## How to create a bundle

To create a bundle of a bunch of files, just add a _bundle file_ to them and you are done. These files are usually called `texbundle.json` and use the [JSON](https://www.json.org/json-en.html) file format (I would rather use something else, but JSON is such a common format that it exists in most standard libraries for quite some time).

This configuration file needs to follow the `texbundle.schema.json` file, also included in this repository. You may use the `texbundle.json` from this repository as template for your bundle file.

A bundle file may contain the following keys:

- `name` (required): The bundle's name. Will be used for directory names and should therefor not contain any whitespace, `/` or `\`.
- `sty`: A list of LaTeX packages to be included in the bundle (without `.sty` suffix). File location must be provided relative to the `sty-dir` directory (default: `texmf`).
- `cls`: A list of LaTeX document classes to be included in the bundle (without `.cls` suffix). File location must be provided relative to the `cls-dir` directory (default: `texmf`).
- `res`: A list of resource files included in the bundle (with suffix). File location must be provided relative to the `res-dir` directory (default: `resources`).
- `cwl-dir`: The directory in which TeXStudio autocompletion files are stored. All packages from `sty` and classes from `cls` are checked for corresponding autocompletion files.

The directories (`*-dir` keys) are all evaluated relative to the location of the bundle file. Files that do not exist are ignored in lists. Empty lists are skipped.
