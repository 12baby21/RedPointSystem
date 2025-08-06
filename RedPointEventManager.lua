--[[
    luaide  模板位置位于 Template/FunTemplate/NewFileTemplate.lua 其中 Template 为配置路径 与luaide.luaTemplatesDir
    luaide.luaTemplatesDir 配置 https://www.showdoc.cc/web/#/luaide?page_id=713062580213505
    author:{author}
    time:2025-08-06 17:51:21
]]


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