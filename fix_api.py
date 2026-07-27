with open('Madrasa web app/api.php', 'r', encoding='utf-8') as f:
    lines = f.readlines()

out_lines = []
skip = False
for i, line in enumerate(lines):
    if i == 552:  # 0-indexed line 553
        skip = True
    if i == 747:  # 0-indexed line 748
        skip = False
    
    if not skip:
        out_lines.append(line)

with open('Madrasa web app/api.php', 'w', encoding='utf-8') as f:
    f.writelines(out_lines)

print("Fixed api.php!")
