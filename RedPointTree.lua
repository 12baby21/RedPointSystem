-- 红点系统树，前缀树结构

---@class RedPointTree
local RedPointTree = class("RedPointTree")
local RedPointStruct = require("RedPointStruct")
---@type LuaUtils
local LuaUtils = require("LuaUtils")
---@type RedPointManager
local RedPointManager = require("RedPointManager")


function RedPointTree:ctor(params)
    self.root = nil
    ---@type table<number, RedPointStruct>
    self.redPointStructMap = {}       -- key为红点id
    self:register(params)
end

---getRedPointStruct 从根节点遍历查询
---@return RedPointStruct
function RedPointTree:getRedPointStruct(ids)
    local curNode = self.root       -- 根节点符合才会进入这个方法
    for i = 2, #ids do
        local id = ids[i]
        curNode = curNode.children[id]
        if not curNode then
            printError(string.format("没有在红点树上找到红点id为%d的逻辑红点", id))
            break
        end
    end
    return curNode
end

---@return RedPointStruct
function RedPointTree:getRedPointStructById(id)
    return self.redPointStructMap[id]
end

---unregister 删除某个红点
---@param idString string
function RedPointTree:unregister(idString)
    local ids = LuaUtils.splitString(idString, "|")
    local node = self:getRedPointStructById(ids[#ids])
    if nil == node then    -- 没有找到该红点
        printError("删除失败，没有找到红点路径为%s的红点：", idString)
        return false
    end
    local parent = node.parent
    if parent then
        parent:removeChild(node.id)
    end
    node = nil
    return true
end


---@return boolean 是否删除失败
function RedPointTree:unregisterById(id)
    local node = self:getRedPointStructById(id)
    if not node then
        printError("删除失败，没有找到红点id为%d的红点：", id)
        return false
    end
    local ret = self:unregisterFromParent(id)
    return ret
end

function RedPointTree:unregisterFromParent(id)
    local node = self.redPointStructMap[id]
    if not node then
        return false
    end
    local parent = node.parent
    -- lua5.1只要不可达就会被垃圾回收Collect
    if parent then
        parent:removeChild(id)
    else
        -- 当前移除的是根结点
        if node == self.root then
            RedPointManager:removeTree(id)
            return true
        end
    end
    --- 层次遍历子红点树，移除redPointStructMap的引用
    local list = { node }
    local curPos = 1
    while curPos <= #list do
        local curNode = list[curPos]
        self.redPointStructMap[curNode:getId()] = nil
        for _, child in ipairs(curNode.children) do
            list[#list + 1] = child
        end
        curPos = curPos + 1
    end
    list = {}      -- 删除list对这些node的引用
    return true
end


---register 递归地注册红点
---params = { idString }
function RedPointTree:register(params)
    --- 从叶子向根添加红点（因为保存了映射，不用遍历了）
    --- 也解决了其中某个红点可能没构造的问题
    local idString = params.idString
    local ids = LuaUtils.splitString(idString, "|")
    local child = nil       -- 上次一构造的子红点
    for i = #ids, 1, -1 do
        local id = ids[i]
        if self.redPointStructMap[id] then
            --- 有这个红点
            break
        end
        --- 当前构造的红点(父红点)
        local curNode = RedPointStruct.new({
            id = id,
            idString = idString,
        })
        curNode:addChild(child)
        child:setParent(curNode)
        self.redPointStructMap[id] = child
    end
    if not self.root then
        self.root = self.redPointStructMap[ids[1]]        -- 设置根节点
    else
        assert(self.root:getId() == ids[1], "根节点红点id不一致，请核实")
    end
    self.redPointStructMap[ids[#ids]]:setUpdateFunc(params.updateFunc)        -- 叶子结点设置方法
end

---registerToParent 向父红点添加红点
---@return boolean 是否注册成功
function RedPointTree:registerToParent(id, parentId)
    if self.redPointStructMap[id] then
        dump("红点已经存在")
        return false
    end
    local parentNode = self.redPointStructMap[parentId]
    if not parentNode then
        dump("父红点不存在")
        return false
    end
    local idString = string.format("%s|%d", parentNode:getIdString(), id)
    local node = RedPointStruct.new({
        id = id,
        idString = idString,
    })
    parentNode:addChild(node)
    node:setParent(parentNode)
    self.redPointStructMap[id] = node
    return true
end

---setUpdateFunc 设置某一个红点的刷新方法
function RedPointTree:setUpdateFunc(id, updateFunc)
    if self.redPointStructMap[id] then
        self.redPointStructMap[id]:setUpdateFunc(updateFunc)
    end
end

return RedPointTree