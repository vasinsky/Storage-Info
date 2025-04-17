local Config = {}

-- For SD2
Config.PATHS = {"/mnt/sdcard/ROMS", "/mnt/mmc", "/mnt/sdcard"}

-- For SD1
--Config.PATHS = {"/mnt/mmc/ROMS", "/mnt/mmc"}

--do nit show details for this
Config.EXCLUDED_PATHS = { 
    ["/mnt/mmc"] = true,
    ["/mnt/sdcard"] = true
}

return Config