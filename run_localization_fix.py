import re, os, json

# Load translations from new location
with open("assets/translations/en.json", "r", encoding="utf-8") as f:
    mapping = list(json.load(f).items())

pattern = re.compile(r'\b(const\s+)?Text\(\s*([\'"])(.+?)\2\s*\)')
key_counter = [0]

def replace_in_file(path):
    with open(path, "r", encoding="utf-8") as file:
        content = file.read()

    original_content = content

    def repl(match):
        if key_counter[0] >= len(mapping):
            return match.group(0)

        key, _ = mapping[key_counter[0]]
        key_counter[0] += 1

        # Strip out `const` if it's there
        return f"Text('{key}'.tr())"

    new_content = pattern.sub(repl, content)

    # Add easy_localization import if missing and file has at least one .tr()
    if new_content != original_content and 'tr()' in new_content:
        if "package:easy_localization/easy_localization.dart" not in new_content:
            import_line = "import 'package:easy_localization/easy_localization.dart';\n"
            # Insert after existing imports
            match = re.search(r"(import\s+['\"].+?['\"];\s*)+", new_content)
            if match:
                end = match.end()
                new_content = new_content[:end] + import_line + new_content[end:]
            else:
                new_content = import_line + new_content

    with open(path, "w", encoding="utf-8") as file:
        file.write(new_content)

# Apply to all .dart files in lib/
for root, _, files in os.walk("lib"):
    for fname in files:
        if fname.endswith(".dart"):
            print(f"Updating: {os.path.join(root, fname)}")
            replace_in_file(os.path.join(root, fname))

print("✅ Done replacing Text(...) with tr(), removed const, and added imports.")
