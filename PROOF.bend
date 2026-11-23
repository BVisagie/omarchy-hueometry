# Hueometry: the proofs of LAWS.bend.

import Base
import ./SPEC.bend as Spec
import ./engine/core.bend as Core
import ./LAWS.bend as Laws

# Kit
# ---
# Every split is a def whose match consumes a parameter: Bend cannot match a
# computed value, so a fact about one is passed in as a parameter first.

def and_l(+a: Bool, -b: Bool, w: Spec.Holds(a && b)) -> Spec.Holds(a):
  match a:
    case True{}:
      Unit{}
    case False{}:
      w

def and_r(+a: Bool, -b: Bool, w: Spec.Holds(a && b)) -> Spec.Holds(b):
  match a:
    case True{}:
      w
    case False{}:
      Empty.absurd(Spec.Holds(b), w)

def ne_sym(a: Nat, b: Nat, w: Spec.Holds(Bool.not(Nat.is_eq(a, b)))) -> Spec.Holds(Bool.not(Nat.is_eq(b, a))):
  match a b:
    case 0n 0n:
      w
    case 0n 1n+q:
      Unit{}
    case 1n+p 0n:
      Unit{}
    case 1n+p 1n+q:
      ne_sym(p, q, w)

# Columns of a replaced board
# ---------------------------

def get_set_same(b: List<&2, List<&2, Nat>>, k: Nat, -v: List<&2, Nat>, w: Spec.Holds(Nat.is_lt(k, Spec.width(b))))
  -> {Spec.column(Core.set_col(b, k, v), k) == v : List<&2, Nat>}:
  match b k:
    case Nil{} 0n:
      match w:
    case Nil{} 1n+p:
      match w:
    case c <> r 0n:
      {==}
    case c <> r 1n+p:
      get_set_same(r, p, v, w)

def get_set_other(b: List<&2, List<&2, Nat>>, k: Nat, m: Nat, -v: List<&2, Nat>, w: Spec.Holds(Bool.not(Nat.is_eq(m, k))))
  -> {Spec.column(Core.set_col(b, k, v), m) == Spec.column(b, m) : List<&2, Nat>}:
  match b k m:
    case Nil{} _ _:
      {==}
    case c <> r 0n 0n:
      match w:
    case c <> r 0n 1n+q:
      {==}
    case c <> r 1n+p 0n:
      {==}
    case c <> r 1n+p 1n+q:
      get_set_other(r, p, q, v, w)

def width_set(b: List<&2, List<&2, Nat>>, k: Nat, -v: List<&2, Nat>)
  -> {Spec.width(Core.set_col(b, k, v)) == Spec.width(b) : Nat}:
  match b k:
    case Nil{} _:
      {==}
    case c <> r 0n:
      {==}
    case c <> r 1n+p:
      %width_set(r, p, v) : {1n+Spec.width(Core.set_col(r, p, v)) == 1n+_ : Nat}
      {==}

def lt_eq(+j: Nat, -x: Nat, -y: Nat, e: {x == y : Nat}, w: Spec.Holds(Nat.is_lt(j, y))) -> Spec.Holds(Nat.is_lt(j, x)):
  %Equal.sym(Nat, x, y, e) : Spec.Holds(Nat.is_lt(j, _))
  w

# The four parts of Spec.movable (&& groups to the left)
# -------------------------------------------------------

def mv_i(+b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, w: Spec.Holds(Spec.movable(b, i, j)))
  -> Spec.Holds(Nat.is_lt(i, Spec.width(b))):
  +lt_i = Nat.is_lt(i, Spec.width(b))
  +lt_j = Nat.is_lt(j, Spec.width(b))
  +ne = Bool.not(Nat.is_eq(i, j))
  +ok = Bool.not(Spec.is_empty(Spec.column(b, i)))
  and_l(lt_i, lt_j, and_l(lt_i && lt_j, ne, and_l((lt_i && lt_j) && ne, ok, w)))

