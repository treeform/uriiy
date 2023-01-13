## Parses URIs and URLs
##
##  The following are two example URLs and their component parts::
##
##       https://admin:hunter1@example.com:8042/over/there?name=ferret#nose
##        \_/   \___/ \_____/ \_________/ \__/\_________/ \_________/ \__/
##         |      |       |       |        |       |          |         |
##       scheme username password hostname port   path[s]    query fragment
##

import std/strutils, std/typetraits

type
  Url* = ref object
    scheme*, username*, password*: string
    hostname*, port*, fragment*: string
    paths*: seq[string]
    query*: QueryParams

  QueryParams* = distinct seq[(string, string)]

converter toBase*(params: var QueryParams): var seq[(string, string)] =
  params.distinctBase

converter toBase*(params: QueryParams): seq[(string, string)] =
  params.distinctBase

proc encodeQueryComponent*(s: string): string =
  ## Similar to encodeURIComponent, however query parameter spaces should
  ## be +, not %20 like encodeURIComponent would encode them.
  ## The encoded string is in the x-www-form-urlencoded format.
  result = newStringOfCap(s.len)
  for c in s:
    case c:
    of ' ':
      result.add '+'
    of 'a'..'z', 'A'..'Z', '0'..'9',
      '-', '.', '_', '~', '!', '*', '\'', '(', ')':
      result.add(c)
    else:
      result.add '%'
      result.add toHex(ord(c), 2)

proc decodeQueryComponent*(s: string): string =
  ## Takes a string and decodes it from the x-www-form-urlencoded format.
  result = newStringOfCap(s.len)
  var i = 0
  while i < s.len:
    case s[i]:
    of '%':
      if s[i+1] in HexDigits and s[i+2] in HexDigits:
        result.add chr(fromHex[uint8](s[i+1 .. i+2]))
        i += 2
      else:
        result.add s[i]
    of '+':
      result.add ' '
    else:
      result.add s[i]
    inc i

proc encodeURIComponent*(s: string): string =
  ## Encodes the string the same as encodeURIComponent does in the browser.
  result = newStringOfCap(s.len)
  for c in s:
    case c:
    of 'a'..'z', 'A'..'Z', '0'..'9',
      '-', '.', '_', '~', '!', '*', '\'', '(', ')':
      result.add(c)
    else:
      result.add '%'
      result.add toHex(ord(c), 2)

proc encodeUrlComponent*(s: string): string =
  ## Encodes the string the same as encodeURIComponent does in the browser.
  encodeURIComponent(s)

proc decodeURIComponent*(s: string): string =
  ## Encodes the string the same as decodeURIComponent does in the browser.
  result = newStringOfCap(s.len)
  var i = 0
  while i < s.len:
    if s[i] == '%' and s[i+1] in HexDigits and s[i+2] in HexDigits:
      result.add chr(fromHex[uint8](s[i+1 .. i+2]))
      i += 2
    else:
      result.add s[i]
    inc i

proc decodeUrlComponent*(s: string): string =
  ## Encodes the string the same as decodeURIComponent does in the browser.
  decodeURIComponent(s)

proc `[]`*(query: QueryParams, key: string): string =
  ## Get a key out of url.query. Returns an empty string if key is not present.
  ## Use a for loop to get multiple keys.
  for (k, v) in query.toBase:
    if k == key:
      return v

proc `[]=`*(query: var QueryParams, key, value: string) =
  ## Sets the value for the key in url.query. If the key is present, this
  ## appends a new key-value pair to the end.
  for pair in query.mitems:
    if pair[0] == key:
      pair[1] = value
      return
  query.add((key, value))

proc contains*(query: QueryParams, key: string): bool =
  ## Returns true if key is in the url.query.
  ## `"name" in url.query` or `"name" notin url.query`
  for pair in query:
    if pair[0] == key:
      return true

proc add*(query: var QueryParams, params: QueryParams) =
  for (k, v) in params:
    query.add((k, v))

proc `$`*(query: QueryParams): string =
  for i, pair in query:
    if i > 0:
      result.add '&'
    result.add encodeQueryComponent(pair[0])
    result.add '='
    result.add encodeQueryComponent(pair[1])

