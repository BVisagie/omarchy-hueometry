# Hueometry: the proofs of LAWS.bend.

import Base
import ./SPEC.bend as Spec
import ./engine/core.bend as Core
import ./engine/gen.bend as Gen
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

# Law 9
# -----
# The transfer back from j to i rebuilds b: replacing a column twice keeps
# the second, and putting a column back where it came from changes nothing.

def set_set_same(b: List<&2, List<&2, Nat>>, k: Nat, -v: List<&2, Nat>, -u: List<&2, Nat>)
  -> {Core.set_col(Core.set_col(b, k, v), k, u) == Core.set_col(b, k, u) : List<&2, List<&2, Nat>>}:
  match b k:
    case Nil{} _:
      {==}
    case c <> r 0n:
      {==}
    case +c <> r 1n+p:
      %set_set_same(r, p, v, u) : {c <> Core.set_col(Core.set_col(r, p, v), p, u) == c <> _ : List<&2, List<&2, Nat>>}
      {==}

def set_get(b: List<&2, List<&2, Nat>>, k: Nat) -> {Core.set_col(b, k, Spec.column(b, k)) == b : List<&2, List<&2, Nat>>}:
  match b k:
    case Nil{} _:
      {==}
    case c <> r 0n:
      {==}
    case +c <> +r 1n+p:
      %set_get(r, p) : {c <> Core.set_col(r, p, Spec.column(r, p)) == c <> _ : List<&2, List<&2, Nat>>}
      {==}

def btrans(-a: List<&2, List<&2, Nat>>, -b: List<&2, List<&2, Nat>>, -c: List<&2, List<&2, Nat>>,
  ab: {a == b : List<&2, List<&2, Nat>>}, bc: {b == c : List<&2, List<&2, Nat>>}) -> {a == c : List<&2, List<&2, Nat>>}:
  Equal.trans(List<&2, List<&2, Nat>>, a, b, c, ab, bc)

def back_go(+b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, src: List<&2, Nat>, e: {Spec.column(b, i) == src : List<&2, Nat>},
  ne: Spec.Holds(Bool.not(Spec.is_empty(src))), +wi: Spec.Holds(Nat.is_lt(i, Spec.width(b))), wj: Spec.Holds(Nat.is_lt(j, Spec.width(b))), +wij: Spec.Holds(Bool.not(Nat.is_eq(i, j))))
  -> {Core.transfer(Core.transfer.go(b, i, j, src), j, i) == b : List<&2, List<&2, Nat>>}:
  match src:
    case Nil{}:
      match ne:
    case +h <> +t:
      +x = Core.set_col(b, i, t)
      +cj = Spec.column(b, j)
      +v = {h <> cj : List<&2, Nat>}
      +y = Core.set_col(x, j, v)
      +z = Core.set_col(y, j, cj)
      # transfer(y, j, i) reads column j of y, which is v
      sa = Equal.cong(List<&2, Nat>, List<&2, List<&2, Nat>>, s => Core.transfer.go(y, j, i, s), Spec.column(y, j), v,
        get_set_same(x, j, v, lt_eq(j, Spec.width(x), Spec.width(b), width_set(b, i, t), wj)))
      # column i of y is t
      yi = Equal.trans(List<&2, Nat>, Spec.column(y, i), Spec.column(x, i), t, get_set_other(x, j, i, v, wij), get_set_same(b, i, t, wi))
      sb = Equal.cong(List<&2, Nat>, List<&2, List<&2, Nat>>, s => Core.set_col(z, i, h <> s), Spec.column(y, i), t, yi)
      # replacing column j twice keeps cj, which is column j of x: x again
      xj = Equal.sym(List<&2, Nat>, Spec.column(x, j), cj, get_set_other(b, i, j, t, ne_sym(i, j, wij)))
      zx = btrans(z, Core.set_col(x, j, cj), x, set_set_same(x, j, v, cj),
        btrans(Core.set_col(x, j, cj), Core.set_col(x, j, Spec.column(x, j)), x,
          Equal.cong(List<&2, Nat>, List<&2, List<&2, Nat>>, s => Core.set_col(x, j, s), cj, Spec.column(x, j), xj),
          set_get(x, j)))
      sc = Equal.cong(List<&2, List<&2, Nat>>, List<&2, List<&2, Nat>>, q => Core.set_col(q, i, h <> t), z, x, zx)
      # column i replaced by t then by h <> t, which is column i of b: b again
      sd = btrans(Core.set_col(x, i, h <> t), Core.set_col(b, i, h <> t), b, set_set_same(b, i, t, h <> t),
        btrans(Core.set_col(b, i, h <> t), Core.set_col(b, i, Spec.column(b, i)), b,
          Equal.cong(List<&2, Nat>, List<&2, List<&2, Nat>>, s => Core.set_col(b, i, s), h <> t, Spec.column(b, i), Equal.sym(List<&2, Nat>, Spec.column(b, i), h <> t, e)),
          set_get(b, i)))
      btrans(Core.transfer(y, j, i), Core.transfer.go(y, j, i, v), b, sa,
        btrans(Core.transfer.go(y, j, i, v), Core.set_col(z, i, h <> t), b, sb,
          btrans(Core.set_col(z, i, h <> t), Core.set_col(x, i, h <> t), b, sc, sd)))

def bool_disc(b: Bool) -> Data:
  match b:
    case True{}:
      Empty
    case False{}:
      Unit

def false_ne_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : bool_disc(_)
  Unit{}

def undo_fin(+colours: Nat, +cap: Nat, +start: List<&2, List<&2, Nat>>, +b: List<&2, List<&2, Nat>>, +history: List<&2, Core.Move>, +i: Nat, +j: Nat,
  ok: Bool, e: {Spec.legal(cap, b, i, j) == ok : Bool}, f: {ok == True{} : Bool})
  -> {Core.undo(Core.apply.fin(colours, cap, start, b, history, i, j, ok)) == Core.Game{colours, cap, start, b, history} : Core.Game}:
  match ok:
    case True{}:
      +w = legal_mv(cap, b, i, j, holds_true(Spec.legal(cap, b, i, j), e))
      bb = back_go(b, i, j, Spec.column(b, i), {==}, mv_src(b, i, j, w), mv_i(b, i, j, w), mv_j(b, i, j, w), mv_ne(b, i, j, w))
      Equal.cong(List<&2, List<&2, Nat>>, Core.Game, q => Core.Game{colours, cap, start, q, history}, Core.transfer(Core.transfer(b, i, j), j, i), b, bb)
    case False{}:
      Empty.absurd({Core.undo(Core.Game{colours, cap, start, b, history}) == Core.Game{colours, cap, start, b, history} : Core.Game}, false_ne_true(f))

def Laws.undo_takes_back(g, m, e):
  match g m:
    case Core.Game{+colours, +cap, +start, +b, +history} Core.Mv{+i, +j}:
      undo_fin(colours, cap, start, b, history, i, j, Spec.legal(cap, b, i, j), {==}, e)

def Laws.undo_without_moves(colours, cap, start, b):
  {==}

# Law 8
# -----
# If every occupied column is full and one colour, a colour's count is cap
# times the number of columns holding it. A valid board has exactly cap of
# each colour, and cap >= 1, so each colour is in exactly one column.

def holds_eq(+x: Bool, w: Spec.Holds(x)) -> {x == True{} : Bool}:
  match x:
    case True{}:
      {==}
    case False{}:
      match w:

