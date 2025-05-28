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

--- 仍遗留问题：
function RedPointStruct:ctor(params)
    --- ctor方法必需参数
    self.id = params.id                 -- 红点唯一id
    self.isLeaf = params.isLeaf         -- 是否是叶子结点 ?
    self.idString = params.idString     -- 完整的层级结构
    --- ctor方法可选参数
    --- 如果没有更新方法直接找孩子即可
    self._updateFuncMap = {}        -- key为红点类型，value为回调函数列表，红点条件采用的逻辑关系暂未确定


    self.isDirty = false        -- 脏标，子红点刷新了，更新子红点
    ---@type RedPointStruct
    self.parent = params.parent
    ---@type RedPointStruct[]
    self.children = {}      -- 保存所有的子红点，当向下查询红点时，可以不用重复计算红点
    self.childCnt = 0       -- 记录子红点数量，用于当没有子红点时删除父红点的此红点
    self.showNumber = 1     -- 大于零认为可以显示
    self.redPointCnt = 0            -- 数字红点，统计子红点的红点数
    self:_initUpdateFunc(params.funcMap)
end

--- _initUpdateFunc 设置红点刷新函数
--- 因为一个红点可以被拆成多个条件，所以采用队列形式保存
function RedPointStruct:_initUpdateFunc(funcMap)
    for _, v in pairs(funcMap) do
        if not self._updateFuncMap[v.type] then
            self._updateFuncMap[v.type] = {
                isDirty = true,
                funcList = {},
            }
        end
        local funcList = self._updateFuncMap[v.type].funcList
        funcList[#funcList + 1] = v.updateFunc
    end
end

--- 初步考虑，当数据变化时，递归setDirty，实际需要刷新的时候，才进行计算，减小性能消耗
--- UI刷新后重置本node脏标
function RedPointStruct:setDirty(isDirty, redPointType)
    self.isDirty = isDirty
    if isDirty and self.parent then
        self.parent:setDirty(isDirty, redPointType)
    end
end

---addChild
---@param child RedPointStruct
function RedPointStruct:addChild(child)
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
            -- todo:没有父红点，说明这是根红点，从森林中移除
        end
    end
end

---isShow todo:逻辑需要补全
---@return number 大于0代表有红点
function RedPointStruct:isShow(customData, showType)
    if not self.isLeaf and not self.isDirty then
        --- 不是叶子结点 && 没有脏标   ->   不用重新统计
        return self.showNumber
    end

    if not self.isLeaf and self.isDirty then
        --- 不是叶子结点 && 有脏标   ->   重新统计孩子结点的数据
        self.showNumber = 0
        for _, child in pairs(self.children) do
            local childNum = child:isShow(customData)
            self.showNumber = self.showNumber + childNum
        end
        return self.showNumber
    end

    --- 叶子结点   ->   通过刷新方法获取红点数据
    if self.updateFunc then
        local oldShowNumber = self.showNumber
        self.showNumber = self.updateFunc(customData)
        if self.parent and oldShowNumber ~= self.showNumber then
            self.parent:setDirty(true)
        end
        return self.showNumber
    end

    return 0
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



