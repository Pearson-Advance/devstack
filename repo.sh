#!/usr/bin/env bash

set -e
set -o pipefail

# Script for Git repos housing edX services. These repos are mounted as
# data volumes into their corresponding Docker containers to facilitate development.
# Repos are cloned to/removed from the directory above the one housing this file.

if [ -z "$DEVSTACK_WORKSPACE" ]; then
    echo "need to set workspace dir"
    exit 1
elif [ -d "$DEVSTACK_WORKSPACE" ]; then
    cd "$DEVSTACK_WORKSPACE"
else
    echo "Workspace directory $DEVSTACK_WORKSPACE doesn't exist"
    exit 1
fi

# When you add new services should add them to both repos and ssh_repos
# (or non_release_repos and non_release_ssh_repos if they are not part
# of Open edX releases).

declare -A repos=(
    ["https://github.com/edx/course-discovery.git"]="open-release/juniper.master"
    ["https://github.com/edx/credentials.git"]="open-release/juniper.master"
    ["https://github.com/edx/cs_comments_service.git"]="open-release/juniper.master"
    ["https://github.com/pearson-Advance/ecommerce.git"]="pearson-release/juniper.master"
    ["https://github.com/edx/edx-e2e-tests.git"]="open-release/juniper.master"
    ["https://github.com/edx/edx-notes-api.git"]="open-release/juniper.master"
    ["https://github.com/pearson-Advance/edx-platform.git"]="pearson-release/juniper.master"
    ["https://github.com/edx/xqueue.git"]="open-release/juniper.master"
    ["https://github.com/edx/edx-analytics-pipeline.git"]="open-release/juniper.master"
    ["https://github.com/edx/frontend-app-gradebook.git"]="open-release/juniper.master"
    ["https://github.com/edx/frontend-app-publisher.git"]="open-release/juniper.master"
    ["https://github.com/edx/frontend-app-learning.git"]="master"
    ["https://github.com/edx/registrar.git"]="master"
    ["https://github.com/edx/frontend-app-program-console.git"]="master"
)

declare -A ssh_repos=(
    ["git@github.com:edx/course-discovery.git"]="open-release/juniper.master"
    ["git@github.com:edx/credentials.git"]="open-release/juniper.master"
    ["git@github.com:edx/cs_comments_service.git"]="open-release/juniper.master"
    ["git@github.com:pearson-Advance/ecommerce.git"]="pearson-release/juniper.master"
    ["git@github.com:edx/edx-e2e-tests.git"]="open-release/juniper.master"
    ["git@github.com:edx/edx-notes-api.git"]="open-release/juniper.master"
    ["git@github.com:pearson-Advance/edx-platform.git"]="pearson-release/juniper.master"
    ["git@github.com:edx/xqueue.git"]="open-release/juniper.master"
    ["git@github.com:edx/edx-analytics-pipeline.git"]="open-release/juniper.master"
    ["git@github.com:edx/frontend-app-gradebook.git"]="open-release/juniper.master"
    ["git@github.com:edx/frontend-app-publisher.git"]="open-release/juniper.master"
    ["git@github.com:edx/frontend-app-learning.git"]="master"
    ["git@github.com:edx/registrar.git"]="master"
    ["git@github.com:edx/frontend-app-program-console.git"]="master"
)

declare -A private_repos=(
    # Needed to run whitelabel tests.
    ["https://github.com/edx/edx-themes.git"]="master"
)

name_pattern=".*/(.*).git"

