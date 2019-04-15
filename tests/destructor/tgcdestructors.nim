discard """
  cmd: '''nim c --newruntime $file'''
  output: '''hi
ho
ha
@["arg", "asdfklasdfkl", "asdkfj", "dfasj", "klfjl"]
22 22'''
"""

import allocators
include system / ansi_c

proc main =
  var s: seq[string] = @[]
  for i in 0..<80: s.add "foo"

main()

const
  test = @["hi", "ho", "ha"]

for t in test:
  echo t

type
  InterpolatedKind* = enum
    ikStr,                   ## ``str`` part of the interpolated string
    ikDollar,                ## escaped ``$`` part of the interpolated string
    ikVar,                   ## ``var`` part of the interpolated string
    ikExpr                   ## ``expr`` part of the interpolated string

iterator interpolatedFragments*(s: string): tuple[kind: InterpolatedKind,
                                                  value: string] =
  var i = 0
  var kind: InterpolatedKind
  while true:
    var j = i
    if j < s.len and s[j] == '$':
      if j+1 < s.len and s[j+1] == '{':
        inc j, 2
        var nesting = 0
        block curlies:
          while j < s.len:
            case s[j]
            of '{': inc nesting
            of '}':
              if nesting == 0:
                inc j
                break curlies
              dec nesting
            else: discard
            inc j
          raise newException(ValueError,
            "Expected closing '}': " & substr(s, i, s.high))
        inc i, 2 # skip ${
        kind = ikExpr
      elif j+1 < s.len and s[j+1] in {'A'..'Z', 'a'..'z', '_'}:
        inc j, 2
        while j < s.len and s[j] in {'A'..'Z', 'a'..'z', '0'..'9', '_'}: inc(j)
        inc i # skip $
        kind = ikVar
      elif j+1 < s.len and s[j+1] == '$':
        inc j, 2
        inc i # skip $
        kind = ikDollar
      else:
        raise newException(ValueError,
          "Unable to parse a varible name at " & substr(s, i, s.high))
    else:
      while j < s.len and s[j] != '$': inc j
      kind = ikStr
    if j > i:
      # do not copy the trailing } for ikExpr:
      yield (kind, substr(s, i, j-1-ord(kind == ikExpr)))
    else:
      break
    i = j

proc parseCmdLine(c: string): seq[string] =
  result = @[]
  var i = 0
  var a = ""
  while true:
    setLen(a, 0)
    while i < c.len and c[i] in {' ', '\t', '\l', '\r'}: inc(i)
    if i >= c.len: break
    var inQuote = false
    while i < c.len:
      case c[i]
      of '\\':
        var j = i
        while j < c.len and c[j] == '\\': inc(j)
        if j < c.len and c[j] == '"':
          for k in 1..(j-i) div 2: a.add('\\')
          if (j-i) mod 2 == 0:
            i = j
          else:
            a.add('"')
            i = j+1
        else:
          a.add(c[i])
          inc(i)
      of '"':
        inc(i)
        if not inQuote: inQuote = true
        elif i < c.len and c[i] == '"':
          a.add(c[i])
          inc(i)
        else:
          inQuote = false
          break
      of ' ', '\t':
        if not inQuote: break
        a.add(c[i])
        inc(i)
      else:
        a.add(c[i])
        inc(i)
    add(result, a)


proc other =
  let input = "$test{}  $this is ${an{  example}}  "
  let expected = @[(ikVar, "test"), (ikStr, "{}  "), (ikVar, "this"),
                  (ikStr, " is "), (ikExpr, "an{  example}"), (ikStr, "  ")]
  var i = 0
  for s in interpolatedFragments(input):
    doAssert s == expected[i]
    inc i

  echo parseCmdLine("arg asdfklasdfkl asdkfj dfasj klfjl")

other()

#echo s
let (a, d) = allocCounters()
discard cprintf("%ld %ld\n", a, d)