#!/usr/bin/env python3
# Tests host_of() and clean_fetch()'s BANNED check in essential-app.py -
# the real security boundary of that file: whether a user-supplied
# Essential app's fetch URL/pick string is safe to run.
import importlib.util
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("essential_app", Path(sys.argv[1]))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

checks = 0


def check(cond, msg):
    global checks
    assert cond, msg
    checks += 1


check(mod.host_of("https://example.com/path") == "example.com", "plain https host")
check(mod.host_of("http://example.com") == "", "http (not https) rejected")
check(mod.host_of("https://evil.com#@trusted.com") == "evil.com",
      "a fragment/@ trick must not surface a different host than the one actually connected to")
check(mod.host_of("https://" + "a" * 300) == "", "over-length host rejected")
check(mod.host_of("not a url") == "", "garbage input rejected")

budget = mod.Budget()
ok = mod.clean_fetch({"url": "https://example.com/feed", "pick": "title"}, budget)
check(ok is not None and ok["pick"] == "title", "a normal pick value passes through")

budget2 = mod.Budget()
banned = mod.clean_fetch({"url": "https://example.com/feed", "pick": "eval(x)"}, budget2)
check(banned is not None and banned["pick"] == "",
      "a banned name in pick must be stripped, not passed through")

budget3 = mod.Budget()
bad_url = mod.clean_fetch({"url": "http://example.com/feed"}, budget3)
check(bad_url is None, "a non-https url is rejected entirely")

print(f"essential-app: {checks} checks passed")
