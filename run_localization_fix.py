import re, os, json

# Load the key-to-text mapping
with open("new_en.json", "r", encoding="utf-8") as f:
    mapping = list(json.load(f).items())

pattern = re.compile(r'Text\(\s*([\'"])(.+?)\1\s*\)')
key_counter = [0]  # mutable object to allow modification inside nested function

def replace_in_file(path):
    with open(path, "r", encoding="utf-8") as file:
        content = file.read()

    def repl(match):
        if key_counter[0] >= len(mapping):
            return match.group(0)
        key, _ = mapping[key_counter[0]]
        key_counter[0] += 1
        return f"Text('{key}'.tr())"

    new_content = pattern.sub(repl, content)

    with open(path, "w", encoding="utf-8") as file:
        file.write(new_content)

# Walk through all Dart files in lib/
for root, _, files in os.walk("lib"):
    for fname in files:
        if fname.endswith(".dart"):
            print(f"Updating: {os.path.join(root, fname)}")
            replace_in_file(os.path.join(root, fname))

print("✅ Done replacing Text(...) with tr() in .dart files.")
