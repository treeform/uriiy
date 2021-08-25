# Urlly (Pronounced "you-really?")

URL and URI parsing for Nim for C/JS backends. Similar api to browsers's `window.location`.

This module works everywhere and parses everything! Including providing an easy way to work with the query key-value pairs.

```
  foo://admin:hunter1@example.com:8042/over/there?name=ferret#nose
  \_/   \___/ \_____/ \_________/ \__/\_________/ \_________/ \__/
   |      |       |       |        |       |          |         |
scheme username password hostname port   path       query fragment
```

This library is being actively developed and we'd be happy for you to use it.

`nimble install urlly`

![Github Actions](https://github.com/treeform/urlly/workflows/Github%20Actions/badge.svg)

### Documentation

API reference: https://nimdocs.com/treeform/urlly

## Using the `parseUrl()`.

```nim
let test = "foo://admin:hunter1@example.com:8042/over/there?name=ferret#nose"
let url = parseUrl(test)
url.scheme == "foo"
url.username == "admin"
url.password == "hunter1"
url.hostname == "example.com"
url.port == "8042"
url.authority == "admin:hunter1@example.com:8042"
url.paths == @["over", "there"]
url.path == "/over/there"
url.search == "name=ferret"
url.query["name"] == "ferret"
url.fragment == "nose"
$url == test
```

## Using the `$()`.

You can always turn a `Url` into a `string` with the `$` function.

```nim
var url = Url()
url.hostname = "example.com"
url.query["q"] = "foo"
url.fragment = "heading1"
assert $url == "example.com?q=foo#heading1"
```

## Using the `query` parameter.

The `Url.query` is just a sequence of key value pairs (`seq[(string, string)]`). This preserves their order and allows 100% exact reconstruction of the url string. This also allows you to walk through each pair looking for things you need:

```nim
let url = parseUrl("?name=ferret&age=12&leg=1&leg=2&leg=3&leg=4")

for (k, v) in url.query:
  if k == "leg":
    echo v
```

But for most use cases a special `[]` is provided. This is the most common use of the query.

```nim
url.query["name"] == "ferret"
```

If the key repeats multiple times only the first one is returned using the `[]` method. Use the for loop method if you need to support multiple keys or preserves special ordering.

```nim
url.query["leg"] == "1"
```

Missing keys are just empty strings, no need to check if its there or handle exceptions:

```nim
url.query["missing"] == ""
````

You can also modify the query string with `[]=` method:

```nim
url.query["missing"] = "no more!"
```
