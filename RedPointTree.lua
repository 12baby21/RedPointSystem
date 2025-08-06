-- 红点系统树，前缀树结构

---@class RedPointTree
local RedPointTree = class("RedPointTree")
local RedPointStruct = require("redPoint.RedPointStruct")
---@type LuaUtils
local LuaUtils = require("redPoint.LuaUtils")

function RedPointTree:ctor(params)
    ---@type RedPointStruct
    self.root = nil
    ---@type table<number, RedPointStruct>
    self.redPointStructMap = {}       -- key为红点id
    self:registerWithFullPath(params)
end

---tryRegisterToParent 尝试注册红点，如果没有父红点则创建
---@return number 根红点的id
function RedPointTree:tryRegisterToParent(params)
    local id = params.id
    local parentId = params.parentId
    local isRootChanged = false
    local oldRootId = self.root and self.root.id or ""
    local parentStruct = self.redPointStructMap[parentId]
    if not parentStruct and parentId then
        parentStruct = RedPointStruct.new({
            id = parentId,
            idString = tostring(parentId),
        })
        isRootChanged = true
        self.root = parentStruct
        self.redPointStructMap[parentId] = parentStruct
    end
    local redPointStruct = self.redPointStructMap[id]
    if not redPointStruct then
        redPointStruct = RedPointStruct.new({
            id = id,
            idString = (parentStruct and parentStruct.idString or "") .. "|" .. id,
        })
        if not self.root then
            isRootChanged = true
            self.root = redPointStruct
        end
        self.redPointStructMap[id] = redPointStruct
    end
    --- 这里放在外面是因为，即使子红点存在，但可能原来是根结点，所以也需要替换下
    if parentStruct then
        redPointStruct.parent = parentStruct
        parentStruct:addChild(redPointStruct)
    end
    redPointStruct:setUpdateFunc(params.funcMap)
    return { isRootChanged = isRootChanged, newRootId = self.root.id, oldRootId = oldRootId }
end

---registerWithFullPath 用完整路径注册红点
function RedPointTree:registerWithFullPath(params)
    --- 从叶子向根添加红点（因为保存了映射，不用遍历了）
    --- 也解决了其中某个红点可能没构造的问题
    local idString = params.idString
    local ids = LuaUtils.splitString(idString, "|")
    local child = nil       -- 上次一构造的子红点
    local lastId = ids[#ids]
    local rootId = ids[1]
    for i = #ids, 1, -1 do
        local curId = ids[i]
        
        if self.redPointStructMap[curId] then
            --- 有这个红点
            break
        end
        --- 当前构造的红点(父红点)
        local curNode = RedPointStruct.new({
            id = curId,
            idString = table.concat(ids, "|"),
        })
        ids[i] = nil
        if child then
            curNode:addChild(child)
            child:setParent(curNode)
        end
        child = curNode
        self.redPointStructMap[curId] = curNode
    end
    if not self.root then
        self.root = self.redPointStructMap[rootId]        -- 设置根节点
    end
    self.redPointStructMap[lastId]:setUpdateFunc(params.funcMap)        -- 叶子结点设置方法
end

---getRedPointStruct 从根节点遍历查询
---@return RedPointStruct
function RedPointTree:getRedPointStruct(idString)
    local ids = LuaUtils.splitString(idString, "|")
    return self:getRedPointStructByIds(ids[#ids])
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
            sgs.RedPointManager:removeTree(id)
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

---hasRedPointStruct 红点树上是否有某个id的红点
function RedPointTree:hasRedPointStruct(id)
    local isValid = not LuaUtils.isStrNullOrEmpty(id)
    return isValid and self.redPointStructMap[id]
end

---------------------------------- 测试用 ---------------------------------
---printTree 打印红点树结构
function RedPointTree:printTree()
    if not self.root then
        print("红点树为空")
        return
    end
    
    print("红点树结构:")
    self:_printNode(self.root, 0)
end

---_printNode 递归打印节点信息
function RedPointTree:_printNode(node, depth)
    if not node then return end
    
    local indent = string.rep("  ", depth)
    local eventIdStr = ""
    if node.triggerEvents and #node.triggerEvents > 0 then
        eventIdStr = " [事件: " .. table.concat(node.triggerEvents, ",") .. "]"
    end
    
    print(string.format("%s- %s (ID: %s)%s", indent, node.idString, node.id, eventIdStr))
    
    for _, child in ipairs(node.children) do
        self:_printNode(child, depth + 1)
    end
end



return RedPointTree