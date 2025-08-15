
local RedPointEventManger = class("RedPointEventManager")

local _instance = nil
function RedPointEventManger:getInstance()
    if _instance == nil then
        _instance = setmetatable({}, RedPointEventManger)
        _instance:init()
    end
    return _instance
end

function RedPointEventManger:init()
    cc(self):addComponent("components.behavior.EventProtocol"):exportMethods()
end



return RedPointEventManger
