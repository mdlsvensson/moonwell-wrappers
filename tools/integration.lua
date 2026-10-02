-- Builds a consumer map with the library, runs LuaLS over it and checks what gets bundled:
-- yue -e tools/integration.lua. It uses the real moonwell program, the Pkl schema of a Moonwell checkout, the editor
-- files moonwell generates and the bundler.
package.path = './tools/?.lua;' .. package.path
local Lib = require('lib')

local root = Lib.slash(Lib.cwd())
local function absolute(path)
    if path:match('^%a:[/\\]') or path:sub(1, 1) == '/' then return Lib.slash(path) end
    return root .. '/' .. path
end
-- The moonwell program: on the PATH, or the executable MOONWELL names.
local program = Lib.quote(Lib.native(os.getenv('MOONWELL') or 'moonwell'))
-- The Moonwell checkout whose schema the consumer links to.
local repo = absolute(os.getenv('MOONWELL_REPO') or '../moonwell')
local yueOverride = os.getenv('MOONWELL_YUE')
local yue = Lib.quote(Lib.native(yueOverride or 'yue'))
local luals = os.getenv('MOONWELL_LUALS') or 'lua-language-server'

Lib.mkdir('.test-work')
local work = root .. '/.test-work/integration-' .. os.time()
local consumer = work .. '/consumer'
Lib.mkdir(work)
Lib.write('.test-work/latest-integration.json', '{"work":"' .. work .. '","consumer":"' .. consumer .. '"}')
print('Consumer: ' .. consumer)

local function moonwell(args, cwd)
    local output = Lib.must(program .. ' ' .. args, cwd or consumer)
    print((output:gsub('%s+$', '')))
end

local function compileEditor()
    Lib.must(yue .. ' -l -c --target=5.3 --path ' .. Lib.quote(consumer .. '/.moonwell/yue/?.lua')
        .. ' -o src/main.lua src/main.yue', consumer)
end

local function clean(report, label)
    for file, diagnostics in pairs(report) do
        if #diagnostics > 0 then
            local first = diagnostics[1]
            error(label .. ' diagnostics in ' .. file .. ': ' .. first.code .. ' ' .. first.message, 0)
        end
    end
end

local function bundle() return Lib.read(consumer .. '/dist/stage/map.w3x/war3map.lua') end

-- `init --link` finds the checkout by walking up from its working directory, so it runs there.
moonwell('init --link ' .. Lib.quote(Lib.native(consumer)), repo)
Lib.write(consumer .. '/moonwell.local.pkl', table.concat({
    'amends "moonwell.pkl"',
    'libraries { ["wrappers"] { path = "' .. root .. '"; dir = "src" } }',
    yueOverride and ('yue { path = "' .. absolute(yueOverride) .. '" }') or '',
    '',
}, '\n'))

-- Positive fixtures: a clean check, normal and minified builds, and no editor diagnostics.
Lib.copy('tests/editor-positive.yue', consumer .. '/src/main.yue')
moonwell('check')
moonwell('build')
moonwell('build --minify')
compileEditor()
Lib.copy('tests/editor-positive.lua', consumer .. '/lua/positive.lua')
clean(Lib.diagnose(luals, consumer, 'positive'), 'Positive editor')
print('LuaLS: positive Lua and compiled Yue fixtures clean')

Lib.copy('tests/editor-negative.lua', consumer .. '/lua/negative.lua')
local intended = Lib.expectMarked('tests/editor-negative.lua', Lib.diagnose(luals, consumer, 'negative'),
    'negative.lua', 'Editor negative fixture')
print('LuaLS: ' .. intended .. ' intentional type errors detected at the expected lines')
Lib.remove(consumer .. '/lua/negative.lua')

-- The library's own files against Moonwell's native declarations: native names, argument counts and argument types.
-- The consumer runs above never diagnose library files, and the planted fixture proves this check reports each kind.
local source = work .. '/source'
Lib.copyTree('src/wrappers', source .. '/wrappers')
Lib.mkdir(source .. '/types')
for _, name in ipairs({'natives.d.lua', 'moonwell.d.lua'}) do
    Lib.copy(consumer .. '/.moonwell/types/' .. name, source .. '/types/' .. name)
end
Lib.copy('tests/natives-negative.lua', source .. '/natives-negative.lua')
Lib.write(source .. '/.luarc.json', '{"runtime.version": "Lua 5.3", "runtime.path": ["?.lua", "?/init.lua"], '
    .. '"runtime.builtin": {"io": "disable", "debug": "disable", "package": "disable"}, '
    .. '"workspace.library": ["types"], "workspace.useGitIgnore": false, "workspace.checkThirdParty": false}')
local planted = Lib.expectMarked('tests/natives-negative.lua', Lib.diagnose(luals, source, 'natives'),
    'natives-negative.lua', 'Native-call check')
print("LuaLS: src/wrappers is clean against Moonwell's natives; " .. planted .. ' planted mistakes detected')

-- A Unit-only entry exercises reachability without an umbrella import.
Lib.write(consumer .. '/src/main.yue', 'import "wrappers.unit" as Unit\nimport "wrappers.player" as Player\n'
    .. 'u = Unit.create Player.fromIndex(0), 1751543663, 10, 20, 270\nu\\remove!\n')
