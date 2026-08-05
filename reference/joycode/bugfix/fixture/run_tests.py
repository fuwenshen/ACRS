"""零依赖测试运行器（stdlib only）。

Reference Implementation 要求可在任何只有 python3 的环境复现，
故不依赖 pytest。发现并运行 test_inventory 中所有 test_* 函数，
全部通过 exit 0，任一失败 exit 1 —— 退出码即 ACRS 的接地证据（P-4）。
"""

import sys
import traceback

import test_inventory


def main() -> int:
    tests = [
        (name, getattr(test_inventory, name))
        for name in dir(test_inventory)
        if name.startswith("test_") and callable(getattr(test_inventory, name))
    ]
    failed = 0
    for name, fn in sorted(tests):
        try:
            fn()
            print(f"PASS {name}")
        except Exception:  # noqa: BLE001 - 测试运行器需捕获一切失败
            failed += 1
            print(f"FAIL {name}")
            traceback.print_exc()
    print(f"\n{len(tests) - failed}/{len(tests)} passed, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
