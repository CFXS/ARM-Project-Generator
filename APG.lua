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
            if TableContains(cfg.Modules, "tm4c-driverlib", true) then
                table.insert(ret, 'target_include_directories(CFXS_HW PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/vendor/tm4c-driverlib")')
            end
            table.insert(ret, 'target_link_libraries(${EXE_NAME} PUBLIC CFXS_HW)')
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
        module_entry = function(cfg)
            return table.concat({
                'add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/vendor/tm4c-driverlib")',
                'target_link_libraries(${EXE_NAME} PUBLIC TM4C_driverlib)'
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

CFXS_ASSERT(cfg.Toolchain ~= nil, "\"Toolchain\" field not found")
CFXS_ASSERT(type(cfg.Toolchain) == "string", "\"Toolchain\" is not a string")
CFXS_ASSERT(TableContains(TOOLCHAINS, cfg.Toolchain, true), "Unknown toolchain: \""..cfg.Toolchain.."\"")
print("Toolchain: "..cfg.Toolchain)

if cfg.UnityBuild ~= nil then
    CFXS_ASSERT(tonumber(cfg.UnityBuild), "UnityBuild is not a number")
end

if cfg.IncludeDirectories ~= nil then
    CFXS_ASSERT(type(cfg.IncludeDirectories) == "table", "IncludeDirectories is not a table")
    if #cfg.IncludeDirectories == 0 then
        cfg.IncludeDirectories = nil
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
print("Generating folder structure")
MakeDir("Docs")
MakeDir(".vscode")
MakeDir(cfg.ProjectName)
MakeDir(cfg.ProjectName.."/res")
MakeDir(cfg.ProjectName.."/src")
MakeDir(cfg.ProjectName.."/vendor")

-------------------------------------------------------------------------------------
-- Add .clang-format
print("Copy .clang-format");
WriteFile(cfg, ".clang-format", ReadFile("Templates/.clang-format"))

-------------------------------------------------------------------------------------
-- Generate root CMakeLists.txt
print("Generating root CMakeLists.txt file")

local root_CMakeLists = ReadFile("Templates/root_CMakeLists.txt")
                           :gsub("${ProjectName}", cfg.ProjectName)
                           :gsub("${Toolchain}", TOOLCHAINS[cfg.Toolchain])

WriteFile(cfg, "CMakeLists.txt", root_CMakeLists)

print("Done")