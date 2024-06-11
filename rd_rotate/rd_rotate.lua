--[[

Simple server rotation using LibRotate.

The configuration:
- persist_index: If true, the addon will save the rotation index, and continue the rotation after server restart.
                 If false, the rotation will start from the first setup after server restart
- default: Default setup. See rd_rotate.txt and lib_rotate.lua for more information about the setup format.
- rotation: Array of setups to rotate. Each setup will be created as combination of the default setup, overridden by the index-th setup from rotation.

Persistent data:
- index: Index of rotation, used so the rotation continues after server restart, rather than starting
         from the first element, if enabled. Delete the data file to restart the rotation

--]]

local addon_storage = ...
local config = addon_storage.config
config.persist_index = config.persist_index or false
if type( config.default ) ~= "table" then config.default = {} end
if type( config.rotation ) ~= "table" then config.rotation = {} end

local addon_data = addon_storage.data
if not config.persist_index or not addon_data.index then addon_data.index = 0 end

local lib_rotation = LibRotate.new( config.default )

-- remember the initial state
local initial_state = {}

-- Check the rotation
local rotation_ok = true

local function shallow_copy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end

local function verify_setups()
	rotation_ok = true
	if #config.rotation == 0 then
		print( "RDRotate: No rotation defined in config, will only apply the defaults" )
		rotation_ok = false
		return
	end

	if ( session.next_attributes.ServerControlsSetup == 0 ) then
		print( "RDRotate: Using scripted setup rotation while the server is not configured to control the game's setup. Make sure to set \"controlGameSetup\" in the server config." )
		rotation_ok = false
	end

    for index,setup in ipairs( config.rotation ) do
		if not lib_rotation:_verify_attribute_names( setup, true ) then
			print( "RDRotate: Setup at index " .. index .. " contains errors!" )
			rotation_ok = false
		end
	end

	if not rotation_ok then
		print( "RDRotate: Rotation setups contain errors, rotation addon disabled" )
	end
end


-- The main "rotate to next setup" function
local function advance_next_setup()
	if not rotation_ok then
		return
	end

	-- Save state before  advancing (as on startup we tick this once too)
	SavePersistentData()

	-- Increment rotation index and find the setup.
	local setup
	if #config.rotation > 0 then
		if not addon_data.index then addon_data.index = 0 end
		if addon_data.index < 0 then addon_data.index = 0 end
		addon_data.index = addon_data.index + 1
		if addon_data.index > #config.rotation then addon_data.index = 1 end
		setup = shallow_copy(config.rotation[ addon_data.index ])
	end

	for k, v in pairs(setup) do
		if initial_state[k] == nil then
			local iv = session.next_attributes[k]
			print("RDRotate: Remembering initial " .. k .. " = " .. iv)
			initial_state[k] = iv
		end
	end

	-- RaceDateHour is actually a delta from the initial RaceDateHour
    if setup.RaceDateHour then
        setup.RaceDateHour = (setup.RaceDateHour + initial_state.RaceDateHour) % 24
		print( "RDRotate: RaceDateHour = " .. setup.RaceDateHour )
    end

	SetNextSessionAttributes(initial_state)
	-- now override them with the next state
	SetNextSessionAttributes( setup )
end


-- Startup
local function set_first_setup()
	if not rotation_ok then
		return
	end

	advance_next_setup()

end


-- Used to track state changes to decide when the advance the setup
local last_session_state = "None"

-- Main addon callback
local function addon_callback( callback, ... )

	-- Set first setup in the list when the server starts.
	if callback == Callback.ServerStateChanged then
		local oldState, newState = ...
		if ( oldState == "Starting" ) and ( newState == "Running" ) then
			verify_setups()
			set_first_setup()
		end
	end

	-- Handle session state changes. Note that Callback.SessionManagerStateChanged notifies about the session manager
	-- (just idle/allocating/running), which we are not interested in. Instead we use the log events.
	-- Lobby->Loading - we started current track, advance to next
	-- Session destroyed while in the Lobby - quit while in the lobby, also advance to next
	if callback == Callback.EventLogged then
		local event = ...
		if ( event.type == "Session" ) and ( event.name == "StateChanged" ) then
			if ( event.attributes.PreviousState == "Lobby" ) and ( event.attributes.NewState == "Loading" ) then
				advance_next_setup()
			end
			last_session_state = event.attributes.NewState
		elseif ( event.type == "Session" ) and ( event.name == "SessionDestroyed" ) then
			if last_session_state == "Lobby" then
				advance_next_setup()
			end
			last_session_state = "None"
		end
	end
end


-- Main
RegisterCallback( addon_callback )
EnableCallback( Callback.ServerStateChanged )
EnableCallback( Callback.EventLogged )


-- EOF --