def holds_not_eq(+x: Bool, w: Spec.Holds(Bool.not(x))) -> {x == False{} : Bool}:
  match x:
    case True{}:
      match w:
    case False{}:
      {==}

def eq_sound(a: Nat, b: Nat, w: Spec.Holds(Nat.is_eq(a, b))) -> {a == b : Nat}:
  match a b:
    case 0n 0n:
      {==}
    case 0n 1n+q:
      match w:
    case 1n+p 0n:
      match w:
    case 1n+p 1n+q:
      Equal.cong(Nat, Nat, n => 1n+n, p, q, eq_sound(p, q, w))

def eq_refl(a: Nat) -> Spec.Holds(Nat.is_eq(a, a)):
  match a:
    case 0n:
      Unit{}
    case 1n+p:
      eq_refl(p)

def eq_of(+a: Nat, -b: Nat, e: {a == b : Nat}) -> Spec.Holds(Nat.is_eq(a, b)):
  %e : Spec.Holds(Nat.is_eq(a, _))
  eq_refl(a)

def ne_of(+p: Nat, -h: Nat, -x: Nat, e: {h == x : Nat}, w: Spec.Holds(Bool.not(Nat.is_eq(p, h)))) -> Spec.Holds(Bool.not(Nat.is_eq(p, x))):
  %e : Spec.Holds(Bool.not(Nat.is_eq(p, _)))
  w

def nat_disc(n: Nat) -> Data:
  match n:
    case 0n:
      Unit
    case 1n+p:
      Empty

def succ_ne_zero(-n: Nat, e: {1n+n == 0n : Nat}) -> Empty:
  %Equal.sym(Nat, 1n+n, 0n, e) : nat_disc(_)
  Unit{}

# all beads of t have colour h: count p in t is size(t) when p is h, else 0

def all_same(+p: Nat, +h: Nat, t: List<&2, Nat>, +e: Spec.Holds(Nat.is_eq(p, h)), wa: Spec.Holds(Spec.all_colour(h, t)))
  -> {Spec.count_col(p, t) == Spec.size(t) : Nat}:
  match t:
    case Nil{}:
      {==}
    case +x <> +u:
      +wa2 = wa
      px = Equal.trans(Nat, p, h, x, eq_sound(p, h, e), eq_sound(h, x, and_l(Nat.is_eq(h, x), Spec.all_colour(h, u), wa2)))
      %Equal.sym(Bool, Nat.is_eq(p, x), True{}, holds_eq(Nat.is_eq(p, x), eq_of(p, x, px))) : {Spec.bump(_, Spec.count_col(p, u)) == 1n+Spec.size(u) : Nat}
      Equal.cong(Nat, Nat, n => 1n+n, Spec.count_col(p, u), Spec.size(u), all_same(p, h, u, e, and_r(Nat.is_eq(h, x), Spec.all_colour(h, u), wa2)))

def all_other(+p: Nat, +h: Nat, t: List<&2, Nat>, +e: Spec.Holds(Bool.not(Nat.is_eq(p, h))), wa: Spec.Holds(Spec.all_colour(h, t)))
  -> {Spec.count_col(p, t) == 0n : Nat}:
  match t:
    case Nil{}:
      {==}
    case +x <> +u:
      +wa2 = wa
      nx = ne_of(p, h, x, eq_sound(h, x, and_l(Nat.is_eq(h, x), Spec.all_colour(h, u), wa2)), e)
      %Equal.sym(Bool, Nat.is_eq(p, x), False{}, holds_not_eq(Nat.is_eq(p, x), nx)) : {Spec.bump(_, Spec.count_col(p, u)) == 0n : Nat}
      all_other(p, h, u, e, and_r(Nat.is_eq(h, x), Spec.all_colour(h, u), wa2))

def holds_not(-x: Bool, e: {x == False{} : Bool}) -> Spec.Holds(Bool.not(x)):
  %Equal.sym(Bool, x, False{}, e) : Spec.Holds(Bool.not(_))
  Unit{}

# a full one-colour column holds cap of its colour and none of the others

def head_cases(+p: Nat, +h: Nat, +t: List<&2, Nat>, +cap: Nat, ee: Bool, +e: {Nat.is_eq(p, h) == ee : Bool},
  +wa: Spec.Holds(Spec.all_colour(h, t)), ws: Spec.Holds(Nat.is_eq(1n+Spec.size(t), cap)))
  -> Or({0n == Spec.count_col(p, h <> t) : Nat}, {cap == Spec.count_col(p, h <> t) : Nat}):
  match ee:
    case True{}:
      +same = all_same(p, h, t, holds_true(Nat.is_eq(p, h), e), wa)
      %Equal.sym(Bool, Nat.is_eq(p, h), True{}, e) : Or({0n == Spec.bump(_, Spec.count_col(p, t)) : Nat}, {cap == Spec.bump(_, Spec.count_col(p, t)) : Nat})
      Inr{Equal.trans(Nat, cap, 1n+Spec.size(t), 1n+Spec.count_col(p, t),
        Equal.sym(Nat, 1n+Spec.size(t), cap, eq_sound(1n+Spec.size(t), cap, ws)),
        Equal.cong(Nat, Nat, n => 1n+n, Spec.size(t), Spec.count_col(p, t), Equal.sym(Nat, Spec.count_col(p, t), Spec.size(t), same)))}
    case False{}:
      +other = all_other(p, h, t, holds_not(Nat.is_eq(p, h), e), wa)
      %Equal.sym(Bool, Nat.is_eq(p, h), False{}, e) : Or({0n == Spec.bump(_, Spec.count_col(p, t)) : Nat}, {cap == Spec.bump(_, Spec.count_col(p, t)) : Nat})
      Inl{Equal.sym(Nat, Spec.count_col(p, t), 0n, other)}

def col_cases(+p: Nat, +cap: Nat, col: List<&2, Nat>, w: Spec.Holds(Spec.is_empty(col) || (Spec.uniform(col) && Nat.is_eq(Spec.size(col), cap))))
  -> Or({0n == Spec.count_col(p, col) : Nat}, {cap == Spec.count_col(p, col) : Nat}):
  match col:
    case Nil{}:
      Inl{{==}}
    case +h <> +t:
      +w2 = w
      head_cases(p, h, t, cap, Nat.is_eq(p, h), {==},
        and_l(Spec.all_colour(h, t), Nat.is_eq(1n+Spec.size(t), cap), w2),
        and_r(Spec.all_colour(h, t), Nat.is_eq(1n+Spec.size(t), cap), w2))

def col_zero(+p: Nat, -cap: Nat, -col: List<&2, Nat>, -x: Nat, -y: Nat, ih: {x == Nat.mul(y, cap) : Nat}, z: {0n == Spec.count_col(p, col) : Nat})
  -> {Nat.add(Spec.count_col(p, col), x) == Nat.mul(Spec.bump(Nat.is_lt(0n, Spec.count_col(p, col)), y), cap) : Nat}:
  %z : {Nat.add(_, x) == Nat.mul(Spec.bump(Nat.is_lt(0n, _), y), cap) : Nat}
  ih

def col_full.go(cap: Nat, -x: Nat, +y: Nat, ih: {x == Nat.mul(y, cap) : Nat}, wcap: Spec.Holds(Nat.is_lt(0n, cap)))
  -> {Nat.add(cap, x) == Nat.mul(Spec.bump(Nat.is_lt(0n, cap), y), cap) : Nat}:
  match cap:
    case 0n:
      match wcap:
    case 1n+c:
      cong_add(1n+c, x, Nat.mul(y, 1n+c), ih)

