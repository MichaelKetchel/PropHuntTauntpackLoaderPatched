--[[-----------------------------------------------------------------
Prop Hunt Tauntpack Loader                                 2017-03-14

Adds a Prop Hunt 24/7 tauntpack-compatible loader to the original
Prop Hunt by AMT that is available from Kow@lski's Steam Workshop.

Used for development of new tauntpacks and to support other servers.
--- HISTORY ---------------------------------------------------------
2014-06-19  Initial upload to Steam Workshop.
2015-07-04  Added additional configuration options to disable taunts.
            Fixed ph_rldtaunts on dedicated servers (Musician101).
2015-07-04  Hotfix for gamemode lockout.
2017-03-14  Compatibility update for Wolvin's Prop Hunt Enhanced.
2017-03-16  Hotfix: Alternate way to network the tauntlist.
2017-05-06  Fixing a regression for Kow@lski's version of Prop Hunt.
-----------------------------------------------------------------]]--

local Original_Prop_Taunts   = Original_Prop_Taunts or {}
local Original_Hunter_Taunts = Original_Hunter_Taunts or {}
local Gamemode_Prop_Taunts   = Gamemode_Prop_Taunts or {}
local Gamemode_Hunter_Taunts = Gamemode_Hunter_Taunts or {}
local Blacklisted_Taunts     = Blacklisted_Taunts or {}

local ReloadFunc             = PerformReload
local ListTauntsFunc         = ListTaunts
local PlayTauntFunc          = PlayTaunt

local AddonData_Directory    = "tauntpack_loader"

util.AddNetworkString( "PHTPL_RequestTauntList" )
util.AddNetworkString( "PHTPL_UpdateTaunts" )


-- Queue clientside for transfer
AddCSLuaFile( "autorun/client/cl_ph_tauntpack_loader.lua" )


