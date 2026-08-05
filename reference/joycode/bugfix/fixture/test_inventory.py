"""库存台账回归测试。

test_ship_reserved_releases_reservation 在修复前必然失败，
用作 BugFix Reference Implementation 的可复现失败锚点（退出码即接地证据）。
"""

from inventory import Inventory


def test_stock_in_increases_on_hand():
    inv = Inventory()
    inv.stock_in(10)
    assert inv.on_hand == 10
    assert inv.available() == 10


def test_reserve_reduces_available():
    inv = Inventory()
    inv.stock_in(10)
    inv.reserve(4)
    assert inv.available() == 6


def test_cannot_reserve_more_than_available():
    inv = Inventory()
    inv.stock_in(5)
    try:
        inv.reserve(6)
    except ValueError:
        return
    raise AssertionError("预留超过可用量本应抛错")


def test_ship_reserved_releases_reservation():
    """出库已预留的货后：实物减少，预留释放，可用量正确。

    这是暴露 bug 的关键用例——修复前 reserved 不会归零，available 会算错。
    """
    inv = Inventory()
    inv.stock_in(10)
    inv.reserve(4)
    inv.stock_out(4)  # 把预留的 4 件发出去
    assert inv.on_hand == 6
    assert inv.reserved == 0
    assert inv.available() == 6
