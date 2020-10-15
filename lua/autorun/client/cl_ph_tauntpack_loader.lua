--[[-----------------------------------------------------------------
Prop Hunt Tauntpack Loader                                 2017-03-14

Adds a Prop Hunt 24/7 tauntpack-compatible loader to the original
Prop Hunt by AMT that is available from Kow@lski's Steam Workshop.

Used for development of new tauntpacks and to support other servers.
--- HISTORY ---------------------------------------------------------
2017-03-14  Compatibility update for Wolvin's Prop Hunt Enhanced.
2017-03-16  Hotfix: Alternate way to network the tauntlist.
2017-05-06  Fixing a regression for Kow@lski's version of Prop Hunt.
-----------------------------------------------------------------]]--

-- Use disposable local tables on the client.
-- PH.eu does everything via request-reply, so there is little risk of collision.
local Prop_Taunts   = Prop_Taunts or {}
local Hunter_Taunts = Hunter_Taunts or {}

-- Actively request tauntlist from the server
local function RequestTauntsFromServer()
	if #Prop_Taunts == 0 or #Hunter_Taunts == 0 then
		MsgN( "No taunt data available, requesting from server..." )
		net.Start( "PHTPL_RequestTauntList" )
		net.SendToServer()
	end
end
hook.Add( "InitPostEntity", "PHTPL_RequestTauntsFromServer", RequestTauntsFromServer )


-- Server sent us a new tauntlist. Perform local overwrites as instructed.
local function ProcessTLUpdateFromServer( len, ply )
	-- Empty tables
	Hunter_Taunts = {}
	Prop_Taunts   = {}

	-- Fill tables
	--Hunter_Taunts = net.ReadTable()
	--Prop_Taunts   = net.ReadTable()

	for i = 1, net.ReadUInt( 16 ) do
		Hunter_Taunts[i] = {
			net.ReadString(),
			net.ReadString()
		}
	end

	for i = 1, net.ReadUInt( 16 ) do
		Prop_Taunts[i] = {
			net.ReadString(),
			net.ReadString()
		}
	end

	-- Yes, it's ugly... but cut me some slack here, I'm pressed for time!
	if PHE ~= nil then
		-- ## Wolvin's Prop Hunt Enhanced
		PHE.PH_TAUNT_CUSTOM.HUNTER = {}
		PHE.PH_TAUNT_CUSTOM.PROP   = {}

		for _, t in pairs( Hunter_Taunts ) do
			-- table.insert( PHE.PH_TAUNT_CUSTOM.HUNTER, t[1])
			PHE:AddCustomTaunt(TEAM_HUNTERS, t[2], t[1])
		end
    
		
		for _, t in pairs( Prop_Taunts ) do
			-- table.insert( PHE.PH_TAUNT_CUSTOM.PROP, t[1] )
			PHE:AddCustomTaunt(TEAM_PROPS, t[2], t[1])
		end
		-- PHE:RefreshTauntList()
	else
		-- ## AMT-variant Prop Hunt
		HUNTER_TAUNTS = {}		
		PROP_TAUNTS   = {}

		for _, t in pairs( Hunter_Taunts ) do
			table.insert( HUNTER_TAUNTS, t[1] )
		end
		
		for _, t in pairs( Prop_Taunts ) do
			table.insert( PROP_TAUNTS, t[1] )
		end
	end
	MsgN( "Taunts received from server" )
end
net.Receive( "PHTPL_UpdateTaunts", ProcessTLUpdateFromServer )


-- Just for funsies.
MsgN( "Prop Hunt Tauntpack Loader clientside initialized." )
