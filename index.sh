#!/bin/sh

# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Constants
# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
DEFAULT_TARGET_BRANCH="main"
DEFAULT_MAILMAP_FILE="./mailmap"
DEFAULT_FORCE="false"
DEFAULT_HELP="false"
DEFAULT_VERBOSE="false"

COLOR_RED=$(tput setaf 1)
COLOR_GREEN=$(tput setaf 2)
COLOR_YELLOW=$(tput setaf 3)
COLOR_BLUE=$(tput setaf 4)
COLOR_PURPLE=$(tput setaf 5)
COLOR_AQUA=$(tput setaf 6)
COLOR_WHITE=$(tput setaf 7)
COLOR_RESET=$(tput sgr0)

TEMP_DIR="temp"

HELP_USAGE="
Usage: $(basename "$0") <repo> [-b <branch>] [-m <mailmap>] [-h] [-f] [-v]
"
HELP_POSITIONALS="
Positionals:
    repo    Git repository to rewrite           [string]
"
HELP_OPTIONS="
Options:
    -b  --branch    Branch to rewrite           [string][default: \"main\"]
    -m  --mailmap   Path to mailmap file        [string][default: \"../mailmap\"]
    -f  --force     Force filter-repo command   [boolean]
    -h  --help      Show this help text         [boolean]
    -v  --verbose   Show additional logging     [boolean]
"
function printHelp {
    printf "${COLOR_YELLOW}%s${COLOR_RESET}" "$HELP_USAGE"
    printf "${COLOR_YELLOW}%s${COLOR_RESET}" "$HELP_POSITIONALS"
    printf "${COLOR_YELLOW}%s${COLOR_RESET}" "$HELP_OPTIONS"
}
function printError {
    printf "\n${COLOR_YELLOW}%s${COLOR_RESET}\n" "Please enter \"$(basename "$0") -h\" if you would like help."
    printf "\n${COLOR_RED}%s${COLOR_RESET}\n" "Error:
    $1
"
}

# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Parse optional args and assign variables
# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--branch)
      TARGET_BRANCH="$2"
      shift # past argument
      shift # past value
      ;;
    -m|--mailmap)
      MAILMAP_FILE="$2"
      shift # past argument
      shift # past value
      ;;
    -f|--force)
      FORCE="true"
      shift # past argument
      ;;
    -h|--help)
      HELP="true"
      shift # past argument
      ;;
    -v|--verbose)
      VERBOSE="true"
      shift # past argument
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Display usage if user prompts for help
# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

if [ "$HELP" = "true" ]; then
    printHelp
    exit 0
fi

# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Parse args and assign variables
# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters
GIT_REPO="${POSITIONAL_ARGS[0]}"
TARGET_BRANCH="${TARGET_BRANCH:-$DEFAULT_TARGET_BRANCH}"
MAILMAP_FILE="${MAILMAP_FILE:-$DEFAULT_MAILMAP_FILE}"
FORCE="${FORCE:-$DEFAULT_FORCE}"
HELP="${HELP:-$DEFAULT_HELP}"
VERBOSE="${VERBOSE:-$DEFAULT_VERBOSE}"

# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Arg validation and info
# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

if [ "$VERBOSE" = "true" ]; then
    printf "${COLOR_WHITE}%s${COLOR_RESET}" "
Variables:
    GIT_REPO        \"$GIT_REPO\"
    TARGET_BRANCH   \"$TARGET_BRANCH\"
    MAILMAP         \"$MAILMAP_FILE\"
    FORCE           $FORCE
    HELP            $HELP
    VERBOSE         $VERBOSE
"
fi

if ! [ -e "git-filter-repo" ];then
    printError "Dependency missing - git-filter-repo (https://github.com/newren/git-filter-repo/blob/main/INSTALL.md)"
    exit 1
fi

if ! [ -f "$MAILMAP_FILE" ]; then
    printError "Cannot find mailmap file (${MAILMAP_FILE}). For help creating one see https://git-scm.com/docs/gitmailmap."
    exit 1
fi

if [ -z "$GIT_REPO" ]; then
    printError "Git repo argument missing."
    exit 1
fi

# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Main
# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Clone and traverse
if [ "$VERBOSE" = "true" ]; then
    printf "${COLOR_WHITE}%s${COLOR_RESET}\n" "Cloning git repo to $TEMP_REPO..."
fi
git clone "$TEMP_REPO" "$TEMP_DIR"
pushd "$TEMP_DIR"

# Switch branch if necessary
curBranch="$(git symbolic-ref HEAD 2>/dev/null)" ||
curBranch="(unnamed branch)"
curBranch=${curBranch##refs/heads/}
if [ "$VERBOSE" = "true" ]; then
    printf "${COLOR_WHITE}%s${COLOR_RESET}\n" "Current branch: $currentBranch"
fi
if [ "$curBranch" = "$TARGET_BRANCH" ]; then
    if [ "$VERBOSE" = "true" ]; then
        printf "${COLOR_WHITE}%s${COLOR_RESET}\n" "Changing branch to $TARGET_BRANCH..."
    fi
    git checkout "$TARGET_BRANCH"
fi

# Rewrite the metadata
if [ "$VERBOSE" = "true" ]; then
    printf "${COLOR_WHITE}%s${COLOR_RESET}\n" "Rewriting git history..."
fi
git filter-repo --mailmap "$MAILMAP_FILE" --force

# Push to remote
if [ "$VERBOSE" = "true" ]; then
    printf "${COLOR_WHITE}%s${COLOR_RESET}\n" "Pushing changes to remote..."
fi
git remote add origin "$TEMP_REPO"
git push --set-upstream origin "$TARGET_BRANCH" -f

# Clean up
popd
if [ "$VERBOSE" = "true" ]; then
    printf "${COLOR_WHITE}%s${COLOR_RESET}\n" "Removing temp file ($TEMP_DIR)..."
fi
rm -rf "$TEMP_DIR"


printf "\n${COLOR_GREEN}%s${COLOR_RESET}\n" "Successfully rewrote history of $GIT_REPO."
