functor CttUtil
  (structure Lcf : LCF_APART
   structure Syntax : ABT
   structure Conv : CONV
     where type term = Syntax.t
   structure Ctt : CTT
      where type tactic = Lcf.tactic
      where type conv = Conv.conv
      where type term = Syntax.t
      where type name = Syntax.Variable.t) : CTT_UTIL =
struct
  structure Lcf = Lcf
  structure Tacticals = ProgressTacticals(Lcf)
  open Conv Ctt

  structure Conversionals = Conversionals
    (structure Syntax = Syntax
     structure Conv = Conv)

  open Tacticals Rules
  infix ORELSE ORELSE_LAZY THEN

  type intro_args =
    {term : term option,
     invertible : bool,
     rule : int option,
     freshVariable : name option,
     level : Level.t option}

  type elim_args =
    {target : int,
     names : name list,
     term : term option}

  type eq_cd_args =
    {names : name list,
     invertible : bool,
     level : Level.t option,
     terms : term list}

  type ext_args =
    {freshVariable : name option,
     level : Level.t option}

  fun Intro {term,rule,invertible,freshVariable,level} =
     UnitIntro
       ORELSE Assumption
       ORELSE_LAZY (fn _ => case valOf rule of
                                0 => PlusIntroL level
                              | 1 => PlusIntroR level
                              | _ => raise Fail "Out of range for PLUS")
       ORELSE FunIntro (freshVariable, level)
       ORELSE IsectIntro (freshVariable, level)
       ORELSE_LAZY (fn _ => ProdIntro (valOf term, freshVariable, level))
       ORELSE IndependentProdIntro
       ORELSE_LAZY (fn _ => SubsetIntro (valOf term, freshVariable, level))
       ORELSE IndependentSubsetIntro
       ORELSE CEqRefl
       ORELSE ApproxRefl
       ORELSE BaseIntro
       ORELSE MemCD
       ORELSE
       (if not invertible then
            CEqStruct
        else
            FAIL)

  fun take2 (x::y::_) = SOME (x,y)
    | take2 _ = NONE

  fun take3 (x::y::z::_) = SOME (x,y,z)
    | take3 _ = NONE

  fun listAt (xs, n) = SOME (List.nth (xs, n)) handle _ => NONE

  fun Elim {target, names, term} =
    let
      val twoNames = take2 names
    in
      (VoidElim THEN Hypothesis target)
        ORELSE UnitElim target
        ORELSE_LAZY (fn _ => BaseElimEq (target, listAt (names, 0)))
        ORELSE_LAZY (fn _ => PlusElim (target, twoNames))
        ORELSE_LAZY (fn _ => ProdElim (target, twoNames))
        ORELSE_LAZY (fn _ => FunElim (target, valOf term, twoNames))
        ORELSE_LAZY (fn _ => IsectElim (target, valOf term, twoNames))
        ORELSE NatElim (target, twoNames)
        ORELSE SubsetElim (target, twoNames)
    end

  fun EqCD {names, level, invertible, terms} =
    let
      val freshVariable = listAt (names, 0)
    in
      AxEq
        ORELSE EqEq
        ORELSE CEqEq
        ORELSE UnitEq
        ORELSE VoidEq
        ORELSE HypEq
        ORELSE UnivEq
        ORELSE PlusEq
        ORELSE InlEq level
        ORELSE InrEq level
        ORELSE BaseEq
        ORELSE BaseMemberEq
        ORELSE FunEq freshVariable
        ORELSE IsectEq freshVariable
        ORELSE ProdEq freshVariable
        ORELSE SubsetEq freshVariable
        ORELSE PairEq (freshVariable, level)
        ORELSE LamEq (freshVariable, level)
        ORELSE SubsetMemberEq (freshVariable, level)
        ORELSE IsectMemberEq (freshVariable, level)
        ORELSE_LAZY (fn _ =>
          case terms of
               [M, N] => IsectMemberCaseEq (SOME M, N)
             | [N] => IsectMemberCaseEq (NONE, N)
             | _ => FAIL)
        ORELSE NatEq
        ORELSE ZeroEq
        ORELSE SuccEq
        ORELSE Cum level
        ORELSE EqInSupertype
        ORELSE
        (if not invertible then
             NatRecEq (listAt (terms, 0), take2 names)
               ORELSE_LAZY (fn _ => DecideEq (List.nth (terms, 0))
                                             (List.nth (terms, 1),
                                              List.nth (terms, 2),
                                              take3 names))
               ORELSE SpreadEq (listAt (terms, 0), listAt (terms, 1), take3 names)
               ORELSE ApEq (listAt (terms, 0))
         else
             FAIL)

    end

  fun Ext {freshVariable, level} =
    FunExt (freshVariable, level)

  local
    val InvAutoEqCD = EqCD {names = [],
                            level = NONE,
                            invertible = true,
                            terms = []}
    val AutoEqCD = EqCD {names = [],
                         level = NONE,
                         invertible = false,
                         terms = []}

    val AutoVoidElim = VoidElim THEN Assumption

    val InvAutoIntro = Intro {term = NONE,
                              rule = NONE,
                              invertible = true,
                              freshVariable = NONE,
                              level = NONE}
    val AutoIntro = Intro {term = NONE,
                           rule = NONE,
                           invertible = false,
                           freshVariable = NONE,
                           level = NONE}

    open Conversions Conversionals
    infix CORELSE

    val DeepReduce = RewriteGoal (CDEEP Step)
  in
    fun FinAuto 0 = LIMIT (InvAutoIntro ORELSE AutoVoidElim ORELSE InvAutoEqCD)
      | FinAuto n = FinAuto 0 THEN (AutoIntro ORELSE AutoEqCD) THEN FinAuto (n - 1)

    val InfAuto = LIMIT (AutoIntro ORELSE AutoVoidElim ORELSE AutoEqCD)

    fun Auto NONE = InfAuto
      | Auto (SOME n) = FinAuto n

    fun Reduce NONE = LIMIT DeepReduce
      | Reduce (SOME n) =
        let
          fun go 0 = ID
            | go n = DeepReduce THEN (go (n - 1))
        in
          go n
        end
  end

  local
    structure Tacticals = Tacticals (Lcf)
    open Tacticals Sequent
    infix THENL >>
  in
    fun CutLemma (world, lbl) =
      let
        val {statement,...} = Ctt.Development.lookupTheorem world lbl
        val H >> P = statement
        val _ = if Context.eq (H, Context.empty) then () else raise Fail "nonempty context"
        val name = Syntax.Variable.named (Ctt.Development.Telescope.Label.toString lbl)
      in
        Assert (P, SOME name)
          THENL [Lemma (world, lbl), ID]
      end
  end

end

structure CttUtil = CttUtil
  (structure Syntax = Syntax and Lcf = Lcf and Conv = Conv and Ctt = Ctt)
