-- 红点系统树，前缀树结构

---@class RedPointTree
local RedPointTree = class("RedPointTree")
local RedPointStruct = require("RedPointStruct")
---@type LuaUtils
local LuaUtils = require("LuaUtils")


function RedPointTree:ctor(params)
    self.root = nil
    self.redPointNodeMap = {}       -- key为红点id
    self:register(params)
end

---Init 初始化红点树
function RedPointTree:init(redPointParams)
    local ids = LuaUtils.splitString(redPointParams.ids, "|")
    -- 先创建根节点
    -- todo: 这块逻辑应该可以优化
    local isLeaf = #ids == 1
    self.root = RedPointStruct.new({
        id = ids[1],
        idString = redPointParams.ids,      -- 检索用
        isLeaf = isLeaf,
        level = 1,
        updateFunc = isLeaf and redPointParams.updateFunc or nil,
    })

    -- 构建前缀树
    -- todo：不该代码添加，应该从配置添加
    for level, v in ipairs(ids) do
        -- 知道层级，才能知道结点在树中的位置
        isLeaf = #ids == level
        self:register({
            id = ids[level],
            idString = redPointParams.ids,
            isLeaf = isLeaf,
            level = level,
            updateFunc = isLeaf and redPointParams.updateFunc or nil,
        })
    end

end

--- getRedPointNode查询节点是否在树中并返回节点 应该可以所有红点树有一个为id为0的公共根
function RedPointTree:getRedPointNode(idString)
    local curNode = self.root
    local ids = LuaUtils.splitString(idString, "|")
    for i = 2, #ids do
        local id = ids[i]
        local child = curNode.children[id]
        if not child then
            return nil          -- 没找到该红点
        end
        curNode = child
    end
    return curNode
end

---@return RedPointStruct
function RedPointTree:getRedPointNodeById(id)
    return self.redPointNodeMap[id]
end


---deleteRedPointStruct 删除某个红点
---@param idString string
function RedPointTree:deleteRedPointStruct(idString)
    -- todo:理论上不应该支持删除非叶结点，如果需要支持则需要后续开发
    local node = self:getRedPointNode(idString)
    if nil == node then    -- 没有找到该红点
        dump(idString, "删除失败，没有找到当前层级结构的红点：")
        return false
    end
    local parent = node.parent
    if parent then
        parent:removeChild(node.id)
    end
    node = nil
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
        if self.redPointNodeMap[id] then
            --- 有这个红点
            break
        end
        --- 当前构造的红点
        local curNode = RedPointStruct.new({
            id = id,
            idString = idString,
        })
        curNode:addChild(child)
        child:setParent(curNode)
        curNode = child
        self.redPointNodeMap[id] = child
    end
    if not self.root then
        self.root = self.redPointNodeMap[ids[1]]        -- 设置根节点
    else
        assert(self.root:getId() == ids[1], "根节点红点id不一致，请核实")
    end
    self.redPointNodeMap[ids[#ids]]:setUpdateFunc(params.updateFunc)        -- 叶子结点设置方法
end

---setUpdateFunc 设置某一个红点的刷新方法
function RedPointTree:setUpdateFunc(id, updateFunc)
    if self.redPointNodeMap[id] then
        self.redPointNodeMap[id]:setUpdateFunc(updateFunc)
    end
end

return RedPointTree