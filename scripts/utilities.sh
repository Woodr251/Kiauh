#!/bin/bash

#=======================================================================#
# Copyright (C) 2020 - 2022 Dominik Willner <th33xitus@gmail.com>       #
#                                                                       #
# This file is part of KIAUH - Klipper Installation And Update Helper   #
# https://github.com/th33xitus/kiauh                                    #
#                                                                       #
# This file may be distributed under the terms of the GNU GPLv3 license #
#=======================================================================#

set -e

### base variables
SYSTEMD="/etc/systemd/system"
LOGFILE="/tmp/kiauh.log"

# setting up some frequently used functions
check_euid(){
  if [ "${EUID}" -eq 0 ]
  then
    echo -e "${red}"
    top_border
    echo -e "|       !!! THIS SCRIPT MUST NOT RAN AS ROOT !!!        |"
    bottom_border
    echo -e "${white}"
    exit 1
  fi
}

function timestamp() {
  date +"[%F %T]"
}

function log() {
  local message="${1}"
  echo -e "$(timestamp) ${message}" | tr -s " " >> "${LOGFILE}"
}

check_klipper_cfg_path(){
  source_kiauh_ini
  if [ -z "${klipper_cfg_loc}" ]; then
    echo
    top_border
    echo -e "|                    ${red}!!! WARNING !!!${white}                    |"
    echo -e "|        ${red}No Klipper configuration directory set!${white}        |"
    hr
    echo -e "|  Before we can continue, KIAUH needs to know where    |"
    echo -e "|  you want your printer configuration to be.           |"
    blank_line
    echo -e "|  Please specify a folder where your Klipper configu-  |"
    echo -e "|  ration is stored or, if you don't have one yet, in   |"
    echo -e "|  which it should be saved after the installation.     |"
    bottom_border
    change_klipper_cfg_path
  fi
}

change_klipper_cfg_path(){
  source_kiauh_ini
  old_klipper_cfg_loc="${klipper_cfg_loc}"
  EXAMPLE_FOLDER=$(printf "%s/your_config_folder" "${HOME}")
  while true; do
    top_border
    echo -e "|  ${red}IMPORTANT:${white}                                           |"
    echo -e "|  Please enter the new path in the following format:   |"
    printf "|  ${yellow}%-51s${white}  |\n" "${EXAMPLE_FOLDER}"
    blank_line
    echo -e "|  By default 'klipper_config' is recommended!          |"
    bottom_border
    echo
    echo -e "${cyan}###### Please set the Klipper config directory:${white} "
    if [ -z "${old_klipper_cfg_loc}" ]; then
      read -e -i "/home/${USER}/klipper_config" -e new_klipper_cfg_loc
    else
      read -e -i "${old_klipper_cfg_loc}" -e new_klipper_cfg_loc
    fi
    echo
    read -p "${cyan}###### Set config directory to '${yellow}${new_klipper_cfg_loc}${cyan}' ? (Y/n):${white} " yn
    case "${yn}" in
      Y|y|Yes|yes|"")
        echo -e "###### > Yes"

        ### backup the old config dir
        backup_klipper_config_dir

        ### write new location to kiauh.ini
        sed -i "s|klipper_cfg_loc=${old_klipper_cfg_loc}|klipper_cfg_loc=${new_klipper_cfg_loc}|" "${INI_FILE}"
        status_msg "Directory set to '${new_klipper_cfg_loc}'!"

        ### write new location to klipper and moonraker service
        set_klipper_cfg_path
        echo; ok_msg "Config directory changed!"
        break;;
      N|n|No|no)
        echo -e "###### > No"
        change_klipper_cfg_path
        break;;
      *)
        print_unkown_cmd
        print_msg && clear_msg;;
    esac
  done
}