def col_full(+p: Nat, +cap: Nat, -col: List<&2, Nat>, -x: Nat, +y: Nat, ih: {x == Nat.mul(y, cap) : Nat}, f: {cap == Spec.count_col(p, col) : Nat}, wcap: Spec.Holds(Nat.is_lt(0n, cap)))
  -> {Nat.add(Spec.count_col(p, col), x) == Nat.mul(Spec.bump(Nat.is_lt(0n, Spec.count_col(p, col)), y), cap) : Nat}:
  %f : {Nat.add(_, x) == Nat.mul(Spec.bump(Nat.is_lt(0n, _), y), cap) : Nat}
  col_full.go(cap, x, y, ih, wcap)

def col_combine(+p: Nat, +cap: Nat, -col: List<&2, Nat>, -x: Nat, +y: Nat, ih: {x == Nat.mul(y, cap) : Nat},
  d: Or({0n == Spec.count_col(p, col) : Nat}, {cap == Spec.count_col(p, col) : Nat}), wcap: Spec.Holds(Nat.is_lt(0n, cap)))
  -> {Nat.add(Spec.count_col(p, col), x) == Nat.mul(Spec.bump(Nat.is_lt(0n, Spec.count_col(p, col)), y), cap) : Nat}:
  match d:
    case Inl{z}:
      col_zero(p, cap, col, x, y, ih, z)
    case Inr{f}:
      col_full(p, cap, col, x, y, ih, f, wcap)

def count_by_columns(+p: Nat, +cap: Nat, b: List<&2, List<&2, Nat>>, w: Spec.Holds(Spec.occupied_full_uniform(cap, b)), +wcap: Spec.Holds(Nat.is_lt(0n, cap)))
  -> {Spec.count(p, b) == Nat.mul(Spec.columns_with(p, b), cap) : Nat}:
  match b:
    case Nil{}:
      {==}
    case +col <> +r:
      +w2 = w
      +ok = Spec.is_empty(col) || (Spec.uniform(col) && Nat.is_eq(Spec.size(col), cap))
      col_combine(p, cap, col, Spec.count(p, r), Spec.columns_with(p, r),
        count_by_columns(p, cap, r, and_r(ok, Spec.occupied_full_uniform(cap, r), w2), wcap),
        col_cases(p, cap, col, and_l(ok, Spec.occupied_full_uniform(cap, r), w2)), wcap)

# n * cap = cap with cap >= 1 means n = 1

def zero_cap(-cap: Nat, e: {0n == cap : Nat}, w: Spec.Holds(Nat.is_lt(0n, cap))) -> Spec.Holds(Nat.is_lt(0n, 0n)):
  %Equal.sym(Nat, 0n, cap, e) : Spec.Holds(Nat.is_lt(0n, _))
  w

def big_cap(cap: Nat, -z: Nat, e: {Nat.add(cap, z) == 0n : Nat}, w: Spec.Holds(Nat.is_lt(0n, cap))) -> Empty:
  match cap:
    case 0n:
      w
    case 1n+c:
      succ_ne_zero(Nat.add(c, z), e)

def one_of_many(+r: Nat, +cap: Nat, e: {Nat.add(cap, Nat.add(cap, Nat.mul(r, cap))) == cap : Nat}, w: Spec.Holds(Nat.is_lt(0n, cap))) -> Empty:
  +m = Nat.add(cap, Nat.mul(r, cap))
  z = add_cancel(cap, m, 0n, Equal.trans(Nat, Nat.add(cap, m), cap, Nat.add(cap, 0n), e, Equal.sym(Nat, Nat.add(cap, 0n), cap, add_zero_r(cap))))
  big_cap(cap, Nat.mul(r, cap), z, w)

def mul_one.go(q: Nat, +cap: Nat, e: {Nat.add(cap, Nat.mul(q, cap)) == cap : Nat}, w: Spec.Holds(Nat.is_lt(0n, cap))) -> Spec.Holds(Nat.is_eq(1n+q, 1n)):
  match q:
    case 0n:
      Unit{}
    case 1n+r:
      Empty.absurd(Spec.Holds(Nat.is_eq(2n+r, 1n)), one_of_many(r, cap, e, w))

def mul_one(n: Nat, +cap: Nat, e: {Nat.mul(n, cap) == cap : Nat}, w: Spec.Holds(Nat.is_lt(0n, cap))) -> Spec.Holds(Nat.is_eq(n, 1n)):
  match n:
    case 0n:
      zero_cap(cap, e, w)
    case 1n+q:
      mul_one.go(q, cap, e, w)

# each colour in exactly one column

def one_column(+p: Nat, +cap: Nat, +b: List<&2, List<&2, Nat>>, wc: Spec.Holds(Nat.is_eq(Spec.count(p, b), cap)),
  wo: Spec.Holds(Spec.occupied_full_uniform(cap, b)), +wcap: Spec.Holds(Nat.is_lt(0n, cap)))
  -> Spec.Holds(Nat.is_eq(Spec.columns_with(p, b), 1n)):
  mul_one(Spec.columns_with(p, b), cap,
    Equal.trans(Nat, Nat.mul(Spec.columns_with(p, b), cap), Spec.count(p, b), cap,
      Equal.sym(Nat, Spec.count(p, b), Nat.mul(Spec.columns_with(p, b), cap), count_by_columns(p, cap, b, wo, wcap)),
      eq_sound(Spec.count(p, b), cap, wc)), wcap)

def each_one_column(+k: Nat, +cap: Nat, +b: List<&2, List<&2, Nat>>, wc: Spec.Holds(Spec.counts_ok(k, cap, b)),
  +wo: Spec.Holds(Spec.occupied_full_uniform(cap, b)), +wcap: Spec.Holds(Nat.is_lt(0n, cap)))
  -> Spec.Holds(Spec.one_column_each(k, b)):
  match k:
    case 0n:
      Unit{}
    case 1n+p:
      +wc2 = wc
      +here = Nat.is_eq(Spec.count(p, b), cap)
      and_intro(Nat.is_eq(Spec.columns_with(p, b), 1n), Spec.one_column_each(p, b),
        one_column(p, cap, b, and_l(here, Spec.counts_ok(p, cap, b), wc2), wo, wcap),
        each_one_column(p, cap, b, and_r(here, Spec.counts_ok(p, cap, b), wc2), wo, wcap))

def victory.go(+ok: Bool, +o: Bool, -e: Bool, k: Spec.Holds(ok) -> Spec.Holds(o)) -> {(ok && e) == ((o && ok) && e) : Bool}:
  match ok:
    case True{}:
      match o:
        case True{}:
          {==}
        case False{}:
          Empty.absurd({(True{} && e) == ((False{} && True{}) && e) : Bool}, k(Unit{}))
    case False{}:
      match o:
        case True{}:
          {==}
        case False{}:
          {==}

