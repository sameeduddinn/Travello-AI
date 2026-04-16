"""
Batch convert hardcoded pixel values to responsive R.* calls in Flutter files.
Only converts Flutter UI code, skips pw.* (PDF) lines.
"""
import re
import sys

def convert_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    changed = 0
    new_lines = []
    
    for i, line in enumerate(lines):
        original = line
        
        # Skip pw.* (PDF) lines
        if 'pw.' in line:
            new_lines.append(line)
            continue
        
        # Skip lines that are comments
        stripped = line.strip()
        if stripped.startswith('//') or stripped.startswith('*') or stripped.startswith('/*'):
            new_lines.append(line)
            continue
        
        # Skip already-converted lines (R.sp, R.r, R.rh already present for this value)
        # We'll be careful to not double-convert
        
        # 1. fontSize: NUMBER -> fontSize: R.sp(context, NUMBER)
        # But NOT if already R.sp
        line = re.sub(
            r'fontSize:\s*(\d+\.?\d*)\b',
            lambda m: f'fontSize: R.sp(context, {m.group(1)})' if f'R.sp(context, {m.group(1)})' not in line else m.group(0),
            line
        )
        
        # 2. const SizedBox(height: NUMBER) -> SizedBox(height: R.rh(context, NUMBER))
        line = re.sub(
            r'const\s+SizedBox\(\s*height:\s*(\d+\.?\d*)\)',
            lambda m: f'SizedBox(height: R.rh(context, {m.group(1)}))',
            line
        )
        # Non-const SizedBox(height: NUMBER)
        line = re.sub(
            r'(?<!const\s)SizedBox\(\s*height:\s*(\d+\.?\d*)\)',
            lambda m: f'SizedBox(height: R.rh(context, {m.group(1)}))' if 'R.rh' not in m.group(0) else m.group(0),
            line
        )
        
        # 3. const SizedBox(width: NUMBER) -> SizedBox(width: R.r(context, NUMBER))
        line = re.sub(
            r'const\s+SizedBox\(\s*width:\s*(\d+\.?\d*)\)',
            lambda m: f'SizedBox(width: R.r(context, {m.group(1)}))',
            line
        )
        line = re.sub(
            r'(?<!const\s)SizedBox\(\s*width:\s*(\d+\.?\d*)\)',
            lambda m: f'SizedBox(width: R.r(context, {m.group(1)}))' if 'R.r' not in m.group(0) else m.group(0),
            line
        )
        
        # 4. size: NUMBER (icon sizes) -> size: R.r(context, NUMBER)
        # But not borderRadius, not already R.*
        line = re.sub(
            r'(?<!\.)size:\s*(\d+\.?\d*)\b',
            lambda m: f'size: R.r(context, {m.group(1)})' if 'R.r(context' not in line[:line.find(m.group(0))+len(m.group(0))] or True else m.group(0),
            line
        )
        # Fix: be more precise - only convert size: NUMBER that's not already R.r
        # Revert the above and do it properly
        line = original  # reset
        if 'pw.' in line:
            new_lines.append(line)
            continue
        if stripped.startswith('//') or stripped.startswith('*') or stripped.startswith('/*'):
            new_lines.append(line)
            continue
            
        # Track if we made changes
        modified = line
        
        # fontSize: NUMBER (not already R.sp)
        def fix_fontsize(m):
            full = m.group(0)
            if 'R.sp(' in full:
                return full
            num = m.group(1)
            return f'fontSize: R.sp(context, {num})'
        modified = re.sub(r'fontSize:\s*(\d+\.?\d*)', fix_fontsize, modified)
        
        # const SizedBox(height: NUMBER)
        modified = re.sub(
            r'const\s+SizedBox\(\s*height:\s*(\d+\.?\d*)\s*\)',
            lambda m: f'SizedBox(height: R.rh(context, {m.group(1)}))',
            modified
        )
        
        # const SizedBox(width: NUMBER)  
        modified = re.sub(
            r'const\s+SizedBox\(\s*width:\s*(\d+\.?\d*)\s*\)',
            lambda m: f'SizedBox(width: R.r(context, {m.group(1)}))',
            modified
        )
        
        # const EdgeInsets.all(NUMBER)
        modified = re.sub(
            r'const\s+EdgeInsets\.all\(\s*(\d+\.?\d*)\s*\)',
            lambda m: f'EdgeInsets.all(R.r(context, {m.group(1)}))',
            modified
        )
        
        # const EdgeInsets.symmetric(horizontal: N, vertical: N)
        modified = re.sub(
            r'const\s+EdgeInsets\.symmetric\(\s*horizontal:\s*(\d+\.?\d*)\s*,\s*vertical:\s*(\d+\.?\d*)\s*\)',
            lambda m: f'EdgeInsets.symmetric(horizontal: R.r(context, {m.group(1)}), vertical: R.r(context, {m.group(2)}))',
            modified
        )
        modified = re.sub(
            r'const\s+EdgeInsets\.symmetric\(\s*vertical:\s*(\d+\.?\d*)\s*,\s*horizontal:\s*(\d+\.?\d*)\s*\)',
            lambda m: f'EdgeInsets.symmetric(vertical: R.r(context, {m.group(1)}), horizontal: R.r(context, {m.group(2)}))',
            modified
        )
        # const EdgeInsets.symmetric(vertical: N) only
        modified = re.sub(
            r'const\s+EdgeInsets\.symmetric\(\s*vertical:\s*(\d+\.?\d*)\s*\)',
            lambda m: f'EdgeInsets.symmetric(vertical: R.r(context, {m.group(1)}))',
            modified
        )
        # const EdgeInsets.symmetric(horizontal: N) only
        modified = re.sub(
            r'const\s+EdgeInsets\.symmetric\(\s*horizontal:\s*(\d+\.?\d*)\s*\)',
            lambda m: f'EdgeInsets.symmetric(horizontal: R.r(context, {m.group(1)}))',
            modified
        )
        
        # const EdgeInsets.only(...)
        def fix_edge_only(m):
            s = m.group(0)
            s = s.replace('const ', '')
            # Replace each named param: left: N -> left: R.r(context, N)
            s = re.sub(r'(left|right|top|bottom):\s*(\d+\.?\d*)', 
                       lambda mm: f'{mm.group(1)}: R.r(context, {mm.group(2)})', s)
            return s
        modified = re.sub(r'const\s+EdgeInsets\.only\([^)]+\)', fix_edge_only, modified)
        
        # const EdgeInsets.fromLTRB(N, N, N, N)
        modified = re.sub(
            r'const\s+EdgeInsets\.fromLTRB\(\s*(\d+\.?\d*)\s*,\s*(\d+\.?\d*)\s*,\s*(\d+\.?\d*)\s*,\s*(\d+\.?\d*)\s*\)',
            lambda m: f'EdgeInsets.fromLTRB(R.r(context, {m.group(1)}), R.r(context, {m.group(2)}), R.r(context, {m.group(3)}), R.r(context, {m.group(4)}))',
            modified
        )
        
        # size: NUMBER for icons (not inside borderRadius, not already R.r)
        # Only match "size: NUMBER" that's NOT preceded by R.r(context,
        def fix_icon_size(m):
            prefix = m.group(1) if m.group(1) else ''
            if 'R.r(context' in prefix:
                return m.group(0)
            num = m.group(2)
            return f'{prefix}size: R.r(context, {num})'
        modified = re.sub(r'((?:^|[^.])?)size:\s*(\d+\.?\d*)', fix_icon_size, modified)
        
        # Non-const SizedBox (standalone, not part of const)
        # Already handled const versions above; now handle non-const that aren't already converted
        if 'SizedBox(height:' in modified and 'R.rh' not in modified and 'const SizedBox' not in modified:
            modified = re.sub(
                r'SizedBox\(\s*height:\s*(\d+\.?\d*)\s*\)',
                lambda m: f'SizedBox(height: R.rh(context, {m.group(1)}))',
                modified
            )
        if 'SizedBox(width:' in modified and 'R.r' not in modified:
            modified = re.sub(
                r'SizedBox\(\s*width:\s*(\d+\.?\d*)\s*\)',
                lambda m: f'SizedBox(width: R.r(context, {m.group(1)}))',
                modified
            )
        
        if modified != original:
            changed += 1
        
        new_lines.append(modified)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print(f"Changed {changed} lines in {filepath}")

if __name__ == '__main__':
    for fp in sys.argv[1:]:
        convert_file(fp)
