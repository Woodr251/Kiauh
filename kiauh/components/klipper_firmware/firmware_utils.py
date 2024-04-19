# ======================================================================= #
#  Copyright (C) 2020 - 2024 Dominik Willner <th33xitus@gmail.com>        #
#                                                                         #
#  This file is part of KIAUH - Klipper Installation And Update Helper    #
#  https://github.com/dw-0/kiauh                                          #
#                                                                         #
#  This file may be distributed under the terms of the GNU GPLv3 license  #
# ======================================================================= #

from subprocess import CalledProcessError, check_output, Popen, PIPE, STDOUT, run
from typing import List

from components.klipper import KLIPPER_DIR
from components.klipper.klipper import Klipper
from components.klipper_firmware import SD_FLASH_SCRIPT
from components.klipper_firmware.flash_options import (
    FlashOptions,
    FlashMethod,
)
from core.instance_manager.instance_manager import InstanceManager
from utils.logger import Logger
from utils.system_utils import log_process


def find_firmware_file() -> bool:
    target = KLIPPER_DIR.joinpath("out")
    target_exists = target.exists()

    f1 = "klipper.elf.hex"
    f2 = "klipper.elf"
    f3 = "klipper.bin"
    fw_file_exists = (
        target.joinpath(f1).exists() and target.joinpath(f2).exists()
    ) or target.joinpath(f3).exists()

    return target_exists and fw_file_exists


def find_usb_device_by_id() -> List[str]:
    try:
        command = "find /dev/serial/by-id/* 2>/dev/null"
        output = check_output(command, shell=True, text=True)
        return output.splitlines()
    except CalledProcessError as e:
        Logger.print_error("Unable to find a USB device!")
        Logger.print_error(e, prefix=False)
        return []


def find_uart_device() -> List[str]:
    try:
        command = '"find /dev -maxdepth 1 -regextype posix-extended -regex "^\/dev\/tty(AMA0|S0)$" 2>/dev/null"'
        output = check_output(command, shell=True, text=True)
        return output.splitlines()
    except CalledProcessError as e:
        Logger.print_error("Unable to find a UART device!")
        Logger.print_error(e, prefix=False)
        return []


def find_usb_dfu_device() -> List[str]:
    try:
        command = '"lsusb | grep "DFU" | cut -d " " -f 6 2>/dev/null"'
        output = check_output(command, shell=True, text=True)
        return output.splitlines()
    except CalledProcessError as e:
        Logger.print_error("Unable to find a USB DFU device!")
        Logger.print_error(e, prefix=False)
        return []


def get_sd_flash_board_list() -> List[str]:
    if not KLIPPER_DIR.exists() or not SD_FLASH_SCRIPT.exists():
        return []

    try:
        cmd = f"{SD_FLASH_SCRIPT} -l"
        blist = check_output(cmd, shell=True, text=True)
        return blist.splitlines()[1:]
    except CalledProcessError as e:
        Logger.print_error(f"An unexpected error occured:\n{e}")


def start_flash_process(flash_options: FlashOptions) -> None:
    Logger.print_status(f"Flashing '{flash_options.selected_mcu}' ...")
    try:
        if not flash_options.flash_method:
            raise Exception("Missing value for flash_method!")
        if not flash_options.flash_command:
            raise Exception("Missing value for flash_command!")
        if not flash_options.selected_mcu:
            raise Exception("Missing value for selected_mcu!")
        if not flash_options.connection_type:
            raise Exception("Missing value for connection_type!")
        if (
            flash_options.flash_method == FlashMethod.SD_CARD
            and not flash_options.selected_board
        ):
            raise Exception("Missing value for selected_board!")

        if flash_options.flash_method is FlashMethod.REGULAR:
            cmd = [
                "make",
                flash_options.flash_command.value,
                f"FLASH_DEVICE={flash_options.selected_mcu}",
            ]
        elif flash_options.flash_method is FlashMethod.SD_CARD:
            if not SD_FLASH_SCRIPT.exists():
                raise Exception("Unable to find Klippers sdcard flash script!")
            cmd = [
                SD_FLASH_SCRIPT.as_posix(),
                f"-b {flash_options.selected_baudrate}",
                flash_options.selected_mcu,
                flash_options.selected_board,
            ]
        else:
            raise Exception("Invalid value for flash_method!")

        instance_manager = InstanceManager(Klipper)
        instance_manager.stop_all_instance()

        process = Popen(cmd, cwd=KLIPPER_DIR, stdout=PIPE, stderr=STDOUT, text=True)
        log_process(process)

        instance_manager.start_all_instance()

        rc = process.returncode
        if rc != 0:
            raise Exception(f"Flashing failed with returncode: {rc}")
        else:
            Logger.print_ok("Flashing successfull!", start="\n", end="\n\n")

    except (Exception, CalledProcessError):
        Logger.print_error("Flashing failed!", start="\n")
        Logger.print_error("See the console output above!", end="\n\n")


def run_make_clean() -> None:
    try:
        run(
            "make clean",
            cwd=KLIPPER_DIR,
            shell=True,
            check=True,
        )
    except CalledProcessError as e:
        Logger.print_error(f"Unexpected error:\n{e}")
        raise


def run_make_menuconfig() -> None:
    try:
        run(
            "make PYTHON=python3 menuconfig",
            cwd=KLIPPER_DIR,
            shell=True,
            check=True,
        )
    except CalledProcessError as e:
        Logger.print_error(f"Unexpected error:\n{e}")
        raise


def run_make() -> None:
    try:
        run(
            "make PYTHON=python3",
            cwd=KLIPPER_DIR,
            shell=True,
            check=True,
        )
    except CalledProcessError as e:
        Logger.print_error(f"Unexpected error:\n{e}")
        raise