def Laws.victory_is_solved(colours, cap, b, w):
  +a = Nat.is_lt(0n, colours)
  +c = Nat.is_lt(0n, cap)
  +d = Nat.is_eq(Spec.width(b), 1n+colours)
  +f = Spec.fits(cap, b)
  +g = Spec.counts_ok(colours, cap, b)
  +h = Nat.is_eq(Spec.total(b), Nat.mul(colours, cap))
  +wcap = and_r(a, c, and_l(a && c, d, and_l((a && c) && d, f, and_l(((a && c) && d) && f, g, and_l((((a && c) && d) && f) && g, h, w)))))
  +wcounts = and_r(((a && c) && d) && f, g, and_l((((a && c) && d) && f) && g, h, w))
  victory.go(Spec.occupied_full_uniform(cap, b), Spec.one_column_each(colours, b), Nat.is_eq(Spec.empties(b), 1n),
    wo => each_one_column(colours, cap, b, wcounts, wo, wcap))

# Restart and replay
# ------------------

def Laws.restart_goes_back(g):
  match g:
    case Core.Game{c, k, +s, b, h}:
      {==}

# a game is rebuilt by replaying its history from its first board
def Rebuilds(+g: Core.Game) -> Type:
  {Core.replay(Core.oldest_first(Core.history(g)), Core.restart(g)) == g : Core.Game}

def replay_snoc(xs: List<&2, Core.Move>, g: Core.Game, +m: Core.Move)
  -> {Core.replay(List.append(&2, Core.Move, xs, [m]), g) == Core.apply(Core.replay(xs, g), m) : Core.Game}:
  match xs:
    case Nil{}:
      {==}
    case x <> r:
      replay_snoc(r, Core.apply(g, x), m)

def rebuild_fin(+c: Nat, +k: Nat, +s: List<&2, List<&2, Nat>>, +b: List<&2, List<&2, Nat>>, +h: List<&2, Core.Move>, +i: Nat, +j: Nat,
  ok: Bool, e: {Spec.legal(k, b, i, j) == ok : Bool}, pg: Rebuilds(Core.Game{c, k, s, b, h}))
  -> Rebuilds(Core.apply.fin(c, k, s, b, h, i, j, ok)):
  match ok:
    case True{}:
      +g = {Core.Game{c, k, s, b, h} : Core.Game}
      +mv = {Core.Mv{i, j} : Core.Move}
      +r = {Core.Game{c, k, s, s, Nil{}} : Core.Game}
      Equal.trans(Core.Game, Core.replay(List.append(&2, Core.Move, Core.oldest_first(h), [mv]), r), Core.apply(Core.replay(Core.oldest_first(h), r), mv), Core.apply.fin(c, k, s, b, h, i, j, True{}),
        replay_snoc(Core.oldest_first(h), r, mv),
        Equal.trans(Core.Game, Core.apply(Core.replay(Core.oldest_first(h), r), mv), Core.apply(g, mv), Core.apply.fin(c, k, s, b, h, i, j, True{}),
          Equal.cong(Core.Game, Core.Game, x => Core.apply(x, mv), Core.replay(Core.oldest_first(h), r), g, pg),
          Equal.cong(Bool, Core.Game, o => Core.apply.fin(c, k, s, b, h, i, j, o), Spec.legal(k, b, i, j), True{}, e)))
    case False{}:
      pg

def rebuild_apply(g: Core.Game, m: Core.Move, pg: Rebuilds(g)) -> Rebuilds(Core.apply(g, m)):
  match g m:
    case Core.Game{+c, +k, +s, +b, +h} Core.Mv{+i, +j}:
      rebuild_fin(c, k, s, b, h, i, j, Spec.legal(k, b, i, j), {==}, pg)

def rebuild_replay(ms: List<&2, Core.Move>, +g: Core.Game, pg: Rebuilds(g)) -> Rebuilds(Core.replay(ms, g)):
  match ms:
    case Nil{}:
      pg
    case +m <> r:
      rebuild_replay(r, Core.apply(g, m), rebuild_apply(g, m, pg))

def append_nil(xs: List<&2, Core.Move>) -> {List.append(&2, Core.Move, xs, Nil{}) == xs : List<&2, Core.Move>}:
  match xs:
    case Nil{}:
      {==}
    case +x <> r:
      %append_nil(r) : {x <> List.append(&2, Core.Move, r, Nil{}) == x <> _ : List<&2, Core.Move>}
      {==}

def append_assoc(xs: List<&2, Core.Move>, -ys: List<&2, Core.Move>, -zs: List<&2, Core.Move>)
  -> {List.append(&2, Core.Move, List.append(&2, Core.Move, xs, ys), zs) == List.append(&2, Core.Move, xs, List.append(&2, Core.Move, ys, zs)) : List<&2, Core.Move>}:
  match xs:
    case Nil{}:
      {==}
    case +x <> r:
      %append_assoc(r, ys, zs) : {x <> List.append(&2, Core.Move, List.append(&2, Core.Move, r, ys), zs) == x <> _ : List<&2, Core.Move>}
      {==}

# Base's reverse, with its accumulator, is oldest_first followed by the
# accumulator
def rev_go(xs: List<&2, Core.Move>, +acc: List<&2, Core.Move>)
  -> {List.reverse.go(&2, Core.Move, xs, acc) == List.append(&2, Core.Move, Core.oldest_first(xs), acc) : List<&2, Core.Move>}:
  match xs:
    case Nil{}:
      {==}
    case +x <> +r:
      Equal.trans(List<&2, Core.Move>, List.reverse.go(&2, Core.Move, r, x <> acc), List.append(&2, Core.Move, Core.oldest_first(r), x <> acc),
        List.append(&2, Core.Move, List.append(&2, Core.Move, Core.oldest_first(r), [x]), acc),
        rev_go(r, x <> acc),
        Equal.sym(List<&2, Core.Move>, List.append(&2, Core.Move, List.append(&2, Core.Move, Core.oldest_first(r), [x]), acc), List.append(&2, Core.Move, Core.oldest_first(r), x <> acc),
          append_assoc(Core.oldest_first(r), [x], acc)))

def oldest_is_reverse(+h: List<&2, Core.Move>) -> {Core.oldest_first(h) == List.reverse(&2, Core.Move, h) : List<&2, Core.Move>}:
  Equal.sym(List<&2, Core.Move>, List.reverse.go(&2, Core.Move, h, Nil{}), Core.oldest_first(h),
    Equal.trans(List<&2, Core.Move>, List.reverse.go(&2, Core.Move, h, Nil{}), List.append(&2, Core.Move, Core.oldest_first(h), Nil{}), Core.oldest_first(h),
      rev_go(h, Nil{}), append_nil(Core.oldest_first(h))))

def Laws.replay_rebuilds(ms, colours, cap, s):
  +g = Core.replay(ms, Core.new(colours, cap, s))
  %oldest_is_reverse(Core.history(g)) : {Core.replay(_, Core.restart(g)) == g : Core.Game}
  rebuild_replay(ms, Core.new(colours, cap, s), {==})

# Reading a game, and playing a legal move
# ----------------------------------------

def Laws.reads_colours(c, k, s, b, h):
  {==}

def Laws.reads_cap(c, k, s, b, h):
  {==}

def Laws.reads_start(c, k, s, b, h):
  {==}

def Laws.reads_board(c, k, s, b, h):
  {==}

def Laws.reads_history(c, k, s, b, h):
  {==}

def Laws.reads_solved(c, k, s, b, h):
  {==}

def Laws.reads_move(i, j):
  {==}

