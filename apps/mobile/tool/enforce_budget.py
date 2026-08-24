import os
import stat
import sys
import tempfile


EXCLUDED_FEATURE_NAMES = frozenset({'retired_sprawl'})

# Real V1 top-level modules. Used only by --self-test fixtures.
V1_FEATURE_NAMES = (
    'archive',
    'auth',
    'belief_changes',
    'belief_evidence',
    'capture',
    'caregiver_grant',
    'fact_ledger',
    'insights',
    'onboarding',
    'quick_capture',
    'record',
    'search',
    'settings',
    'sync',
)


def load_budget():
    budget = {}
    if not os.path.exists('.feature_count_budget'):
        print("Error: .feature_count_budget file missing.")
        sys.exit(1)
    with open('.feature_count_budget', 'r') as f:
        for line in f:
            stripped = line.strip()
            if not stripped or stripped.startswith('#'):
                continue
            if ':' in stripped:
                k, v = stripped.split(':', 1)
                budget[k.strip()] = int(v.strip())
    return budget


def count_living_docs(docs_dir='docs'):
    """Count markdown docs outside docs/archive/."""
    if not os.path.isdir(docs_dir):
        return 0

    archive_root = os.path.join(docs_dir, 'archive')
    count = 0
    for root, _, files in os.walk(docs_dir):
        if root == archive_root or root.startswith(archive_root + os.sep):
            continue
        count += sum(1 for name in files if name.endswith('.md'))
    return count


def count_tool_scripts(tool_dir='tool'):
    """Count executable root-level tool scripts (.py, .dart, .sh)."""
    if not os.path.isdir(tool_dir):
        return 0

    script_suffixes = {'.py', '.dart', '.sh'}
    return sum(
        1
        for name in os.listdir(tool_dir)
        if os.path.isfile(os.path.join(tool_dir, name))
        and os.path.splitext(name)[1] in script_suffixes
    )


def _dir_has_regular_files(path):
    """True if path contains any regular file. Does not follow symlinks."""
    for root, dirs, files in os.walk(path, followlinks=False):
        dirs[:] = [
            name
            for name in dirs
            if name not in EXCLUDED_FEATURE_NAMES
            and not os.path.islink(os.path.join(root, name))
        ]
        for name in files:
            fpath = os.path.join(root, name)
            try:
                mode = os.lstat(fpath).st_mode
            except OSError:
                continue
            if stat.S_ISREG(mode):
                return True
    return False


def count_v1_feature_dirs(features_dir='lib/features'):
    """Count real V1 feature modules.

    A top-level directory counts only when it is not a symlink, is not
    named retired_sprawl, and contains at least one regular file (directly
    or nested). Walks never follow symlinks, so zip-materialized empty
    stubs and dirs whose only "content" is a symlink to retired code do
    not count.
    """
    if not os.path.isdir(features_dir):
        return 0, 0

    v1_dirs = []
    symlink_dirs = []
    try:
        scanned = os.scandir(features_dir)
    except OSError:
        return 0, 0

    with scanned:
        for entry in scanned:
            if entry.name in EXCLUDED_FEATURE_NAMES:
                continue
            if entry.is_symlink() or os.path.islink(entry.path):
                symlink_dirs.append(entry.name)
                continue
            if not entry.is_dir(follow_symlinks=False):
                continue
            if not _dir_has_regular_files(entry.path):
                continue
            v1_dirs.append(entry.name)

    return len(v1_dirs), len(symlink_dirs)


def main():
    budget = load_budget()

    feature_count, symlink_count = count_v1_feature_dirs()

    doc_count = count_living_docs()

    tool_count = count_tool_scripts()

    failed = False

    print("Directory counts against budget:")
    max_features = budget.get('max_features', 13)
    print(f" -> V1 features: {feature_count} (Max: {max_features})")
    if symlink_count:
        print(f"    (excluding {symlink_count} retired_sprawl symlinks)")
    if feature_count > max_features:
        failed = True
    elif feature_count < max_features:
        print(f"    NOTE: ratchet max_features down toward {feature_count} when stable.")

    max_docs = budget.get('max_docs', 15)
    print(f" -> Docs: {doc_count} (Max: {max_docs})")
    if doc_count > max_docs:
        failed = True
    elif doc_count < max_docs:
        print(f"    NOTE: ratchet max_docs down toward {doc_count} when stable.")

    max_tools = budget.get('max_tool_scripts', 7)
    print(f" -> Tools: {tool_count} (Max: {max_tools})")
    if tool_count > max_tools:
        failed = True
    elif tool_count < max_tools:
        print(f"    NOTE: ratchet max_tool_scripts down toward {tool_count} when stable.")

    if failed:
        print("\n[!] FAILURE: Repository budget exceeded. Clean up sprawl before merging.")
        return 1

    print("\n[SUCCESS] All repository budgets are within limits.")
    return 0


