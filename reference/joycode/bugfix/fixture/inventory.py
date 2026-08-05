"""极简库存台账：入库 / 预留 / 出库 / 可用量。

这是 ACRS BugFix Reference Implementation 的被测对象（fixture）。
它故意埋了一个真实、可复现、根因单一的 bug —— 见 stock_out。
"""


class Inventory:
    def __init__(self) -> None:
        self.on_hand = 0   # 实物在库数量
        self.reserved = 0  # 已被预留、尚未出库的数量

    def stock_in(self, qty: int) -> None:
        """入库：增加实物在库。"""
        if qty <= 0:
            raise ValueError("qty must be positive")
        self.on_hand += qty

    def reserve(self, qty: int) -> None:
        """预留：占用可用库存，供后续出库。"""
        if qty <= 0:
            raise ValueError("qty must be positive")
        if qty > self.available():
            raise ValueError("not enough available to reserve")
        self.reserved += qty

    def available(self) -> int:
        """可用量 = 在库 - 已预留。"""
        return self.on_hand - self.reserved

    def stock_out(self, qty: int) -> None:
        """出库：把已预留的实物真正发走。

        出库只能针对已预留的量（先 reserve 再 stock_out）。
        发货后既要减少实物在库，也应释放对应的预留。
        """
        if qty <= 0:
            raise ValueError("qty must be positive")
        if qty > self.reserved:
            raise ValueError("cannot ship more than reserved")
        self.on_hand -= qty
        # 发货后同步释放对应预留，避免 reserved 只增不减、available() 算错。
        self.reserved -= qty