def Laws.legal_is_played(c, k, s, b, h, i, j, e):
  %Equal.sym(Bool, Spec.legal(k, b, i, j), True{}, e) : {Core.apply.fin(c, k, s, b, h, i, j, _) == Core.Game{c, k, s, Core.transfer(b, i, j), Core.Mv{i, j} <> h} : Core.Game}
  {==}

def Laws.step_accepts_legal(c, k, s, b, h, i, j, e):
  %Equal.sym(Bool, Spec.legal(k, b, i, j), True{}, e) : {Core.step.fin(_, Core.Game{c, k, s, b, h}, Core.Mv{i, j}) == Core.Accepted{Core.apply(Core.Game{c, k, s, b, h}, Core.Mv{i, j}), Spec.top(Spec.column(b, i))} : Core.Outcome}
  {==}

def Laws.step_refuses_illegal(c, k, s, b, h, i, j, e):
  %Equal.sym(Bool, Spec.legal(k, b, i, j), False{}, e) : {Core.step.fin(_, Core.Game{c, k, s, b, h}, Core.Mv{i, j}) == Core.Rejected{Core.why(k, b, i, j)} : Core.Outcome}
  {==}


# Law 7
# -----

def length_succ(h: List<&2, Core.Move>, +n: Nat) -> {Core.length.go(h, 1n+n) == 1n+Core.length.go(h, n) : Nat}:
  match h:
    case Nil{}:
      {==}
    case m <> r:
      length_succ(r, 1n+n)

def count_fin(+c: Nat, +k: Nat, +s: List<&2, List<&2, Nat>>, +b: List<&2, List<&2, Nat>>, +h: List<&2, Core.Move>, +i: Nat, +j: Nat, ok: Bool)
  -> {Core.moves(Core.apply.fin(c, k, s, b, h, i, j, ok)) == Nat.add(Spec.bit(ok), Core.moves(Core.Game{c, k, s, b, h})) : Nat}:
  match ok:
    case True{}:
      length_succ(h, 0n)
    case False{}:
      {==}

def Laws.counts_moves(c, k, s, b, h, i, j):
  count_fin(c, k, s, b, h, i, j, Spec.legal(k, b, i, j))

# Why a move is refused
# ---------------------

def Laws.reason_no_column(k, b, i, j, w):
  +r = Nat.is_lt(i, Spec.width(b)) && Nat.is_lt(j, Spec.width(b))
  %Equal.sym(Bool, Bool.not(r), True{}, holds_eq(Bool.not(r), w)) : {Bool.pick(Core.Reason, _, Core.NoSuchColumn{}, Bool.pick(Core.Reason, Nat.is_eq(i, j), Core.SameColumn{}, Bool.pick(Core.Reason, Spec.is_empty(Spec.column(b, i)), Core.EmptySource{}, Core.FullTarget{}))) == Core.NoSuchColumn{} : Core.Reason}
  {==}

def Laws.reason_same_column(k, b, i, j, w, ws):
  +r = Nat.is_lt(i, Spec.width(b)) && Nat.is_lt(j, Spec.width(b))
  %Equal.sym(Bool, r, True{}, holds_eq(r, w)) : {Bool.pick(Core.Reason, Bool.not(_), Core.NoSuchColumn{}, Bool.pick(Core.Reason, Nat.is_eq(i, j), Core.SameColumn{}, Bool.pick(Core.Reason, Spec.is_empty(Spec.column(b, i)), Core.EmptySource{}, Core.FullTarget{}))) == Core.SameColumn{} : Core.Reason}
  %Equal.sym(Bool, Nat.is_eq(i, j), True{}, holds_eq(Nat.is_eq(i, j), ws)) : {Bool.pick(Core.Reason, _, Core.SameColumn{}, Bool.pick(Core.Reason, Spec.is_empty(Spec.column(b, i)), Core.EmptySource{}, Core.FullTarget{})) == Core.SameColumn{} : Core.Reason}
  {==}

def Laws.reason_empty_source(k, b, i, j, w, ws, we):
  +r = Nat.is_lt(i, Spec.width(b)) && Nat.is_lt(j, Spec.width(b))
  %Equal.sym(Bool, r, True{}, holds_eq(r, w)) : {Bool.pick(Core.Reason, Bool.not(_), Core.NoSuchColumn{}, Bool.pick(Core.Reason, Nat.is_eq(i, j), Core.SameColumn{}, Bool.pick(Core.Reason, Spec.is_empty(Spec.column(b, i)), Core.EmptySource{}, Core.FullTarget{}))) == Core.EmptySource{} : Core.Reason}
  %Equal.sym(Bool, Nat.is_eq(i, j), False{}, holds_not_eq(Nat.is_eq(i, j), ws)) : {Bool.pick(Core.Reason, _, Core.SameColumn{}, Bool.pick(Core.Reason, Spec.is_empty(Spec.column(b, i)), Core.EmptySource{}, Core.FullTarget{})) == Core.EmptySource{} : Core.Reason}
  %Equal.sym(Bool, Spec.is_empty(Spec.column(b, i)), True{}, holds_eq(Spec.is_empty(Spec.column(b, i)), we)) : {Bool.pick(Core.Reason, _, Core.EmptySource{}, Core.FullTarget{}) == Core.EmptySource{} : Core.Reason}
  {==}

def Laws.reason_full_target(k, b, i, j, w, ws, we, wf):
  +r = Nat.is_lt(i, Spec.width(b)) && Nat.is_lt(j, Spec.width(b))
  %Equal.sym(Bool, r, True{}, holds_eq(r, w)) : {Bool.pick(Core.Reason, Bool.not(_), Core.NoSuchColumn{}, Bool.pick(Core.Reason, Nat.is_eq(i, j), Core.SameColumn{}, Bool.pick(Core.Reason, Spec.is_empty(Spec.column(b, i)), Core.EmptySource{}, Core.FullTarget{}))) == Core.FullTarget{} : Core.Reason}
  %Equal.sym(Bool, Nat.is_eq(i, j), False{}, holds_not_eq(Nat.is_eq(i, j), ws)) : {Bool.pick(Core.Reason, _, Core.SameColumn{}, Bool.pick(Core.Reason, Spec.is_empty(Spec.column(b, i)), Core.EmptySource{}, Core.FullTarget{})) == Core.FullTarget{} : Core.Reason}
  %Equal.sym(Bool, Spec.is_empty(Spec.column(b, i)), False{}, holds_not_eq(Spec.is_empty(Spec.column(b, i)), we)) : {Bool.pick(Core.Reason, _, Core.EmptySource{}, Core.FullTarget{}) == Core.FullTarget{} : Core.Reason}
  {==}

# Validity is kept
# ----------------

def Laws.valid_after_restart(c, k, s, b, h, w):
  w

def eq_rw(-x: Nat, -y: Nat, e: {x == y : Nat}, +n: Nat, w: Spec.Holds(Nat.is_eq(y, n))) -> Spec.Holds(Nat.is_eq(x, n)):
  %Equal.sym(Nat, x, y, e) : Spec.Holds(Nat.is_eq(_, n))
  w

def width_rw(-x: Nat, -y: Nat, e: {x == y : Nat}, +n: Nat, w: Spec.Holds(Nat.is_eq(y, n))) -> Spec.Holds(Nat.is_eq(x, n)):
  eq_rw(x, y, e, n, w)

