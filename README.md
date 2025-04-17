# Storage-Info

The application is designed to obtain quick information about the status of flash cards.

By default, the application is configured for 2 memory cards, but you can switch the application to work with one memory card - see Config.PATHS in Config.lua

-- For SD2
Config.PATHS = {"/mnt/sdcard/ROMS", "/mnt/mmc", "/mnt/sdcard"}

-- For SD1
--Config.PATHS = {"/mnt/mmc/ROMS", "/mnt/mmc"}

For detailed viewing (list of directories on the specified path and their size) mount points are disabled

Config.EXCLUDED_PATHS = {
    ["/mnt/mmc"] = true,
    ["/mnt/sdcard"] = true
}

I think there is no need to view this in detail, besides - to determine the size of the directory in detailed viewing can spend large resources and take up time

For detailed viewing, the directory with games /mnt/sdcard/ROMS or /mnt/mmc/ROMS is available, which is very convenient - if you decide to sacrifice some games to free up space on the memory card

I tested the application on Anbernic  RG35xx H

Installing the application via the ARCHIVE manager