def mv_j(+b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, w: Spec.Holds(Spec.movable(b, i, j)))
  -> Spec.Holds(Nat.is_lt(j, Spec.width(b))):
  +lt_i = Nat.is_lt(i, Spec.width(b))
  +lt_j = Nat.is_lt(j, Spec.width(b))
  +ne = Bool.not(Nat.is_eq(i, j))
  +ok = Bool.not(Spec.is_empty(Spec.column(b, i)))
  and_r(lt_i, lt_j, and_l(lt_i && lt_j, ne, and_l((lt_i && lt_j) && ne, ok, w)))

def mv_ne(+b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, w: Spec.Holds(Spec.movable(b, i, j)))
  -> Spec.Holds(Bool.not(Nat.is_eq(i, j))):
  +lt_i = Nat.is_lt(i, Spec.width(b))
  +lt_j = Nat.is_lt(j, Spec.width(b))
  +ne = Bool.not(Nat.is_eq(i, j))
  +ok = Bool.not(Spec.is_empty(Spec.column(b, i)))
  and_r(lt_i && lt_j, ne, and_l((lt_i && lt_j) && ne, ok, w))

def mv_src(+b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, w: Spec.Holds(Spec.movable(b, i, j)))
  -> Spec.Holds(Bool.not(Spec.is_empty(Spec.column(b, i)))):
  +lt_i = Nat.is_lt(i, Spec.width(b))
  +lt_j = Nat.is_lt(j, Spec.width(b))
  +ne = Bool.not(Nat.is_eq(i, j))
  +ok = Bool.not(Spec.is_empty(Spec.column(b, i)))
  and_r((lt_i && lt_j) && ne, ok, w)

# Transfer
# --------
# Each lemma takes the source column as a parameter `src`, so it can match
# on it; the law passes Spec.column(b, i), which makes the types line up.

def src_go(+b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, src: List<&2, Nat>,
  ne: Spec.Holds(Bool.not(Spec.is_empty(src))), wi: Spec.Holds(Nat.is_lt(i, Spec.width(b))), wij: Spec.Holds(Bool.not(Nat.is_eq(i, j))))
  -> {Spec.column(Core.transfer.go(b, i, j, src), i) == Spec.rest(src) : List<&2, Nat>}:
  match src:
    case Nil{}:
      match ne:
    case h <> t:
      +x = Core.set_col(b, i, t)
      Equal.trans(List<&2, Nat>,
        Spec.column(Core.set_col(x, j, h <> Spec.column(b, j)), i), Spec.column(x, i), t,
        get_set_other(x, j, i, h <> Spec.column(b, j), wij),
        get_set_same(b, i, t, wi))

def Laws.transfer_source(b, i, j, w):
  src_go(b, i, j, Spec.column(b, i), mv_src(b, i, j, w), mv_i(b, i, j, w), mv_ne(b, i, j, w))

def dst_go(+b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, src: List<&2, Nat>,
  ne: Spec.Holds(Bool.not(Spec.is_empty(src))), wj: Spec.Holds(Nat.is_lt(j, Spec.width(b))))
  -> {Spec.column(Core.transfer.go(b, i, j, src), j) == Spec.moved(src, Spec.column(b, j)) : List<&2, Nat>}:
  match src:
    case Nil{}:
      match ne:
    case h <> t:
      +x = Core.set_col(b, i, t)
      get_set_same(x, j, h <> Spec.column(b, j), lt_eq(j, Spec.width(x), Spec.width(b), width_set(b, i, t), wj))

def Laws.transfer_target(b, i, j, w):
  dst_go(b, i, j, Spec.column(b, i), mv_src(b, i, j, w), mv_j(b, i, j, w))