def counts_keep(+kk: Nat, +k: Nat, +b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, +wm: Spec.Holds(Spec.movable(b, i, j)), w: Spec.Holds(Spec.counts_ok(kk, k, b)))
  -> Spec.Holds(Spec.counts_ok(kk, k, Core.transfer(b, i, j))):
  match kk:
    case 0n:
      Unit{}
    case 1n+p:
      +w2 = w
      +here = Nat.is_eq(Spec.count(p, b), k)
      and_intro(Nat.is_eq(Spec.count(p, Core.transfer(b, i, j)), k), Spec.counts_ok(p, k, Core.transfer(b, i, j)),
        eq_rw(Spec.count(p, Core.transfer(b, i, j)), Spec.count(p, b),
          cons_go(p, b, i, j, Spec.column(b, i), {==}, mv_i(b, i, j, wm), mv_j(b, i, j, wm), mv_ne(b, i, j, wm)), k,
          and_l(here, Spec.counts_ok(p, k, b), w2)),
        counts_keep(p, k, b, i, j, wm, and_r(here, Spec.counts_ok(p, k, b), w2)))

def valid_transfer(+c: Nat, +k: Nat, +b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, +wl: Spec.Holds(Spec.legal(k, b, i, j)), +w: Spec.Holds(Spec.valid(c, k, b)))
  -> Spec.Holds(Spec.valid(c, k, Core.transfer(b, i, j))):
  +t = Core.transfer(b, i, j)
  +wm = legal_mv(k, b, i, j, wl)
  +a = Nat.is_lt(0n, c)
  +bb = Nat.is_lt(0n, k)
  +cc = Nat.is_eq(Spec.width(b), 1n+c)
  +d = Spec.fits(k, b)
  +e = Spec.counts_ok(c, k, b)
  +f = Nat.is_eq(Spec.total(b), Nat.mul(c, k))
  +cc2 = Nat.is_eq(Spec.width(t), 1n+c)
  +d2 = Spec.fits(k, t)
  +e2 = Spec.counts_ok(c, k, t)
  +f2 = Nat.is_eq(Spec.total(t), Nat.mul(c, k))
  +wab = and_l((((a && bb) && cc) && d), e, and_l(((((a && bb) && cc) && d) && e), f, w))
  +wabc = and_l((a && bb) && cc, d, wab)
  and_intro(((((a && bb) && cc2) && d2) && e2), f2,
    and_intro((((a && bb) && cc2) && d2), e2,
      and_intro(((a && bb) && cc2), d2,
        and_intro((a && bb), cc2,
          and_l(a && bb, cc, wabc),
          width_rw(Spec.width(t), Spec.width(b), width_go(b, i, j, Spec.column(b, i)), 1n+c, and_r(a && bb, cc, wabc))),
        cap_go(k, b, i, j, Spec.column(b, i), {==}, and_r((a && bb) && cc, d, wab), legal_room(k, b, i, j, wl))),
      counts_keep(c, k, b, i, j, wm, and_r((((a && bb) && cc) && d), e, and_l(((((a && bb) && cc) && d) && e), f, w)))),
    eq_rw(Spec.total(t), Spec.total(b), tot_go(b, i, j, Spec.column(b, i), {==}, mv_i(b, i, j, wm), mv_j(b, i, j, wm), mv_ne(b, i, j, wm)), Nat.mul(c, k),
      and_r(((((a && bb) && cc) && d) && e), f, w)))

def valid_fin(+c: Nat, +k: Nat, -s: List<&2, List<&2, Nat>>, +b: List<&2, List<&2, Nat>>, -h: List<&2, Core.Move>, +i: Nat, +j: Nat,
  ok: Bool, e: {Spec.legal(k, b, i, j) == ok : Bool}, +w: Spec.Holds(Spec.valid(c, k, b)))
  -> Spec.Holds(Spec.valid(c, k, Core.board(Core.apply.fin(c, k, s, b, h, i, j, ok)))):
  match ok:
    case True{}:
      valid_transfer(c, k, b, i, j, holds_true(Spec.legal(k, b, i, j), e), w)
    case False{}:
      w

def Laws.valid_after_move(c, k, s, b, h, i, j, w):
  valid_fin(c, k, s, b, h, i, j, Spec.legal(k, b, i, j), {==}, w)

# Every reached game keeps colours' cap k, a valid board, and a valid board
# after one undo.
def Reached(+c: Nat, +k: Nat, +g: Core.Game) -> Type:
  {Core.cap(g) == k : Nat} & Spec.Holds(Spec.valid(c, k, Core.board(g)) && Spec.valid(c, k, Core.board(Core.undo(g))))

def undo_cap(+c: Nat, -k2: Nat, -k: Nat, +c2: Nat, +s: List<&2, List<&2, Nat>>, +b: List<&2, List<&2, Nat>>, +h: List<&2, Core.Move>,
  e: {k2 == k : Nat}, w: Spec.Holds(Spec.valid(c, k, Core.board(Core.undo(Core.Game{c2, k2, s, b, h})))))
  -> Spec.Holds(Spec.valid(c, k, Core.board(Core.undo(Core.Game{c2, k, s, b, h})))):
  %e : Spec.Holds(Spec.valid(c, k, Core.board(Core.undo(Core.Game{c2, _, s, b, h}))))
  w

def valid_rw(+c: Nat, +k: Nat, -x: List<&2, List<&2, Nat>>, -y: List<&2, List<&2, Nat>>, e: {x == y : List<&2, List<&2, Nat>>}, w: Spec.Holds(Spec.valid(c, k, y)))
  -> Spec.Holds(Spec.valid(c, k, x)):
  %Equal.sym(List<&2, List<&2, Nat>>, x, y, e) : Spec.Holds(Spec.valid(c, k, _))
  w

def reached_fin(+c: Nat, +k: Nat, +c2: Nat, +s: List<&2, List<&2, Nat>>, +b: List<&2, List<&2, Nat>>, +h: List<&2, Core.Move>, +i: Nat, +j: Nat,
  ok: Bool, e: {Spec.legal(k, b, i, j) == ok : Bool}, +wv: Spec.Holds(Spec.valid(c, k, b)), wu: Spec.Holds(Spec.valid(c, k, Core.board(Core.undo(Core.Game{c2, k, s, b, h})))))
  -> Reached(c, k, Core.apply.fin(c2, k, s, b, h, i, j, ok)):
  match ok:
    case True{}:
      +wl = holds_true(Spec.legal(k, b, i, j), e)
      +wm = legal_mv(k, b, i, j, wl)
      +t = Core.transfer(b, i, j)
      ({==}, and_intro(Spec.valid(c, k, t), Spec.valid(c, k, Core.transfer(t, j, i)),
        valid_transfer(c, k, b, i, j, wl, wv),
        valid_rw(c, k, Core.transfer(t, j, i), b, back_go(b, i, j, Spec.column(b, i), {==}, mv_src(b, i, j, wm), mv_i(b, i, j, wm), mv_j(b, i, j, wm), mv_ne(b, i, j, wm)), wv)))
    case False{}:
      ({==}, and_intro(Spec.valid(c, k, b), Spec.valid(c, k, Core.board(Core.undo(Core.Game{c2, k, s, b, h}))), wv, wu))

