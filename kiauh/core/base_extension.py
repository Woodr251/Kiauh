# ======================================================================= #
#  Copyright (C) 2020 - 2024 Dominik Willner <th33xitus@gmail.com>        #
#                                                                         #
#  This file is part of KIAUH - Klipper Installation And Update Helper    #
#  https://github.com/dw-0/kiauh                                          #
#                                                                         #
#  This file may be distributed under the terms of the GNU GPLv3 license  #
# ======================================================================= #

from abc import abstractmethod, ABC
from typing import Dict


# noinspection PyUnusedLocal
# noinspection PyMethodMayBeStatic
class BaseExtension(ABC):
    def __init__(self, metadata: Dict[str, str]):
        self.metadata = metadata

    @abstractmethod
    def install_extension(self, **kwargs) -> None:
        raise NotImplementedError(
            "Subclasses must implement the install_extension method"
        )

    @abstractmethod
    def remove_extension(self, **kwargs) -> None:
        raise NotImplementedError(
            "Subclasses must implement the remove_extension method"
        )
