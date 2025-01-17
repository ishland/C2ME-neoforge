#!/usr/bin/env bash
# get base dir regardless of execution location
# resolve shell-specifics
case "$(echo "$SHELL" | sed -E 's|/usr(/local)?||g')" in
    "/bin/zsh")
        RCPATH="$HOME/.zshrc"
        SOURCE="${BASH_SOURCE[0]:-${(%):-%N}}"
    ;;
    *)
        RCPATH="$HOME/.bashrc"
        if [[ -f "$HOME/.bash_aliases" ]]; then
            RCPATH="$HOME/.bash_aliases"
        fi
        SOURCE="${BASH_SOURCE[0]}"
    ;;
esac

# get base dir regardless of execution location

while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
. "$(dirname "$SOURCE")/init.sh"
PS1="$"

gpgsign="$(git config commit.gpgsign || echo "false")"
echo "Rebuilding Forked projects.... "
function applyPatch {
    what=$1
    what_name=$(basename "$what")
    target=$2
    branch=$3
    patch_folder=$4

    cd "$basedir/$what" || exit
    git fetch --all
    git branch -f upstream "$branch" >/dev/null

    cd "$basedir" || exit
    if [ ! -d  "$basedir/$target" ]; then
        mkdir "$basedir/$target"
        cd "$basedir/$target" || exit
        git init
        git remote add origin "$5"
        cd "$basedir" || exit
    fi
    cd "$basedir/$target" || exit

    # Disable GPG signing before AM, slows things down and doesn't play nicely.
    # There is also zero rational or logical reason to do so for these sub-repo AMs.
    # Calm down kids, it's re-enabled (if needed) immediately after, pass or fail.
    git config commit.gpgsign false

    echo "Resetting $target to $what_name..."
    git remote rm upstream > /dev/null 2>&1
    git remote add upstream "$basedir"/"$what" >/dev/null 2>&1
    git checkout master 2>/dev/null || git checkout -b master
    git fetch upstream >/dev/null 2>&1
    git reset --hard upstream/upstream
    echo "  Applying patches to $target..."
    git am --abort >/dev/null 2>&1
    if ! git am --3way --ignore-whitespace "$basedir/patches/$patch_folder/"*.patch
    then
        echo "  Something did not apply cleanly to $target."
        echo "  Please review above details and finish the apply then"
        echo "  save the changes with rebuildPatches.sh"
        exit 1
    else
        echo "  Patches applied cleanly to $target"
    fi
}

function enableCommitSigningIfNeeded {
    if [[ "$gpgsign" == "true" ]]; then
        git config commit.gpgsign true
    fi
}

(
    (applyPatch C2ME-fabric C2ME-fabric-patched HEAD main) || exit 1
    enableCommitSigningIfNeeded
) || (
    echo "Failed to apply patches"
    enableCommitSigningIfNeeded
    exit 1
) || exit 1