def others_go(+b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, +k: Nat, src: List<&2, Nat>,
  wi: Spec.Holds(Bool.not(Nat.is_eq(k, i))), wj: Spec.Holds(Bool.not(Nat.is_eq(k, j))))
  -> {Spec.column(Core.transfer.go(b, i, j, src), k) == Spec.column(b, k) : List<&2, Nat>}:
  match src:
    case Nil{}:
      {==}
    case h <> t:
      +x = Core.set_col(b, i, t)
      Equal.trans(List<&2, Nat>,
        Spec.column(Core.set_col(x, j, h <> Spec.column(b, j)), k), Spec.column(x, k), Spec.column(b, k),
        get_set_other(x, j, k, h <> Spec.column(b, j), wj),
        get_set_other(b, i, k, t, wi))

def Laws.transfer_others(b, i, j, k, wi, wj):
  others_go(b, i, j, k, Spec.column(b, i), wi, wj)

def width_go(+b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, src: List<&2, Nat>)
  -> {Spec.width(Core.transfer.go(b, i, j, src)) == Spec.width(b) : Nat}:
  match src:
    case Nil{}:
      {==}
    case h <> t:
      +x = Core.set_col(b, i, t)
      Equal.trans(Nat, Spec.width(Core.set_col(x, j, h <> Spec.column(b, j))), Spec.width(x), Spec.width(b),
        width_set(x, j, h <> Spec.column(b, j)),
        width_set(b, i, t))

def Laws.transfer_width(b, i, j):
  width_go(b, i, j, Spec.column(b, i))

# Arithmetic
# ----------

