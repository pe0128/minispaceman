"""Exercise Win32 mouse/key routing against our own Godot windows only."""
import ctypes
import argparse
from ctypes import wintypes
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
user32 = ctypes.windll.user32
user32.FindWindowW.restype = wintypes.HWND
user32.FindWindowW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR]
user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.IsWindowVisible.argtypes = [wintypes.HWND]
user32.IsWindow.argtypes = [wintypes.HWND]


def find_own_window(title, pid, timeout=8):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        handle = user32.FindWindowW(None, title)
        owner = wintypes.DWORD()
        if handle:
            user32.GetWindowThreadProcessId(handle, ctypes.byref(owner))
            if owner.value == pid:
                return handle
        time.sleep(0.05)
    raise AssertionError(f"Missing own window: {title}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--executable", type=Path)
    args = parser.parse_args()
    (ROOT / "artifacts").mkdir(exist_ok=True)
    executable = args.executable.resolve() if args.executable else Path("D:/godot/Godot_v4.7.2-stable_win64.exe")
    command = [str(executable)]
    if args.executable is None:
        command.extend(["--path", str(ROOT)])
    command.extend(["--log-file", str(ROOT / "artifacts/ui-runtime.log"), "--quit-after", "900", "--", "--ui-test"])
    with (ROOT / "artifacts/ui-smoke.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=executable.parent, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            pet = find_own_window("minispaceman", process.pid)
            point = (105 << 16) | 96
            user32.PostMessageW(pet, 0x0203, 1, point)
            user32.PostMessageW(pet, 0x0202, 0, point)
            world = find_own_window("桌宠世界 · Esc 返回", process.pid)
            time.sleep(1)
            user32.PostMessageW(world, 0x0100, 0x1B, 0x00010001)
            user32.PostMessageW(world, 0x0101, 0x1B, 0xC0010001)
            time.sleep(0.5)
            # Godot destroys a native child HWND when hidden and creates a new
            # one on show; reacquire the restored pet instead of its stale HWND.
            pet = find_own_window("minispaceman", process.pid)
            assert user32.IsWindowVisible(pet), "Escape did not restore pet"
            assert not user32.FindWindowW(None, "桌宠世界 · Esc 返回"), "World window was not freed"
            user32.PostMessageW(pet, 0x0010, 0, 0)
            assert process.wait(timeout=5) == 0
            print("UI_SMOKE double-click / Escape / close passed")
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)


if __name__ == "__main__":
    main()
