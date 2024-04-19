# ======================================================================= #
#  Copyright (C) 2020 - 2024 Dominik Willner <th33xitus@gmail.com>        #
#                                                                         #
#  This file is part of KIAUH - Klipper Installation And Update Helper    #
#  https://github.com/dw-0/kiauh                                          #
#                                                                         #
#  This file may be distributed under the terms of the GNU GPLv3 license  #
# ======================================================================= #


import shutil
import subprocess
from typing import List

from components.klipper.klipper import Klipper
from components.moonraker.moonraker import Moonraker
from components.webui_client.base_data import BaseWebClientConfig
from core.instance_manager.instance_manager import InstanceManager
from utils.filesystem_utils import remove_file, remove_config_section
from utils.logger import Logger


def run_client_config_removal(
    client_config: BaseWebClientConfig,
    kl_instances: List[Klipper],
    mr_instances: List[Moonraker],
) -> None:
    remove_client_config_dir(client_config)
    remove_client_config_symlink(client_config)
    remove_config_section(f"update_manager {client_config.name}", mr_instances)
    remove_config_section(client_config.config_section, kl_instances)


def remove_client_config_dir(client_config: BaseWebClientConfig) -> None:
    Logger.print_status(f"Removing {client_config.name} ...")
    client_config_dir = client_config.config_dir
    if not client_config_dir.exists():
        Logger.print_info(f"'{client_config_dir}' does not exist. Skipping ...")
        return

    try:
        shutil.rmtree(client_config_dir)
    except OSError as e:
        Logger.print_error(f"Unable to delete '{client_config_dir}':\n{e}")


def remove_client_config_symlink(client_config: BaseWebClientConfig) -> None:
    im = InstanceManager(Klipper)
    instances: List[Klipper] = im.instances
    for instance in instances:
        Logger.print_status(f"Removing symlink from '{instance.cfg_dir}' ...")
        symlink = instance.cfg_dir.joinpath(client_config.config_filename)
        if not symlink.is_symlink():
            Logger.print_info(f"'{symlink}' does not exist. Skipping ...")
            continue

        try:
            remove_file(symlink)
        except subprocess.CalledProcessError:
            Logger.print_error("Failed to remove symlink!")
