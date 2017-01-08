--[[================================================================================
        Lightroom/Lightroom
        
        Supplements LrApplication namespace (Lightroom from an app point of view, as opposed to a plugin point of view...).
================================================================================--]]


local Lightroom = Object:newClass{ className="Lightroom", register=false }



--- Constructor for extending class.
--
function Lightroom:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function Lightroom:new( t )
    local o = Object.new( self, t )
    return o
end



-- ###1 not sure this is reliable @2/Dec/2013 10:31
function Lightroom:getFilenamePresetDir()
    local datDir = LrPathUtils.getStandardFilePath( 'appData' )
    for k, v in pairs( LrApplication.filenamePresets() ) do
        local exists = LrFileUtils.exists( v )
        if exists then
            --Debug.pause( "exists", v )
            return false, LrPathUtils.parent( v ) -- presets not stored with catalog
        end 
        --Debug.pause( v:sub( -60 ) )
    end
    local catDir = cat:getCatDir()
    local lrSets = LrPathUtils.child( catDir, "Lightroom Settings" )
    local fnTmpl = LrPathUtils.child( lrSets, "Filename Templates" )
    if fso:existsAsDir( fnTmpl ) then
        return true, fnTmpl -- presets *are* stored with catalog
    else
        return nil, LrPathUtils.child( datDir, "Filename Templates" ), fnTmpl -- not sure where they're stored: here's both locations.
    end
end



--- Evaluate conditions necessary for successfully restarting Lightroom. *** saves prefs? ###1
--
--  @return restart function appropriate for OS, or nil.
--  @return status message to explain no restart function.
--
function Lightroom:prepareForRestart( catPath )
    local f, qual
    local s, m = app:call( Call:new{ name="Preparing to Restart Lightroom", async=false, main=function( call ) -- no guarding "should" be necessary.
        local exe
        local opts
        if not str:is( catPath ) then
            catPath = catalog:getPath()
        end
        local targets = { catPath }
        local doPrompt
        if WIN_ENV then
            exe = app:getPref( "lrApp" ) or app:getGlobalPref( "lrApp" ) -- set one of these in plugin manager or the like, to avoid prompt each time.
            opts = "-restart"
            if str:is( exe ) then
                if fso:existsAsFile( exe ) then
                    f = function()
                        return app:executeCommand( exe, opts, targets )
                    end -- no qualifications: if config'd should be good to go.
                else
                    qual = str:fmtx( "Lightroom app does not exist here: '^1' - consider changing pref...", exe )
                end
            else -- no exe config'd
                -- local sts, othr, x  = app:executeCommand( "ftype", nil, "Adobe.AdobeLightroom" )
                local sts, cmdOrMsg, resp  = app:executeCommand( "ftype Adobe.AdobeLightroom", nil, nil, nil, 'del', true )
                if sts then
                    app:logv( cmdOrMsg )
                    local q1, q2 = resp:find( "=", 1, true )
                    if q1 then
                        local p1, p2 = resp:find( ".exe", q2 + 1, true )
                        if p1 then
                            exe = resp:sub( q2 + 1, p2 )
                            if str:is( exe ) then
                                if fso:existsAsFile( exe ) then
                                    f = function()
                                        return app:executeCommand( exe, opts, targets )
                                    end
                                    qual = str:fmtx( "Lightroom executable (obtained by asking Windows): ^1", exe )
                                else
                                    qual = str:fmtx( "Lightroom app should exist here, but doesn't: '^1' - consider setting explicit pref...", exe )
                                end
                            else
                                qual = str:fmtx( "Exe file as parsed from ftype command does not exist: ^1", exe )
                            end
                        else
                            qual = str:fmtx( "Unable to parse exe file from ftype command, which returned: ^1", resp )
                        end
                    else
                        qual = str:fmtx( "Unable to parse exe file from ftype command, which returned '^1'", resp )
                    end
                else
                    qual = str:fmtx( "Unable to obtain lr executable from ftype command - ^1", cmdOrMsg )
                end
            end
        else -- Mac
            f = nil
            qual = "Auto-restart not supported on Mac yet."
            --[[ best not to try programmatic restart on Mac, until tested.
            f = function()
                return app:executeCommand( "open", nil, targets ) -- ###1 test on Mac - @10/May/2013 17:20 - not validated on Mac.
            end -- no qual
            --]]
        end
    end } )
    if s then
        return f, qual
    else
        return nil, m
    end
end