_checkout ()
{
    eval "declare -A repositories="${1#*=}

    for repo in "${!repositories[@]}"
    do
        # Use Bash's regex match operator to capture the name of the repo.
        # Results of the match are saved to an array called $BASH_REMATCH.
        [[ $repo =~ $name_pattern ]]
        name="${BASH_REMATCH[1]}"

        # If a directory exists and it is nonempty, assume the repo has been cloned.
        if [ -d "$name" ] && [ -n "$(ls -A "$name" 2>/dev/null)" ]; then
            echo "Checking out branch ${repositories[$repo]} of $name"
            cd "$name"
            _checkout_and_update_branch ${repositories[$repo]}
            cd ..
        fi
    done
}

checkout ()
{
    _checkout "$(declare -p repos)"
}

_clone ()
{
    eval "declare -A repositories="${1#*=}

    for repo in "${!repositories[@]}"
    do
        # Use Bash's regex match operator to capture the name of the repo.
        # Results of the match are saved to an array called $BASH_REMATCH.
        [[ $repo =~ $name_pattern ]]
        name="${BASH_REMATCH[1]}"

        # If a directory exists and it is nonempty, assume the repo has been checked out
        # and only make sure it's on the required branch
        if [ -d "$name" ] && [ -n "$(ls -A "$name" 2>/dev/null)" ]; then
            if [ ! -d "$name/.git" ]; then
                printf "ERROR: [%s] exists but is not a git repo.\n" "$name"
                exit 1
            fi
            printf "The [%s] repo is already checked out. Checking for updates.\n" "$name"
            cd "${DEVSTACK_WORKSPACE}/${name}"
            _checkout_and_update_branch "${repositories[$repo]}"
            cd ..
        else
            if [ "${SHALLOW_CLONE}" == "1" ]; then
                git clone --single-branch -b ${repositories[$repo]} -c core.symlinks=true --depth=1 "${repo}"
            else
                git clone --single-branch -b ${repositories[$repo]} -c core.symlinks=true "${repo}"
            fi
        fi
    done
    cd - &> /dev/null
}

_checkout_and_update_branch ()
{
    GIT_SYMBOLIC_REF="$(git symbolic-ref HEAD 2>/dev/null)"
    BRANCH_NAME=${GIT_SYMBOLIC_REF##refs/heads/}
    DESIRED_BRANCH=$1

    if [ "${BRANCH_NAME}" == "${DESIRED_BRANCH}" ]; then
        git pull origin ${DESIRED_BRANCH}
    else
        git fetch origin ${DESIRED_BRANCH}:${DESIRED_BRANCH}
        git checkout ${DESIRED_BRANCH}
    fi
    find . -name '*.pyc' -not -path './.git/*' -delete
}

clone ()
{
    _clone "$(declare -p repos)"
}

clone_ssh ()
{
    _clone "$(declare -p ssh_repos)"
}

clone_private ()
{
    _clone "$(declare -p private_repos)"
}

reset ()
{
    currDir=$(pwd)
    for repo in ${!repos[*]}
    do
        [[ $repo =~ $name_pattern ]]
        name="${BASH_REMATCH[1]}"

        if [ -d "$name" ]; then
            cd "$name";git reset --hard HEAD;git checkout master;git reset --hard origin/master;git pull;cd "$currDir"
        else
            printf "The [%s] repo is not cloned. Continuing.\n" "$name"
        fi
    done
    cd - &> /dev/null
}

status ()
{
    currDir=$(pwd)
    for repo in ${!repos[*]}
    do
        [[ $repo =~ $name_pattern ]]
        name="${BASH_REMATCH[1]}"

        if [ -d "$name" ]; then
            printf "\nGit status for [%s]:\n" "$name"
            cd "$name";git status;cd "$currDir"
        else
            printf "The [%s] repo is not cloned. Continuing.\n" "$name"
        fi
    done
    cd - &> /dev/null
}

if [ "$1" == "checkout" ]; then
    checkout
elif [ "$1" == "clone" ]; then
    clone
elif [ "$1" == "clone_ssh" ]; then
    clone_ssh
elif [ "$1" == "whitelabel" ]; then
    clone_private
elif [ "$1" == "reset" ]; then
    read -p "This will override any uncommited changes in your local git checkouts. Would you like to proceed? [y/n] " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        reset
    fi
elif [ "$1" == "status" ]; then
    status
fi