set_klipper_cfg_path(){
  ### stop services
  do_action_service "stop" "klipper"
  do_action_service "stop" "moonraker"

  ### copy config files to new klipper config folder
  if [ -n "${old_klipper_cfg_loc}" ] && [ -d "${old_klipper_cfg_loc}" ]; then
    if [ ! -d "${new_klipper_cfg_loc}" ]; then
      status_msg "Copy config files to '${new_klipper_cfg_loc}' ..."
      mkdir -p "${new_klipper_cfg_loc}"
      cd "${old_klipper_cfg_loc}"
      cp -r -v ./* "${new_klipper_cfg_loc}"
      ok_msg "Done!"
    fi
  fi

  SERVICE_FILES=$(find "${SYSTEMD}" -regextype posix-extended -regex "${SYSTEMD}/klipper(-[^0])+[0-9]*.service")
  ### handle single klipper instance service file
  if [ -f "${SYSTEMD}/klipper.service" ]; then
    status_msg "Configuring Klipper for new path ..."
    sudo sed -i -r "/ExecStart=/ s|klippy.py (.+)\/printer.cfg|klippy.py ${new_klipper_cfg_loc}/printer.cfg|" "${SYSTEMD}/klipper.service"
    ok_msg "OK!"
  elif [ -n "${SERVICE_FILES}" ]; then
    ### handle multi klipper instance service file
    status_msg "Configuring Klipper for new path ..."
    for service in ${SERVICE_FILES}; do
      sudo sed -i -r "/ExecStart=/ s|klippy.py (.+)\/printer_|klippy.py ${new_klipper_cfg_loc}/printer_|" "${service}"
    done
    ok_msg "OK!"
  fi

  SERVICE_FILES=$(find "${SYSTEMD}" -regextype posix-extended -regex "${SYSTEMD}/moonraker(-[^0])+[0-9]*.service")
  ### handle single moonraker instance service and moonraker.conf file
  if [ -f "${SYSTEMD}/moonraker.service" ]; then
    status_msg "Configuring Moonraker for new path ..."
    sudo sed -i -r "/ExecStart=/ s|-c (.+)\/moonraker\.conf|-c ${new_klipper_cfg_loc}/moonraker.conf|" "${SYSTEMD}/moonraker.service"

    ### replace old file path with new one in moonraker.conf
    sed -i -r "/config_path:/ s|config_path:.*|config_path: ${new_klipper_cfg_loc}|" "${new_klipper_cfg_loc}/moonraker.conf"
    ok_msg "OK!"
  elif [ -n "${SERVICE_FILES}" ]; then
    ### handle multi moonraker instance service file
    status_msg "Configuring Moonraker for new path ..."
    for service in ${SERVICE_FILES}; do
      sudo sed -i -r "/ExecStart=/ s|-c (.+)\/printer_|-c ${new_klipper_cfg_loc}/printer_|" "${service}"
    done
    MR_CONFS=$(find "${new_klipper_cfg_loc}" -regextype posix-extended -regex "${new_klipper_cfg_loc}/printer_[1-9]+/moonraker.conf")
    ### replace old file path with new one in moonraker.conf
    for moonraker_conf in ${MR_CONFS}; do
      loc=$(echo "${moonraker_conf}" | rev | cut -d"/" -f2- | rev)
      sed -i -r "/config_path:/ s|config_path:.*|config_path: ${loc}|" "${moonraker_conf}"
    done
    ok_msg "OK!"
  fi

  ### reloading units
  sudo systemctl daemon-reload

  ### restart services
  do_action_service "restart" "klipper"
  do_action_service "restart" "moonraker"
}

source_kiauh_ini(){
  source $INI_FILE
}

do_action_service(){
  shopt -s extglob # enable extended globbing
  SERVICES="${SYSTEMD}/$2?(-*([0-9])).service"
  ### set a variable for the ok and status messages
  [ "$1" == "start" ] && ACTION1="started" && ACTION2="Starting"
  [ "$1" == "stop" ] && ACTION1="stopped" && ACTION2="Stopping"
  [ "$1" == "restart" ] && ACTION1="restarted" && ACTION2="Restarting"
  [ "$1" == "enable" ] && ACTION1="enabled" && ACTION2="Enabling"
  [ "$1" == "disable" ] && ACTION1="disabled" && ACTION2="Disabling"

  if ls "${SERVICES}" 2>/dev/null 1>&2; then
    for service in $(ls "${SERVICES}" | rev | cut -d"/" -f1 | rev); do
      status_msg "${ACTION2} ${service} ..."
      sudo systemctl "${1}" "${service}"
      ok_msg "${service} ${ACTION1}!"
    done
  fi
  shopt -u extglob # disable extended globbing
}

toggle_octoprint_service(){
  if systemctl list-unit-files | grep -E "octoprint.*" | grep "enabled" &>/dev/null; then
    do_action_service "stop" "octoprint"
    do_action_service "disable" "octoprint"
    sleep 2
    CONFIRM_MSG=" OctoPrint Service is now >>> DISABLED <<< !"
  elif systemctl list-unit-files | grep -E "octoprint.*" | grep "disabled" &>/dev/null; then
    do_action_service "enable" "octoprint"
    do_action_service "start" "octoprint"
    sleep 2
    CONFIRM_MSG=" OctoPrint Service is now >>> ENABLED <<< !"
  else
    ERROR_MSG=" You cannot activate a service that does not exist!"
  fi
}

read_octoprint_service_status(){
  unset OPRINT_SERVICE_STATUS
  if [ ! -f "/etc/systemd/system/octoprint.service" ]; then
    return 0
  fi
  if systemctl list-unit-files | grep -E "octoprint*" | grep "enabled" &>/dev/null; then
    OPRINT_SERVICE_STATUS="${red}[Disable]${white} OctoPrint Service                       "
  else
    OPRINT_SERVICE_STATUS="${green}[Enable]${white} OctoPrint Service                        "
  fi
}

start_klipperscreen(){
  status_msg "Starting KlipperScreen Service ..."
  sudo systemctl start KlipperScreen && ok_msg "KlipperScreen Service started!"
}

stop_klipperscreen(){
  status_msg "Stopping KlipperScreen Service ..."
  sudo systemctl stop KlipperScreen && ok_msg "KlipperScreen Service stopped!"
}

restart_klipperscreen(){
  status_msg "Restarting KlipperScreen Service ..."
  sudo systemctl restart KlipperScreen && ok_msg "KlipperScreen Service restarted!"
}

start_MoonrakerTelegramBot(){
  status_msg "Starting MoonrakerTelegramBot Service ..."
  sudo systemctl start moonraker-telegram-bot && ok_msg "MoonrakerTelegramBot Service started!"
}

stop_MoonrakerTelegramBot(){
  status_msg "Stopping MoonrakerTelegramBot Service ..."
  sudo systemctl stop moonraker-telegram-bot && ok_msg "MoonrakerTelegramBot Service stopped!"
}

restart_MoonrakerTelegramBot(){
  status_msg "Restarting MoonrakerTelegramBot Service ..."
  sudo systemctl restart moonraker-telegram-bot && ok_msg "MoonrakerTelegramBot Service restarted!"
}

restart_nginx(){
  if ls /lib/systemd/system/nginx.service 2>/dev/null 1>&2; then
    status_msg "Restarting NGINX Service ..."
    sudo systemctl restart nginx && ok_msg "NGINX Service restarted!"
  fi
}

dependency_check(){
  local dep="${1}" # dep: array
  status_msg "Checking for the following dependencies:"
  #check if package is installed, if not write name into array
  for pkg in ${dep}
  do
    echo -e "${cyan}● ${pkg} ${white}"
    if [[ ! $(dpkg-query -f'${Status}' --show "${pkg}" 2>/dev/null) = *\ installed ]]; then
      inst+=("${pkg}")
    fi
  done
  #if array is not empty, install packages from array elements
  if [ "${#inst[@]}" -ne 0 ]; then
    status_msg "Installing the following dependencies:"
    for element in "${inst[@]}"
    do
      echo -e "${cyan}● ${element} ${white}"
    done
    echo
    sudo apt-get update --allow-releaseinfo-change && sudo apt-get install "${inst[@]}" -y
    ok_msg "Dependencies installed!"
    #clearing the array
    unset inst
  else
    ok_msg "Dependencies already met! Continue..."
  fi
}

setup_gcode_shell_command(){
  echo
  top_border
  echo -e "| You are about to install the G-Code Shell Command     |"
  echo -e "| extension. Please make sure to read the instructions  |"
  echo -e "| before you continue and remember that potential risks |"
  echo -e "| can be involved after installing this extension!      |"
  blank_line
  echo -e "| ${red}You accept that you are doing this on your own risk!${white}  |"
  bottom_border
  while true; do
    read -p "${cyan}###### Do you want to continue? (Y/n):${white} " yn
    case "${yn}" in
      Y|y|Yes|yes|"")
        if [ -d "${KLIPPER_DIR}/klippy/extras" ]; then
          status_msg "Installing gcode shell command extension ..."
          if [ -f "${KLIPPER_DIR}/klippy/extras/gcode_shell_command.py" ]; then
            warn_msg "There is already a file named 'gcode_shell_command.py'\nin the destination location!"
            while true; do
              read -p "${cyan}###### Do you want to overwrite it? (Y/n):${white} " yn
              case "${yn}" in
                Y|y|Yes|yes|"")
                  rm -f "${KLIPPER_DIR}/klippy/extras/gcode_shell_command.py"
                  install_gcode_shell_command
                  break;;
                N|n|No|no)
                  break;;
              esac
            done
          else
            install_gcode_shell_command
          fi
        else
          ERROR_MSG="Folder ~/klipper/klippy/extras not found!"
        fi
        break;;
      N|n|No|no)
        break;;
      *)
        print_unkown_cmd
        print_msg && clear_msg;;
    esac
  done
}

install_gcode_shell_command(){
  do_action_service "stop" "klipper"
  status_msg "Copy 'gcode_shell_command.py' to '${KLIPPER_DIR}/klippy/extras' ..."
  cp "${SRCDIR}/kiauh/resources/gcode_shell_command.py" "${KLIPPER_DIR}/klippy/extras"
  while true; do
    echo
    read -p "${cyan}###### Do you want to create the example shell command? (Y/n):${white} " yn
    case "${yn}" in
      Y|y|Yes|yes|"")
        status_msg "Copy shell_command.cfg ..."
        ### create a backup of the config folder
        backup_klipper_config_dir

        ### handle single printer.cfg
        if [ -f "${klipper_cfg_loc}/printer.cfg" ] && [ ! -f "${klipper_cfg_loc}/shell_command.cfg" ]; then
          ### copy shell_command.cfg to config location
          cp "${SRCDIR}/kiauh/resources/shell_command.cfg" "${klipper_cfg_loc}"
          ok_msg "${klipper_cfg_loc}/shell_command.cfg created!"

          ### write the include to the very first line of the printer.cfg
          sed -i "1 i [include shell_command.cfg]" "${klipper_cfg_loc}/printer.cfg"
        fi

        ### handle multi printer.cfg
        if ls "${klipper_cfg_loc}"/printer_*  2>/dev/null 1>&2; then
          for config in $(find ${klipper_cfg_loc}/printer_*/printer.cfg); do
            path=$(echo "${config}" | rev | cut -d"/" -f2- | rev)
            if [ ! -f "${path}/shell_command.cfg" ]; then
              ### copy shell_command.cfg to config location
              cp "${SRCDIR}/kiauh/resources/shell_command.cfg" "${path}"
              ok_msg "${path}/shell_command.cfg created!"

              ### write the include to the very first line of the printer.cfg
              sed -i "1 i [include shell_command.cfg]" "${path}/printer.cfg"
            fi
          done
        fi
        break;;
      N|n|No|no)
        break;;
    esac
  done
  ok_msg "Shell command extension installed!"
  do_action_service "restart" "klipper"
}

