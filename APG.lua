-- CFXS / Rihards Veips 2021 --

local args = {...}
local ProjectDir = args[1]
local ScriptDir = arg[0]

while ScriptDir:len() > 0 do
    ScriptDir = ScriptDir:sub(1, ScriptDir:len() - 1)
    if ScriptDir:sub(ScriptDir:len(), ScriptDir:len()) == "/" or ScriptDir:sub(ScriptDir:len(), ScriptDir:len()) == "\\" then
        ScriptDir = ScriptDir:sub(1, ScriptDir:len() - 1)
        break
    end
end

print("[CFXS ARM Project Generator v1.0]", ScriptDir);

function CFXS_ASSERT(cond, msg)
    if not cond then
        print(msg)
        os.exit(-1)
    end
end 

function Exists(path)
    if type(path)~="string" then return false end
    return os.rename(path, path) and true or false
end

function TableContains(t, val, byKey)
    for k, v in pairs(t) do
        if (byKey == true and k or v) == val then
            return true
        end
    end
    return false
end

function Exec(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
end

function WriteFile(cfg, path, content)
    local file = io.open(ProjectDir.."/"..path, "w+")
    file:write(content)
    file:close()
end

function ReadFile(path)
    local file = io.open(ScriptDir.."/"..path, "r")
    local res = file:read("a")
    file:close()
    return res
end

function MakeDir(path)
    os.execute(("mkdir "..ProjectDir.."/"..path):gsub("/", (os.getenv('OS'):match("Windows") and "\\" or "/")))
end

------------------------------------------------------------------------------------------------

CFXS_ASSERT(#args > 0, "Project path not specified")
CFXS_ASSERT(Exists(args[1].."/.git"), "Project folder is not a git repository")
CFXS_ASSERT(Exists(args[1].."/APG.cfg.lua"), "Project folder does not contain APG.cfg.lua")
if #args == 1 or args[2] ~= "-d" then
    CFXS_ASSERT(Exec("git -C "..args[1].." status"):match("nothing to commit, working tree clean"), "Commit and push all changes before running the generator:\n"..Exec("git -C "..args[1].." status"))
end

------------------------------------------------------------------------------------------------

-- available submodules
local MODULES = {
    ["CMake"]          = { -- CMake
        git = "https://github.com/CFXS/CFXS-CMake-Bare-Metal-Toolchain.git",
        defaultBranch = "master",
        path = "CMake"
    },
    ["LicenseGen"]      = { -- LicenseGen
        git = "https://github.com/CFXS/CFXS-License-Header-Generator.git",
        defaultBranch = "master",
        path = "${ProjectName}/vendor/LicenseGen"
    },
    ["SeggerRTT"]      = { -- SeggerRTT
        git = "https://github.com/CFXS/SeggerRTT-printf.git",
        defaultBranch = "master",
        path = "${ProjectName}/vendor/SeggerRTT-printf",
        get_module_entry = function(cfg)
            return table.concat({
                'add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/vendor/SeggerRTT-printf")',
                'target_link_libraries(${EXE_NAME} PUBLIC printf_impl_SeggerRTT)'
            }, '\n')
        end
    },
    ["CFXS-Base"]      = { -- CFXS-Base
        git = "https://github.com/CFXS/CFXS-Base.git",
        defaultBranch = "master",
        path = "${ProjectName}/vendor/CFXS-Base",
        get_module_entry = function(cfg)
            return table.concat({
                'add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/vendor/CFXS-Base")',
                'target_link_libraries(${EXE_NAME} PUBLIC CFXS_Base)'
            }, '\n')
        end
    },
    ["CFXS-HW"]        = { -- CFXS-HW
        git = "https://github.com/CFXS/CFXS-HW.git",
        defaultBranch = "master",
        path = "${ProjectName}/vendor/CFXS-HW",
        get_module_entry = function(cfg)
            local ret = {
                'add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/vendor/CFXS-HW")',
                'target_include_directories(CFXS_HW PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/vendor/CFXS-Base/include")'
            }
            if TableContains(cfg.Modules, "tm4c-driverlib") then
                table.insert(ret, 'target_include_directories(CFXS_HW PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/vendor/tm4c-driverlib")')
            end
            table.insert(ret, 'target_link_libraries(${EXE_NAME} PUBLIC CFXS_HW)')

            return table.concat(ret, "\n")
        end
    },
    ["CFXS-DSP"]       = { -- CFXS-DSP
        git = "https://github.com/CFXS/CFXS-DSP.git",
        defaultBranch = "master",
        path = "${ProjectName}/vendor/CFXS-DSP",
        get_module_entry = function(cfg)
            CFXS_ASSERT(TableContains(cfg.Modules, "CFXS-Base", true), "CFXS-DSP missing CFXS-Base dependency")
            return table.concat({
                'add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/vendor/CFXS-DSP")',
                'target_include_directories(CFXS_DSP PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/vendor/CFXS-Base/include")',
                'target_link_libraries(${EXE_NAME} PUBLIC CFXS_DSP)'
            }, '\n')
        end
    },
    ["tm4c-driverlib"] = { -- tm4c-driverlib
        git = "https://github.com/CFXS/tm4c-driverlib.git",
        defaultBranch = "master",
        path = "${ProjectName}/vendor/tm4c-driverlib",
        get_module_entry = function(cfg)
            return table.concat({
                'add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/vendor/tm4c-driverlib")',
                'target_link_libraries(${EXE_NAME} PUBLIC tm4c_driverlib)'
            }, '\n')
        end
    },
}

local TOOLCHAINS = {
    ["GCC"] = "CMake/Toolchain/GCC_ARM.cmake",
}

local CPUS = {
    ["TM4C1294NCPDT"] = {
        defs = {
            "PART_TM4C1294NCPDT",
            "TARGET_IS_TM4C129_RA2",
            "CFXS_PLATFORM_TM4C"
        },
        toolchain_target = "CortexM4F"
    }
}

function InsertVariables(cfg, str)
    return str:gsub("${ProjectName}", cfg.ProjectName)
                :gsub("${ProjectNameRaw}", cfg.ProjectNameRaw)
                :gsub("${Toolchain}", TOOLCHAINS[cfg.Toolchain])
                :gsub("${ToolchainTarget}", CPUS[cfg.CPU].toolchain_target)
                :gsub("${Year}", os.date("%Y"))
end

local cfg = loadfile(args[1].."/APG.cfg.lua")();

if cfg.Modules == nil then
    cfg.Modules = {"CMake"}
else
    CFXS_ASSERT(type(cfg.Modules) == "table", "Modules is not a table")
end

if not TableContains(cfg.Modules, "CMake") then
    table.insert(cfg.Modules, "CMake")
end

CFXS_ASSERT(cfg.ProjectName ~= nil, "\"ProjectName\" field not found")
CFXS_ASSERT(type(cfg.ProjectName) == "string", "\"ProjectName\" is not a string")
cfg.ProjectNameRaw = cfg.ProjectName
cfg.ProjectName = cfg.ProjectName:gsub("%s", "_"):gsub("/", "_"):gsub("\\", "_"):gsub("%$", "_"):gsub("%%", "_"):gsub("&", "_"):gsub("%^", "_"):gsub("\"", "_"):gsub("'", "_"):gsub("!", "_")

CFXS_ASSERT(cfg.Toolchain ~= nil, "\"Toolchain\" field not found")
CFXS_ASSERT(type(cfg.Toolchain) == "string", "\"Toolchain\" is not a string")
CFXS_ASSERT(TableContains(TOOLCHAINS, cfg.Toolchain, true), "Unknown toolchain: \""..cfg.Toolchain.."\"")
print("Toolchain: "..cfg.Toolchain)

if cfg.UnityBuildBatchSize ~= nil then
    CFXS_ASSERT(tonumber(cfg.UnityBuildBatchSize), "UnityBuildBatchSize is not a number")
end

if cfg.LicenseHeader ~= nil then
    CFXS_ASSERT(type(cfg.LicenseHeader) == "string", "LicenseHeader is not a string")
end

if cfg.IncludeDirectories ~= nil then
    CFXS_ASSERT(type(cfg.IncludeDirectories) == "table", "IncludeDirectories is not a table")
    if #cfg.IncludeDirectories == 0 then
        cfg.IncludeDirectories = nil
    end
end


if cfg.Defines ~= nil then
    CFXS_ASSERT(type(cfg.Defines) == "table", "Defines is not a table")
    if #cfg.Defines == 0 then
        cfg.Defines = nil
    end
end

CFXS_ASSERT(cfg.CPU ~= nil, "\"CPU\" field not found")
CFXS_ASSERT(type(cfg.CPU) == "string", "\"CPU\" is not a string")
CFXS_ASSERT(TableContains(CPUS, cfg.CPU, true), "Unknown CPU: \""..cfg.CPU.."\"")
print("CPU: "..cfg.CPU)

CFXS_ASSERT(cfg.CLOCK_FREQUENCY ~= nil, "\"CLOCK_FREQUENCY\" field not found")
CFXS_ASSERT(tonumber(cfg.CLOCK_FREQUENCY) ~= nil, "\"CLOCK_FREQUENCY\" is not a number")
cfg.CLOCK_FREQUENCY = math.floor(tonumber(cfg.CLOCK_FREQUENCY))
print("Clock Frequency: "..string.format("%.0fMHz", cfg.CLOCK_FREQUENCY / 1e6))

if #cfg.Modules then
    print("Modules:")
    for i, v in pairs(cfg.Modules) do
        local moduleName = v:match(":") and v:match(":(.+)") or v
        CFXS_ASSERT(TableContains(MODULES, moduleName, true), "Unknown module: \""..v.."\"")
        local branchName = v:match(":") and v:match("(.+):") or MODULES[moduleName].defaultBranch

        print(" - "..moduleName.." @ "..branchName)
    end
end

if cfg.IncludeDirectories then
    print("Include directories:")
    for i, v in pairs(cfg.IncludeDirectories) do
        print(" - \""..cfg.ProjectName..v.."\"")
    end
end

-------------------------------------------------------------------------------------
-- Generate folder structure
print("Generate folder structure")
MakeDir("Docs")
MakeDir(".vscode")
MakeDir(cfg.ProjectName)
MakeDir(cfg.ProjectName.."/res")
MakeDir(cfg.ProjectName.."/src")
MakeDir(cfg.ProjectName.."/vendor")

-------------------------------------------------------------------------------------
-- Copy .clang-format
print("Copy .clang-format");
WriteFile(cfg, ".clang-format", ReadFile("Templates/.clang-format"))

-------------------------------------------------------------------------------------
-- Generate .gitignore
print("Generate .gitignore");
WriteFile(cfg, ".gitignore", "/build")

-------------------------------------------------------------------------------------
-- Generate _License.lhg
if cfg.LicenseHeader then
    print("Generate _License.lhg");
    WriteFile(cfg, cfg.ProjectName.."/_License.lhg", InsertVariables(cfg, cfg.LicenseHeader))
end

-------------------------------------------------------------------------------------
-- Copy LinkerScript.ld
print("Copy LinkerScript.ld");
WriteFile(cfg, cfg.ProjectName.."/LinkerScript.ld", ReadFile("Templates/LinkerScripts/"..cfg.CPU.."/LinkerScript.ld"))

-------------------------------------------------------------------------------------
-- Generate root CMakeLists.txt
print("Generate root CMakeLists.txt file")
local root_CMakeLists = InsertVariables(cfg, ReadFile("Templates/root_CMakeLists.txt"))
WriteFile(cfg, "CMakeLists.txt", root_CMakeLists)

-------------------------------------------------------------------------------------
-- Copy _Sources.cmake
print("Copy _Sources.cmake");
WriteFile(cfg, cfg.ProjectName.."/_Sources.cmake", ReadFile("Templates/_Sources.cmake"))

-------------------------------------------------------------------------------------
-- Generate _Modules.cmake
print("Generate _Modules.cmake");

local moduleInit = {}

for i, v in pairs(cfg.Modules) do
    local mod = MODULES[v]
    
    if mod.get_module_entry then
        table.insert(moduleInit, "# "..v.."\n"..mod.get_module_entry(cfg))
    end
end

WriteFile(cfg, cfg.ProjectName.."/_Modules.cmake", table.concat(moduleInit, "\n\n"))

-------------------------------------------------------------------------------------
-- Generate _IncludeDirectories.cmake
print("Generate _IncludeDirectories.cmake");
local includeDirs = {}

for i, v in pairs(cfg.IncludeDirectories) do
    table.insert(includeDirs, 'target_include_directories(${EXE_NAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}'..v..')')
end

WriteFile(cfg, cfg.ProjectName.."/_IncludeDirectories.cmake", table.concat(includeDirs, "\n"))

-------------------------------------------------------------------------------------
-- Generate _Defines.cmake
print("Generate _Defines.cmake");

local defines = {}

table.insert(defines, "# Target")
for i, v in pairs(CPUS[cfg.CPU].defs) do
    table.insert(defines, 'add_compile_definitions("'..v..'")')
end
table.insert(defines, 'add_compile_definitions("CFXS_CPU_CLOCK_FREQUENCY='..cfg.CLOCK_FREQUENCY..'")')

if cfg.Defines then
    table.insert(defines, "\n# Project")
    
    local debugDefined = {}
    local releaseDefined = {}
    local minsizerelDefined = {}
    local relwithdebinfoDefined = {}
    local not_debugDefined = {}
    local not_releaseDefined = {}
    local not_minsizerelDefined = {}
    local not_relwithdebinfoDefined = {}
    
    for i, v in pairs(cfg.Defines) do
        if v:match(":") then
            local group = v:match("(.+):")
            local def = v:match(":(.+)")
            local cleanGroup = group:gsub("!", "")

            CFXS_ASSERT(cleanGroup == "debug" or cleanGroup == "release" or cleanGroup == "relwithdebinfo" or cleanGroup == "minsizerel", "Unknown define group: \""..cleanGroup.."\"")

            if cleanGroup == "debug" then
                table.insert(group:match("!") and not_debugDefined or debugDefined, 'add_compile_definitions("'..def..'")')
            elseif cleanGroup == "release" then
                table.insert(group:match("!") and not_releaseDefined or releaseDefined, 'add_compile_definitions("'..def..'")')
            elseif cleanGroup == "minsizerel" then
                table.insert(group:match("!") and not_minsizerelDefined or minsizerelDefined, 'add_compile_definitions("'..def..'")')
            elseif cleanGroup == "relwithdebinfo" then
                table.insert(group:match("!") and not_relwithdebinfoDefined or relwithdebinfoDefined, 'add_compile_definitions("'..def..'")')
            end
        else
            table.insert(defines, 'add_compile_definitions("'..v..'")')
        end
    end

    if #debugDefined > 0 then
        table.insert(defines, '\nif("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")')
        for i, v in pairs(debugDefined) do
            table.insert(defines, "    "..v)
        end
        if #not_debugDefined > 0 then
            table.insert(defines, 'else()')
            for i, v in pairs(not_debugDefined) do
                table.insert(defines, "    "..v)
            end
        end
        table.insert(defines, 'endif()')
    end

    if #releaseDefined > 0 then
        table.insert(defines, '\nif("${CMAKE_BUILD_TYPE}" STREQUAL "Release")')
        for i, v in pairs(releaseDefined) do
            table.insert(defines, "    "..v)
        end
        if #not_releaseDefined > 0 then
            table.insert(defines, 'else()')
            for i, v in pairs(not_releaseDefined) do
                table.insert(defines, "    "..v)
            end
        end
        table.insert(defines, 'endif()')
    end

    if #minsizerelDefined > 0 then
        table.insert(defines, '\nif("${CMAKE_BUILD_TYPE}" STREQUAL "MinSizeRel")')
        for i, v in pairs(minsizerelDefined) do
            table.insert(defines, "    "..v)
        end
        if #not_minsizerelDefined > 0 then
            table.insert(defines, 'else()')
            for i, v in pairs(not_minsizerelDefined) do
                table.insert(defines, "    "..v)
            end
        end
        table.insert(defines, 'endif()')
    end

    if #relwithdebinfoDefined > 0 then
        table.insert(defines, '\nif("${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo")')
        for i, v in pairs(relwithdebinfoDefined) do
            table.insert(defines, "    "..v)
        end
        if #not_relwithdebinfoDefined > 0 then
            table.insert(defines, 'else()')
            for i, v in pairs(not_relwithdebinfoDefined) do
                table.insert(defines, "    "..v)
            end
        end
        table.insert(defines, 'endif()')
    end
end

WriteFile(cfg, cfg.ProjectName.."/_Defines.cmake", table.concat(defines, "\n"))

-------------------------------------------------------------------------------------
-- Generate project CMakeLists.txt
print("Generate project CMakeLists.txt file")
local project_CMakeLists = InsertVariables(cfg, ReadFile("Templates/project_CMakeLists.txt"))

if cfg.UnityBuildBatchSize then
    project_CMakeLists = project_CMakeLists:gsub("${UNITY_BUILD_CONFIG}", "\nset(CMAKE_UNITY_BUILD true)\nset(CMAKE_UNITY_BUILD_BATCH_SIZE "..cfg.UnityBuildBatchSize..")\n")
else
    project_CMakeLists = project_CMakeLists:gsub("${UNITY_BUILD_CONFIG}", "")
end

WriteFile(cfg, cfg.ProjectName.."/CMakeLists.txt", project_CMakeLists)

-------------------------------------------------------------------------------------
-- Add submodules
print("Add submodules")

for i, v in pairs(cfg.Modules) do
    local moduleName = v:match(":") and v:match(":(.+)") or v
    local branchName = v:match(":") and v:match("(.+):") or MODULES[moduleName].defaultBranch
    local link = MODULES[v].git
    local path = MODULES[v].path

    Exec(table.concat({
        'cd '..ProjectDir,
        'git submodule add -b '..branchName..' -- '..link..' '..InsertVariables(cfg, path)
    }, " && "));
end

-- git submodule add -b master --name master -- https://github.com/nlohmann/json.git libs/json

print("Done")