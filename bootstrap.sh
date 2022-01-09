#!/usr/bin/env sh

set -e

##################
# Global variables

ROOTDIR="$(cd "$(dirname "$0")/" && pwd)"
echo $ROOTDIR
DOTFILES_HOSTS="$ROOTDIR/hosts"
DOTFILES_PLAYBOOK="$ROOTDIR/dotfiles.yml"
DOTFILES_CUSTOM_CONFIG="$ROOTDIR/vars/custom.yml"

###########
# Functions

# Prints an error.
function __bootstrap_error {
  local message="$1"

  (>&2 echo -e "\033[1;91m[ERROR]    $message\033[0;0m")
}

# Prints bootstrap usage.
function __bootstrap_usage {
  if [ -n "$2" ]
  then
    __bootstrap_error "$2"
  fi

  echo "
  Installs new system given some environment variables.

  Usage:
    # $0 [-d <DISTRO> -t <TAG> -T <EXTAG> -h]

  Arguments:
    -h          - Shows this help.
    -t <TAG>    - Role tag
    -T <EXTAG>  - Exclude tags
    -d <DISTRO> - Distro

  Environment variables:
    DOTFILES_BOOTSTRAP_USER      - Linux user.
    DOTFILES_BOOTSTRAP_GIT_NAME  - Git user name.
    DOTFILES_BOOTSTRAP_GIT_EMAIL - Git user e-mail.

  Tags:
    $(ls "$ROOTDIR/roles" | tr "\n" " ")
  "

  exit "$1"
}

###########
# Arguments

while getopts :d:t:T:h option
do
  case "$option" in
    h)
      __bootstrap_usage 0
      ;;
    d)
      DISTRO="${OPTARG}"
      ;;
    t)
      TAG="${OPTARG}"
      ;;
    T)
      EXTAG="${OPTARG}"
      ;;
    *)
      ;;
  esac
done

if [ -z "$TAG"  ] && [ -z "$EXTAG" ]
then
  echo "No tags specified"
  TAG="all"
  EXTAG=""
elif [ -n "$TAG"  ] &&  [ -z "$EXTAG" ]
then
  echo "Using tags $TAG"
  EXTAG=""
elif [ -z "$TAG"  ] &&  [ -n "$EXTAG" ]
then
  echo "Excluding tags $EXTAG"
  TAG="all"
elif [ -n "$TAG"  ] &&  [ -n "$EXTAG" ]
then
  echo "We can't both exclude and include tags! Exiting"
  exit 1
fi


###########
# Bootstrap
if [[ $DISTRO == *"ubuntu"* ]]
then
  echo "Installing Ansible for Ubuntu"
  apt update && apt install -y sudo ansible python3-lxml python3-psutil
  apt upgrade
  apt autoremove
elif [[ $DISTRO == *"arch"* ]]
then
  echo "Installing Ansible for Arch"
  pacman --noconfirm --needed -Sy ansible python-lxml python-psutil interception-dual-function-keys
elif [[ $DISTRO == *"alpine"* ]]
then
  echo "Installing Ansible for Alpine, make sure to enable community repo"
  apk update
  apk add ansible
fi

# Hacky way to load vault vars
ansible-vault view vars/vault > tmp_vars
set -a
. ./tmp_vars
set +a
rm ./tmp_vars

# if [[ $DISTRO == "ubuntu" ]]
# then
#   adduser "$DOTFILES_BOOTSTRAP_USER" sudo
# elif [[ $DISTRO == "arch" ]]
# then
#   useradd --create-home "$DOTFILES_BOOTSTRAP_USER"
# fi

if [ -z "$DOTFILES_BOOTSTRAP_USER" ]
then
  __bootstrap_usage 1 "Cannot find variable DOTFILES_BOOTSTRAP_USER"
fi

if [ "$TAG" = "all" ] || [ "$TAG" = "git" ]
then
  if [ -z "$DOTFILES_BOOTSTRAP_GIT_NAME" ]
  then
    __bootstrap_usage 1 "Cannot find variable DOTFILES_BOOTSTRAP_GIT_NAME"
  fi

  if [ -z "$DOTFILES_BOOTSTRAP_GIT_EMAIL" ]
  then
    __bootstrap_usage 1 "Cannot find variable DOTFILES_BOOTSTRAP_GIT_EMAIL"
  fi
fi

DOTFILES_BOOTSTRAP_ROOT="$ROOTDIR"
DOTFILES_BOOTSTRAP_USER_HOME=$(
  getent passwd "$DOTFILES_BOOTSTRAP_USER" |
  cut -d: -f6
)

export PATH="$PATH:/usr/sbin"


if [ ! -f "$DOTFILES_CUSTOM_CONFIG" ]
then
  sudo -u "$DOTFILES_BOOTSTRAP_USER" \
    echo "---" > "$DOTFILES_CUSTOM_CONFIG"
fi

sudo -u "$DOTFILES_BOOTSTRAP_USER" \
  DOTFILES_BOOTSTRAP_ROOT="$DOTFILES_BOOTSTRAP_ROOT" \
  DOTFILES_BOOTSTRAP_USER="$DOTFILES_BOOTSTRAP_USER" \
  DOTFILES_BOOTSTRAP_USER_HOME="$DOTFILES_BOOTSTRAP_USER_HOME" \
  DOTFILES_BOOTSTRAP_GIT_NAME="$DOTFILES_BOOTSTRAP_GIT_NAME" \
  DOTFILES_BOOTSTRAP_GIT_EMAIL="$DOTFILES_BOOTSTRAP_GIT_EMAIL" \
  ansible-playbook -v -i "$DOTFILES_HOSTS" "$DOTFILES_PLAYBOOK" \
  --ask-become-pass \
  --tags "$TAG" \
  --skip-tags "$EXTAG"

exit 0
