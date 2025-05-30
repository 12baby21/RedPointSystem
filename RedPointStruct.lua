--[[
    author:{wujunfei}
    time:2025-05-09 17:46:58
    红点数据逻辑，主要是数据逻辑，提供对外的数据接口
    只是一个数据结构
    需要返回给父红点，显示的优先级最高的红点或者都为false
]]

---@class RedPointStruct
local RedPointStruct = class("RedPointStruct")
---@type RedPointConst
local RedPointConst = require("RedPointConst")

--[[
    红点判断方法
]]

local redPointConfig = {
    [1] = {
        func = function()  end,
        events = {}
    }
}

--[[
    params = {
        id: number 唯一标识
        type: RedPointConst.TYPE  deprecated 显示类型应当属于ui层
    }
]]

function RedPointStruct:ctor(params)
    --- ctor方法必需参数
    self.id = params.id                 -- 红点唯一id
    self.idString = params.idString     -- 完整的层级结构
    --- ctor方法可选参数
    --- 如果没有更新方法直接找孩子即可
    self.updateFuncMap = {}        -- key为红点类型，value为回调函数列表，红点条件采用的逻辑关系暂未确定
    self.registeredType = {}        -- 注册过的红点类型，用于优先级判断
                                    -- false = 0
    self.dirtyMap = {}
    self.isShowMap = {}



    ---@type RedPointStruct
    self.parent = params.parent
    ---@type RedPointStruct[]
    self.children = {}      -- 保存所有的子红点，当向下查询红点时，可以不用重复计算红点
    self.childCnt = 0       -- 记录子红点数量，用于当没有子红点时删除父红点的此红点
    self.showNumber = 1     -- 大于零认为可以显示
    self.redPointCnt = 0            -- 数字红点，统计子红点的红点数
    self:setUpdateFunc(params.funcMap)

    -- todo: 或许可以保存根结点，便于反向查找
end

--- setUpdateFunc 设置红点刷新函数
--- 因为一个红点可以被拆成多个条件，所以采用队列形式保存
function RedPointStruct:setUpdateFunc(funcMap)
    if not funcMap then
        return
    end
    for _, v in pairs(funcMap) do
        if not self.updateFuncMap[v.type] then
            self.updateFuncMap[v.type] = {
                isDirty = true,
                funcList = {},
            }
            self.registeredType[v.type] = true
        end
        local funcList = self.updateFuncMap[v.type].funcList
        funcList[#funcList + 1] = v.updateFunc
    end
end

---setDirty 设置脏标
function RedPointStruct:setDirty(isDirty, redPointType)
    self.dirtyMap[redPointType] = isDirty
    if isDirty and self.parent then
        self.parent:setDirty(isDirty, redPointType)
    end
end

---addChild
---@param child RedPointStruct
function RedPointStruct:addChild(child)
    if not child then
        return
    end
    local redId = child:getId()
    self.children[redId] = {
        node = child,
        isDirty = false,            -- 默认为false，因为子红点刷新后会重置脏标
    }
    self.childCnt = self.childCnt + 1
end

---removeChild 删除子红点，如果所有子红点被移除了，则父红点需要删除该结点
---@param id number
function RedPointStruct:removeChild(id)
    self.children[id] = nil
    self.childCnt = self.childCnt - 1
    if self.childCnt <= 0 then
        if self.parent then
            self.parent:removeChild(self.id)
        else
            sgs.RedPointManager:removeTree(self.id)
        end
    end
end

---@param parent RedPointStruct
function RedPointStruct:setParent(parent)
    self.parent = parent
end


---isShow 实际刷新红点数据，供UI使用
---@return number
function RedPointStruct:isShow(showType)
    --- 没有脏标，直接返回当前保存的值
    if not self.isDirty then
        return self.isShowMap[showType]
    end

    --- 判断自身红点
    local showNum = self.updateFuncMap[showType] and self.updateFuncMap[showType]() or 0
    for _, child in pairs(self.child) do
        -- 如果有一个红点为true
        showNum = showNum + child:isShow(showType)
        if showNum > 0 and showType ~= RedPointConst.TYPE.NUMBER then
            break
        end
    end
    self.dirtyMap[showType] = false
    self.isShowMap[showType] = showNum
    return showNum
end

---getShowInfo 获取显示数据
---会根据红点优先级进行返回
---@return number, number 红点类型，红点显示状态
function RedPointStruct:getShowInfo()
    for _, t in ipairs(RedPointConst.PRIORITY) do
        if self.registeredType[t] then
            local showNum = self:isShow(t)
            if showNum > 0 then
                return t, showNum
            end
        end
    end
    return RedPointConst.TYPE.NONE, 0
end


----------------------------------------------- getter -----------------------------------------------
function RedPointStruct:getId()
    return self.id
end

function RedPointStruct:getIdString()
    return self.idString
end

function RedPointStruct:getChildrenRedCnt()

end


return RedPointStruct



