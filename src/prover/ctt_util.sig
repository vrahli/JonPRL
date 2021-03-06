signature CTT_UTIL =
sig
  include CTT
  val Auto : int option -> tactic

  type intro_args =
    {term : term option,
     rule : int option,
     invertible : bool,
     freshVariable : name option,
     level : Level.t option}

  type elim_args =
    {target : int,
     names : name list,
     term : term option}

  type eq_cd_args =
    {names : name list,
     level : Level.t option,
     invertible : bool,
     terms : term list}

  type ext_args =
    {freshVariable : name option,
     level : Level.t option}

  val Intro : intro_args -> tactic
  val Elim : elim_args -> tactic
  val EqCD : eq_cd_args -> tactic
  val Ext : ext_args -> tactic

  val Reduce : int option -> tactic
  val CutLemma : Development.world * Development.label -> tactic

end
