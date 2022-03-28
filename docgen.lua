--[[
Apache License 2.0

Copyright (c) 2016-2021 SinisterRectus (Original author)
Copyright (c) 2021-2022 Bilal2453 (Heavily modified to partially support EmmyLua)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
]]

local fs = require('fs')
local pathjoin = require('pathjoin')

local insert, sort, concat = table.insert, table.sort, table.concat
local format = string.format
local pathJoin = pathjoin.pathJoin

local function scan(dir)
	for fileName, fileType in fs.scandirSync(dir) do
		local path = pathJoin(dir, fileName)
		if fileType == 'file' then
			coroutine.yield(path)
		else
			scan(path)
		end
	end
end

local function match(s, pattern) -- only useful for one capture
	return assert(s:match(pattern), s)
end

local function gmatch(s, pattern, hash) -- only useful for one capture
	local tbl = {}
	if hash then
		for k in s:gmatch(pattern) do
			tbl[k] = true
		end
	else
		for v in s:gmatch(pattern) do
			insert(tbl, v)
		end
	end
	return tbl
end

local function matchType(c)
	local line
	for _, s in ipairs(c) do
		if s:find '<!ignore>' then return 'ignore' end
	end
	for _, s in ipairs(c) do
		local m = s:match('%-%-%-%s*@(%S+)')
		if m then line = m; break end
	end
	return line
end