moonwell('build')
local unitBundle = bundle()
for _, unused in ipairs({'effect', 'trigger', 'group', 'timer', 'destructable', 'rect', 'region', 'force', 'texttag',
    'sound', 'lightning', 'image', 'ubersplat', 'fogmodifier', 'dialog', 'multiboard', 'leaderboard', 'quest',
    'defeatcondition', 'timerdialog', 'frame', 'damage', 'sync', 'input', 'weathereffect'}) do
    if unitBundle:find('wrappers.' .. unused, 1, true) then error('Unused wrapper bundled: ' .. unused, 0) end
end
-- Run the actual bundled script with the Warcraft globals it uses while its modules load.
local probe = work .. '/bundle-probe.lua'
Lib.write(probe, 'bj_MAX_PLAYER_SLOTS = 28\nlocal p, u = {}, {}\nlocal removed = false\n'
    .. 'function Player(i) assert(i == 0); return p end\n'
    .. 'function CreateUnit(owner, id, x, y, facing)\n'
    .. 'assert(owner == p and id == 1751543663 and x == 10 and y == 20 and facing == 270); return u end\n'
    .. 'function RemoveUnit(value) assert(value == u); removed = true end\n'
    .. unitBundle .. '\nassert(removed, "bundled entry did not remove the unit")\nprint("BUNDLE PASSED")\n')
local ran = Lib.must(yue .. ' -e ' .. Lib.quote(Lib.native(probe)))
if not ran:find('BUNDLE PASSED', 1, true) then error(ran, 0) end
print('Moonwell: normal/minified builds, unused-module exclusion and bundled runtime passed')

-- A map importing just one module bundles only that module and the public modules it returns wrappers of.
local publicModules = {'unit', 'player', 'item', 'destructable', 'rect', 'region', 'force', 'group', 'timer', 'effect',
    'trigger', 'texttag', 'sound', 'lightning', 'image', 'ubersplat', 'fogmodifier', 'dialog', 'multiboard',
    'leaderboard', 'quest', 'defeatcondition', 'timerdialog', 'frame', 'damage', 'sync', 'input', 'weathereffect'}
local soloEntries = {
    {name = 'trigger', source = 'import "wrappers.trigger" as Trigger\nt = Trigger.create!\nt\\destroy!\n',
        allowed = {}},
    {name = 'damage', source = 'import "wrappers.damage" as Damage\n'
        .. 't = Damage.onDamaged (event) -> event\\setAmount 0\nDamage.off t\n',
        allowed = {'unit', 'player', 'item'}},
    {name = 'sync', source = 'import "wrappers.sync" as Sync\n'
        .. 't = Sync.on "load", (player, data) -> print data\nSync.off t\n', allowed = {'player'}},
    {name = 'input', source = 'import "wrappers.input" as Input\nimport "wrappers.player" as Player\n'
        .. 't = Input.onMouseMove Player.fromIndex(0), (player, x, y) -> print x, y\nInput.off t\n',
        allowed = {'player'}},
    {name = 'weathereffect', source = 'import "wrappers.weathereffect" as WeatherEffect\n'
        .. 'w = WeatherEffect.fromHandle AddWeatherEffect GetWorldBounds!, 1380018290\nw\\destroy! if w\n',
        allowed = {}},
    {name = 'texttag', source = 'import "wrappers.texttag" as TextTag\nt = TextTag.create!\nt\\destroy!\n'
        .. 'TextTag.float "+1", 0, 0\n', allowed = {}},
    {name = 'multiboard', source = 'import "wrappers.multiboard" as Multiboard\nb = Multiboard.create 1, 1\n'
        .. 'b\\destroy!\n', allowed = {}},
    {name = 'dialog', source = 'import "wrappers.dialog" as Dialog\nd = Dialog.create!\nd\\destroy!\n',
        allowed = {'player'}},
    {name = 'frame', source = 'import "wrappers.frame" as Frame\nFrame.hideOrigin false\n', allowed = {'player'}},
}
-- "wrappers.timer" is a prefix of "wrappers.timerdialog": match whole module names by the closing quote.
local function bundles(text, name)
    return text:find('wrappers.' .. name .. '"', 1, true) ~= nil or text:find('wrappers.' .. name .. "'", 1, true) ~= nil
end
for _, entry in ipairs(soloEntries) do
    Lib.write(consumer .. '/src/main.yue', entry.source)
    moonwell('build')
    local solo = bundle()
    local allowed = {}
    -- These guard the absence checks below, which would pass if the bundle held no wrapper module at all.
    if not bundles(solo, entry.name) then error(entry.name .. '-only bundle lacks wrappers.' .. entry.name, 0) end
    for _, name in ipairs(entry.allowed) do
        allowed[name] = true
        if not bundles(solo, name) then error(entry.name .. '-only bundle lacks wrappers.' .. name, 0) end
    end
    for _, unused in ipairs(publicModules) do
        if unused ~= entry.name and not allowed[unused] and bundles(solo, unused) then
            error(entry.name .. '-only bundle includes wrappers.' .. unused, 0)
        end
    end
end
print('Moonwell: Trigger-, Damage-, Sync-, Input-, WeatherEffect-, TextTag-, Multiboard-, Dialog- and Frame-only maps '
    .. 'bundle only what they import')

Lib.copy('examples/gate.yue', consumer .. '/src/main.yue')
moonwell('check')
moonwell('build --minify')
compileEditor()
clean(Lib.diagnose(luals, consumer, 'gate'), 'Gate example')
print('Gate example: every module builds and editor diagnostics are clean; game execution remains manual')
print('Integration passed')
