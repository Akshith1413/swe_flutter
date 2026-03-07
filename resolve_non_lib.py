import subprocess
import os

unmerged_files_str = subprocess.check_output(['git', 'diff', '--name-only', '--diff-filter=U'], text=True)
unmerged_files = unmerged_files_str.splitlines()

for f in unmerged_files:
    if f.startswith('lib/') or 'pubspec.yaml' in f:
        print(f"Skipping {f} for manual resolution")
    else:
        print(f"Resolving {f} with --ours")
        subprocess.run(['git', 'checkout', '--ours', f])
        subprocess.run(['git', 'add', f])
