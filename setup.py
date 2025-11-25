# +--------------------------------------------------------------------------------------------------+
# |  __     __  ____  ____  _  _    ____  _  _  __ _  ____  __    ____  ____                         |
# | (  )   / _\(_  _)(  __)( \/ )  (  _ \/ )( \(  ( \(    \(  )  (  __)/ ___)                        |
# | / (_/\/    \ )(   ) _)  )  (    ) _ () \/ (/    / ) D (/ (_/\ ) _) \___ \                        |
# | \____/\_/\_/(__) (____)(_/\_)  (____/\____/\_)__)(____/\____/(____)(____/                        |
# +--------------------------------------------------------------------------------------------------+
# |                                                                                                  |
# |   Copyright (C) 2025 KirbyNel0                                                                   |
# |                                                                                                  |
# |   This program is free software: you can redistribute it and/or modify                           |
# |   it under the terms of the GNU General Public License as published by                           |
# |   the Free Software Foundation, either version 3 of the License, or                              |
# |   (at your option) any later version.                                                            |
# |                                                                                                  |
# |   This program is distributed in the hope that it will be useful,                                |
# |   but WITHOUT ANY WARRANTY; without even the implied warranty of                                 |
# |   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                                  |
# |   GNU General Public License for more details.                                                   |
# |                                                                                                  |
# |   You should have received a copy of the GNU General Public License                              |
# |   along with this program.  If not, see <https://www.gnu.org/licenses/>.                         |
# |                                                                                                  |
# +--------------------------------------------------------------------------------------------------+

# +--------------------------------------------------------------------------------------------------+
# | IMPORTS                                                                                          |
# +--------------------------------------------------------------------------------------------------+

import os
import sys
import json
import shutil
import ctypes
import argparse
from typing import Optional, List


def error(*msg):
    print(*msg, file=sys.stderr)


def warn(*msg):
    print("[!]", *msg)


# +--------------------------------------------------------------------------------------------------+
# | ARGUMENTS                                                                                        |
# +--------------------------------------------------------------------------------------------------+

parser = argparse.ArgumentParser(
    description="""\
This script can be used to install a bunch of LaTeX files from a configuration file, usually named
"texbundle.json". This configuration file defines a LaTeX bundle which will be installed for the
current user.

A LaTeX bundle is just a bunch of LaTeX files, like packages and document classes, which LaTeX
should always be able to find when compiling your documents.

Installation simply includes copying the files of the bundle to predefined places in your file
system, which LaTeX searches by default.""",
    formatter_class=argparse.RawDescriptionHelpFormatter,
)

parser.add_argument(
    "-i",
    "--install",
    help="If provided, will install the current bundle.",
    action="store_true",
    default=False,
    dest="install",
)

parser.add_argument(
    "-u",
    "--uninstall",
    help="""\
If provided, will uninstall the current bundle. Note that, if the configuration changed, some files
of the bundle may not be uninstalled properly. If provided with -Install, the bundle is installed
instead.""",
    action="store_true",
    default=False,
    dest="uninstall",
)

parser.add_argument(
    "-f",
    "--config-file",
    help="""\
Defines the configuration file to use, defaults to "texbundle.tex". The bundle defined in that
file is referred to as "current bundle". May also be a directory containing a "texbundle.json".""",
    default="texbundle.json",
    dest="file",
)

parser.add_argument(
    "-s",
    "--symlink",
    help="""\
Create symbolic links instead of copying files. Recommended for git repostories.
Requires admin privileges on windows.""",
    action="store_true",
    default=False,
    dest="symlink",
)

if len(sys.argv) == 1:
    parser.print_help()
    exit(0)

args = parser.parse_args()

if not (args.install or args.uninstall):
    error("Please specify either --install or --uninstall")
    exit(1)


# +--------------------------------------------------------------------------------------------------+
# | WORKING DIRECTORY                                                                                |
# +--------------------------------------------------------------------------------------------------+


# Resolve path relative to $Root, even if it does not exist
def resolve_full_path(path: os.PathLike) -> str:
    if os.path.isabs(path):
        return path
    return os.path.join(ROOT, path)


# Resolve config file relative to working directory
args.file = os.path.abspath(args.file)

# Directory of the config file
ROOT = os.path.abspath(os.path.join(args.file, os.pardir))

os.chdir(ROOT)

# +--------------------------------------------------------------------------------------------------+
# | READ CONFIG FILE                                                                                 |
# +--------------------------------------------------------------------------------------------------+

# File where package information is stored
config_file = args.file

if not os.path.isfile(config_file):
    config_file = os.path.join(config_file, "texbundle.json")

if not os.path.isfile(config_file):
    error("Configuration file is missing:", config_file)
    exit(1)


with open(config_file) as f:
    # The dictionary storing all configuration
    config = json.load(f)


def get_value(
    mapping: dict, key: str, value_type: type, required: bool = True, default=None
):
    if key not in mapping:
        if required:
            error("Missing required key: '" + key + "'")
            exit(1)
        else:
            return default

    result = mapping[key]

    if not isinstance(result, value_type):
        error(
            "Expected '"
            + key
            + "' to be of type '"
            + value_type.__name__
            + "' but got '"
            + type(result).__name__
            + "'"
        )
        exit(1)

    return result


# The name of the package. Used for texmf file paths.
bundle_name = get_value(config, key="name", value_type=str, required=True)

# A list of all .sty of this package.
sty_list = get_value(config, key="sty", value_type=list, required=False, default=[])

# A list of all .cls of this package.
cls_list = get_value(config, key="cls", value_type=list, required=False, default=[])

# A list of all other files of this package.
res_list = get_value(config, key="res", value_type=list, required=False, default=[])

