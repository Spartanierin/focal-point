local _, ns = ...

-- Data-only and bounded: dictionaries store strings only, never table references.
local Codec = {}
ns.LayoutTransferCodec = Codec
Codec.SchemaVersion = 1
Codec.MaxBytes = 2 * 1024 * 1024
Codec.MaxDictionaryEntries = 512
Codec.MaxDictionaryBytes = Codec.MaxBytes / 2
local MAGIC, MAX_DEPTH, MAX_NODES = "FocalPointLayout:", 32, 100000
local BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_VALUES = {}
for i = 1, #BASE64 do BASE64_VALUES[BASE64:sub(i, i)] = i - 1 end
local function Fail(reason) error(reason, 0) end
local function Finite(v) return v == v and v ~= math.huge and v ~= -math.huge end
local function ValidKey(k) return type(k) == "string" or (type(k) == "number" and Finite(k) and k >= 1 and k % 1 == 0) end
local function LiteralSize(v) return 2 + #tostring(#v) + #v end
local function RefSize(id) return 2 + #tostring(id) end

local function EncodeBase64(data)
    local chunks, out = {}, {}
    for p = 1, #data, 3 do
        local a, b, c = string.byte(data, p, p + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        out[#out+1] = BASE64:sub(math.floor(n / 262144) + 1, math.floor(n / 262144) + 1)
        out[#out+1] = BASE64:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        out[#out+1] = b and BASE64:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "="
        out[#out+1] = c and BASE64:sub(n % 64 + 1, n % 64 + 1) or "="
        if #out >= 4096 then chunks[#chunks+1] = table.concat(out); out = {} end
    end
    if #out > 0 then chunks[#chunks+1] = table.concat(out) end
    return table.concat(chunks)
end

local function DecodeBase64(data)
    if data == "" or #data % 4 ~= 0 then Fail("invalid-transport") end
    local pad = data:sub(-2) == "==" and 2 or (data:sub(-1) == "=" and 1 or 0)
    if #data / 4 * 3 - pad > Codec.MaxBytes then Fail("too-large") end
    local chunks, out = {}, {}
    for p = 1, #data, 4 do
        local a,b,c,d = data:sub(p,p),data:sub(p+1,p+1),data:sub(p+2,p+2),data:sub(p+3,p+3)
        local last = p + 3 == #data
        if not BASE64_VALUES[a] or not BASE64_VALUES[b] or (c == "=" and (not last or d ~= "=")) or (d == "=" and not last) or (c ~= "=" and not BASE64_VALUES[c]) or (d ~= "=" and not BASE64_VALUES[d]) then Fail("invalid-transport") end
        if c == "=" and BASE64_VALUES[b] % 16 ~= 0 then Fail("invalid-transport") end
        if d == "=" and c ~= "=" and BASE64_VALUES[c] % 4 ~= 0 then Fail("invalid-transport") end
        local n = BASE64_VALUES[a]*262144 + BASE64_VALUES[b]*4096 + (BASE64_VALUES[c] or 0)*64 + (BASE64_VALUES[d] or 0)
        out[#out+1] = string.char(math.floor(n / 65536) % 256)
        if c ~= "=" then out[#out+1] = string.char(math.floor(n / 256) % 256) end
        if d ~= "=" then out[#out+1] = string.char(n % 256) end
        if #out >= 4096 then chunks[#chunks+1] = table.concat(out); out = {} end
    end
    if #out > 0 then chunks[#chunks+1] = table.concat(out) end
    return table.concat(chunks)
end

local function SortedKeys(value)
    local keys = {}
    for key in pairs(value) do
        if not ValidKey(key) then Fail("invalid-data") end
        keys[#keys+1] = key
        if #keys > MAX_NODES then Fail("too-complex") end
    end
    table.sort(keys, function(a,b) if type(a) ~= type(b) then return type(a) == "number" end return a < b end)
    return keys
end

local function Collect(document)
    local keys, values, seen, nodes = {}, {}, {}, 0
    local function Add(counts, value) counts[value] = (counts[value] or 0) + 1 end
    local function Visit(value, depth, role)
        nodes = nodes + 1
        if nodes > MAX_NODES or depth > MAX_DEPTH then Fail("too-complex") end
        local kind = type(value)
        if kind == "string" then
            if #value > Codec.MaxBytes / 2 then Fail("too-large") end
            Add(role == "key" and keys or values, value)
        elseif kind == "number" then
            if not Finite(value) then Fail("invalid-data") end
        elseif kind == "boolean" then
            return
        elseif kind == "table" and not getmetatable(value) and not seen[value] then
            seen[value] = true
            for _, key in ipairs(SortedKeys(value)) do Visit(key, depth+1, "key"); Visit(value[key], depth+1, "value") end
            seen[value] = nil
        else Fail("invalid-data") end
    end
    Visit(document, 0, "value")
    return keys, values
end

-- The reference cost uses the longest allowed ID, so every retained entry
-- saves bytes even after deterministic IDs are assigned.
local function Dictionary(counts, maximum)
    local entries = {}
    for value, count in pairs(counts) do
        if count >= 2 and (count - 1) * LiteralSize(value) > count * RefSize(maximum) then entries[#entries+1] = value end
    end
    table.sort(entries)
    while #entries > maximum do table.remove(entries) end
    local lookup = {}
    for i, value in ipairs(entries) do lookup[value] = i end
    return entries, lookup
end

function Codec.Encode(document)
    local ok, result = pcall(function()
        local keyCounts, valueCounts = Collect(document)
        local keyEntries, keyLookup = Dictionary(keyCounts, Codec.MaxDictionaryEntries / 2)
        local valueEntries, valueLookup = Dictionary(valueCounts, Codec.MaxDictionaryEntries / 2)
        local parts, seen, nodes, bytes, dictionaryBytes = {}, {}, 0, 0, 0
        local function Append(value)
            bytes = bytes + #value
            if bytes > Codec.MaxBytes then Fail("too-large") end
            parts[#parts+1] = value
        end
        local function DictionaryEntries(entries)
            Append("d" .. #entries .. ":")
            for _, value in ipairs(entries) do
                dictionaryBytes = dictionaryBytes + #value
                if dictionaryBytes > Codec.MaxDictionaryBytes then Fail("too-large") end
                Append("s" .. #value .. ":" .. value)
            end
        end
        local function Write(value, depth, role)
            nodes = nodes + 1
            if nodes > MAX_NODES or depth > MAX_DEPTH then Fail("too-complex") end
            local kind = type(value)
            if kind == "boolean" then Append(value and "b1" or "b0")
            elseif kind == "number" and Finite(value) then local n=string.format("%.17g",value); Append("n"..#n..":"..n)
            elseif kind == "string" then
                local id = role == "key" and keyLookup[value] or valueLookup[value]
                if id then Append((role == "key" and "k" or "v")..id..":") else Append("s"..#value..":"..value) end
            elseif kind == "table" and not getmetatable(value) and not seen[value] then
                seen[value] = true; local keys=SortedKeys(value); Append("t"..#keys..":")
                for _, key in ipairs(keys) do Write(key,depth+1,"key"); Write(value[key],depth+1,"value") end
                seen[value] = nil
            else Fail("invalid-data") end
        end
        DictionaryEntries(keyEntries); DictionaryEntries(valueEntries); Write(document,0,"value")
        return MAGIC .. Codec.SchemaVersion .. ":" .. EncodeBase64(table.concat(parts))
    end)
    if not ok then return nil, result end
    return result
end

function Codec.Decode(text)
    if type(text) ~= "string" then return nil, "invalid-header" end
    local maxTransport = #MAGIC + #tostring(Codec.SchemaVersion) + 1 + math.ceil(Codec.MaxBytes / 3) * 4
    if #text > maxTransport then return nil, "too-large" end
    text = text:match("^%s*(.-)%s*$")
    local version, payload = text:match("^FocalPointLayout:(%d+):([A-Za-z0-9+/=]*)$")
    if not version then return nil, "invalid-header" end
    if version ~= tostring(Codec.SchemaVersion) then return nil, "transfer-version" end
    local ok, result = pcall(function()
        local raw = DecodeBase64(payload)
        local position, nodes, dictionaryBytes = 1, 0, 0
        local function Length()
            local ending=raw:find(":",position,true)
            if not ending or ending-position > 8 then Fail("invalid-encoding") end
            local digits=raw:sub(position,ending-1)
            if not digits:match("^%d+$") then Fail("invalid-encoding") end
            position=ending+1; return tonumber(digits)
        end
        local function Literal()
            if raw:sub(position,position) ~= "s" then Fail("invalid-encoding") end
            position=position+1; local length=Length()
            if length > Codec.MaxBytes/2 or length > #raw-position+1 then Fail("invalid-encoding") end
            local value=raw:sub(position,position+length-1); position=position+length; return value
        end
        local function ReadDictionary()
            if raw:sub(position,position) ~= "d" then Fail("invalid-encoding") end
            position=position+1; local count=Length()
            if count > Codec.MaxDictionaryEntries/2 then Fail("too-complex") end
            local entries={}
            for i=1,count do local value=Literal(); dictionaryBytes=dictionaryBytes+#value; if dictionaryBytes>Codec.MaxDictionaryBytes then Fail("too-large") end; entries[i]=value end
            return entries
        end
        local keyEntries,valueEntries=ReadDictionary(),ReadDictionary()
        local function Read(depth, role)
            nodes=nodes+1; if nodes>MAX_NODES or depth>MAX_DEPTH then Fail("too-complex") end
            local token=raw:sub(position,position); position=position+1
            if token == "b" then local value=raw:sub(position,position); position=position+1; if value~="0" and value~="1" then Fail("invalid-encoding") end; return value=="1" end
            if token == "k" or token == "v" then
                local id=Length(); if (token=="k" and role~="key") or (token=="v" and role~="value") then Fail("invalid-encoding") end
                local entries=token=="k" and keyEntries or valueEntries; if id<1 or id>#entries then Fail("invalid-encoding") end; return entries[id]
            end
            if token == "s" then position=position-1; return Literal() end
            if token ~= "n" and token ~= "t" then Fail("invalid-encoding") end
            local length=Length()
            if token == "t" then
                if length>MAX_NODES then Fail("too-complex") end
                local value={}; for _=1,length do local key=Read(depth+1,"key"); if not ValidKey(key) or value[key]~=nil then Fail("invalid-encoding") end; value[key]=Read(depth+1,"value") end; return value
            end
            if length==0 or length>32 or length>#raw-position+1 then Fail("invalid-encoding") end
            local data=raw:sub(position,position+length-1); position=position+length
            if not data:match("^[%d%.eE%+%-]+$") then Fail("invalid-encoding") end
            local number=tonumber(data); if not number or not Finite(number) then Fail("invalid-encoding") end; return number
        end
        local value=Read(0,"value"); if position~=#raw+1 then Fail("invalid-encoding") end; return value
    end)
    if not ok then return nil,result end
    return result
end
