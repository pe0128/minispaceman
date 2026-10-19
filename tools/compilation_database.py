"""Write clangd entries from SCons commands, including the MSVC environment."""
import ctypes
import json
import os
from pathlib import Path
import shlex

from SCons.Action import Action


def split_command(command):
    if os.name != "nt":
        return shlex.split(command)
    shell = ctypes.windll.shell32
    shell.CommandLineToArgvW.argtypes = [ctypes.c_wchar_p, ctypes.POINTER(ctypes.c_int)]
    shell.CommandLineToArgvW.restype = ctypes.POINTER(ctypes.c_wchar_p)
    kernel = ctypes.windll.kernel32
    kernel.LocalFree.argtypes = [ctypes.c_void_p]
    count = ctypes.c_int()
    pointer = shell.CommandLineToArgvW(command, ctypes.byref(count))
    if not pointer:
        raise RuntimeError("Cannot parse compiler command")
    try:
        return [pointer[i] for i in range(count.value)]
    finally:
        kernel.LocalFree(pointer)


def write_database(target, source, env):
    path = Path(target[0].get_abspath())
    records = json.loads(path.read_text(encoding="utf-8"))
    environment = env["ENV"]
    includes = environment.get("INCLUDE", "")
    if not isinstance(includes, str):
        includes = os.pathsep.join(includes)
    for record in records:
        arguments = split_command(record.pop("command"))
        compiler = env.WhereIs(arguments[0], path=environment.get("PATH"))
        if not compiler:
            raise RuntimeError("Cannot locate compiler: " + arguments[0])
        arguments[0] = str(Path(compiler).resolve())
        if env.get("is_msvc", False):
            # cl.exe normally obtains these paths from INCLUDE, which clangd
            # does not inherit when started by the editor.
            if not includes:
                raise RuntimeError("MSVC INCLUDE environment is missing")
            for include in includes.split(os.pathsep):
                if include.strip():
                    arguments.append("/I" + str(Path(include.strip()).resolve()))
        directory = Path(record["directory"]).resolve()
        record["directory"] = str(directory)
        record["file"] = str((directory / record["file"]).resolve())
        record["output"] = str((directory / record["output"]).resolve())
        record["arguments"] = arguments
    temporary = path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def configure(env):
    env["COMPILATIONDB_USE_ABSPATH"] = True
    env.AddPostAction(
        env.File(env["compiledb_file"]),
        Action(write_database, "Completing clangd paths $TARGET"),
    )