# The directory where all .sty source files must be located.
sty_source_dir = get_value(
    config,
    "sty-dir",
    value_type=str,
    required=False,
    default=os.path.join(ROOT, "texmf"),
)

if len(sty_list) > 0 and not os.path.isdir(sty_source_dir):
    error("Must be a directory:", sty_source_dir)
    exit(1)

# The directory where all .cls source files must be located.
cls_source_dir = get_value(
    config,
    "cls-dir",
    value_type=str,
    required=False,
    default=os.path.join(ROOT, "texmf"),
)

if len(cls_list) > 0 and not os.path.isdir(cls_source_dir):
    error("Must be a directory:", cls_source_dir)

# The directory where all resource files must be located. (optional)
res_source_dir = get_value(
    config,
    "res-dir",
    value_type=str,
    required=False,
    default=os.path.join(ROOT, "resources"),
)

if not os.path.isdir(res_source_dir):
    res_source_dir = None
    if res_list != []:
        res_list = []
        print("[!] Resource directory not found, ignoring all resources")

# The directory where all .cwl source files must be located. (optional)
cwl_source_dir = get_value(
    config,
    "cwl-dir",
    value_type=str,
    required=False,
    default=os.path.join(ROOT, "autocompletion"),
)

if not os.path.isdir(cwl_source_dir):
    cwl_source_dir = None

# +--------------------------------------------------------------------------------------------------+
# | TARGET DIRECTORIES                                                                               |
# +--------------------------------------------------------------------------------------------------+

# The user's home directory.
USER_HOME = os.path.expanduser("~")

# The directory where all .sty and .cls source files should be copied to.
texmf_dir = ""

# The directory where all .cwl source files should be copied to.
texstudio_dir = ""

if sys.platform == "linux" or sys.platform == "linux2":
    texmf_dir = os.path.join(USER_HOME, "texmf", "tex", "latex", bundle_name)
    texstudio_dir = os.path.join(
        USER_HOME, ".config", "texstudio", "completion", "user"
    )
elif sys.platform == "windows":
    texmf_dir = os.path.join(
        USER_HOME, "AppData", "Roaming", "MiKTeX", "latex", bundle_name
    )
    texstudio_dir = os.path.join(
        USER_HOME, "AppData", "Roaming", "texstudio", "completion", "user"
    )
elif sys.platform == "darwin":
    texmf_dir = os.path.join(USER_HOME, "Library", "texmf", "tex", "latex", bundle_name)
    texstudio_dir = os.path.join(
        USER_HOME, ".config", "texstudio", "completion", "user"
    )
else:
    error("Unknown platform:" + sys.platform)
    exit(1)

os.makedirs(texmf_dir, exist_ok=True)
os.makedirs(texstudio_dir, exist_ok=True)

# +--------------------------------------------------------------------------------------------------+
# | METHOD SELECTION                                                                                 |
# +--------------------------------------------------------------------------------------------------+

# Create symlinks
if args.symlink:
    if sys.platform == "windows":
        try:
            is_admin = os.getuid() == 0
        except AttributeError:
            is_admin = ctypes.windll.shell32.IsUserAnAdmin() != 0

        if not is_admin:
            error("Admin privileges are required to create symlinks on windows.")
            exit(1)

    def install_file(from_file, to_file):
        from_file = resolve_full_path(from_file)
        to_file = resolve_full_path(to_file)
        if os.path.isfile(to_file):
            os.remove(to_file)
        os.symlink(src=from_file, dst=to_file)


# Copy files
else:

    def install_file(from_file, to_file):
        from_file = resolve_full_path(from_file)
        to_file = resolve_full_path(to_file)
        if os.path.isfile(to_file):
            os.remove(to_file)
        shutil.copy2(src=from_file, dst=to_file)


# +--------------------------------------------------------------------------------------------------+
# | ACTION                                                                                           |
# +--------------------------------------------------------------------------------------------------+


def iter_files(
    name: str,
    files: Optional[List[str]],
    from_dir: os.PathLike,
    to_dir: os.PathLike,
    suffix: str = "",
):
    if from_dir is None or len(files) == 0:
        return

    print()
    print("==>", name)
    print("From:", from_dir)
    print("To:  ", to_dir)

    for name in files:
        source = os.path.join(from_dir, name + suffix)
        dest = os.path.join(to_dir, name + suffix)

        source = resolve_full_path(source)
        dest = resolve_full_path(dest)

        # Create possible directories
        parent_dir = os.path.abspath(os.path.join(dest, os.pardir))

        if args.install:
            if not os.path.isfile(source):
                continue

            print(" +", name)
            os.makedirs(parent_dir, exist_ok=True)
            install_file(from_file=source, to_file=dest)
        elif args.uninstall:
            if not os.path.isfile(dest):
                continue

            print(" -", name)
            os.remove(dest)


if args.install:
    print("[ Install", bundle_name, "]")
elif args.uninstall:
    print("[ Uninstall", bundle_name, "]")

iter_files(
    "LaTeX packages",
    sty_list,
    from_dir=sty_source_dir,
    to_dir=texmf_dir,
    suffix=".sty",
)

iter_files(
    "LaTeX document classes",
    cls_list,
    from_dir=cls_source_dir,
    to_dir=texmf_dir,
    suffix=".cls",
)

iter_files(
    "Resource files",
    res_list,
    from_dir=res_source_dir,
    to_dir=texmf_dir,
    suffix="",
)

iter_files(
    "TeXStudio autocompletion files",
    sty_list + cls_list,
    from_dir=cwl_source_dir,
    to_dir=texstudio_dir,
    suffix=".cwl",
)
