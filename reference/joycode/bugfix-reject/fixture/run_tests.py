"""极简测试运行器（不依赖 pytest）。

用法：
  python run_tests.py               运行全部测试
  python run_tests.py <name> [..]   只运行指定名字的测试（scoped repro 用）

退出码：0 = 全通过；1 = 有失败。
"""
import sys
import traceback
import test_inventory as suite


def main(argv):
    all_tests = {name: fn for name, fn in vars(suite).items()
                 if name.startswith("test_") and callable(fn)}
    if argv:
        selected = {n: all_tests[n] for n in argv if n in all_tests}
        missing = [n for n in argv if n not in all_tests]
        for n in missing:
            print(f"UNKNOWN TEST: {n}")
        if missing:
            return 1
    else:
        selected = all_tests

    failures = 0
    for name, fn in sorted(selected.items()):
        try:
            fn()
            print(f"PASS {name}")
        except Exception:
            failures += 1
            print(f"FAIL {name}")
            traceback.print_exc()
    total = len(selected)
    print(f"--- {total - failures}/{total} passed, {failures} failed ---")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
