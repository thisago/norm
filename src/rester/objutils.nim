import macros


type
  PragmaKind* = enum
    pkFlag, pkKval

  Pragma* = object
    ##[ A container for a pragma definition components.

    There are two kinds of pragmas: flags and key-value pairs. For flag pragmas,
    only the pragma name is stored. For key-value pragmas, name and value is stored.

    Components are stored as NimNodes.
    ]##

    name*: NimNode
    case kind*: PragmaKind
    of pkFlag: discard
    of pkKval: value*: NimNode

  Field* = object
    ##[ A container for a single object field definition components:
      - field name
      - field type
      - field pragmas

    Components are stored as NimNodes.
    ]##

    name*: NimNode
    exported*: bool
    typ*: NimNode
    pragmas*: seq[Pragma]

  Object* = object
    ##[ A container for object definition components:
      - type name
      - type pragmas
      - object fields

    Components are stored as NimNodes.
    ]##

    name*: NimNode
    exported*: bool
    pragmas*: seq[Pragma]
    fields*: seq[Field]


proc getPragmas(pragmaDefs: NimNode): seq[Pragma] =
  for pragmaDef in pragmaDefs:
    result.add case pragmaDef.kind
      of nnkIdent: Pragma(kind: pkFlag, name: pragmaDef)
      of nnkExprColonExpr: Pragma(kind: pkKval, name: pragmaDef[0], value: pragmaDef[1])
      else: Pragma()

proc parseDef(def: NimNode, dest: var (Field | Object)) =
  expectKind(def[0], {nnkIdent, nnkPostfix, nnkPragmaExpr})

  case def[0].kind
    of nnkIdent:
      dest.name = def[0]
    of nnkPostfix:
      dest.name = def[0][1]
      dest.exported = true
    of nnkPragmaExpr:
      expectKind(def[0][0], {nnkIdent, nnkPostfix})
      case def[0][0].kind
      of nnkIdent:
        dest.name = def[0][0]
      of nnkPostfix:
        dest.name = def[0][0][1]
        dest.exported = true
      else: discard
      dest.pragmas = def[0][1].getPragmas()
    else: discard

proc parseObjDef*(typeDef: NimNode): Object =
  ## Parse type definition of an object into an ``Object`` instance.

  parseDef(typeDef, result)

  expectKind(typeDef[2], nnkObjectTy)

  for fieldDef in typeDef[2][2]:
    var field = Field()
    parseDef(fieldDef, field)
    field.typ = fieldDef[1]
    result.fields.add field

proc makeFieldDef(field: Field): NimNode =
  discard

proc makeObjDef(obj: Object): NimNode =
  discard

macro foo(body: untyped): untyped =
  for node in body:
    for typeDef in node:
      echo typeDef.parseObjDef()
      echo typeDef.treeRepr

foo:
  type
    User* {.table: "users".} = object
      name* {.protected, qwe: "asd".}: string
      age*: int

macro `[]`*(obj: object, fieldName: string): untyped =
  ## Access object field value by name: ``obj["field"]`` translates to ``obj.field``.

  runnableExamples:
    type
      Example = object
        field: int

    let example = Example(field: 123)

    doAssert example["field"] == example.field

  newDotExpr(obj, newIdentNode(fieldName.strVal))

macro `[]=`*(obj: var object, fieldName: string, value: untyped): untyped =
  ## Set object field value by name: ``obj["field"] = value`` translates to ``obj.field = value``.

  runnableExamples:
    type
      Example = object
        field: int

    var example = Example()

    example["field"] = 321

    doAssert example["field"] == 321

  newAssignment(newDotExpr(obj, newIdentNode(fieldName.strVal)), value)

proc fieldNames*(obj: object): seq[string] =
  ## Get object's field names as a sequence.

  runnableExamples:
    type
      Example = object
        a: int
        b: float
        c: string

    assert Example().fieldNames == @["a", "b", "c"]

  for field, _ in obj.fieldPairs:
    result.add field