def reached_apply(+c: Nat, +k: Nat, g: Core.Game, m: Core.Move, r: Reached(c, k, g)) -> Reached(c, k, Core.apply(g, m)):
  match g m:
    case Core.Game{+c2, +k2, +s, +b, +h} Core.Mv{+i, +j}:
      (ek0, both) = r
      +ek = ek0
      +both2 = both
      +wv = and_l(Spec.valid(c, k, b), Spec.valid(c, k, Core.board(Core.undo(Core.Game{c2, k2, s, b, h}))), both2)
      +wu = and_r(Spec.valid(c, k, b), Spec.valid(c, k, Core.board(Core.undo(Core.Game{c2, k2, s, b, h}))), both2)
      %Equal.sym(Nat, k2, k, ek) : Reached(c, k, Core.apply.fin(c2, _, s, b, h, i, j, Spec.legal(_, b, i, j)))
      reached_fin(c, k, c2, s, b, h, i, j, Spec.legal(k, b, i, j), {==}, wv, undo_cap(c, k2, k, c2, s, b, h, ek, wu))

def reached_replay(ms: List<&2, Core.Move>, +c: Nat, +k: Nat, +g: Core.Game, r: Reached(c, k, g)) -> Reached(c, k, Core.replay(ms, g)):
  match ms:
    case Nil{}:
      r
    case +m <> rest:
      reached_replay(rest, c, k, Core.apply(g, m), reached_apply(c, k, g, m, r))

def reached_new(+c: Nat, +k: Nat, +s: List<&2, List<&2, Nat>>, +w: Spec.Holds(Spec.valid(c, k, s))) -> Reached(c, k, Core.new(c, k, s)):
  ({==}, and_intro(Spec.valid(c, k, s), Spec.valid(c, k, s), w, w))

def reached_board(+c: Nat, +k: Nat, +g: Core.Game, r: Reached(c, k, g)) -> Spec.Holds(Spec.valid(c, k, Core.board(g))):
  (ek, both) = r
  and_l(Spec.valid(c, k, Core.board(g)), Spec.valid(c, k, Core.board(Core.undo(g))), both)

def reached_undo(+c: Nat, +k: Nat, +g: Core.Game, r: Reached(c, k, g)) -> Spec.Holds(Spec.valid(c, k, Core.board(Core.undo(g)))):
  (ek, both) = r
  and_r(Spec.valid(c, k, Core.board(g)), Spec.valid(c, k, Core.board(Core.undo(g))), both)

def Laws.valid_when_reached(ms, c, k, s, w):
  reached_board(c, k, Core.replay(ms, Core.new(c, k, s)), reached_replay(ms, c, k, Core.new(c, k, s), reached_new(c, k, s, w)))

def Laws.valid_after_undo(ms, c, k, s, w):
  reached_undo(c, k, Core.replay(ms, Core.new(c, k, s)), reached_replay(ms, c, k, Core.new(c, k, s), reached_new(c, k, s, w)))

# Legal targets
# -------------
# below(t, n): t is one of the first n columns and a legal target.

