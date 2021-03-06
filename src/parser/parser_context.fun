functor ParserContext(structure Label : LABEL) :> PARSER_CONTEXT where type label = Label.t =
struct
  type label = Label.t

  structure Dict = SplayDict(structure Key = Label)
  type world =
    {initial : Arity.t Dict.dict,
     added : Arity.t Dict.dict}

  exception NoSuchOperator of label

  fun new bnds =
    {initial =
       List.foldl
         (fn ((lbl, a), wld) => Dict.insert wld lbl a)
         Dict.empty
         bnds,
     added = Dict.empty}

  fun lookupOperator {initial, added} lbl =
    case Dict.find added lbl of
        NONE => (Dict.lookup initial lbl handle _ => raise NoSuchOperator lbl)
      | SOME a => a

  fun declareOperator {initial, added} (lbl, arity) =
    {initial = initial,
     added = Dict.insert added lbl arity}

  fun enumerateOperators {initial, added} =
    Dict.toList added
end

structure StringVariableContext = ParserContext(structure Label = StringVariable)
