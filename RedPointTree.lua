-- 红点系统树，前缀树结构

---@class RedPointTree
local RedPointTree = class("RedPointTree")
local RedPointStruct = require("RedPointStruct")
---@type LuaUtils
local LuaUtils = require("LuaUtils")

-- 节点名
RedPointTree.NodeNames = {
    Root = "Root",

    ModelA = "Root|ModelA",
    ModelA_Sub_1 = "Root|ModelA|ModelA_Sub_1",
    ModelA_Sub_2 = "Root|ModelA|ModelA_Sub_2",

    ModelB = "Root|ModelB",
    ModelB_Sub_1 = "Root|ModelB|ModelB_Sub_1",
    ModelB_Sub_2 = "Root|ModelB|ModelB_Sub_2",
}

function RedPointTree:ctor(redPointParams)
    self.root = nil
    self.redPointNodeMap = {}       -- key为红点id
    self:init(redPointParams)
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
        self:InsertNode({
            id = ids[level],
            idString = redPointParams.ids,
            isLeaf = isLeaf,
            level = level,
            updateFunc = isLeaf and redPointParams.updateFunc or nil,
        })
    end

end

---InsertNode 插入红点
---@param redPointParams table  相关红点参数，具体内容待定
function RedPointTree:insertNode(redPointParams)
    --- 通过id遍历字典树，如果某一个节点不存在
    local ids = LuaUtils.splitString(redPointParams.idString, "|")
    local curNode = self.root
    for i = 2, #ids do
        local id = ids[i]
        local child = curNode.children[id]
        if not child then
            child = RedPointStruct.new()      -- todo
            curNode.children[id] = child
            child.parent = curNode
            curNode = child
            self.redPointNodeMap[id] = child
        end
    end
    return true
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

-- 修改节点的红点数
function RedPointTree:ChangeRedpointCnt(name, delta)
    local targetNode =self:getRedPointStruct(name)
    if nil == targetNode then
        return
    end
    -- 如果是减红点，并且红点数不够减了，则调整delta，使其不减为0
    if delta < 0 and targetNode.redpointCnt + delta < 0 then
        delta = -targetNode.redpointCnt
    end

    local node = self.root
    local pathList = LuaUtil.SplitString(name, "|")
    for _, path in pairs(pathList) do
        local childNode = node.children[path]
        childNode.redpointCnt = childNode.redpointCnt + delta
        node = childNode
        -- 调用回调函数
        for _, cb in pairs(node.updateCb) do
            cb(node.redpointCnt)
        end
    end
end

-- 查询节点的红点数
function RedPointTree:GetRedpointCnt(name)
    local node = self:getRedPointStruct(name)
    if nil == node then
        return 0
    end
    return node.redpointCnt or 0
end

-- 新注册的红点一定是叶子结点
function RedPointTree:register(idString)
    self:insertNode()



end

-- 设置红点更新回调函数
function RedPointTree.SetCallBack(name, key, cb)
    local node = this.getRedPointStruct(name)
    if nil == node then
        return
    end
    node.updateCb[key] = cb
end

-- 递归获取整棵树的路径
function RedPointTree.GetFullTreePath(parent, pathList)
    for path, node in pairs(parent.children) do
        table.insert(pathList, path)
        if LuaUtil.TableCount(node.children) > 0 then
            this.GetFullTreePath(node, pathList)
        end
    end
end

-- 打印整棵树的路径
function RedPointTree.PrintFullTreePath()
    local pathList = {}
    this.GetFullTreePath(this.root, pathList)
    LuaUtil.PrintTable(pathList)
end



return RedPointTree