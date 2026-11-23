# Hueometry: the specification's vocabulary.
#
# This file is part of the owner's specification, with LAWS.bend. Change it
# only when the owner asks, with a `Laws-Change:` commit trailer. It says what
# the words in the laws mean, as plainly as possible, and imports nothing but
# Base. Where a law reads a game through an engine accessor, another law pins
# that accessor to the field it names (LAWS.bend, "Reading a game").
#
# The rules quoted here are from the brief, docs/brief.md, section 3.
#
# A board is a list of columns, numbered from 0. A column lists its beads
# from the TOP down. A bead is its colour's number, from 0.

import Base

# Truth as a type: Unit when b holds, Empty when it fails.
def Holds(b: Bool) -> Data:
  match b:
    case True{}:
      Unit
    case False{}:
      Empty

# Sizes
# -----

# how many beads a column holds
def size(col: List<&2, Nat>) -> Nat:
  match col:
    case Nil{}:
      0n
    case h <> t:
      1n+size(t)

# how many columns a board has
def width(b: List<&2, List<&2, Nat>>) -> Nat:
  match b:
    case Nil{}:
      0n
    case c <> r:
      1n+width(r)

# column k, or an empty column when there is no column k
def column(b: List<&2, List<&2, Nat>>, k: Nat) -> List<&2, Nat>:
  match b k:
    case Nil{} _:
      Nil{}
    case c <> r 0n:
      c
    case c <> r 1n+p:
      column(r, p)

def is_empty(col: List<&2, Nat>) -> Bool:
  match col:
    case Nil{}:
      True{}
    case h <> t:
      False{}

# the top bead of a column (0 for an empty column, which no legal move lifts)
def top(col: List<&2, Nat>) -> Nat:
  match col:
    case Nil{}:
      0n
    case h <> t:
      h

# the column without its top bead
def rest(col: List<&2, Nat>) -> List<&2, Nat>:
  match col:
    case Nil{}:
      Nil{}
    case h <> t:
      t

# dst with src's top bead put on it (dst unchanged when src is empty)
def moved(src: List<&2, Nat>, dst: List<&2, Nat>) -> List<&2, Nat>:
  match src:
    case Nil{}:
      dst
    case h <> t:
      h <> dst

# Moves
# -----

# Rules 1, 2, 5, 6 and 7 of the brief (docs/brief.md, section 3.2): a move takes the top bead of column i and puts it
# on column j. Both columns exist, they differ, and column i has a bead.
# Neither the colours nor where the columns sit on screen matter.
def movable(+b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat) -> Bool:
  Nat.is_lt(i, width(b)) && Nat.is_lt(j, width(b)) && Bool.not(Nat.is_eq(i, j)) && Bool.not(is_empty(column(b, i)))

# Rule 4 added (section 3.2): column j has room for one more bead. Rule 3: a bead may land
# on any colour, so colour is not checked.
def legal(+cap: Nat, +b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat) -> Bool:
  movable(b, i, j) && Nat.is_lt(size(column(b, j)), cap)

# 1 when b holds, else 0: a legal move adds one to the move count
def bit(b: Bool) -> Nat:
  match b:
    case True{}:
      1n
    case False{}:
      0n

# does the list of column numbers include n?
def has(xs: List<&2, Nat>, +n: Nat) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case x <> r:
      Nat.is_eq(n, x) || has(r, n)

# Counting beads
# --------------

# n plus one when b holds
def bump(b: Bool, n: Nat) -> Nat:
  match b:
    case True{}:
      1n+n
    case False{}:
      n

# how many beads of colour c a column holds
def count_col(+c: Nat, col: List<&2, Nat>) -> Nat:
  match col:
    case Nil{}:
      0n
    case h <> t:
      bump(Nat.is_eq(c, h), count_col(c, t))

# how many beads of colour c a board holds
def count(+c: Nat, b: List<&2, List<&2, Nat>>) -> Nat:
  match b:
    case Nil{}:
      0n
    case col <> r:
      Nat.add(count_col(c, col), count(c, r))

# how many beads a board holds, of any colour
def total(b: List<&2, List<&2, Nat>>) -> Nat:
  match b:
    case Nil{}:
      0n
    case col <> r:
      Nat.add(size(col), total(r))

# Capacity
# --------

# every column holds at most cap beads
def fits(+cap: Nat, b: List<&2, List<&2, Nat>>) -> Bool:
  match b:
    case Nil{}:
      True{}
    case col <> r:
      Nat.is_le(size(col), cap) && fits(cap, r)

# Valid boards
# ------------

# every colour below k has exactly cap beads on the board
def counts_ok(+k: Nat, +cap: Nat, +b: List<&2, List<&2, Nat>>) -> Bool:
  match k:
    case 0n:
      True{}
    case 1n+p:
      Nat.is_eq(count(p, b), cap) && counts_ok(p, cap, b)

# A valid puzzle (section 3.1): at least one colour, columns of capacity at
# least 1, one more column than colours, no column over capacity, and exactly
# cap beads of each colour 0..colours-1 and no others (the total is
# colours * cap, so no bead has any other colour).
def valid(+colours: Nat, +cap: Nat, +b: List<&2, List<&2, Nat>>) -> Bool:
  Nat.is_lt(0n, colours) && Nat.is_lt(0n, cap) && Nat.is_eq(width(b), 1n+colours) && fits(cap, b) && counts_ok(colours, cap, b) && Nat.is_eq(total(b), Nat.mul(colours, cap))

# Victory (section 3.3)
# ---------------------

# every bead of the column has colour c
def all_colour(+c: Nat, col: List<&2, Nat>) -> Bool:
  match col:
    case Nil{}:
      True{}
    case h <> t:
      Nat.is_eq(c, h) && all_colour(c, t)

# the column holds only one colour (an empty column counts)
def uniform(col: List<&2, Nat>) -> Bool:
  match col:
    case Nil{}:
      True{}
    case h <> t:
      all_colour(h, t)

# how many columns hold at least one bead of colour c
def columns_with(+c: Nat, b: List<&2, List<&2, Nat>>) -> Nat:
  match b:
    case Nil{}:
      0n
    case col <> r:
      bump(Nat.is_lt(0n, count_col(c, col)), columns_with(c, r))

# how many columns are empty
def empties(b: List<&2, List<&2, Nat>>) -> Nat:
  match b:
    case Nil{}:
      0n
    case col <> r:
      bump(is_empty(col), empties(r))

# condition 1: every colour below k occupies exactly one column
def one_column_each(+k: Nat, +b: List<&2, List<&2, Nat>>) -> Bool:
  match k:
    case 0n:
      True{}
    case 1n+p:
      Nat.is_eq(columns_with(p, b), 1n) && one_column_each(p, b)

# conditions 2 and 3: every occupied column is one colour and full
def occupied_full_uniform(+cap: Nat, b: List<&2, List<&2, Nat>>) -> Bool:
  match b:
    case Nil{}:
      True{}
    case +col <> r:
      (is_empty(col) || (uniform(col) && Nat.is_eq(size(col), cap))) && occupied_full_uniform(cap, r)

# Solved: the four victory conditions, as section 3.3 states them.
def solved(+colours: Nat, +cap: Nat, +b: List<&2, List<&2, Nat>>) -> Bool:
  one_column_each(colours, b) && occupied_full_uniform(cap, b) && Nat.is_eq(empties(b), 1n)