def below(+k: Nat, +b: List<&2, List<&2, Nat>>, +i: Nat, +t: Nat, +n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      (Nat.is_eq(t, p) && Spec.legal(k, b, i, p)) || below(k, b, i, t, p)

def bool_a(x: Bool, y: Bool, z: Bool) -> {(y || (x || z)) == (((x && True{}) || y) || z) : Bool}:
  match x y z:
    case True{} True{} True{}:
      {==}
    case True{} True{} False{}:
      {==}
    case True{} False{} True{}:
      {==}
    case True{} False{} False{}:
      {==}
    case False{} True{} True{}:
      {==}
    case False{} True{} False{}:
      {==}
    case False{} False{} True{}:
      {==}
    case False{} False{} False{}:
      {==}

def bool_b(x: Bool, y: Bool, z: Bool) -> {(y || z) == (((x && False{}) || y) || z) : Bool}:
  match x y z:
    case True{} True{} True{}:
      {==}
    case True{} True{} False{}:
      {==}
    case True{} False{} True{}:
      {==}
    case True{} False{} False{}:
      {==}
    case False{} True{} True{}:
      {==}
    case False{} True{} False{}:
      {==}
    case False{} False{} True{}:
      {==}
    case False{} False{} False{}:
      {==}

def tg_step(l: Bool, +p: Nat, +acc: List<&2, Nat>, +t: Nat, +y: Bool)
  -> {(y || Spec.has(Bool.pick(List<&2, Nat>, l, p <> acc, acc), t)) == (((Nat.is_eq(t, p) && l) || y) || Spec.has(acc, t)) : Bool}:
  match l:
    case True{}:
      bool_a(Nat.is_eq(t, p), y, Spec.has(acc, t))
    case False{}:
      bool_b(Nat.is_eq(t, p), y, Spec.has(acc, t))

def tg_go(+k: Nat, +b: List<&2, List<&2, Nat>>, +i: Nat, +t: Nat, +n: Nat, +acc: List<&2, Nat>)
  -> {Spec.has(Core.targets.go(k, b, i, n, acc), t) == (below(k, b, i, t, n) || Spec.has(acc, t)) : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      +l = Spec.legal(k, b, i, p)
      +acc2 = Bool.pick(List<&2, Nat>, l, p <> acc, acc)
      Equal.trans(Bool, Spec.has(Core.targets.go(k, b, i, p, acc2), t), below(k, b, i, t, p) || Spec.has(acc2, t),
        ((Nat.is_eq(t, p) && l) || below(k, b, i, t, p)) || Spec.has(acc, t),
        tg_go(k, b, i, t, p, acc2),
        tg_step(l, p, acc, t, below(k, b, i, t, p)))

def or_false(x: Bool) -> {(x || False{}) == x : Bool}:
  match x:
    case True{}:
      {==}
    case False{}:
      {==}

def below_step.top(r: Nat, -y: Bool) -> {(False{} || False{}) == (Nat.is_lt(1n+r, 1n) && y) : Bool}:
  match r:
    case 0n:
      {==}
    case 1n+s:
      {==}

def below_step(t: Nat, p: Nat, +x: Bool, -y: Bool, f: {t == p : Nat} -> {x == y : Bool})
  -> {((Nat.is_eq(t, p) && x) || (Nat.is_lt(t, p) && y)) == (Nat.is_lt(t, 1n+p) && y) : Bool}:
  match t p:
    case 0n 0n:
      Equal.trans(Bool, x || False{}, x, y, or_false(x), f({==}))
    case 0n 1n+q:
      {==}
    case 1n+r 0n:
      below_step.top(r, y)
    case 1n+r 1n+q:
      below_step(r, q, x, y, e => f(Equal.cong(Nat, Nat, n => 1n+n, r, q, e)))

def below_zero(+k: Nat, +b: List<&2, List<&2, Nat>>, +i: Nat, t: Nat) -> {False{} == (Nat.is_lt(t, 0n) && Spec.legal(k, b, i, t)) : Bool}:
  match t:
    case 0n:
      {==}
    case 1n+r:
      {==}

def below_eq(+k: Nat, +b: List<&2, List<&2, Nat>>, +i: Nat, +t: Nat, +n: Nat)
  -> {below(k, b, i, t, n) == (Nat.is_lt(t, n) && Spec.legal(k, b, i, t)) : Bool}:
  match n:
    case 0n:
      below_zero(k, b, i, t)
    case 1n+p:
      %Equal.sym(Bool, below(k, b, i, t, p), Nat.is_lt(t, p) && Spec.legal(k, b, i, t), below_eq(k, b, i, t, p)) : {((Nat.is_eq(t, p) && Spec.legal(k, b, i, p)) || _) == (Nat.is_lt(t, 1n+p) && Spec.legal(k, b, i, t)) : Bool}
      below_step(t, p, Spec.legal(k, b, i, p), Spec.legal(k, b, i, t),
        e => Equal.cong(Nat, Bool, q => Spec.legal(k, b, i, q), p, t, Equal.sym(Nat, t, p, e)))

def and_implied(+l: Bool, +a: Bool, f: Spec.Holds(l) -> Spec.Holds(a)) -> {(a && l) == l : Bool}:
  match l:
    case True{}:
      match a:
        case True{}:
          {==}
        case False{}:
          Empty.absurd({(False{} && True{}) == True{} : Bool}, f(Unit{}))
    case False{}:
      match a:
        case True{}:
          {==}
        case False{}:
          {==}

def Laws.targets_are_legal(c, k, s, b, h, i, t):
  +w = Spec.width(b)
  +l = Spec.legal(k, b, i, t)
  +bl = below(k, b, i, t, w)
  Equal.trans(Bool, Spec.has(Core.targets.go(k, b, i, w, Nil{}), t), bl || False{}, l, tg_go(k, b, i, t, w, Nil{}),
    Equal.trans(Bool, bl || False{}, bl, l, or_false(bl),
      Equal.trans(Bool, bl, Nat.is_lt(t, w) && l, l, below_eq(k, b, i, t, w),
        and_implied(l, Nat.is_lt(t, w), wl => mv_j(b, i, t, legal_mv(k, b, i, t, wl))))))

# Generated puzzles are solvable
# ------------------------------
# generate answers Some only from emit, and only when the puzzle passed
# accept, whose first half is exactly what the law claims.

def maybe_disc(m: Maybe<&2, Gen.Puzzle>) -> Data:
  match m:
    case None{}:
      Unit
    case Some{p}:
      Empty

def none_ne_some(-p: Gen.Puzzle, e: {None{} == Some{p} : Maybe<&2, Gen.Puzzle>}) -> Empty:
  %e : maybe_disc(_)
  Unit{}

def pboard(m: Maybe<&2, Gen.Puzzle>) -> List<&2, List<&2, Nat>>:
  match m:
    case None{}:
      Nil{}
    case Some{p}:
      match p:
        case Gen.Puzzle{b, c}:
          b

def pcert(m: Maybe<&2, Gen.Puzzle>) -> List<&2, Core.Move>:
  match m:
    case None{}:
      Nil{}
    case Some{p}:
      match p:
        case Gen.Puzzle{b, c}:
          c

def emit_ok(+colours: Nat, +cap: Nat, +pb: List<&2, List<&2, Nat>>, +pc: List<&2, Core.Move>, -b: List<&2, List<&2, Nat>>, -cert: List<&2, Core.Move>,
  -rest: Unit -> Maybe<&2, Gen.Puzzle>,
  ih: {rest(Unit{}) == Some{Gen.Puzzle{b, cert}} : Maybe<&2, Gen.Puzzle>} -> Spec.Holds(Gen.sound(colours, cap, b, cert)),
  ok: Bool, eo: {Gen.accept(colours, cap, pb, pc) == ok : Bool},
  +e: {Gen.emit(ok, Gen.Puzzle{pb, pc}, rest) == Some{Gen.Puzzle{b, cert}} : Maybe<&2, Gen.Puzzle>})
  -> Spec.Holds(Gen.sound(colours, cap, b, cert)):
  match ok:
    case True{}:
      +so = Gen.sound(colours, cap, pb, pc)
      ws = and_l(so, Gen.mixed(colours, cap, pb), holds_true(Gen.accept(colours, cap, pb, pc), eo))
      eb = Equal.cong(Maybe<&2, Gen.Puzzle>, List<&2, List<&2, Nat>>, pboard, Some{Gen.Puzzle{pb, pc}}, Some{Gen.Puzzle{b, cert}}, e)
      ec = Equal.cong(Maybe<&2, Gen.Puzzle>, List<&2, Core.Move>, pcert, Some{Gen.Puzzle{pb, pc}}, Some{Gen.Puzzle{b, cert}}, e)
      %eb : Spec.Holds(Gen.sound(colours, cap, _, cert))
      %ec : Spec.Holds(Gen.sound(colours, cap, pb, _))
      ws
    case False{}:
      ih(e)

def attempt_ok(+colours: Nat, +cap: Nat, p: Gen.Puzzle, -b: List<&2, List<&2, Nat>>, -cert: List<&2, Core.Move>,
  -rest: Unit -> Maybe<&2, Gen.Puzzle>,
  ih: {rest(Unit{}) == Some{Gen.Puzzle{b, cert}} : Maybe<&2, Gen.Puzzle>} -> Spec.Holds(Gen.sound(colours, cap, b, cert)),
  e: {Gen.attempt(colours, cap, p, rest) == Some{Gen.Puzzle{b, cert}} : Maybe<&2, Gen.Puzzle>})
  -> Spec.Holds(Gen.sound(colours, cap, b, cert)):
  match p:
    case Gen.Puzzle{+pb, +pc}:
      emit_ok(colours, cap, pb, pc, b, cert, rest, ih, Gen.accept(colours, cap, pb, pc), {==}, e)

def tries_ok(+n: Nat, +colours: Nat, +cap: Nat, +seed: U32, +steps: Nat, -b: List<&2, List<&2, Nat>>, -cert: List<&2, Core.Move>,
  e: {Gen.tries(n, colours, cap, seed, steps) == Some{Gen.Puzzle{b, cert}} : Maybe<&2, Gen.Puzzle>})
  -> Spec.Holds(Gen.sound(colours, cap, b, cert)):
  match n:
    case 0n:
      Empty.absurd(Spec.Holds(Gen.sound(colours, cap, b, cert)), none_ne_some(Gen.Puzzle{b, cert}, e))
    case 1n+p:
      attempt_ok(colours, cap, Gen.candidate(colours, cap, Gen.rng.attempt(seed, 1n+p), steps), b, cert,
        u => Gen.tries(p, colours, cap, seed, steps),
        e2 => tries_ok(p, colours, cap, seed, steps, b, cert, e2),
        e)

def Laws.generated_puzzles_solve(colours, cap, seed, b, cert, e):
  tries_ok(16n, colours, cap, seed, Nat.mul(4n, Nat.mul(1n+colours, cap)), b, cert, e)


# Building and reading games
# --------------------------

def Laws.new_is_fresh(c, k, b):
  {==}

def length_is(h: List<&2, Core.Move>, +n: Nat) -> {Core.length.go(h, n) == Nat.add(List.length(&2, Core.Move, h), n) : Nat}:
  match h:
    case Nil{}:
      {==}
    case m <> +r:
      Equal.trans(Nat, Core.length.go(r, 1n+n), Nat.add(List.length(&2, Core.Move, r), 1n+n), 1n+Nat.add(List.length(&2, Core.Move, r), n),
        length_is(r, 1n+n), add_succ_r(List.length(&2, Core.Move, r), n))

def Laws.moves_is_history(c, k, s, b, h):
  Equal.trans(Nat, Core.length.go(h, 0n), Nat.add(List.length(&2, Core.Move, h), 0n), List.length(&2, Core.Move, h),
    length_is(h, 0n), add_zero_r(List.length(&2, Core.Move, h)))

def Laws.replay_nothing(g):
  {==}

def Laws.replay_in_order(m, ms, g):
  {==}