def pred(n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+p:
      p

def succ_inj(-a: Nat, -b: Nat, e: {1n+a == 1n+b : Nat}) -> {a == b : Nat}:
  Equal.cong(Nat, Nat, pred, 1n+a, 1n+b, e)

def cong_add(+p: Nat, -x: Nat, -y: Nat, e: {x == y : Nat}) -> {Nat.add(p, x) == Nat.add(p, y) : Nat}:
  %e : {Nat.add(p, x) == Nat.add(p, _) : Nat}
  {==}

def trans3(-a: Nat, -b: Nat, -c: Nat, -d: Nat, ab: {a == b : Nat}, bc: {b == c : Nat}, cd: {c == d : Nat}) -> {a == d : Nat}:
  Equal.trans(Nat, a, b, d, ab, Equal.trans(Nat, b, c, d, bc, cd))

def add_zero_r(a: Nat) -> {Nat.add(a, 0n) == a : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_zero_r(p) : {1n+Nat.add(p, 0n) == 1n+_ : Nat}
      {==}

def add_succ_r(a: Nat, +b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_succ_r(p, b) : {1n+Nat.add(p, 1n+b) == 1n+_ : Nat}
      {==}

def add_comm(+a: Nat, +b: Nat) -> {Nat.add(a, b) == Nat.add(b, a) : Nat}:
  match a:
    case 0n:
      Equal.sym(Nat, Nat.add(b, 0n), b, add_zero_r(b))
    case 1n+p:
      Equal.trans(Nat, 1n+Nat.add(p, b), 1n+Nat.add(b, p), Nat.add(b, 1n+p),
        Equal.cong(Nat, Nat, n => 1n+n, Nat.add(p, b), Nat.add(b, p), add_comm(p, b)),
        Equal.sym(Nat, Nat.add(b, 1n+p), 1n+Nat.add(b, p), add_succ_r(b, p)))

def add_assoc(a: Nat, -b: Nat, -c: Nat) -> {Nat.add(Nat.add(a, b), c) == Nat.add(a, Nat.add(b, c)) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_assoc(p, b, c) : {1n+Nat.add(Nat.add(p, b), c) == 1n+_ : Nat}
      {==}

def add_swap(+a: Nat, +b: Nat, +c: Nat) -> {Nat.add(a, Nat.add(b, c)) == Nat.add(b, Nat.add(a, c)) : Nat}:
  trans3(Nat.add(a, Nat.add(b, c)), Nat.add(Nat.add(a, b), c), Nat.add(Nat.add(b, a), c), Nat.add(b, Nat.add(a, c)),
    Equal.sym(Nat, Nat.add(Nat.add(a, b), c), Nat.add(a, Nat.add(b, c)), add_assoc(a, b, c)),
    Equal.cong(Nat, Nat, n => Nat.add(n, c), Nat.add(a, b), Nat.add(b, a), add_comm(a, b)),
    add_assoc(b, a, c))

def add_cancel(p: Nat, -a: Nat, -b: Nat, e: {Nat.add(p, a) == Nat.add(p, b) : Nat}) -> {a == b : Nat}:
  match p:
    case 0n:
      e
    case 1n+q:
      add_cancel(q, a, b, succ_inj(Nat.add(q, a), Nat.add(q, b), e))

def add_bump_l(e: Bool, -a: Nat, -b: Nat) -> {Nat.add(Spec.bump(e, a), b) == Spec.bump(e, Nat.add(a, b)) : Nat}:
  match e:
    case True{}:
      {==}
    case False{}:
      {==}

def add_bump_r(e: Bool, a: Nat, +b: Nat) -> {Nat.add(a, Spec.bump(e, b)) == Spec.bump(e, Nat.add(a, b)) : Nat}:
  match e:
    case True{}:
      add_succ_r(a, b)
    case False{}:
      {==}

# Counting over a replaced column
# -------------------------------
# Replacing column k by v: count(new) + count(old column k)
#                        = count(old) + count(v).

def count_set(+c: Nat, b: List<&2, List<&2, Nat>>, +k: Nat, +v: List<&2, Nat>, w: Spec.Holds(Nat.is_lt(k, Spec.width(b))))
  -> {Nat.add(Spec.count_col(c, Spec.column(b, k)), Spec.count(c, Core.set_col(b, k, v))) == Nat.add(Spec.count_col(c, v), Spec.count(c, b)) : Nat}:
  match b k:
    case Nil{} 0n:
      match w:
    case Nil{} 1n+p:
      match w:
    case +col <> +r 0n:
      add_swap(Spec.count_col(c, col), Spec.count_col(c, v), Spec.count(c, r))
    case +col <> +r 1n+p:
      +a = Spec.count_col(c, Spec.column(r, p))
      +x = Spec.count_col(c, col)
      +s = Spec.count(c, Core.set_col(r, p, v))
      trans3(Nat.add(a, Nat.add(x, s)), Nat.add(x, Nat.add(a, s)), Nat.add(x, Nat.add(Spec.count_col(c, v), Spec.count(c, r))), Nat.add(Spec.count_col(c, v), Nat.add(x, Spec.count(c, r))),
        add_swap(a, x, s),
        cong_add(x, Nat.add(a, s), Nat.add(Spec.count_col(c, v), Spec.count(c, r)), count_set(c, r, p, v, w)),
        add_swap(x, Spec.count_col(c, v), Spec.count(c, r)))

def total_set(b: List<&2, List<&2, Nat>>, +k: Nat, +v: List<&2, Nat>, w: Spec.Holds(Nat.is_lt(k, Spec.width(b))))
  -> {Nat.add(Spec.size(Spec.column(b, k)), Spec.total(Core.set_col(b, k, v))) == Nat.add(Spec.size(v), Spec.total(b)) : Nat}:
  match b k:
    case Nil{} 0n:
      match w:
    case Nil{} 1n+p:
      match w:
    case +col <> +r 0n:
      add_swap(Spec.size(col), Spec.size(v), Spec.total(r))
    case +col <> +r 1n+p:
      +a = Spec.size(Spec.column(r, p))
      +x = Spec.size(col)
      +s = Spec.total(Core.set_col(r, p, v))
      trans3(Nat.add(a, Nat.add(x, s)), Nat.add(x, Nat.add(a, s)), Nat.add(x, Nat.add(Spec.size(v), Spec.total(r))), Nat.add(Spec.size(v), Nat.add(x, Spec.total(r))),
        add_swap(a, x, s),
        cong_add(x, Nat.add(a, s), Nat.add(Spec.size(v), Spec.total(r)), total_set(r, p, v, w)),
        add_swap(x, Spec.size(v), Spec.total(r)))

# Conservation through a transfer
# -------------------------------
# With x = b with column i replaced by t, and y = x with column j replaced by
# h <> column(b, j): count(y) = bump(c == h, count(x)) = count(b), each by
# count_set and cancelling the same column count on both sides.

def holds_true(-x: Bool, e: {x == True{} : Bool}) -> Spec.Holds(x):
  %Equal.sym(Bool, x, True{}, e) : Spec.Holds(_)
  Unit{}

def cons_go(+c: Nat, +b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, src: List<&2, Nat>, e: {Spec.column(b, i) == src : List<&2, Nat>},
  wi: Spec.Holds(Nat.is_lt(i, Spec.width(b))), wj: Spec.Holds(Nat.is_lt(j, Spec.width(b))), wij: Spec.Holds(Bool.not(Nat.is_eq(i, j))))
  -> {Spec.count(c, Core.transfer.go(b, i, j, src)) == Spec.count(c, b) : Nat}:
  match src:
    case Nil{}:
      {==}
    case +h <> +t:
      +x = Core.set_col(b, i, t)
      +cj = Spec.column(b, j)
      +y = Core.set_col(x, j, h <> cj)
      +ee = Nat.is_eq(c, h)
      +a = Spec.count_col(c, cj)
      +p = Spec.count(c, x)
      +tt = Spec.count_col(c, t)
      # add(a, count(y)) = add(count_col(column(x, j)), count(y)) = add(bump(ee, a), p)
      s1 = Equal.trans(Nat, Nat.add(a, Spec.count(c, y)), Nat.add(Spec.count_col(c, Spec.column(x, j)), Spec.count(c, y)), Nat.add(Spec.bump(ee, a), p),
        Equal.cong(List<&2, Nat>, Nat, col => Nat.add(Spec.count_col(c, col), Spec.count(c, y)), cj, Spec.column(x, j),
          Equal.sym(List<&2, Nat>, Spec.column(x, j), cj, get_set_other(b, i, j, t, ne_sym(i, j, wij)))),
        count_set(c, x, j, h <> cj, lt_eq(j, Spec.width(x), Spec.width(b), width_set(b, i, t), wj)))
      q1 = add_cancel(a, Spec.count(c, y), Spec.bump(ee, p),
        trans3(Nat.add(a, Spec.count(c, y)), Nat.add(Spec.bump(ee, a), p), Spec.bump(ee, Nat.add(a, p)), Nat.add(a, Spec.bump(ee, p)),
          s1, add_bump_l(ee, a, p), Equal.sym(Nat, Nat.add(a, Spec.bump(ee, p)), Spec.bump(ee, Nat.add(a, p)), add_bump_r(ee, a, p))))
      # add(bump(ee, tt), p) = add(tt, count(b)), from count_set at column i
      s2 = Equal.trans(Nat, Nat.add(Spec.bump(ee, tt), p), Nat.add(Spec.count_col(c, Spec.column(b, i)), p), Nat.add(tt, Spec.count(c, b)),
        Equal.cong(List<&2, Nat>, Nat, col => Nat.add(Spec.count_col(c, col), p), h <> t, Spec.column(b, i),
          Equal.sym(List<&2, Nat>, Spec.column(b, i), h <> t, e)),
        count_set(c, b, i, t, wi))
      q2 = add_cancel(tt, Spec.bump(ee, p), Spec.count(c, b),
        trans3(Nat.add(tt, Spec.bump(ee, p)), Spec.bump(ee, Nat.add(tt, p)), Nat.add(Spec.bump(ee, tt), p), Nat.add(tt, Spec.count(c, b)),
          add_bump_r(ee, tt, p), Equal.sym(Nat, Nat.add(Spec.bump(ee, tt), p), Spec.bump(ee, Nat.add(tt, p)), add_bump_l(ee, tt, p)), s2))
      Equal.trans(Nat, Spec.count(c, y), Spec.bump(ee, p), Spec.count(c, b), q1, q2)

def tot_go(+b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, src: List<&2, Nat>, e: {Spec.column(b, i) == src : List<&2, Nat>},
  wi: Spec.Holds(Nat.is_lt(i, Spec.width(b))), wj: Spec.Holds(Nat.is_lt(j, Spec.width(b))), wij: Spec.Holds(Bool.not(Nat.is_eq(i, j))))
  -> {Spec.total(Core.transfer.go(b, i, j, src)) == Spec.total(b) : Nat}:
  match src:
    case Nil{}:
      {==}
    case +h <> +t:
      +x = Core.set_col(b, i, t)
      +cj = Spec.column(b, j)
      +y = Core.set_col(x, j, h <> cj)
      +ee = {True{} : Bool}
      +a = Spec.size(cj)
      +p = Spec.total(x)
      +tt = Spec.size(t)
      # the same argument, counting every bead
      s1 = Equal.trans(Nat, Nat.add(a, Spec.total(y)), Nat.add(Spec.size(Spec.column(x, j)), Spec.total(y)), Nat.add(Spec.bump(ee, a), p),
        Equal.cong(List<&2, Nat>, Nat, col => Nat.add(Spec.size(col), Spec.total(y)), cj, Spec.column(x, j),
          Equal.sym(List<&2, Nat>, Spec.column(x, j), cj, get_set_other(b, i, j, t, ne_sym(i, j, wij)))),
        total_set(x, j, h <> cj, lt_eq(j, Spec.width(x), Spec.width(b), width_set(b, i, t), wj)))
      q1 = add_cancel(a, Spec.total(y), Spec.bump(ee, p),
        trans3(Nat.add(a, Spec.total(y)), Nat.add(Spec.bump(ee, a), p), Spec.bump(ee, Nat.add(a, p)), Nat.add(a, Spec.bump(ee, p)),
          s1, add_bump_l(ee, a, p), Equal.sym(Nat, Nat.add(a, Spec.bump(ee, p)), Spec.bump(ee, Nat.add(a, p)), add_bump_r(ee, a, p))))
            s2 = Equal.trans(Nat, Nat.add(Spec.bump(ee, tt), p), Nat.add(Spec.size(Spec.column(b, i)), p), Nat.add(tt, Spec.total(b)),
        Equal.cong(List<&2, Nat>, Nat, col => Nat.add(Spec.size(col), p), h <> t, Spec.column(b, i),
          Equal.sym(List<&2, Nat>, Spec.column(b, i), h <> t, e)),
        total_set(b, i, t, wi))
      q2 = add_cancel(tt, Spec.bump(ee, p), Spec.total(b),
        trans3(Nat.add(tt, Spec.bump(ee, p)), Spec.bump(ee, Nat.add(tt, p)), Nat.add(Spec.bump(ee, tt), p), Nat.add(tt, Spec.total(b)),
          add_bump_r(ee, tt, p), Equal.sym(Nat, Nat.add(Spec.bump(ee, tt), p), Spec.bump(ee, Nat.add(tt, p)), add_bump_l(ee, tt, p)), s2))
      Equal.trans(Nat, Spec.total(y), Spec.bump(ee, p), Spec.total(b), q1, q2)

# From the rules to transfer
# --------------------------

def legal_mv(+cap: Nat, +b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, w: Spec.Holds(Spec.legal(cap, b, i, j)))
  -> Spec.Holds(Spec.movable(b, i, j)):
  and_l(Spec.movable(b, i, j), Nat.is_lt(Spec.size(Spec.column(b, j)), cap), w)

def legal_room(+cap: Nat, +b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, w: Spec.Holds(Spec.legal(cap, b, i, j)))
  -> Spec.Holds(Nat.is_lt(Spec.size(Spec.column(b, j)), cap)):
  and_r(Spec.movable(b, i, j), Nat.is_lt(Spec.size(Spec.column(b, j)), cap), w)

# Law 1
# -----

def cons_fin(+c: Nat, -colours: Nat, +cap: Nat, -start: List<&2, List<&2, Nat>>, +b: List<&2, List<&2, Nat>>, -history: List<&2, Core.Move>, +i: Nat, +j: Nat,
  ok: Bool, e: {Spec.legal(cap, b, i, j) == ok : Bool})
  -> {Spec.count(c, Core.board(Core.apply.fin(colours, cap, start, b, history, i, j, ok))) == Spec.count(c, b) : Nat}:
  match ok:
    case True{}:
      +w = legal_mv(cap, b, i, j, holds_true(Spec.legal(cap, b, i, j), e))
      cons_go(c, b, i, j, Spec.column(b, i), {==}, mv_i(b, i, j, w), mv_j(b, i, j, w), mv_ne(b, i, j, w))
    case False{}:
      {==}

def Laws.conserves_colours(c, g, m):
  match g m:
    case Core.Game{colours, +cap, start, +b, history} Core.Mv{+i, +j}:
      cons_fin(c, colours, cap, start, b, history, i, j, Spec.legal(cap, b, i, j), {==})

def tot_fin(-colours: Nat, +cap: Nat, -start: List<&2, List<&2, Nat>>, +b: List<&2, List<&2, Nat>>, -history: List<&2, Core.Move>, +i: Nat, +j: Nat,
  ok: Bool, e: {Spec.legal(cap, b, i, j) == ok : Bool})
  -> {Spec.total(Core.board(Core.apply.fin(colours, cap, start, b, history, i, j, ok))) == Spec.total(b) : Nat}:
  match ok:
    case True{}:
      +w = legal_mv(cap, b, i, j, holds_true(Spec.legal(cap, b, i, j), e))
      tot_go(b, i, j, Spec.column(b, i), {==}, mv_i(b, i, j, w), mv_j(b, i, j, w), mv_ne(b, i, j, w))
    case False{}:
      {==}

def Laws.conserves_beads(g, m):
  match g m:
    case Core.Game{colours, +cap, start, +b, history} Core.Mv{+i, +j}:
      tot_fin(colours, cap, start, b, history, i, j, Spec.legal(cap, b, i, j), {==})

# Law 2
# -----

def and_intro(+a: Bool, -b: Bool, wa: Spec.Holds(a), wb: Spec.Holds(b)) -> Spec.Holds(a && b):
  match a:
    case True{}:
      wb
    case False{}:
      Empty.absurd(Spec.Holds(False{} && b), wa)

def le_zero(n: Nat) -> Spec.Holds(Nat.is_le(0n, n)):
  match n:
    case 0n:
      Unit{}
    case 1n+p:
      Unit{}

# a + 1 <= n implies a <= n
def le_pred(a: Nat, n: Nat, w: Spec.Holds(Nat.is_le(1n+a, n))) -> Spec.Holds(Nat.is_le(a, n)):
  match a n:
    case 0n m:
      le_zero(m)
    case 1n+p 0n:
      match w:
    case 1n+p 1n+q:
      le_pred(p, q, w)

# a < n implies a + 1 <= n
def lt_le_succ(a: Nat, n: Nat, w: Spec.Holds(Nat.is_lt(a, n))) -> Spec.Holds(Nat.is_le(1n+a, n)):
  match a n:
    case 0n 0n:
      match w:
    case 0n 1n+q:
      le_zero(q)
    case 1n+p 0n:
      match w:
    case 1n+p 1n+q:
      lt_le_succ(p, q, w)

def le_size_eq(-x: List<&2, Nat>, -y: List<&2, Nat>, e: {x == y : List<&2, Nat>}, +cap: Nat, w: Spec.Holds(Nat.is_le(Spec.size(x), cap)))
  -> Spec.Holds(Nat.is_le(Spec.size(y), cap)):
  %e : Spec.Holds(Nat.is_le(Spec.size(_), cap))
  w

# every column of a board that fits fits
def fits_col(+cap: Nat, b: List<&2, List<&2, Nat>>, k: Nat, w: Spec.Holds(Spec.fits(cap, b)))
  -> Spec.Holds(Nat.is_le(Spec.size(Spec.column(b, k)), cap)):
  match b k:
    case Nil{} _:
      le_zero(cap)
    case +c <> +r 0n:
      and_l(Nat.is_le(Spec.size(c), cap), Spec.fits(cap, r), w)
    case +c <> +r 1n+p:
      fits_col(cap, r, p, and_r(Nat.is_le(Spec.size(c), cap), Spec.fits(cap, r), w))

def fits_set(+cap: Nat, b: List<&2, List<&2, Nat>>, k: Nat, +v: List<&2, Nat>, w: Spec.Holds(Spec.fits(cap, b)), wv: Spec.Holds(Nat.is_le(Spec.size(v), cap)))
  -> Spec.Holds(Spec.fits(cap, Core.set_col(b, k, v))):
  match b k:
    case Nil{} _:
      Unit{}
    case +c <> +r 0n:
      and_intro(Nat.is_le(Spec.size(v), cap), Spec.fits(cap, r), wv, and_r(Nat.is_le(Spec.size(c), cap), Spec.fits(cap, r), w))
    case +c <> +r 1n+p:
      +w2 = w
      and_intro(Nat.is_le(Spec.size(c), cap), Spec.fits(cap, Core.set_col(r, p, v)),
        and_l(Nat.is_le(Spec.size(c), cap), Spec.fits(cap, r), w2),
        fits_set(cap, r, p, v, and_r(Nat.is_le(Spec.size(c), cap), Spec.fits(cap, r), w2), wv))

def cap_go(+cap: Nat, +b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, src: List<&2, Nat>, e: {Spec.column(b, i) == src : List<&2, Nat>},
  +wf: Spec.Holds(Spec.fits(cap, b)), wr: Spec.Holds(Nat.is_lt(Spec.size(Spec.column(b, j)), cap)))
  -> Spec.Holds(Spec.fits(cap, Core.transfer.go(b, i, j, src))):
  match src:
    case Nil{}:
      wf
    case +h <> +t:
      +x = Core.set_col(b, i, t)
      wt = le_pred(Spec.size(t), cap, le_size_eq(Spec.column(b, i), h <> t, e, cap, fits_col(cap, b, i, wf)))
      fits_set(cap, x, j, h <> Spec.column(b, j), fits_set(cap, b, i, t, wf, wt), lt_le_succ(Spec.size(Spec.column(b, j)), cap, wr))

def cap_fin(-colours: Nat, +cap: Nat, -start: List<&2, List<&2, Nat>>, +b: List<&2, List<&2, Nat>>, -history: List<&2, Core.Move>, +i: Nat, +j: Nat,
  ok: Bool, e: {Spec.legal(cap, b, i, j) == ok : Bool}, +wf: Spec.Holds(Spec.fits(cap, b)))
  -> Spec.Holds(Spec.fits(cap, Core.board(Core.apply.fin(colours, cap, start, b, history, i, j, ok)))):
  match ok:
    case True{}:
      +w = holds_true(Spec.legal(cap, b, i, j), e)
      cap_go(cap, b, i, j, Spec.column(b, i), {==}, wf, legal_room(cap, b, i, j, w))
    case False{}:
      wf

def Laws.keeps_capacity(g, m, w):
  match g m:
    case Core.Game{colours, +cap, start, +b, history} Core.Mv{+i, +j}:
      cap_fin(colours, cap, start, b, history, i, j, Spec.legal(cap, b, i, j), {==}, w)

# Law 5
# -----

def Laws.refused_changes_nothing(g, m, e):
  match g m:
    case Core.Game{+colours, +cap, +start, +b, +history} Core.Mv{+i, +j}:
      %Equal.sym(Bool, Spec.legal(cap, b, i, j), False{}, e) : {Core.apply.fin(colours, cap, start, b, history, i, j, _) == Core.Game{colours, cap, start, b, history} : Core.Game}
      {==}
