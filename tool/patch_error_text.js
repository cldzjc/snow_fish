// 一次性脚本：把 `Text('xxx失败：$e')` 换成 friendlyError(...)，并补 import。
// 用法：node tool/patch_error_text.js
const fs = require('fs');
const path = require('path');

const root = path.resolve('lib');
const files = [];
(function walk(dir) {
  for (const name of fs.readdirSync(dir)) {
    const full = path.join(dir, name);
    const stat = fs.statSync(full);
    if (stat.isDirectory()) walk(full);
    else if (name.endsWith('.dart')) files.push(full);
  }
})(root);

const pattern = /Text\('([^'$]{0,20}失败)[：:]\s*\$\{?\s*([A-Za-z_][\w.]*)\s*\}?'\)/g;
const results = [];

for (const file of files) {
  if (file.endsWith('error_text.dart')) continue;
  let code = fs.readFileSync(file, 'utf8');
  let count = 0;
  let next = code.replace(pattern, (_m, label, expr) => {
    count += 1;
    return `Text(friendlyError(${expr}, fallback: '${label}'))`;
  });
  if (count === 0) continue;

  const rel = path.relative(path.dirname(file), path.join(root, 'utils/error_text.dart'))
    .replace(/\\/g, '/');
  if (!next.includes("utils/error_text.dart")) {
    const lines = next.split('\n');
    // 插到最后一个 import 之后
    let last = -1;
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('import ')) last = i;
    }
    if (last >= 0) lines.splice(last + 1, 0, `import '${rel.startsWith('.') ? rel : './' + rel}';`);
    next = lines.join('\n');
  }
  fs.writeFileSync(file, next, 'utf8');
  results.push(`${path.relative(root, file)}  ${count}`);
}

console.log(results.join('\n'));
console.log('total files: ' + results.length);