--- Restarts lightroom with current or specified catalog *** @deprecated, since does not save prefs - use other method, unless you want to subvert prefs.
--
--  @usage *** Does NOT save preferences on the way out (@25/Nov/2013, there is no way I know to restart and save prefs).
--  @usage depends on 'lrApp' pref or global-pref for exe-path in windows environment - if not there, user will be prompted for exe file.
--
--  @param catPath (string, default = current catalog) path to catalog to restart with.
--  @param noPrompt (boolean, default = false) set true for no prompting, otherwise user will be prompted prior to restart, if prompt not permanently dismissed that is.
--
function Lightroom:restart( catPath, noPrompt )
    local s, m = app:call( Call:new{ name="Restarting Lightroom", async=false, main=function( call ) -- no guarding "should" be necessary.
        local exe
        local opts
        if not str:is( catPath ) then
            catPath = catalog:getPath()
        end
        local targets = { catPath }
        local doPrompt
        if WIN_ENV then
            exe = app:getPref( "lrApp" ) or app:getGlobalPref( "lrApp" ) -- set one of these in plugin manager or the like, to avoid prompt each time.
            opts = "-restart"
            if not str:is( exe ) or not fso:existsAsFile( exe ) then
                if not str:is( exe ) then
                    app:logVerbose( "Consider setting 'lrApp' in plugin manager or the like." )
                    Debug.pause( "Consider setting 'lrApp' in plugin manager or the like." )
                else
                    app:logWarning( "Lightroom app does not exist here: '^1' - consider changing pref...", exe )
                end
                repeat
                    exe = dia:selectFile{ -- this serves as the "prompt".
                        title = "Select lightroom.exe file for restart.",
                        fileTypes = { "exe" },
                    }
                    if exe ~= nil then
                        if fso:existsAsFile( exe ) then
                            break
                        else
                            app:show{ warning="Nope - try again." }                            
                        end
                    else
                        return false, "user cancelled"
                    end
                until false
            elseif not noPrompt then
                doPrompt = true
            -- else just do it.
            end
            --app:setGlobalPref( "lrApp", exe ) -- not working: seems pref is not commited, even if long sleep.
            --app:sleep( .1 ) -- superstition, probably does not help to persist prefs..
            --[[ *** save for possible future resurrection: can't get restart to happen following task-kill.
            local s, m = app:executeCommand( "taskkill", "/im lightroom.exe", nil ) -- no targets. ###1 if this works, port to exit method as well.
            if s then 
                app:log( "Issued taskkill..." )
            else
                return false, m
            end
            --]]
            --assert( app:getGlobalPref( "lrApp" ) == exe, "no" )
        else
            exe = "open"
            doPrompt = true
        end
        if doPrompt then
            -- osascript -e 'tell application "Adobe Photoshop Lightroom 5" to quit' -- ###1
            local btn = app:show{ confirm="Lightroom will restart now, if it's OK with you.",
                actionPrefKey = "Restart Lightroom",
            }
            if btn ~= 'ok' then
                return false, "user cancelled"
            end
        -- else don't prompt
        end
        app:executeCommand( exe, opts, targets )
        app:error( "Lightroom should have restarted." ) -- since it never get's here, I question if preferences were actually saved - hmm...
    end } )
end



--- Exit Lightroom
--
function Lightroom:exit()
    local keys = app:getPref( 'keysToExitLightroom' )
    if not str:is( keys ) then
        keys = ( WIN_ENV and "{Alt Down}f{Alt Up}x" ) or "Cmd-fx"
    end
    local s, m
    if WIN_ENV then
        s, m = app:sendWinAhkKeys( keys ) -- until 25/Nov/2013 23:00
        -- I tried this once and it seemed prefs were saved, now it seems they're not.. - I'm sticking with the keystroke injection, which either works
        -- exactly as expected or not at all.
        --s, m = app:executeCommand( "taskkill", "/im lightroom.exe", nil ) - no targets. ###2 theoretically, this should be more reliable, but so far: it's not.
    else
        s, m = app:sendMacEncKeys( keys ) -- ###1 test on Mac.
    end
    return s, m
end