proc parseSearch*(search: string): QueryParams =
  ## Parses the search part into strings pairs
  ## "name=&age&legs=4" -> @[("name", ""), ("age", ""), ("legs", "4")]
  for pairStr in search.split('&'):
    let
      pair = pairStr.split('=', 1)
      kv =
        if pair.len == 2:
          (decodeQueryComponent(pair[0]), decodeQueryComponent(pair[1]))
        else:
          (decodeQueryComponent(pair[0]), "")
    when defined(js):
      # Work round for JS bug: https://github.com/nim-lang/Nim/issues/21247
      result.toBase.add(kv)
    else:
      result.add(kv)

proc parseUrl*(s: string): Url =
  ## Parses a URL or a URL into the Url object.
  var
    s = s
    url = Url()

  let hasFragment = s.rfind('#')
  if hasFragment != -1:
    url.fragment = decodeURIComponent(s[hasFragment + 1 .. ^1])
    s = s[0 .. hasFragment - 1]

  let hasSearch = s.find('?')
  if hasSearch != -1:
    let search = s[hasSearch + 1 .. ^1]
    s = s[0 .. hasSearch - 1]
    url.query = parseSearch(search)
  else:
    # Handle ? being ommitted but a search still being present
    let hasAmpersand = s.find('&')
    if hasAmpersand != -1:
      let search = s[hasAmpersand + 1 .. ^1]
      s = s[0 .. hasAmpersand - 1]
      url.query = parseSearch(search)

  let hasScheme = s.find("://")
  if hasScheme != -1:
    url.scheme = s[0 .. hasScheme - 1]
    s = s[hasScheme + 3 .. ^1]

  let hasLogin = s.find('@')
  if hasLogin != -1:
    let login = s[0 .. hasLogin - 1]
    let hasPassword = login.find(':')
    if hasPassword != -1:
      url.username = login[0 .. hasPassword - 1]
      url.password = login[hasPassword + 1 .. ^1]
    else:
      url.username = login
    s = s[hasLogin + 1 .. ^1]

  let hasPath = s.find('/')
  if hasPath != -1:
    for part in s[hasPath + 1 .. ^1].split('/'):
      url.paths.add(decodeURIComponent(part))
    s = s[0 .. hasPath - 1]

  let hasPort = s.find(':')
  if hasPort != -1:
    url.port = s[hasPort + 1 .. ^1]
    s = s[0 .. hasPort - 1]

  if hasSearch == -1 and ("&" in s) or ("=" in s):
    # Probably search without ?, append to query
    let prev = url.query # In case we already got from handling ommitted ?
    url.query = parseSearch(s)
    url.query.add(prev)
    s = ""

  url.hostname = s
  return url

proc host*(url: Url): string =
  ## Returns the hostname and port part of the URL as a string.
  ## Example: "example.com:8042"
  url.hostname & ":" & url.port

proc search*(url: Url): string =
  ## Returns the search part of the URL as a string.
  ## Example: "name=ferret&age=12&legs=4"
  $url.query

proc path*(url: Url): string =
  ## Returns the paths combined into a single path string.
  ## @["foo", "bar"] -> "/foo/bar"
  if url.paths.len > 0:
    for part in url.paths:
      result.add '/'
      result.add encodeURIComponent(part)

proc `path=`*(url: Url, s: string) =
  if s == "":
    url.paths.setLen(0)
  elif s[0] == '/':
    url.paths = s.split('/')[1 .. ^1]
  else:
    url.paths = s.split('/')

  # We encodeURIComponent on the way out so decode on the way in
  for path in url.paths.mitems:
    path = decodeURIComponent(path)

proc authority*(url: Url): string =
  ## Returns the authority part of URL as a string.
  ## Example: "admin:hunter1@example.com:8042"
  if url.username.len > 0:
    result.add url.username
    if url.password.len > 0:
      result.add ':'
      result.add url.password
    result.add '@'
  if url.hostname.len > 0:
    result.add url.hostname
  if url.port.len > 0:
    result.add ':'
    result.add url.port

proc `$`*(url: Url): string =
  ## Turns Url into a string. Preserves query string param ordering.
  if url.scheme.len > 0:
    result.add url.scheme
    result.add "://"
  result.add url.authority
  result.add url.path
  if url.query.len > 0:
    result.add '?'
    result.add url.search
  if url.fragment.len > 0:
    result.add '#'
    result.add encodeURIComponent(url.fragment)
