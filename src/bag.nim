# Validate HTTP input data in a fancy way
# 
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bag

import pkg/valido
import std/[macros, tables]

type
  TField* = enum
    TButton
    TCheckbox
    TColor
    TDate
    TDatalist
    TEmail
    TFile
    THidden
    TMonth
    TNumber
    TPassword
    TTextarea
    TRadio
    TRange
    TReset
    TSelect
    TSearch
    TSubmit
    TTel
    TText
    TTime
    TUrl
    TWeek
    # special `text` based fields 
    TBase32
    TBase58
    TBase64
    TCard
    TCountry
    TCountryState
    TCountryCapital
    TCurrency
    TEAN
    TIP
    TJSON
    TMD5
    TPort
    TAlpha
    TAlphanumeric
    TUppercase
    TLowercase
    TBool
    TFloat
    THex
    TRegex
    TUUID
    TCSRF

  MinMax* = ref object
    length: int
    error: string

  Rule* = ref object
    id*: string
    required*: bool
    ftype*: TField
    error*: string
    min*, max*: MinMax

  Rules* = OrderedTable[string, Rule]
  
  InputBag* = ref object
    failed: seq[(string, string)]
    rules: Rules

proc isValid*(bag: InputBag): bool =
  result = bag.failed.len == 0

proc isInvalid*(bag: InputBag): bool =
  result = bag.failed.len != 0

proc getErrors*(bag: InputBag): seq[(string, string)] =
  result = bag.failed

proc addRule*(bag: InputBag, rule: Rule) =
  bag.rules[rule.id] = rule

template Fail() =
  add bag.failed, (rule.id, rule.error)

template Fail(error: string) =
  add bag.failed, (rule.id, error)

template minMaxCheck() =
  if rule.min != nil:
    if not valido.isMin(f[1], rule.min.length):
      Fail rule.min.error
  if rule.max != nil:
    if not valido.isMax(f[1], rule.max.length):
      Fail rule.max.error

proc validate*(bag: InputBag, data: seq[(string, string)]) =
  for f in data:
    if bag.rules.hasKey(f[0]):
      let rule = bag.rules[f[0]]
      case rule.ftype:
      of TEmail:
        if not valido.isEmail(f[1]): Fail
      of TPassword:
        if not valido.isStrongPassword(f[1]): Fail
      of TCheckbox:
        if f[1] != "on": Fail
      of TText:
        if rule.required:
          if valido.isEmpty(f[1]): Fail
          else: minMaxCheck
        else: minMaxCheck
      of TTextarea:
        if rule.required:
          if isEmpty(f[1]): Fail
          else: minMaxCheck
        else: minMaxCheck
      else: discard
      bag.rules.del(f[0])
  for k, rule in pairs bag.rules:
    if rule.required:
      add bag.failed, (rule.id, rule.error)
  bag.rules.clear()

proc parseRule(rule: NimNode, isRequired = true): NimNode {.compileTime.} =
  expectKind rule[0], nnkIdent
  expectKind rule[1], nnkStmtList
  var newRule = newTree(nnkObjConstr).add(ident "Rule")
  for r in rule[1]:
    if r.kind == nnkIdent:
      newRule.add(
        newColonExpr(ident "id", newLit rule[0].strVal),
        newColonExpr(ident "ftype", ident r.strVal),
        newColonExpr(ident "required", newLit isRequired),
      )
    elif r.kind == nnkInfix:
      if r[0].kind == nnkIdent:
        if r[0].strVal == "or":
          expectKind r[2], nnkStrLit
          expectKind r[1], nnkIdent
          newRule.add(
            newColonExpr(ident "id", newLit rule[0].strVal),
            newColonExpr(ident "ftype", ident r[1].strVal),
            newColonExpr(ident "required", newLit isRequired),
            newColonExpr(ident "error", r[2])
          )
      if r.len == 4:
        expectKind r[3], nnkStmtList
        for c in r[3]: # parse criterias
          expectKind c, nnkCall
          expectKind c[0], nnkIdent
          expectKind c[1], nnkStmtList
          if eqIdent(c[0], "min") or eqIdent(c[0], "max"):
            newRule.add(
              newColonExpr(c[0],
                nnkObjConstr.newTree(
                  ident "MinMax",
                  newColonExpr(
                    ident "length",
                    c[1][0][1]
                  ),
                  newColonExpr(
                    ident "error",
                    c[1][0][2]
                  )
                )
              )
            )
  result = newRule

macro newBag*(data, rules) =
  ## Create a new input bag validation at compile time.
  ##
  ## `data` expects a `seq[tuple[k, v: string]]`
  ## that represent submitted data from the current request.
  ##
  ## `rules` is used to define your rules at compile-time.
  runnableExamples:
    let data = [
      ("email": "test@example.com"),
      ("password", "123admin"),
      ("remember", "on")
    ]
    newBag data:
      email: TEmail or "Invalid email address"
      password: TPassword or "Invalid password"
      *remember: TCheckbox  # optional field, default: off/false

  expectKind rules, nnkStmtList
  result = newStmtList()
  let varBagInstance = newVarStmt(
    ident "Bag",
    newCall(ident "InputBag")
  )
  var rulesList = newStmtList()
  for r in rules:
    if r.kind == nnkCall:
      # handle required fields
      let node = parseRule(r)
      # echo node.repr
      rulesList.add(
        newCall(
          ident "addRule",
          ident "Bag",
          node
        )
      )
    elif r.kind == nnkPrefix:
      # handle optional fields
      discard

  result.add varBagInstance
  result.add rulesList
  result.add quote do:
    Bag.validate(`data`)
when isMainModule:
  var fields = @[
    ("email", "test@examplecom"),
    ("password", "123admin"),
    ("message", "Lorem ipsum something better than that")
  ]
  newBag fields:
    text: TText or "auth.error.name"
    email: TEmail or "auth.error.email"
    password: TPassword or "auth.error.password":
      min: 8 or "auth.error.password.min"
    message: TTextarea or "comment.message.empty":
      min: 4 or "comment.message.min"
      max: 6 or "comment.message.max"
    *remember: TCheckbox

  var errorMessages = toTable({
    "auth.error.name": "Please provide a name",
    "auth.error.email": "Invalid email address",
    "auth.error.password": "Invalid password",
    "comment.message.empty": "Missing a message",
    "comment.message.min": "Min 80 characters",
    "comment.message.max": "Max 120 characters"
  })
  proc i18n(key: string): string =
    result = errorMessages[key]

  if not Bag.isValid:
    for e in Bag.getErrors:
      echo i18n(e[1])