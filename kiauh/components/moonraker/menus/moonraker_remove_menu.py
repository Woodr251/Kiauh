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

from components.moonraker import moonraker_remove
from core.menus import Option
from core.menus.base_menu import BaseMenu
from utils.constants import RESET_FORMAT, COLOR_RED, COLOR_CYAN


# noinspection PyUnusedLocal
class MoonrakerRemoveMenu(BaseMenu):
    def __init__(self, previous_menu: Optional[Type[BaseMenu]] = None):
        super().__init__()
        self.previous_menu = previous_menu
        self.remove_moonraker_service = False
        self.remove_moonraker_dir = False
        self.remove_moonraker_env = False
        self.remove_moonraker_polkit = False
        self.delete_moonraker_logs = False

    def set_previous_menu(self, previous_menu: Optional[Type[BaseMenu]]) -> None:
        from core.menus.remove_menu import RemoveMenu

        self.previous_menu: Type[BaseMenu] = (
            previous_menu if previous_menu is not None else RemoveMenu
        )

    def set_options(self) -> None:
        self.options = {
            "0": Option(method=self.toggle_all, menu=False),
            "1": Option(method=self.toggle_remove_moonraker_service, menu=False),
            "2": Option(method=self.toggle_remove_moonraker_dir, menu=False),
            "3": Option(method=self.toggle_remove_moonraker_env, menu=False),
            "4": Option(method=self.toggle_remove_moonraker_polkit, menu=False),
            "5": Option(method=self.toggle_delete_moonraker_logs, menu=False),
            "c": Option(method=self.run_removal_process, menu=False),
        }

    def print_menu(self) -> None:
        header = " [ Remove Moonraker ] "
        color = COLOR_RED
        count = 62 - len(color) - len(RESET_FORMAT)
        checked = f"[{COLOR_CYAN}x{RESET_FORMAT}]"
        unchecked = "[ ]"
        o1 = checked if self.remove_moonraker_service else unchecked
        o2 = checked if self.remove_moonraker_dir else unchecked
        o3 = checked if self.remove_moonraker_env else unchecked
        o4 = checked if self.remove_moonraker_polkit else unchecked
        o5 = checked if self.delete_moonraker_logs else unchecked
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
            |  4) {o4} Remove Policy Kit Rules                       |
            |  5) {o5} Delete all Log-Files                          |
            |-------------------------------------------------------|
            |  C) Continue                                          |
            """
        )[1:]
        print(menu, end="")

    def toggle_all(self, **kwargs) -> None:
        self.remove_moonraker_service = True
        self.remove_moonraker_dir = True
        self.remove_moonraker_env = True
        self.remove_moonraker_polkit = True
        self.delete_moonraker_logs = True

    def toggle_remove_moonraker_service(self, **kwargs) -> None:
        self.remove_moonraker_service = not self.remove_moonraker_service

    def toggle_remove_moonraker_dir(self, **kwargs) -> None:
        self.remove_moonraker_dir = not self.remove_moonraker_dir

    def toggle_remove_moonraker_env(self, **kwargs) -> None:
        self.remove_moonraker_env = not self.remove_moonraker_env

    def toggle_remove_moonraker_polkit(self, **kwargs) -> None:
        self.remove_moonraker_polkit = not self.remove_moonraker_polkit

    def toggle_delete_moonraker_logs(self, **kwargs) -> None:
        self.delete_moonraker_logs = not self.delete_moonraker_logs

    def run_removal_process(self, **kwargs) -> None:
        if (
            not self.remove_moonraker_service
            and not self.remove_moonraker_dir
            and not self.remove_moonraker_env
            and not self.remove_moonraker_polkit
            and not self.delete_moonraker_logs
        ):
            error = f"{COLOR_RED}Nothing selected! Select options to remove first.{RESET_FORMAT}"
            print(error)
            return

        moonraker_remove.run_moonraker_removal(
            self.remove_moonraker_service,
            self.remove_moonraker_dir,
            self.remove_moonraker_env,
            self.remove_moonraker_polkit,
            self.delete_moonraker_logs,
        )

        self.remove_moonraker_service = False
        self.remove_moonraker_dir = False
        self.remove_moonraker_env = False
        self.remove_moonraker_polkit = False
        self.delete_moonraker_logs = False
