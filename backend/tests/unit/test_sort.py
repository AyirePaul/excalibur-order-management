from dataclasses import dataclass
from datetime import date

import pytest

from app.services.sort import sort_by


@dataclass
class Item:
    name: str
    value: float


def test_sort_ascending():
    items = [Item("b", 2.0), Item("a", 1.0), Item("c", 3.0)]
    result = sort_by(items, key_fn=lambda x: x.value)
    assert [i.name for i in result] == ["a", "b", "c"]


def test_sort_descending():
    items = [Item("b", 2.0), Item("a", 1.0), Item("c", 3.0)]
    result = sort_by(items, key_fn=lambda x: x.value, reverse=True)
    assert [i.name for i in result] == ["c", "b", "a"]


def test_sort_by_date():
    @dataclass
    class Dated:
        d: date

    items = [Dated(date(2025, 3, 1)), Dated(date(2025, 1, 1)), Dated(date(2025, 2, 1))]
    result = sort_by(items, key_fn=lambda x: x.d)
    assert result[0].d == date(2025, 1, 1)
    assert result[-1].d == date(2025, 3, 1)


def test_sort_empty():
    assert sort_by([], key_fn=lambda x: x) == []


def test_sort_single_element():
    result = sort_by([Item("only", 1.0)], key_fn=lambda x: x.value)
    assert len(result) == 1


def test_sort_stable():
    items = [Item("a", 1.0), Item("b", 1.0), Item("c", 1.0)]
    result = sort_by(items, key_fn=lambda x: x.value)
    assert [i.name for i in result] == ["a", "b", "c"]


def test_sort_does_not_mutate():
    original = [Item("b", 2.0), Item("a", 1.0)]
    original_copy = list(original)
    sort_by(original, key_fn=lambda x: x.value)
    assert original == original_copy


def test_sort_strings():
    words = ["banana", "apple", "cherry"]
    result = sort_by(words, key_fn=lambda x: x)
    assert result == ["apple", "banana", "cherry"]


@pytest.mark.parametrize("n", [10, 100, 1000])
def test_sort_large_lists(n):
    import random

    items = [Item(str(i), random.random()) for i in range(n)]  # noqa: S311
    result = sort_by(items, key_fn=lambda x: x.value)
    for i in range(len(result) - 1):
        assert result[i].value <= result[i + 1].value
