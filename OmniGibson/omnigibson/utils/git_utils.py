from pathlib import Path

import git

import omnigibson as og
from omnigibson.utils.bddl_utils import BDDL_PACKAGE_DIR


def git_info(directory):
    repo = git.Repo(directory)
    try:
        branch_name = repo.active_branch.name
    except TypeError:
        branch_name = "[DETACHED]"
    return {
        "directory": str(directory),
        "code_diff": repo.git.diff(None),
        "code_diff_staged": repo.git.diff("--staged"),
        "commit_hash": repo.head.commit.hexsha,
        "branch_name": branch_name,
    }


def project_git_info():
    return {
        "OmniGibson": git_info(Path(og.root_path).parent),
        "bddl": git_info(BDDL_PACKAGE_DIR.parent),
    }
