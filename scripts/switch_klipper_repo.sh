#!/usr/bin/env bash

#=======================================================================#
# Copyright (C) 2020 - 2024 Dominik Willner <th33xitus@gmail.com>       #
#                                                                       #
# This file is part of KIAUH - Klipper Installation And Update Helper   #
# https://github.com/dw-0/kiauh                                         #
#                                                                       #
# This file may be distributed under the terms of the GNU GPLv3 license #
#=======================================================================#

set -e

function change_klipper_repo_menu() {
  local repo_file="${KIAUH_SRCDIR}/klipper_repos.txt"
  local repo branch repos=() branches=()

  if [[ ! -f ${repo_file} ]]; then
    print_error "File not found:\n '${KIAUH_SRCDIR}/klipper_repos.txt'"
    return
  fi

  ### generate the repolist from the klipper_repos.txt textfile
  while IFS="," read -r repo branch; do
    repo=$(echo "${repo}" | sed -r "s/^http(s)?:\/\/github.com\///" | sed "s/\.git$//" )
    repos+=("${repo}")
    ### if branch is not given, default to 'master'
    [[ -z ${branch} ]] && branch="master"
    branches+=("${branch}")
  done < <(grep -E "^[^#]" "${repo_file}")

  top_border
  echo -e "|     ~~~~~~~~ [ Set custom Klipper repo ] ~~~~~~~~     | "
  hr
  blank_line
  ### print repolist
  local i=0
  for _ in "${repos[@]}"; do
    printf "| %s) %-63s|\n" "${i}" "${yellow}${repos[${i}]}${white} → ${branches[${i}]}"
    i=$(( i + 1 ))
  done
  blank_line
  back_help_footer

  local option
  local num="^[0-9]+$"
  local back="^(B|b)$"
  local help="^(H|h)$"

  while true; do
    read -p "${cyan}###### Perform action:${white} " option

    if [[ ${option} =~ ${num} && ${option} -lt ${#repos[@]} ]]; then
      select_msg "Repo: ${repos[option]} Branch: ${branches[option]}"

      if [[ -d ${KLIPPER_DIR} ]]; then
        top_border
        echo -e "|                   ${red}!!! ATTENTION !!!${white}                   |"
        echo -e "| Existing Klipper folder found! Proceeding will remove | "
        echo -e "| the existing Klipper folder and replace it with a     | "
        echo -e "| clean copy of the previously selected source repo!    | "
        bottom_border

        local yn
        while true; do
        read -p "${cyan}###### Proceed? (Y/n):${white} " yn
          case "${yn}" in
            Y|y|Yes|yes|"")
              select_msg "Yes"
              switch_klipper_repo "${repos[${option}]}" "${branches[${option}]}"
              set_custom_klipper_repo "${repos[${option}]}" "${branches[${option}]}"
              break;;
            N|n|No|no)
              select_msg "No"
              break;;
            *)
              error_msg "Invalid command!";;
          esac
        done
        break
      else
        status_msg "Set custom Klipper repository to:\n       ● Repository: ${repos[${option}]}\n       ● Branch: ${branches[${option}]}"
        set_custom_klipper_repo "${repos[${option}]}" "${branches[${option}]}"
        ok_msg "This repo will now be used for new Klipper installations!\n"
        break
      fi

    elif [[ ${option} =~ ${back} ]]; then
      clear && print_header
      settings_menu
    elif [[ ${option} =~ ${help} ]]; then
      clear && print_header
      show_custom_klipper_repo_help
    else
      error_msg "Invalid command!"
    fi
  done

  change_klipper_repo_menu
}

#================================================#
#=================== HELPERS ====================#
#================================================#

function switch_klipper_repo() {
  local repo=${1} branch=${2}

  status_msg "Switching Klipper repository..."
  do_action_service "stop" "klipper"

  [[ -d ${KLIPPER_DIR} ]] && rm -rf "${KLIPPER_DIR}"
  clone_klipper "${repo}" "${branch}"

  do_action_service "start" "klipper"
}

function show_custom_klipper_repo_help() {
  top_border
  echo -e "|   ~~~~ < ? > Help: Custom Klipper repo < ? > ~~~~     |"
  hr
  echo -e "| With this setting, it is possible to install Klipper  |"
  echo -e "| from a custom repository. It will also switch an      |"
  echo -e "| existing Klipper installation to the newly selected   |"
  echo -e "| source repository.                                    |"
  echo -e "| A list of repositories is automatically generated by  |"
  echo -e "| a 'klipper_repos.txt' textfile in KIAUHs root folder. |"
  echo -e "| An example file is provided at the same location.     |"
  blank_line
  back_footer

  local choice
  while true; do
    read -p "${cyan}###### Please select:${white} " choice
    case "${choice}" in
      B|b)
        clear && print_header
        change_klipper_repo_menu
        break;;
      *)
        deny_action "show_settings_help";;
    esac
  done
}
