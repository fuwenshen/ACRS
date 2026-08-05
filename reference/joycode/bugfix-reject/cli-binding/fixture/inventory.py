"""库存预留/释放/发货逻辑（RI-BUGFIX-002 fixture）。

不变量：available == on_hand - reserved（任意时刻都应成立）。

本文件**故意**埋了两个对称 bug（reserve 与 unreserve），且两个 bug 会
**相互掩盖**：初始状态下 available 从不变动，unreserve 的相关断言反而"碰巧通过"；
一旦修好 reserve，unreserve 的 bug 才会被暴露出来。
"""


class Inventory:
    def __init__(self, on_hand):
        self.on_hand = on_hand
        self.reserved = 0
        self.available = on_hand

    def reserve(self, qty):
        """预留库存：应减少 available、增加 reserved。"""
        if qty > self.available:
            raise ValueError("not enough available")
        self.reserved += qty
        self.available -= qty

    def unreserve(self, qty):
        """取消预留：应增加 available、减少 reserved。"""
        if qty > self.reserved:
            raise ValueError("not enough reserved")
        self.reserved -= qty
        self.available += qty

    def ship(self, qty):
        """发货已预留的库存：减少 reserved 与 on_hand。"""
        if qty > self.reserved:
            raise ValueError("not enough reserved to ship")
        self.reserved -= qty
        self.on_hand -= qty
