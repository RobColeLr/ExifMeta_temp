--[[
        Collections.lua
        
        Interface to smart-collection utility class - no object to represent an individual (extended) collection...
        
        *** This module came late: much having to do with collections has been implemented elsewhere, so @26/Dec/2013, this class is quite limited.
--]]


local Collections, dbg, dbgf = Object:newClass{ className = "Collections", register = true }



--- Constructor for extending class.
--
function Collections:newClass( t )
    return Object.newClass( self, t )
end


--- Constructor for new instance.
--
function Collections:new( t )
    local o = Object.new( self, t )
    return o
end



--- Get path to collection.
--
--  @usage assuming coll is a collection, even if special.
--
--  @param coll (LrCollection, required) can not be nil, but can be a special collection.
--  @param sep (string, default: app--path-sep) path separator.
--
--  @return path (string) If no parent returns collection name, even if special.
--  @return comp (array of strings) components, in case you want to roll your own path or sub-path.. last element is name of collection itself.
--
function Collections:getCollPath( coll, sep )
    sep = sep or '/'
    if coll.getParent then
        local c = { cat:getSourceName( coll ) }
        local p = coll:getParent()
        while p ~= nil do
            c[#c + 1] = cat:getSourceName( p )
            if p.getParent then
                p = p:getParent()
            else
                break
            end
        end
        tab:reverseInPlace( c )
        return table.concat( c, sep ), c
    else
        return cat:getSourceName( coll )
    end
end



return Collections