from collections.abc import Callable
from typing import Protocol, TypeVar, runtime_checkable


@runtime_checkable
class SupportsRichComparison(Protocol):
    def __lt__(self, other: object) -> bool: ...
    def __gt__(self, other: object) -> bool: ...


T = TypeVar("T")


def sort_by[T](
    items: list[T],
    key_fn: Callable[[T], SupportsRichComparison],
    reverse: bool = False,
) -> list[T]:
    """Generic stable sort. key_fn must return a comparable value."""
    return sorted(items, key=key_fn, reverse=reverse)  # type: ignore[arg-type]
