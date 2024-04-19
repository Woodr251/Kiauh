# ======================================================================= #
#  Copyright (C) 2020 - 2024 Dominik Willner <th33xitus@gmail.com>        #
#                                                                         #
#  This file is part of KIAUH - Klipper Installation And Update Helper    #
#  https://github.com/dw-0/kiauh                                          #
#                                                                         #
#  This file may be distributed under the terms of the GNU GPLv3 license  #
# ======================================================================= #

import textwrap
from typing import Type, Optional

from components.klipper import klipper_remove
from core.menus import FooterType, Option
from core.menus.base_menu import BaseMenu
from utils.constants import RESET_FORMAT, COLOR_RED, COLOR_CYAN


# noinspection PyUnusedLocal
class KlipperRemoveMenu(BaseMenu):
    def __init__(self, previous_menu: Optional[Type[BaseMenu]] = None):
        super().__init__()
        self.previous_menu = previous_menu
        self.footer_type = FooterType.BACK_HELP
        self.remove_klipper_service = False
        self.remove_klipper_dir = False
        self.remove_klipper_env = False
        self.delete_klipper_logs = False

    def set_previous_menu(self, previous_menu: Optional[Type[BaseMenu]]) -> None:
        from core.menus.remove_menu import RemoveMenu

        self.previous_menu: Type[BaseMenu] = (
            previous_menu if previous_menu is not None else RemoveMenu
        )

    def set_options(self) -> None:
        self.options = {
            "0": Option(method=self.toggle_all, menu=False),
            "1": Option(method=self.toggle_remove_klipper_service, menu=False),
            "2": Option(method=self.toggle_remove_klipper_dir, menu=False),
            "3": Option(method=self.toggle_remove_klipper_env, menu=False),
            "4": Option(method=self.toggle_delete_klipper_logs, menu=False),
            "c": Option(method=self.run_removal_process, menu=False),
        }

    def print_menu(self) -> None:
        header = " [ Remove Klipper ] "
        color = COLOR_RED
        count = 62 - len(color) - len(RESET_FORMAT)
        checked = f"[{COLOR_CYAN}x{RESET_FORMAT}]"
        unchecked = "[ ]"
        o1 = checked if self.remove_klipper_service else unchecked
        o2 = checked if self.remove_klipper_dir else unchecked
        o3 = checked if self.remove_klipper_env else unchecked
        o4 = checked if self.delete_klipper_logs else unchecked
        menu = textwrap.dedent(
            f"""
            /=======================================================\\
            | {color}{header:~^{count}}{RESET_FORMAT} |
            |-------------------------------------------------------|
            | Enter a number and hit enter to select / deselect     |
            | the specific option for removal.                      |
            |-------------------------------------------------------|
            |  0) Select everything                                 |
            |-------------------------------------------------------|
            |  1) {o1} Remove Service                                |
            |  2) {o2} Remove Local Repository                       |
            |  3) {o3} Remove Python Environment                     |
            |  4) {o4} Delete all Log-Files                          |
            |-------------------------------------------------------|
            |  C) Continue                                          |
            """
        )[1:]
        print(menu, end="")

    def toggle_all(self, **kwargs) -> None:
        self.remove_klipper_service = True
        self.remove_klipper_dir = True
        self.remove_klipper_env = True
        self.delete_klipper_logs = True

    def toggle_remove_klipper_service(self, **kwargs) -> None:
        self.remove_klipper_service = not self.remove_klipper_service

    def toggle_remove_klipper_dir(self, **kwargs) -> None:
        self.remove_klipper_dir = not self.remove_klipper_dir

    def toggle_remove_klipper_env(self, **kwargs) -> None:
        self.remove_klipper_env = not self.remove_klipper_env

    def toggle_delete_klipper_logs(self, **kwargs) -> None:
        self.delete_klipper_logs = not self.delete_klipper_logs

    def run_removal_process(self, **kwargs) -> None:
        if (
            not self.remove_klipper_service
            and not self.remove_klipper_dir
            and not self.remove_klipper_env
            and not self.delete_klipper_logs
        ):
            error = f"{COLOR_RED}Nothing selected! Select options to remove first.{RESET_FORMAT}"
            print(error)
            return

        klipper_remove.run_klipper_removal(
            self.remove_klipper_service,
            self.remove_klipper_dir,
            self.remove_klipper_env,
            self.delete_klipper_logs,
        )

        self.remove_klipper_service = False
        self.remove_klipper_dir = False
        self.remove_klipper_env = False
        self.delete_klipper_logs = False
