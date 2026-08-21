import os
import sys


def load_budget():
    budget = {}
    if not os.path.exists('.feature_count_budget'):
        print("Error: .feature_count_budget file missing.")
        sys.exit(1)
    with open('.feature_count_budget', 'r') as f:
        for line in f:
            if ':' in line:
                k, v = line.split(':')
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


def count_v1_feature_dirs(features_dir='lib/features'):
    """Count real V1 feature modules — excludes retired_sprawl symlinks."""
    if not os.path.isdir(features_dir):
        return 0, 0

    v1_dirs = []
    symlink_dirs = []
    for name in os.listdir(features_dir):
        path = os.path.join(features_dir, name)
        if not os.path.isdir(path):
            continue
        if os.path.islink(path):
            symlink_dirs.append(name)
        else:
            v1_dirs.append(name)

    return len(v1_dirs), len(symlink_dirs)


def main():
    budget = load_budget()

    feature_count, symlink_count = count_v1_feature_dirs()

    doc_count = count_living_docs()

    tool_count = count_tool_scripts()

    failed = False

    print("Directory counts against budget:")
    print(f" -> V1 features: {feature_count} (Max: {budget.get('max_features', 35)})")
    if symlink_count:
        print(f"    (excluding {symlink_count} retired_sprawl symlinks)")
    if feature_count > budget.get('max_features', 35):
        failed = True

    print(f" -> Docs: {doc_count} (Max: {budget.get('max_docs', 20)})")
    if doc_count > budget.get('max_docs', 20):
        failed = True

    print(f" -> Tools: {tool_count} (Max: {budget.get('max_tool_scripts', 8)})")
    if tool_count > budget.get('max_tool_scripts', 8):
        failed = True

    if failed:
        print("\n[!] FAILURE: Repository budget exceeded. Clean up sprawl before merging.")
        sys.exit(1)

    print("\n[SUCCESS] All repository budgets are within limits.")


if __name__ == '__main__':
    main()
