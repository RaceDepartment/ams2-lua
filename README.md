# ams2-lua

Lua scripts used in the RD/OT club races


# rd_rotate

Lighter touch version of the standard `sms_rotate` script included with the dedicated server.  It uses the server.cfg as the initial base instead of requiring the full setup to be defined in it's own json config.  This allows it to be used with a server managment application like Emperor Server Manager which creates a crafted `server.cfg`

# install steps

1. copy the `rd_rotate` directory from this repo to the `lua` directory under where the AMS2 dedicated server is installed
2. copy `rd_rotate\rd_rotate_default_config.json` to `lua_config\rd_rotate_config.json` (you can also just start the DS and it should automatically copy it if it doesn't exist)
3. edit `lua_config\rd_rotate_config.json` as required
4. add `rd_rotate` to the `Lua API Addons` in Server > Options > Lua e.g.:

        luaApiAddons : [
            "sms_base",
            "sms_motd",
            "sms_stats",
            "rd_rotate"
        ]

    NOTE: you neeed to remove `sms_rotate` if it's in the list as it will conflict with `rd_rotate`