create_minimal_cfg(){
  #create a minimal default config
  if [ "${SEL_DEF_CFG}" = "true" ]; then
		cat <<- EOF >> "${PRINTER_CFG}"
		[mcu]
		serial: </dev/serial/by-id/your-mcu>

		[printer]
		kinematics: none
		max_velocity: 1
		max_accel: 1

		[virtual_sdcard]
		path: ~/sdcard

		[pause_resume]
		[display_status]
EOF
  fi
}

init_ini(){
  ### copy an existing kiauh.ini to its new location to keep all possible saved values
  if [ -f "${SRCDIR}/kiauh/kiauh.ini" ] && [ ! -f "${INI_FILE}" ]; then
    cp "${SRCDIR}/kiauh/kiauh.ini" "${INI_FILE}"
  fi
  if [ ! -f "${INI_FILE}" ]; then
    echo -e "#don't edit this file if you don't know what you are doing...\c" > "${INI_FILE}"
  fi
  if [ ! $(grep -E "^backup_before_update=." "${INI_FILE}") ]; then
    echo -e "\nbackup_before_update=false\c" >> "${INI_FILE}"
  fi
  if [ ! $(grep -E "^previous_origin_state=[[:alnum:]]" "${INI_FILE}") ]; then
    echo -e "\nprevious_origin_state=0\c" >> "${INI_FILE}"
  fi
  if [ ! $(grep -E "^previous_smoothing_state=[[:alnum:]]" "${INI_FILE}") ]; then
    echo -e "\nprevious_smoothing_state=0\c" >> "${INI_FILE}"
  fi
  if [ ! $(grep -E "^previous_shaping_state=[[:alnum:]]" "${INI_FILE}") ]; then
    echo -e "\nprevious_shaping_state=0\c" >> "${INI_FILE}"
  fi
  if [ ! $(grep -E "^logupload_accepted=." "${INI_FILE}") ]; then
    echo -e "\nlogupload_accepted=false\c" >> "${INI_FILE}"
  fi
  ###add empty klipper config path if missing
  if [ ! $(grep -E "^klipper_cfg_loc=" "${INI_FILE}") ]; then
    echo -e "\nklipper_cfg_loc=\c" >> "${INI_FILE}"
  fi
  fetch_webui_ports
}
