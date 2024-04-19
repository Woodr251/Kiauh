# ======================================================================= #
#  Copyright (C) 2020 - 2024 Dominik Willner <th33xitus@gmail.com>        #
#                                                                         #
#  This file is part of KIAUH - Klipper Installation And Update Helper    #
#  https://github.com/dw-0/kiauh                                          #
#                                                                         #
#  This file may be distributed under the terms of the GNU GPLv3 license  #
# ======================================================================= #

from dataclasses import field
from enum import Enum
from typing import Union, List


class FlashMethod(Enum):
    REGULAR = "Regular"
    SD_CARD = "SD Card"


class FlashCommand(Enum):
    FLASH = "flash"
    SERIAL_FLASH = "serialflash"


class ConnectionType(Enum):
    USB = "USB"
    USB_DFU = "USB (DFU)"
    UART = "UART"


class FlashOptions:
    _instance = None
    _flash_method: Union[FlashMethod, None] = None
    _flash_command: Union[FlashCommand, None] = None
    _connection_type: Union[ConnectionType, None] = None
    _mcu_list: List[str] = field(default_factory=list)
    _selected_mcu: str = ""
    _selected_board: str = ""
    _selected_baudrate: int = 250000

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(FlashOptions, cls).__new__(cls, *args, **kwargs)
        return cls._instance

    @classmethod
    def destroy(cls):
        cls._instance = None

    @property
    def flash_method(self) -> Union[FlashMethod, None]:
        return self._flash_method

    @flash_method.setter
    def flash_method(self, value: Union[FlashMethod, None]):
        self._flash_method = value

    @property
    def flash_command(self) -> Union[FlashCommand, None]:
        return self._flash_command

    @flash_command.setter
    def flash_command(self, value: Union[FlashCommand, None]):
        self._flash_command = value

    @property
    def connection_type(self) -> Union[ConnectionType, None]:
        return self._connection_type

    @connection_type.setter
    def connection_type(self, value: Union[ConnectionType, None]):
        self._connection_type = value

    @property
    def mcu_list(self) -> List[str]:
        return self._mcu_list

    @mcu_list.setter
    def mcu_list(self, value: List[str]) -> None:
        self._mcu_list = value

    @property
    def selected_mcu(self) -> str:
        return self._selected_mcu

    @selected_mcu.setter
    def selected_mcu(self, value: str) -> None:
        self._selected_mcu = value

    @property
    def selected_board(self) -> str:
        return self._selected_board

    @selected_board.setter
    def selected_board(self, value: str) -> None:
        self._selected_board = value

    @property
    def selected_baudrate(self) -> int:
        return self._selected_baudrate

    @selected_baudrate.setter
    def selected_baudrate(self, value: int) -> None:
        self._selected_baudrate = value
