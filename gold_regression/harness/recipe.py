"""Recipe resolution for the gold-regression harness.

An object is driven by a self-contained recipe. Two locations are supported so
objects can be built in parallel without editing one shared file:

  1. objects/{Name}/recipe.json  -- the per-object recipe (preferred; required
     for any object with discovery logic, HDL, or downstream jobs).
  2. harness/objects.json        -- a shared file holding the simple/legacy
     recipes (Suppliers lives here, unchanged).

load_recipe(name) returns the recipe dict from whichever exists, preferring the
per-object file. This keeps every shared module (build, load, verify) pointed at
one resolver instead of hard-coding objects.json.
"""
import os
import json

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # gold_regression/


def objects_subdir():
    """Which object tree to read/write.

    Defaults to 'objects' (the FROZEN v1 fixtures that use ${TOKEN} discovery).
    Set the env var GOLD_OBJECTS_SUBDIR to run a different version through the
    SAME harness without touching v1 -- e.g. GOLD_OBJECTS_SUBDIR=objects_seeded
    for the v2 fixtures that hard-code seeded references instead of discovering
    them. This is the only switch; every module resolves folders through
    object_dir(), so one env var re-points the whole engine.
    """
    return os.environ.get('GOLD_OBJECTS_SUBDIR', 'objects')


def _shared_objects():
    # The shared objects.json lives beside the harness and is version-neutral;
    # a per-object recipe in the active tree always wins over it.
    p = os.path.join(HERE, 'objects.json')
    if not os.path.exists(p):
        return {}
    with open(p, 'r', encoding='utf-8') as f:
        return json.load(f)


def object_dir(name):
    return os.path.join(ROOT, objects_subdir(), name)


def load_recipe(name):
    """Return the recipe dict for an object.

    Per-object objects/{Name}/recipe.json wins; otherwise the entry in the
    shared harness/objects.json. Raises KeyError if neither has it.
    """
    per_obj = os.path.join(object_dir(name), 'recipe.json')
    if os.path.exists(per_obj):
        with open(per_obj, 'r', encoding='utf-8') as f:
            return json.load(f)
    shared = _shared_objects()
    if name in shared:
        return shared[name]
    raise KeyError(
        f'No recipe for {name!r}: looked in {per_obj} and harness/objects.json')


# Back-compat shim: older modules imported load_objects() and indexed by name.
def load_objects():
    """Legacy accessor. Returns a dict-like that resolves per-object recipes on
    lookup, falling back to the shared objects.json. Existing callers that do
    load_objects()[name] keep working."""
    class _Resolver(dict):
        def __missing__(self, key):
            return load_recipe(key)
    d = _Resolver(_shared_objects())
    return d
