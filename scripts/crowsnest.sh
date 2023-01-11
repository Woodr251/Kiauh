#!/usr/bin/env bash

#=======================================================================#
# Copyright (C) 2020 - 2022 Dominik Willner <th33xitus@gmail.com>       #
#                                                                       #
# This file is part of KIAUH - Klipper Installation And Update Helper   #
# https://github.com/th33xitus/kiauh                                    #
#                                                                       #
# This file may be distributed under the terms of the GNU GPLv3 license #
#=======================================================================#

#=======================================================================#
# Crowsnest Installer brought to you by KwadFan <me@stephanwe.de>       #
# Copyright (C) 2022 KwadFan <me@stephanwe.de>                          #
# https://github.com/KwadFan/crowsnest                                  #
#=======================================================================#

# Error Handling
set -e

# Helper messages

function multi_instance_message(){
    echo -e "Crowsnest is NOT designed to support Multi Instances."
    echo -e "A Workaround for this is to choose the most used instance as a 'master'"
    echo -e "Use this instance to setup your 'crowsnest.conf' and steering it's service.\n"
    echo -e "Found the following instances:\n"
    for i in ${1}; do
        select_msg "${i}"
    done
    echo -e "\nLaunching crowsnest's configuration tool ..."
    continue_config
}

# Helper funcs
function clone_crowsnest(){
    $(command -v git) clone "${CROWSNEST_REPO}" -b master "${CROWSNEST_DIR}"
}

function check_multi_instance(){
    local -a instances
    readarray -t instances < <(find "${HOME}" -regex "${HOME}/[a-zA-Z0-9_]+_data/*" -printf "%P\n" 2> /dev/null | sort)
    if [[ "${#instances[@]}" -gt 1 ]]; then
        status_msg "Multi Instance Install detected ..."
        multi_instance_message "${instances[*]}"
        if [[ -d "${HOME}/crowsnest" ]]; then
            pushd "${HOME}/crowsnest" &> /dev/null || exit 1
            if ! make config ;then
                error_msg "Something went wrong! Please try again..."
                if [[ -f "tools/.config" ]]; then
                    rm -f tools/.config
                fi
                exit 1
            fi
            if [[ ! -f "tools/.config" ]]; then
                log_error "failure while generating .config"
                error_msg "Generating .config failed, installation aborted"
                exit 1
            fi
            popd &> /dev/null || exit 1
        fi
    fi
}

function continue_config() {
    local reply
    while true; do
        read -erp "Continue? [Y/n]: " -i "Y" reply
        case "${reply}" in
            [Yy]* )
                break
            ;;
            [Nn]* )
                warn_msg "Installation aborted by user ... Exiting!"
                exit 1
            ;;
            * )
                echo -e "\e[31mERROR: Please type Y or N !\e[0m"
            ;;
        esac
    done
    return 0
}

# function install_basic_deps(){
#     local -a install
#     local -a deps
#     deps=(git make)
#     for i in "${deps[@]}"; do
#         if [[ -z "$(command -v "${i}")" ]]; then
#             install+="${i}"
#         fi
#     done
#     if [[ -n "${install[*]}" ]]; then
#         ### Update system package info ( shameless stolen from klipper.sh )
#         status_msg "Updating package lists..."
#         if ! sudo apt-get update --allow-releaseinfo-change; then
#             log_error "failure while updating package lists"
#             error_msg "Updating package lists failed!"
#             exit 1
#         fi
#         status_msg "Installing required packages..."
#         if ! sudo apt-get install --yes "${install[@]}"; then
#             log_error "failure while installing required crowsnest basic packages"
#             error_msg "Installing required packages failed!"
#             exit 1
#         fi
#     else
#         ok_msg "All basic dependencies met, nothing to do!"
#     fi
# }


