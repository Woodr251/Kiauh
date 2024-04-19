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
from pathlib import Path
from typing import List

from components.webui_client.base_data import BaseWebClient, BaseWebClientConfig
from kiauh import KIAUH_CFG
from components.klipper.klipper import Klipper
from components.moonraker.moonraker import Moonraker
from components.webui_client.client_dialogs import (
    print_client_already_installed_dialog,
)
from components.webui_client.client_utils import (
    backup_client_config_data,
    config_for_other_client_exist,
)
from core.config_manager.config_manager import ConfigManager

from core.instance_manager.instance_manager import InstanceManager
from core.repo_manager.repo_manager import RepoManager
from utils.common import backup_printer_config_dir
from utils.filesystem_utils import (
    create_symlink,
    add_config_section,
    add_config_section_at_top,
)
from utils.input_utils import get_confirm
from utils.logger import Logger


def install_client_config(client_data: BaseWebClient) -> None:
    client_config: BaseWebClientConfig = client_data.client_config
    display_name = client_config.display_name

    if config_for_other_client_exist(client_data.client):
        Logger.print_info("Another Client-Config is already installed! Skipped ...")
        return

    if client_config.config_dir.exists():
        print_client_already_installed_dialog(display_name)
        if get_confirm(f"Re-install {display_name}?", allow_go_back=True):
            shutil.rmtree(client_config.config_dir)
        else:
            return

    mr_im = InstanceManager(Moonraker)
    mr_instances: List[Moonraker] = mr_im.instances
    kl_im = InstanceManager(Klipper)
    kl_instances = kl_im.instances

    try:
        download_client_config(client_config)
        create_client_config_symlink(client_config, kl_instances)

        backup_printer_config_dir()

        add_config_section(
            section=f"update_manager {client_config.name}",
            instances=mr_instances,
            options=[
                ("type", "git_repo"),
                ("primary_branch", "master"),
                ("path", str(client_config.config_dir)),
                ("origin", str(client_config.repo_url)),
                ("managed_services", "klipper"),
            ],
        )
        add_config_section_at_top(client_config.config_section, kl_instances)
        kl_im.restart_all_instance()

    except Exception as e:
        Logger.print_error(f"{display_name} installation failed!\n{e}")
        return

    Logger.print_ok(f"{display_name} installation complete!", start="\n")


def download_client_config(client_config: BaseWebClientConfig) -> None:
    try:
        Logger.print_status(f"Downloading {client_config.display_name} ...")
        rm = RepoManager(
            client_config.repo_url,
            target_dir=str(client_config.config_dir),
        )
        rm.clone_repo()
    except Exception:
        Logger.print_error(f"Downloading {client_config.display_name} failed!")
        raise


def update_client_config(client: BaseWebClient) -> None:
    client_config: BaseWebClientConfig = client.client_config

    Logger.print_status(f"Updating {client_config.display_name} ...")

    if not client_config.config_dir.exists():
        Logger.print_info(
            f"Unable to update {client_config.display_name}. Directory does not exist! Skipping ..."
        )
        return

    cm = ConfigManager(cfg_file=KIAUH_CFG)
    if cm.get_value("kiauh", "backup_before_update"):
        backup_client_config_data(client)

    repo_manager = RepoManager(
        repo=client_config.repo_url,
        branch="master",
        target_dir=str(client_config.config_dir),
    )
    repo_manager.pull_repo()

    Logger.print_ok(f"Successfully updated {client_config.display_name}.")
    Logger.print_info("Restart Klipper to reload the configuration!")


def create_client_config_symlink(
    client_config: BaseWebClientConfig, klipper_instances: List[Klipper] = None
) -> None:
    if klipper_instances is None:
        kl_im = InstanceManager(Klipper)
        klipper_instances = kl_im.instances

    Logger.print_status(f"Create symlink for {client_config.config_filename} ...")
    source = Path(client_config.config_dir, client_config.config_filename)
    for instance in klipper_instances:
        target = instance.cfg_dir
        Logger.print_status(f"Linking {source} to {target}")
        try:
            create_symlink(source, target)
        except subprocess.CalledProcessError:
            Logger.print_error("Creating symlink failed!")