-- Reply to clients requesting the tauntlist from the server.
-- Do not use net.WriteTable here, the 64kb table serialization
-- limit seems to be easily reached with bigger tauntpacks!
local function ProcessSendListRequest( len, ply )
	net.Start( "PHTPL_UpdateTaunts" )

	-- Hunter taunts
	net.WriteUInt( #GAMEMODE.Hunter_Taunts, 16 )
	for _, v in ipairs( GAMEMODE.Hunter_Taunts ) do
		net.WriteString( v[1] )
		net.WriteString( v[2] )
	end

	-- Prop taunts
	net.WriteUInt( #GAMEMODE.Prop_Taunts, 16 )
	for _, v in ipairs( GAMEMODE.Prop_Taunts ) do
		net.WriteString( v[1] )
		net.WriteString( v[2] )
	end

	net.Send( ply )
end
net.Receive( "PHTPL_RequestTauntList", ProcessSendListRequest )


-- Require clients to load specific Workshop resources
local function LoadWorkshopResources()
	local workshop_fname = AddonData_Directory .. "/workshop_resources.txt"

	-- Make sure our resources text file exists!
	if not file.Exists( workshop_fname, "DATA" ) then
		file.CreateDir( AddonData_Directory )
	end

	if not file.Exists( workshop_fname, "DATA" ) then
		file.Append( workshop_fname, "# Prop Hunt Tauntpack Loader - Workshop Resources\r\n" )
		file.Append( workshop_fname, "#\r\n" )
		file.Append( workshop_fname, "# Format:\r\n" )
		file.Append( workshop_fname, "# <Workshop ID>;<Description>\r\n\r\n" )
		file.Append( workshop_fname, "#123456789;My example Workshop content\r\n" )
	end

	-- Add all the Steam Workshop content we need
	local workshop_textdata = file.Read( workshop_fname )
	local workshop_lines = string.Explode( "\n", workshop_textdata )

	MsgN( "Adding additional Workshop resources..." )
	for i, line in ipairs( workshop_lines ) do

		-- Ignore comment lines (beginning with #)
		if string.sub( line, 1, 1 ) != "#" and string.len( line ) > 2 then
			local data = string.Explode( ";", line )

			-- Format:
			-- data[1] = Workshop Content ID
			-- data[2] = Description

			resource.AddWorkshop( string.Trim( data[1] ) )
		end
	end
end


-- Load the blacklist of unwanted taunts
local function LoadBlacklistedTaunts()
	local blacklist_fname = AddonData_Directory .. "/taunt_blacklist.txt"

	-- Make sure our blacklist text file exists!
	if not file.Exists( blacklist_fname, "DATA" ) then
		file.CreateDir( AddonData_Directory )
	end

	if not file.Exists( blacklist_fname, "DATA" ) then
		file.Append( blacklist_fname, "# Prop Hunt Tauntpack Loader - Blacklisted Taunts\r\n" )
		file.Append( blacklist_fname, "#\r\n" )
		file.Append( blacklist_fname, "# Format:\r\n" )
		file.Append( blacklist_fname, "# <Path to the file>;<Optional Description>\r\n\r\n" )
		file.Append( blacklist_fname, "#taunts/props/31.mp3;No Bad Boys here!\r\n" )
	end

	local blacklist_textdata = file.Read( blacklist_fname )
	local blacklist_lines = string.Explode( "\n", blacklist_textdata )

	-- Empty the blacklist before populating it!
	Blacklisted_Taunts = {}

	MsgN( "Populating taunt blacklist..." )
	for i, line in ipairs( blacklist_lines ) do

		-- Ignore comment lines (beginning with #)
		if string.sub( line, 1, 1 ) != "#" and string.len( line ) > 2 then
			local data = string.Explode( ";", line )

			-- Format:
			-- data[1] = File to blacklist
			-- All additional data will be ignored!

			table.insert( Blacklisted_Taunts, string.Trim( data[1] ) )
		end
	end
end


-- Helper function to reload the taunts from the mounted tauntpacks
local function ReloadTaunts( bVerbose )
	GAMEMODE.Hunter_Taunts = {}
	GAMEMODE.Prop_Taunts   = {}

	-- To remove taunts the gamemode added, we need to add these first.
	for _, t in pairs( Original_Hunter_Taunts ) do
		table.insert( GAMEMODE.Hunter_Taunts, {
			t,	-- Add the soundfile
			t	-- Add the path to the soundfile as the description
		} )
	end

	for _, t in pairs( Original_Prop_Taunts ) do
		table.insert( GAMEMODE.Prop_Taunts, {
			t,
			t
		} )
	end

	-- Now let the tauntpacks do their thing
	hook.Run( "ph_AddTaunts" )

	-- Now allow tauntpacks to mess with the order or remove taunts entirely.
	hook.Run( "ph_ModifyTaunts" )

	-- Depending on what flavour of Prop Hunt is running, we need a different
	-- version of the reload function...
	ReloadFunc()

	-- Broadcast new tauntlist to all clients
	net.Start( "PHTPL_UpdateTaunts" )

	-- Hunter taunts
	net.WriteUInt( #GAMEMODE.Hunter_Taunts, 16 )	
	for _, v in ipairs( GAMEMODE.Hunter_Taunts ) do
		net.WriteString( v[1] )
		net.WriteString( v[2] )
	end

	-- Prop taunts
	net.WriteUInt( #GAMEMODE.Prop_Taunts, 16 )
	for _, v in ipairs( GAMEMODE.Prop_Taunts ) do
		net.WriteString( v[1] )
		net.WriteString( v[2] )
	end

	net.Broadcast()
end


-- Worker body for ReloadTaunts
-- ## Prop Hunt
local function PerformReload()
	-- Empty the game's taunt list
	HUNTER_TAUNTS = {}
	PROP_TAUNTS   = {}

	-- Finally, add the additional taunts into the game.
	-- The taunts will have the order and contents the tauntpacks have specified.
	-- This is also the time to apply the blacklists.
	for _, t in pairs( GAMEMODE.Hunter_Taunts ) do
		if not table.HasValue( Blacklisted_Taunts, t[1] ) then
			if bVerbose then
				MsgN( string.format( "Adding Hunter taunt: %s", t[1] ) )
			end
			table.insert( HUNTER_TAUNTS, t[1] )
		else
			if bVerbose then
				MsgN( string.format( "Ignoring blacklisted Hunter taunt: %s", t[1] ) )
			end
		end
	end

	for _, t in pairs( GAMEMODE.Prop_Taunts ) do
		if not table.HasValue( Blacklisted_Taunts, t[1] ) then
			if bVerbose then
				MsgN( string.format( "Adding Prop taunt: %s", t[1] ) )
			end
			table.insert( PROP_TAUNTS, t[1] )
		else
			if bVerbose then
				MsgN( string.format( "Ignoring blacklisted Prop taunt: %s", t[1] ) )
			end
		end
	end
end


-- Worker body for ReloadTaunts
-- ## Wolvin's Prop Hunt Enhanced
local function PerformReload_PHE()
	-- Empty the game's taunt list
	PHE.PH_TAUNT_CUSTOM.HUNTER = {}
	PHE.PH_TAUNT_CUSTOM.PROP   = {}

	-- Finally, add the additional taunts into the game.
	-- The taunts will have the order and contents the tauntpacks have specified.
	-- This is also the time to apply the blacklists.
	for _, t in pairs( GAMEMODE.Hunter_Taunts ) do
		if not table.HasValue( Blacklisted_Taunts, t[1] ) then
			if bVerbose then
				MsgN( string.format( "Adding Hunter taunt: %s", t[1] ) )
			end
			table.insert( PHE.PH_TAUNT_CUSTOM.HUNTER, t[1] )
		else
			if bVerbose then
				MsgN( string.format( "Ignoring blacklisted Hunter taunt: %s", t[1] ) )
			end
		end
	end

	for _, t in pairs( GAMEMODE.Prop_Taunts ) do
		if not table.HasValue( Blacklisted_Taunts, t[1] ) then
			if bVerbose then
				MsgN( string.format( "Adding Prop taunt: %s", t[1] ) )
			end
			table.insert( PHE.PH_TAUNT_CUSTOM.PROP, t[1] )
		else
			if bVerbose then
				MsgN( string.format( "Ignoring blacklisted Prop taunt: %s", t[1] ) )
			end
		end
	end
end


-- Command wrapper for ReloadTaunts
local function ReloadTauntsCmd( ply, cmd, args )
	if not IsValid( ply ) or ply:IsAdmin() then
		MsgN( "Reloading taunts..." )
		LoadBlacklistedTaunts()
		ReloadTaunts( true )
	end
end


-- Prints the list of taunts for a specific team
-- ## Prop Hunt
local function ListTaunts( ply, teamid )

	local tauntlist = {}

	-- Which tauntlist do we want to use?
	if teamid == TEAM_HUNTERS then
		tauntlist = HUNTER_TAUNTS
	else
		tauntlist = PROP_TAUNTS
	end

	if IsValid( ply ) then
		for k, v in pairs( tauntlist ) do
			ply:PrintMessage( HUD_PRINTCONSOLE, k .. "\t" ..  v )
		end
	else
		PrintTable( tauntlist )
	end

end


-- Prints the list of taunts for a specific team
-- ## Wolvin's Prop Hunt Enhanced
local function ListTaunts_PHE( ply, teamid )

	local tauntlist = {}

	-- Which tauntlist do we want to use?
	if teamid == TEAM_HUNTERS then
		tauntlist = PHE.PH_TAUNT_CUSTOM.HUNTER
	else
		tauntlist = PHE.PH_TAUNT_CUSTOM.PROP
	end

	if IsValid( ply ) then
		for k, v in pairs( tauntlist ) do
			ply:PrintMessage( HUD_PRINTCONSOLE, k .. "\t" ..  v )
		end
	else
		PrintTable( tauntlist )
	end

end


-- Command wrapper for ListTaunts()
local function ListTauntsCmd( ply, cmd, args )
	if ( IsValid( ply ) and ply:IsAdmin() ) or not IsValid( ply ) then
		local teamid = args[1]

		if not teamid 
		  or (    string.lower( teamid ) ~= "team_props"
		      and string.lower( teamid ) ~= "team_hunters" ) then
			teamid = "TEAM_PROPS"
		end

		teamid = string.upper( teamid )

		ListTauntsFunc( ply, _G[teamid] )
	end
end


-- Run a taunt
-- ## Prop Hunt
local function PlayTaunt( ply, teamid, num )
	local taunt = ""

	if teamid == TEAM_HUNTERS then
		taunt = HUNTER_TAUNTS[num]
	end

	if teamid == TEAM_PROPS then
		taunt = PROP_TAUNTS[num]
	end

	if taunt then
		MsgN( "Playing taunt " .. taunt )
		ply:EmitSound( taunt, 100 )
	end
end


-- Run a taunt
-- ## Wolvin's Prop Hunt Enhanced
local function PlayTaunt_PHE( ply, teamid, num )
	local taunt = ""

	if teamid == TEAM_HUNTERS then
		taunt = PHE.PH_TAUNT_CUSTOM.HUNTER[num]
	end

	if teamid == TEAM_PROPS then
		taunt = PHE.PH_TAUNT_CUSTOM.PROP[num]
	end

	if taunt then
		MsgN( "Playing taunt " .. taunt )
		ply:EmitSound( taunt, 100 )
	end
end


-- Command wrapper for PlayTaunt()
local function PlayTauntCmd( ply, cmd, args )
	if ( IsValid( ply ) and ply:IsAdmin() and ply:Alive() ) then

		if #args > 2 or #args < 2 then
			return
		end

		local teamid = args[1]
		local taunt = tonumber( args[2] )

		-- Check what team we want to run a taunt for
		if not teamid 
		  or (    string.lower( teamid ) ~= "team_props"
		      and string.lower( teamid ) ~= "team_hunters" ) then
			teamid = "TEAM_PROPS"
		end

		teamid = string.upper( teamid )

		-- Now check whether the taunt is in the valid range of taunts
		if   _G[teamid] == TEAM_HUNTERS and taunt > 0
		  or _G[teamid] == TEAM_PROPS and taunt > 0 then
			PlayTauntFunc( ply, _G[teamid], taunt )
		end
	end
end

-- Initialize the addon and hook up the commands.
local function InitializeTaunts()
	if GAMEMODE_NAME ~= "prop_hunt" then
		return
	end

	MsgN( "Initializing Prop Hunt Tauntpack Loader..." )

	-- Determine what breed of Prop Hunt we are dealing with
	if PHE ~= nil then
		-- ## Wolvin's Prop Hunt Enhanced
		-- Use the gamemode's custom taunt tables
		Gamemode_Prop_Taunts   = PHE.PH_TAUNT_CUSTOM.PROP
		Gamemode_Hunter_Taunts = PHE.PH_TAUNT_CUSTOM.HUNTER
		ReloadFunc             = PerformReload_PHE
		ListTauntsFunc         = ListTaunts_PHE
		PlayTauntFunc          = PlayTaunt_PHE
	else
		-- ## AMT-variant of Prop Hunt
		Gamemode_Prop_Taunts   = PROP_TAUNTS
		Gamemode_Hunter_Taunts = HUNTER_TAUNTS
		ReloadFunc             = PerformReload
		ListTauntsFunc         = ListTaunts
		PlayTauntFunc          = PlayTaunt
	end

	-- Register the new commands
	concommand.Add( "ph_rldtaunts", ReloadTauntsCmd )
	concommand.Add( "ph_tauntlist", ListTauntsCmd )
	concommand.Add( "ph_taunt", PlayTauntCmd )

	GAMEMODE.Prop_Taunts   = GAMEMODE.Prop_Taunts or {}
	GAMEMODE.Hunter_Taunts = GAMEMODE.Hunter_Taunts or {}

	-- Backup the original taunts from the config for later use
	Original_Hunter_Taunts = table.Copy( Gamemode_Hunter_Taunts )
	Original_Prop_Taunts   = table.Copy( Gamemode_Prop_Taunts )

	-- Initialize addon data
	LoadWorkshopResources()
	LoadBlacklistedTaunts()

	-- Processing
	ReloadTaunts( false )
end
hook.Add( "Initialize", "PHTPLoader_Init", InitializeTaunts )
