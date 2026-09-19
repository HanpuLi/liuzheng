# Contributing

Contributions should preserve the project's central invariant: evidence operations must fail visibly rather than silently weaken the record.

Before opening a pull request, run:

```sh
python3 -m py_compile bin/gmail-eml
bash -n bin/stamp bin/webarchive bin/ots-upgrade-sweep.sh scripts/install.sh tests/test-webarchive.sh tests/test-stamp.sh tests/test-install.sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
bash tests/test-webarchive.sh
bash tests/test-stamp.sh
bash tests/test-install.sh
```

Keep tests free of real credentials, email content and case data. Use synthetic messages and temporary directories.

Changes to timestamp providers, trust assumptions, DKIM interpretation, archive naming or overwrite semantics should explain the evidence-model consequence, not only the implementation change.