local function matchComments(s)
	local lines = {}
	local last_line = {}
	for l in s:gmatch('[^\n]*\n?') do
		if l:match '^%-%-' then
			last_line[#last_line + 1] = l
		elseif #last_line > 0 then
			last_line[#last_line + 1] = l
			lines[#lines+1] = last_line
			last_line = {}
		end
	end
	return lines
end

local function matchClassName(s)
	return match(s, '@class ([^%s:]+)')
end

local function matchMethodName(s)
	local m = s:match 'function%s*.-[:.]%s*([_%w]+)'
		or s:match 'function%s*([_%w]+)'
		or s:match '([_%w]+)%s*=%s*function'
	if not m then error(s) end
	return m
end

local function matchDescription(c)
	local desc = {}
	for _, v in ipairs(c) do
		local n, m = v:match('%-%-%-*%s*@'), v:match('%-%-+%s*(.+)')
		if not n and m then
			m = m:gsub('<!.->', '') -- invisible custom tags
			desc[#desc+1] = m
		end
	end
	return table.concat(desc):gsub('^%s+', ''):gsub('%s+$', '')
end

local function matchParents(c)
	local line
	for _, s in ipairs(c) do
		local m = s:match('@class [%a_][%a_%-%.%*]+%s*:%s*([^\n#@%-]+)')
		if m then line = m; break end
	end
	if not line then return {} end
	local ret = {}
	for s in line:gmatch('[^,]+') do
		ret[#ret + 1] = s:match('%S+'):gsub('%s+', '')
	end
	return ret
end

local function matchReturns(s)
	return gmatch(s, '@return (%S+)')
end

local function matchTags(s)
	local ret = {}
	for m in s:gmatch '<!tag%s*:%s*(.-)>' do
		ret[m] = true
	end
	return ret
end

local function matchMethodTags(s)
	local ret = {}
	for m in s:gmatch '<!method%p?tags%s*:%s*(.-)>' do
		ret[m] = true
	end
	return ret
end

local function matchProperties(s)
	local ret = {}
	for n, t, d in s:gmatch '@field%s*(%S+)%s*(%S+)%s*([^\n]*)' do
		ret[#ret+1] = {
			name = n,
			type = t,
			desc = d or '',
		}
	end
	return ret
end

local function matchParameters(c)
	local ret = {}
	for _, s in ipairs(c) do
		local param_name, optional, param_type = s:match('@param%s*([^%s%?]+)%s*(%??)%s*(%S+)')
		if param_name then
			ret[#ret+1] = {param_name, param_type, optional == '?'}
		end
	end
	if #ret > 0 then return ret end

	for _, s in ipairs(c) do
		local params = s:match('@type%s*fun%s*%((.-)%)')
		if not params then goto continue end
		for pp in params:gmatch('[^,]+') do
			local param_name, optional = pp:match('([%w_%-]+)%s*(%??)')
			local param_type = pp:match(':%s*(.+)')
			if param_name then
				ret[#ret+1] = {param_name, param_type, optional == '?'}
			end
		end
		::continue::
	end
	return ret
end

local function matchMethod(s, c)
	return {
		name = matchMethodName(c[#c]),
		desc = matchDescription(c),
		parameters = matchParameters(c),
		returns = matchReturns(s),
		tags = matchTags(s),
	}
end

----

local docs = {}

local function newClass()

	local class = {
		methods = {},
		statics = {},
	}

	local function init(s, c)
		class.name = matchClassName(s)
		class.parents = matchParents(c)
		class.desc = matchDescription(c)
		class.parameters = matchParameters(c)
		class.tags = matchTags(s)
		class.methodTags = matchMethodTags(s)
		class.properties = matchProperties(s)
		assert(not docs[class.name], 'duplicate class: ' .. class.name)
		docs[class.name] = class
	end

	return class, init

end

for f in coroutine.wrap(scan), './libs' do
	local d = assert(fs.readFileSync(f))

	local class, initClass = newClass()
	local comments = matchComments(d)
	for i = 1, #comments do
		local s = table.concat(comments[i], '\n')
		local t = matchType(comments[i])
		if t == 'ignore' then
			goto continue
		elseif t == 'class' then
			initClass(s, comments[i])
		elseif t == 'param' or t == 'return' then
			local method = matchMethod(s, comments[i])
			for k, v in pairs(class.methodTags) do
				method.tags[k] = v
			end
			method.class = class
			insert(method.tags.static and class.statics or class.methods, method)
		end
		::continue::
	end
end

----

local output = 'docs'

local function link(str)
	if type(str) == 'table' then
		local ret = {}
		for i, v in ipairs(str) do
			ret[i] = link(v)
		end
		return concat(ret, ', ')
	else
		local ret, optional = {}, false
		if str:match('%?$') then
			str = str:gsub('%?$', '')
			optional = true
		end
		for t in str:gmatch('[^|]+') do
			insert(ret, docs[t] and format('[[%s]]', t) or t)
		end
		if optional then
			insert(ret, 'nil')
		end
		return concat(ret, '/')
	end
end

local function sorter(a, b)
	return a.name < b.name
end

local function writeHeading(f, heading)
	f:write('## ', heading, '\n\n')
end

local function writeProperties(f, properties)
	sort(properties, sorter)
	f:write('| Name | Type | Description |\n')
	f:write('|-|-|-|\n')
	for _, v in ipairs(properties) do
		f:write('| ', v.name, ' | ', link(v.type), ' | ', v.desc, ' |\n')
	end
	f:write('\n')
end

local function writeParameters(f, parameters)
	f:write('(')
	local optional
	if #parameters > 0 then
		for i, param in ipairs(parameters) do
			f:write(param[1])
			if i < #parameters then
				f:write(', ')
			end
			optional = param[3]
			param[2] = param[2]:gsub('|', '/')
		end
		f:write(')\n\n')
		if optional then
			f:write('| Parameter | Type | Optional |\n')
			f:write('|-|-|:-:|\n')
			for _, param in ipairs(parameters) do
				local o = param[3] and '✔' or ''
				f:write('| ', param[1], ' | ', link(param[2]), ' | ', o, ' |\n')
			end
			f:write('\n')
		else
			f:write('| Parameter | Type |\n')
			f:write('|-|-|\n')
			for _, param in ipairs(parameters) do
				f:write('| ', param[1], ' | ', link(param[2]), ' |\n')
			end
			f:write('\n')
		end
	else
		f:write(')\n\n')
	end
end

local methodTags = {}

methodTags['http'] = 'This method always makes an HTTP request.'
methodTags['http?'] = 'This method may make an HTTP request.'
methodTags['ws'] = 'This method always makes a WebSocket request.'
methodTags['mem'] = 'This method only operates on data in memory.'

local function checkTags(tbl, check)
	for i, v in ipairs(check) do
		if tbl[v] then
			for j, w in ipairs(check) do
				if i ~= j then
					if tbl[w] then
						return error(string.format('mutually exclusive tags encountered: %s and %s', v, w), 1)
					end
				end
			end
		end
	end
end

local function writeMethods(f, methods)

	sort(methods, sorter)
	for _, method in ipairs(methods) do

		f:write('### ', method.name)
		writeParameters(f, method.parameters)
		f:write(method.desc, '\n\n')

		local tags = method.tags
		checkTags(tags, {'http', 'http?', 'mem'})
		checkTags(tags, {'ws', 'mem'})

		for k in pairs(tags) do
			if k ~= 'static' then
				assert(methodTags[k], k)
				f:write('*', methodTags[k], '*\n\n')
			end
		end

		f:write('**Returns:** ', link(method.returns), '\n\n----\n\n')

	end

end

if not fs.existsSync(output) then
	fs.mkdirSync(output)
end

local function collectParents(parents, k, ret, seen)
	ret = ret or {}
	seen = seen or {}
	for _, parent in ipairs(parents) do
		parent = docs[parent]
		if parent then
			for _, v in ipairs(parent[k]) do
				if not seen[v] then
					seen[v] = true
					insert(ret, v)
				end
			end
		end
		if parent then
			collectParents(parent.parents, k, ret, seen)
		end
	end
	return ret
end

for _, class in pairs(docs) do

	local f = io.open(pathJoin(output, class.name .. '.md'), 'w')

	local parents = class.parents
	local parentLinks = link(parents)

	if next(parents) then
		f:write('#### *extends ', parentLinks, '*\n\n')
	end

	f:write(class.desc, '\n\n')

	checkTags(class.tags, {'interface', 'abstract', 'patch'})
	if class.tags.interface then
		writeHeading(f, 'Constructor')
		f:write('### ', class.name)
		writeParameters(f, class.parameters)
	elseif class.tags.abstract then
		f:write('*This is an abstract base class. Direct instances should never exist.*\n\n')
  elseif class.tags.patch then
    f:write("*This is a patched class.\nFor full usage refer to the Discordia Wiki, only patched methods and properities are documented here.*\n\n")
	else
		f:write('*Instances of this class should not be constructed by users.*\n\n')
	end

	local properties = collectParents(parents, 'properties')
	if next(properties) then
		writeHeading(f, 'Properties Inherited From ' .. parentLinks)
		writeProperties(f, properties)
	end

	if next(class.properties) then
		writeHeading(f, 'Properties')
		writeProperties(f, class.properties)
	end

	local statics = collectParents(parents, 'statics')
	if next(statics) then
		writeHeading(f, 'Static Methods Inherited From ' .. parentLinks)
		writeMethods(f, statics)
	end

	local methods = collectParents(parents, 'methods')
	if next(methods) then
		writeHeading(f, 'Methods Inherited From ' .. parentLinks)
		writeMethods(f, methods)
	end

	if next(class.statics) then
		writeHeading(f, 'Static Methods')
		writeMethods(f, class.statics)
	end

	if next(class.methods) then
		writeHeading(f, 'Methods')
		writeMethods(f, class.methods)
	end

	f:close()

end