def _write_file(path, contents=''):
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, 'w') as handle:
        handle.write(contents)


def _try_symlink(target, link_path):
    try:
        os.symlink(target, link_path)
        return True
    except OSError:
        return False


def _build_zip_stub_tree(features_dir, empty_stub_count=373):
    """14 dirs-with-files + empty zip stubs (+ optional symlink / retired)."""
    os.makedirs(features_dir, exist_ok=True)
    for name in V1_FEATURE_NAMES:
        _write_file(os.path.join(features_dir, name, 'lib.dart'), 'library %s;\n' % name)
        os.makedirs(os.path.join(features_dir, name, 'empty_child'), exist_ok=True)

    for index in range(empty_stub_count):
        stub = os.path.join(features_dir, 'stub_%03d' % index)
        os.makedirs(stub, exist_ok=True)

    # Folder that contains only empty subfolders — must not count.
    nested_empty = os.path.join(features_dir, 'nested_empty_stub', 'child', 'grandchild')
    os.makedirs(nested_empty, exist_ok=True)

    # Named retired_sprawl with files — must not count wherever it appears.
    _write_file(os.path.join(features_dir, 'retired_sprawl', 'retired.dart'), 'retired\n')

    symlink_ok = _try_symlink(
        os.path.join(os.pardir, 'retired_sprawl'),
        os.path.join(features_dir, 'symlink_to_retired'),
    )

    # Dir whose only "content" is a symlink — zip-vs-live stub, must not count.
    link_only = os.path.join(features_dir, 'symlink_only_stub')
    os.makedirs(link_only, exist_ok=True)
    _try_symlink(os.path.join(os.pardir, 'retired_sprawl'), os.path.join(link_only, 'pointer'))

    return symlink_ok


def _self_test():
    """Prove zip empty stubs do not inflate the feature count past 14."""
    original_cwd = os.getcwd()
    failures = []

    def check(condition, message):
        if not condition:
            failures.append(message)
            print('self-test FAIL: %s' % message)
        else:
            print('self-test ok: %s' % message)

    with tempfile.TemporaryDirectory() as tmp:
        features_dir = os.path.join(tmp, 'lib', 'features')
        symlink_ok = _build_zip_stub_tree(features_dir)
        count, symlink_count = count_v1_feature_dirs(features_dir)
        check(count == 14, '14 dirs-with-files + 373 empty stubs count as 14, not 387 (got %d)' % count)
        if symlink_ok:
            check(symlink_count == 1, 'top-level symlink skipped (got %d)' % symlink_count)
        else:
            print('self-test skip: OS did not allow a feature-dir symlink')

        emptied = os.path.join(features_dir, 'archive', 'lib.dart')
        os.remove(emptied)
        os.rmdir(os.path.join(features_dir, 'archive', 'empty_child'))
        count_after_empty, _ = count_v1_feature_dirs(features_dir)
        check(
            count_after_empty == 13,
            'emptying a counted real dir drops the count to 13 (got %d)' % count_after_empty,
        )
        _write_file(emptied, 'library archive;\n')
        os.makedirs(os.path.join(features_dir, 'archive', 'empty_child'), exist_ok=True)

        extra = os.path.join(features_dir, 'unallowed_extra', 'lib.dart')
        _write_file(extra, 'library extra;\n')
        over_count, _ = count_v1_feature_dirs(features_dir)
        check(over_count == 15, 'extra non-empty dir counts as 15 (got %d)' % over_count)

        _write_file(
            os.path.join(tmp, '.feature_count_budget'),
            'max_features: 14\nmax_docs: 16\nmax_tool_scripts: 39\n',
        )
        try:
            os.chdir(tmp)
            over_rc = main()
            check(over_rc == 1, 'script fails over budget at 15 (exit %s)' % over_rc)
            os.remove(extra)
            os.rmdir(os.path.dirname(extra))
            ok_rc = main()
            check(ok_rc == 0, 'script succeeds at 14 (exit %s)' % ok_rc)
        finally:
            os.chdir(original_cwd)

    if failures:
        return 1
    print('self-test ok: zip-empty-stub fixture counts 14; over-budget still fails')
    return 0


if __name__ == '__main__':
    if '--self-test' in sys.argv:
        sys.exit(_self_test())
    sys.exit(main())