--- Determine Lr app/exe file path based on develop preset folders, or whatever means possible.
--
--  @return exe file path or nil if none
--  @return Lr program folder path or error message.
-- 
function Lightroom:computeLrAppPath()
    local presetFolders = LrApplication.developPresetFolders()
    for i, v in ipairs( presetFolders ) do
        if v:getPath():find( "Adobe Photoshop Lightroom" ) then
            local presetFolderPath = LrPathUtils.parent( v:getPath() )
            local presetFolderDirName = LrPathUtils.leafName( presetFolderPath )
            Debug.pauseIf( presetFolderDirName ~= 'TEMPLATES', "not templates" )
            local devModulePath = LrPathUtils.parent( presetFolderPath )
            local devModuleDirName = LrPathUtils.leafName( devModulePath )
            Debug.pauseIf( devModuleDirName ~= 'Develop.lrmodule', "not dev module" )
            local lrAppFolderPath = LrPathUtils.parent( devModulePath )
            local lrAppPath = LrPathUtils.child( lrAppFolderPath, WIN_ENV and 'lightroom.exe' or 'lightroom' ) -- ###1 test on Mac.
            if fso:existsAsFile( lrAppPath ) then
                return lrAppPath, lrAppFolderPath -- got it.
            else
                Debug.pause( "Hmm... - no Lr executable here:", lrAppPath )
            end
        end
    end
    Debug.pause( "No Lr app/exe via dev-presets." )
    if WIN_ENV then    
        app:logV( "Unable to compute Lr app path based on preset folders - trying another approach..." )
        local sts, cmdOrMsg, resp  = app:executeCommand( "ftype Adobe.AdobeLightroom", nil, nil, nil, 'del', true )
        if sts then
            app:logv( cmdOrMsg )
            local q1, q2 = resp:find( "=", 1, true )
            if q1 then
                local p1, p2 = resp:find( ".exe", q2 + 1, true )
                if p1 then
                    exe = resp:sub( q2 + 1, p2 )
                    if str:is( exe ) then
                        if fso:existsAsFile( exe ) then
                            app:logV( "Lightroom executable (obtained by asking Windows): ^1", exe )
                            return exe, LrPathUtils.parent( exe ) -- eureka!
                        else
                            qual = str:fmtx( "Lightroom app should exist here, but doesn't: '^1' - consider setting explicit pref...", exe )
                        end
                    else
                        qual = str:fmtx( "exe file as parsed from ftype command does not exist: ^1", exe )
                    end
                else
                    qual = str:fmtx( "unable to parse exe file from ftype command, which returned: ^1", resp )
                end
            else
                qual = str:fmtx( "unable to parse exe file from ftype command, which returned '^1'", resp )
            end
        else
            qual = str:fmtx( "unable to obtain lr executable from ftype command - ^1", cmdOrMsg )
        end
    else
        qual = "unable to compute Lr app path based on preset folders (only method used so far on Mac)."
    end    
    return nil, "Unable to compute Lr app path - "..qual
end

   

--- Get (combo-box compatible) array of develop preset names.
--
function Lightroom:getDevelopPresetNames()
    local names = {}
    local folders = LrApplication.developPresetFolders()
    for i, folder in ipairs( folders ) do
        local presets = folder:getDevelopPresets()
        for i,v in ipairs( presets ) do
            names[#names + 1] = v:getName()
        end
    end
    return names
end
Lightroom.getDevPresetNames = Lightroom.getDevelopPresetNames -- function Lightroom:getDevPresetNames(...)



--- Get (popup compatible) array of develop preset items - value is UUID.
--
function Lightroom:getDevelopPresetItems( substr )
    local items = {}
    local folders = LrApplication.developPresetFolders()
    for i, folder in ipairs( folders ) do
        repeat
            local name = folder:getName()
            if substr and not name:find( substr, 1, true ) then
                break
            end
            local presets = folder:getDevelopPresets()
            for i, v in ipairs( presets ) do
                items[#items + 1] = { title=v:getName(), value=v:getUuid() }
            end
        until true
    end
    return items
end
Lightroom.getDevPresetItems = Lightroom.getDevelopPresetItems -- function Lightroom:getDevPresetItems(...)



--- Get (popup compatible) array of metadata preset items - value is UUID.
--
function Lightroom:getMetadataPresetItems( substr ) -- no equiv to get plain names just yet.
    local items = {}
    local metaPresets = LrApplication.metadataPresets()
    for name, id in pairs( metaPresets ) do
        if not substr or name:find( substr, 1, true ) then
            items[#items + 1] = { title=name, value=id }
        end
    end
    return items
end
Lightroom.getMetaPresetItems = Lightroom.getMetadataPresetItems -- function Lightroom:getMetadataPresetItems(...)


   
return Lightroom 