from .methods import EqualSplit, ExactSplit, PercentSplit, SharesSplit
from .types import SplitMethod


class UnknownSplitMethod(KeyError):
    pass


class SplitRegistry:
    """Split methods keyed by `key`, in registration order (the order the selector shows)."""

    def __init__(self) -> None:
        self._methods: dict[str, SplitMethod] = {}

    def register(self, method: SplitMethod) -> None:
        if method.key in self._methods:
            raise ValueError(f"Split method already registered: {method.key}")
        self._methods[method.key] = method

    def get(self, key: str) -> SplitMethod:
        try:
            return self._methods[key]
        except KeyError:
            raise UnknownSplitMethod(key) from None

    def all(self) -> list[SplitMethod]:
        return list(self._methods.values())

    def keys(self) -> list[str]:
        return list(self._methods)


registry = SplitRegistry()
for _method in (EqualSplit(), ExactSplit(), PercentSplit(), SharesSplit()):
    registry.register(_method)