# Install func
function install_crowsnest(){

    # Step 1: jump to home directory
    pushd "${HOME}" &> /dev/null || exit 1

    # Step 2: Clone crowsnest repo
    status_msg "Cloning 'crowsnest' repository ..."
    if [[ ! -d "${HOME}/crowsnest" ]] &&
    [[ -z "$(ls -A "${HOME}/crowsnest")" ]]; then
        clone_crowsnest
    else
        ok_msg "crowsnest repository already exists ..."
    fi

    # Step 3: Install dependencies
    # status_msg "Install basic dependencies ..."
    # install_basic_deps
    dependency_check git make

    # Step 4: Check for Multi Instance
    check_multi_instance

    # Step 5: Launch crowsnest installer
    pushd "${HOME}/crowsnest" &> /dev/null || exit 1
    title_msg "Installer will prompt you for sudo password!"
    status_msg "Launching crowsnest installer ..."
    if ! sudo make install; then
        error_msg "Something went wrong! Please try again..."
        exit 1
    fi

    # Step 5: Leave directory (twice due two pushd)
    popd &> /dev/null || exit 1
    popd &> /dev/null || exit 1
}

# Remove func
function remove_crowsnest(){
    pushd "${HOME}/crowsnest" &> /dev/null || exit 1
    title_msg "Uninstaller will prompt you for sudo password!"
    status_msg "Launching crowsnest Uninstaller ..."
    if ! make uninstall; then
        error_msg "Something went wrong! Please try again..."
        exit 1
    fi
    if [[ -e "${CROWSNEST_DIR}" ]]; then
        status_msg "Removing Crowsnest directory ..."
        rm -rf "${CROWSNEST_DIR}"
    fi
}

# Status funcs
get_crowsnest_status(){
    local -a files
    files=(
        "${CROWSNEST_DIR}"
        "/usr/local/bin/crowsnest"
        "/etc/logrotate.d/crowsnest"
        "/etc/systemd/system/crowsnest.service"
        "$(find "${HOME}" -name 'crowsnest.env' 2> /dev/null ||
        echo "${HOME}/printer_data/systemd/crowsnest.env")"
        )
        # Contains ugly hackaround for multi instance... :(
    local count
    count=0

    for file in "${files[@]}"; do
        [[ -e "${file}" ]] && count=$(( count +1 ))
    done
    if [[ "${count}" -eq "${#files[*]}" ]]; then
        echo "Installed"
    elif [[ "${count}" -gt 0 ]]; then
        echo "Incomplete!"
    else 
        echo "Not installed!"
    fi
}

# Update funcs
# Shameless stolen from KlipperScreen.sh
function get_local_crowsnest_commit() {
  [[ ! -d ${CROWSNEST_DIR} || ! -d "${CROWSNEST_DIR}/.git" ]] && return

  local commit
  cd "${CROWSNEST_DIR}"
  commit="$(git describe HEAD --always --tags | cut -d "-" -f 1,2)"
  echo "${commit}"
}

function get_remote_crowsnest_commit() {
  [[ ! -d ${CROWSNEST_DIR} || ! -d "${CROWSNEST_DIR}/.git" ]] && return

  local commit
  cd "${CROWSNEST_DIR}" && git fetch origin -q
  commit=$(git describe origin/master --always --tags | cut -d "-" -f 1,2)
  echo "${commit}"
}

function compare_crowsnest_versions() {
  local versions local_ver remote_ver
  local_ver="$(get_local_crowsnest_commit)"
  remote_ver="$(get_remote_crowsnest_commit)"

  if [[ ${local_ver} != "${remote_ver}" ]]; then
    versions="${yellow}$(printf " %-14s" "${local_ver}")${white}"
    versions+="|${green}$(printf " %-13s" "${remote_ver}")${white}"
    # add moonraker to application_updates_available in kiauh.ini
    add_to_application_updates "crowsnest"
  else
    versions="${green}$(printf " %-14s" "${local_ver}")${white}"
    versions+="|${green}$(printf " %-13s" "${remote_ver}")${white}"
  fi

  echo "${versions}"
}