#!/bin/bash

FOLDERS_TO_KEEP="DEFAULT_FOLDER_1,DEFAULT_FOLDER_2,DEFAULT_FOLDER_3,DEFAULT_FOLDER_4"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# FUNCTIONS
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function enable() {
  local folder_names
  folder_names=$1

  IFS=', ' read -r -a folder_names_arr <<<"${folder_names}"

  for folder_name in "${folder_names_arr[@]}"; do
    if [ ! -d "$folder_name" ]; then
      echo " :> Invalid parameter ($folder_name). Use a valid folder name instead."
      exit 2
    fi
  done

  echo " :> Sparse checkout will be enabled for ${folder_names}"

  git config core.sparsecheckout true

  echo "/*" >.git/info/sparse-checkout

  IFS=', ' read -r -a keep_folders_arr <<<"${FOLDERS_TO_KEEP}"
  pipe_delimited_keep_folders=$(
    IFS=$'|'
    echo "${keep_folders_arr[*]}"
  )
  pipe_delimited_folder_names=$(
    IFS=$'|'
    echo "${folder_names_arr[*]}"
  )

  INCLUDED_FOLDERS=".*(${pipe_delimited_keep_folders}|${pipe_delimited_folder_names}).*"
  for d in */; do
    if [[ ! "$d" =~ $INCLUDED_FOLDERS ]]; then
      echo "!${d}" >>.git/info/sparse-checkout
    fi
  done

  git read-tree -mu HEAD

  echo " :> Removing irrelevant folders"
  git clean -fd &>/dev/null

  for d in */; do
    if [[ ! "$d" =~ $INCLUDED_FOLDERS ]]; then
      rm -rf "${d}"
    fi
  done

  echo " :> Sparse checkout completed for ${folder_names}"
}

function disable() {
  echo "/*" >.git/info/sparse-checkout
  git read-tree -mu HEAD
  git config core.sparseCheckout false
  echo " :> Sparse checkout is disabled. All folders are accessible for now."
}

function check_clean_state() {
  output=$(git status --porcelain)
  if [[ ! -z ${output} ]]; then
    echo "Uncommitted changes exist. Terminating."
    exit 3
  fi
}

function usage() {
  echo "Usage:"
  echo "   ./sparse-checkout.sh help"
  echo "   ./sparse-checkout.sh disable"
  echo "   ./sparse-checkout.sh enable FOLDER_NAME_1 FOLDER_NAME_2 FOLDER_NAME_3 [FOLDER_NAME_N]"
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# MAIN
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

OPERATION=$1
FOLDER_NAMES=${*:2}

check_clean_state
if [ "$OPERATION" == "enable" ]; then
  echo " :> Sparse-checkout will be disabled before enabling"
  disable
  enable "$FOLDER_NAMES"
elif [ "$OPERATION" == "disable" ]; then
  disable
elif [ "$OPERATION" == "help" ]; then
  usage
else
  echo "Invalid parameter ($OPERATION)."
  usage
fi
