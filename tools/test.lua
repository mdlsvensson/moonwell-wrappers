-- Runs the behavior suites, each in a fresh process: yue -e tools/test.lua [suite ...].
-- Warcraft natives exist only in the game: a suite runs the real modules with stand-ins for the natives, and the
-- support file installs globals for a whole run, so no two suites share a process.
package.path = './tools/?.lua;' .. package.path
local Lib = require('lib')

local yue = Lib.quote(Lib.native(os.getenv('MOONWELL_YUE') or 'yue'))
local version = Lib.must(yue .. ' -v')
if not version:find('0.34.2', 1, true) then error('YueScript 0.34.2 is required, found: ' .. version, 0) end

local suites = {...}
if #suites == 0 then
    for _, file in ipairs(Lib.files('tests', '.lua')) do
        local name = file:match('^tests/([a-z]+)%.lua$')
        if name and name ~= 'support' then suites[#suites + 1] = name end
    end
end

Lib.mkdir('.test-work')
local failures = 0
for _, suite in ipairs(suites) do
    if not suite:match('^[a-z]+$') then error('invalid suite name: ' .. suite, 0) end
    local file = '.test-work/' .. suite .. '.lua'
    Lib.write(file, "package.path = './src/?.lua;./tests/?.lua;' .. package.path\n"
        .. "require('support')\nrequire('" .. suite .. "')\nfinish()\n")
    local code, output = Lib.run(yue .. ' -e ' .. Lib.quote(Lib.native(file)))
    print(suite .. ': ' .. output:gsub('^%s+', ''):gsub('%s+$', ''))
    if code ~= 0 or not output:find('SUITE PASSED', 1, true) then failures = failures + 1 end
end
if failures > 0 then
    print(failures .. ' of ' .. #suites .. ' suites failed')
    os.exit(1)
end
print('All ' .. #suites .. ' suites passed')
