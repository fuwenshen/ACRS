"""RI-BUGFIX-002 测试。

初始（两 bug 并存）：
  - test_reserve_reduces_available  → 失败（BUG#1，available 没减）
  - test_unreserve_restores_available → 碰巧通过（两 bug 相互掩盖，available 全程不动）
  - test_ship_reduces_on_hand_and_reserved → 通过

只修 reserve（BUG#1）后：
  - test_reserve_reduces_available → 通过
  - test_unreserve_restores_available → 失败（BUG#2 被暴露）
  - test_ship → 通过
"""
from inventory import Inventory


def test_reserve_reduces_available():
    inv = Inventory(10)
    inv.reserve(3)
    assert inv.available == 7, f"reserve 后 available 应为 7，实际 {inv.available}"
    assert inv.reserved == 3, f"reserve 后 reserved 应为 3，实际 {inv.reserved}"


def test_unreserve_restores_available():
    inv = Inventory(10)
    inv.reserve(4)
    inv.unreserve(4)
    assert inv.available == 10, f"unreserve 后 available 应恢复为 10，实际 {inv.available}"
    assert inv.reserved == 0, f"unreserve 后 reserved 应为 0，实际 {inv.reserved}"


def test_ship_reduces_on_hand_and_reserved():
    inv = Inventory(10)
    inv.reserve(5)
    inv.ship(5)
    assert inv.on_hand == 5, f"ship 后 on_hand 应为 5，实际 {inv.on_hand}"
    assert inv.reserved == 0, f"ship 后 reserved 应为 0，实际 {inv.reserved}"
