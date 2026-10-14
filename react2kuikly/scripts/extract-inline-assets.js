/**
 * 提取 React Native 代码中的内联资源（base64 图片、SVG 组件）   
 * 生成本地图片文件，并替换源代码中的引用为 Image 组件引用本地图片
 *
 * 使用方式:
 *   node extract-inline-assets.js --sourceDir <React Native源码目录>
 *
 * 参数:
 *   --sourceDir  必填，React Native 源代码目录的绝对路径或相对路径
 *
 * 功能:
 *   1. 扫描目录下所有 .tsx/.ts/.js/.jsx 文件中的 base64 内联图片
 *   2. 扫描目录下 SVG 组件定义（基于 react-native-svg 的 <Svg><Path /></Svg> 组件）
 *   3. 将 base64 解码保存为本地图片文件（.png/.jpeg 等）
 *   4. 将 SVG 组件提取为独立的 .svg 文件
 *   5. 替换源代码中的内联引用为本地图片路径字符串
 *   6. 清理不再需要的 SVG import 语句，确保 Image import 存在
 *
 * 输出:
 *   在源目录下创建 assets/ 子目录，保存提取的图片文件
 *
 * 依赖: 无外部依赖，纯 Node.js 实现
 */

const fs = require('fs');
const path = require('path');

// ==================== 参数解析 ====================

function parseArgs() {
    const args = process.argv.slice(2);
    const parsed = {};

    for (let i = 0; i < args.length; i++) {
        if (args[i] === '--sourceDir' && args[i + 1]) {
            parsed.sourceDir = path.resolve(args[i + 1]);
            i++;
        }
    }

    if (!parsed.sourceDir) {
        console.error('❌ 错误：缺少必填参数 --sourceDir');
        console.error('用法: node extract-inline-assets.js --sourceDir <React Native源码目录>');
        process.exit(1);
    }

    if (!fs.existsSync(parsed.sourceDir)) {
        console.error(`❌ 错误：目录不存在: ${parsed.sourceDir}`);
        process.exit(1);
    }

    return parsed;
}

// ==================== 配置 ====================

const { sourceDir } = parseArgs();
const SRC_DIR = sourceDir;
const ASSETS_DIR = path.resolve(SRC_DIR, 'assets');

// 项目根目录（向上查找 package.json 所在目录）
const PROJECT_ROOT = findProjectRoot(SRC_DIR);

// 路径别名映射（@/ → src/）
const ALIAS_MAP = {
    '@/': 'src/',
};

// ==================== 工具函数 ====================

/** 确保目录存在 */
function ensureDir(dir) {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
}

/** 读取文件内容 */
function readFile(filePath) {
    return fs.readFileSync(filePath, 'utf-8');
}

/** 写入文件 */
function writeFile(filePath, content) {
    ensureDir(path.dirname(filePath));
    fs.writeFileSync(filePath, content);
}

/** 查找项目根目录（向上查找 package.json） */
function findProjectRoot(startDir) {
    let dir = path.resolve(startDir);
    while (dir !== path.dirname(dir)) {
        if (fs.existsSync(path.join(dir, 'package.json'))) {
            return dir;
        }
        dir = path.dirname(dir);
    }
    // 兜底：返回 sourceDir 的上两级（通常 src/xxx → 根目录）
    return path.resolve(startDir, '../..');
}

/**
 * 解析 import 路径为绝对文件路径
 * 支持相对路径和 @/ 别名
 */
function resolveImportPath(importPath, fromFile) {
    let basePath;

    // 处理别名路径（如 @/component/tabview/index）
    for (const [alias, target] of Object.entries(ALIAS_MAP)) {
        if (importPath.startsWith(alias)) {
            basePath = path.resolve(PROJECT_ROOT, target, importPath.slice(alias.length));
            break;
        }
    }

    // 处理相对路径
    if (!basePath && importPath.startsWith('.')) {
        basePath = path.resolve(path.dirname(fromFile), importPath);
    }

    if (!basePath) return null;

    // 尝试直接匹配或补全扩展名
    const candidates = [
        basePath,
        basePath + '.js',
        basePath + '.ts',
        basePath + '.tsx',
        basePath + '.jsx',
        path.join(basePath, 'index.js'),
        path.join(basePath, 'index.ts'),
        path.join(basePath, 'index.tsx'),
        path.join(basePath, 'index.jsx'),
    ];

    for (const candidate of candidates) {
        if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
            return candidate;
        }
    }

    return null;
}

/**
 * 收集源目录中所有文件的外部依赖文件（递归追踪）
 * 返回去重后的外部文件绝对路径数组
 */
function collectExternalDependencies() {
    const externalFiles = new Set();
    const visited = new Set();
    const sourceFiles = getAllSourceFiles(SRC_DIR);

    function traceImports(file) {
        if (visited.has(file)) return;
        visited.add(file);

        const content = readFile(file);
        const importRegex = /(?:import\s+(?:[\s\S]*?)\s+from\s+|import\s+|export\s+[\s\S]*?\s+from\s+|require\s*\()['"]([^'"]+)['"]\)?/g;
        let match;

        while ((match = importRegex.exec(content)) !== null) {
            const importPath = match[1];
            if (!importPath) continue;

            // 跳过第三方 npm 包
            if (!importPath.startsWith('.') && !importPath.startsWith('@/')) continue;
            if (importPath.startsWith('@') && !importPath.startsWith('@/')) continue;

            const resolved = resolveImportPath(importPath, file);
            if (!resolved) continue;

            // 判断是否在源目录外
            if (!resolved.startsWith(SRC_DIR + path.sep) && resolved !== SRC_DIR) {
                externalFiles.add(resolved);
                // 递归追踪外部文件的依赖
                traceImports(resolved);
            }
        }
    }

    // 从源目录的每个文件开始追踪
    for (const file of sourceFiles) {
        traceImports(file);
    }

    return [...externalFiles];
}

// ==================== 1. 提取 base64 资源 ====================

/**
 * 从文件中提取 base64 数据 URL 并保存为本地图片
 * 返回 { varName, filePath, originalString } 的数组
 */
/**
 * 收集当前页面源文件中实际引用的变量名（用于过滤外部依赖文件中的 base64）
 * 包括：import { VarName } from '...' 以及代码中直接使用的标识符
 */
function findUsedVarsInCurrentPage() {
    const usedVars = new Set();
    const files = getAllSourceFiles(SRC_DIR);

    for (const file of files) {
        const content = readFile(file);

        // 匹配 import { Foo, Bar } from '...' 中的具名导入
        const importRegex = /import\s*\{([^}]+)\}\s*from\s*['"]/g;
        let match;
        while ((match = importRegex.exec(content)) !== null) {
            match[1].split(',').map(s => s.trim()).filter(Boolean).forEach(name => {
                // 处理 alias：import { Foo as Bar } → 取原名 Foo
                const originalName = name.split(/\s+as\s+/)[0].trim();
                usedVars.add(originalName);
            });
        }

        // 匹配代码中直接使用的大写开头标识符（如 src={IconListen64}、src={BASE64}）
        const identifierRegex = /\b([A-Z][A-Za-z0-9_]*)\b/g;
        while ((match = identifierRegex.exec(content)) !== null) {
            usedVars.add(match[1]);
        }
    }

    return usedVars;
}

/**
 * 从文件中提取 base64 数据 URL 并保存为本地图片
 * 返回 { varName, filePath, originalString } 的数组
 * 对外部依赖文件：只提取当前页面实际引用的变量
 */
function extractBase64Assets() {
    console.log('\n📦 [步骤1] 提取 base64 内联资源...');

    const results = [];

    const localFiles = getAllSourceFiles(SRC_DIR);
    const externalFiles = collectExternalDependencies();

    if (externalFiles.length > 0) {
        console.log(`  📎 发现 ${externalFiles.length} 个外部依赖文件，一并扫描`);
    }

    // 预先收集当前页面实际引用的变量名，用于过滤外部文件中的 base64
    const usedVarsInPage = findUsedVarsInCurrentPage();

    const base64Regex = /(?:const|let|var)\s+(\w+)\s*=\s*['"`](data:image\/(\w+);base64,([A-Za-z0-9+/=\s]+))['"`]/g;

    // 源目录内文件：无条件提取所有 base64
    for (const file of localFiles) {
        const content = readFile(file);
        let match;
        base64Regex.lastIndex = 0;
        while ((match = base64Regex.exec(content)) !== null) {
            const varName = match[1];
            const fullDataUrl = match[2];
            const imageFormat = match[3];
            const base64Data = match[4].replace(/\s/g, '');

            const fileName = `${varName}.${imageFormat}`;
            const outputPath = path.join(ASSETS_DIR, fileName);
            const buffer = Buffer.from(base64Data, 'base64');
            writeFile(outputPath, buffer);

            const relativeFile = path.relative(SRC_DIR, file);
            console.log(`  ✅ ${relativeFile}: ${varName} → assets/${fileName} (${buffer.length} bytes)`);
            results.push({ varName, fileName, outputPath, sourceFile: file, fullDataUrl, imageFormat });
        }
    }

    // 外部依赖文件：只提取当前页面实际引用的变量
    for (const file of externalFiles) {
        const content = readFile(file);
        let match;
        base64Regex.lastIndex = 0;
        while ((match = base64Regex.exec(content)) !== null) {
            const varName = match[1];
            const fullDataUrl = match[2];
            const imageFormat = match[3];
            const base64Data = match[4].replace(/\s/g, '');

            // 过滤：只处理当前页面实际引用的变量名
            if (!usedVarsInPage.has(varName)) {
                continue;
            }

            const fileName = `${varName}.${imageFormat}`;
            const outputPath = path.join(ASSETS_DIR, fileName);
            const buffer = Buffer.from(base64Data, 'base64');
            writeFile(outputPath, buffer);

            const relativeFile = path.relative(SRC_DIR, file);
            console.log(`  ✅ ${relativeFile}: ${varName} → assets/${fileName} (${buffer.length} bytes)`);
            results.push({ varName, fileName, outputPath, sourceFile: file, fullDataUrl, imageFormat });
        }
    }

    if (results.length === 0) {
        console.log('  ℹ️  未找到 base64 内联资源');
    }

    return results;
}

// ==================== 2. 提取 SVG 组件资源 ====================

/**
 * 解析 SVG 组件定义，提取 Path 数据并生成 .svg 文件
 */
function extractSvgAssets() {
    console.log('\n🎨 [步骤2] 提取 SVG 内联组件...');

    const results = [];

    // 2a. 扫描源目录内文件 + 外部依赖文件中的 SVG 组件定义
    const localFiles = getAllSourceFiles(SRC_DIR);
    const externalFiles = collectExternalDependencies();
    const files = [...localFiles, ...externalFiles];
    const svgDefinitionFiles = [];

    for (const file of files) {
        const content = readFile(file);
        // 检测文件是否包含 react-native-svg 的 Svg/Path 组件使用
        if (content.includes('react-native-svg') || (content.includes('<Svg') && content.includes('<Path'))) {
            svgDefinitionFiles.push(file);
        }
    }

    // 先收集当前页面实际使用的SVG组件
    const usedIconsInCurrentPage = findUsedIconsInCurrentPage();
    console.log(`  📊 当前页面使用的SVG组件: ${usedIconsInCurrentPage.length > 0 ? usedIconsInCurrentPage.join(', ') : '无'}`);

    for (const svgFile of svgDefinitionFiles) {
        const svgComponents = parseSvgComponents(svgFile);
        for (const comp of svgComponents) {
            // 只生成当前页面实际使用的SVG组件
            if (usedIconsInCurrentPage.includes(comp.exportName)) {
                const svgContent = generateSvgFile(comp);
                const fileName = `${comp.name}.svg`;
                const outputPath = path.join(ASSETS_DIR, fileName);
                writeFile(outputPath, svgContent);

                const relativeFile = path.relative(SRC_DIR, svgFile);
                console.log(`  ✅ ${relativeFile}: ${comp.exportName} → assets/${fileName} (${comp.width}x${comp.height})`);

                results.push({
                    ...comp,
                    fileName,
                    outputPath,
                    sourceFile: svgFile,
                    isLocal: true,
                });
            }
        }
    }

    // 2b. 检查是否有引用外部 SVG 图标组件（如 component/Icon 等）
    const externalIconDirs = findExternalIconImports();
    for (const { iconFile, usedIcons } of externalIconDirs) {
        if (fs.existsSync(iconFile)) {
            const allComponents = parseSvgComponents(iconFile);
            for (const comp of allComponents) {
                // 只生成当前页面实际使用的SVG组件
                if (usedIconsInCurrentPage.includes(comp.exportName)) {
                    // 避免重复（如果已在本地定义中提取过）
                    if (results.some(r => r.exportName === comp.exportName)) continue;

                    const svgContent = generateSvgFile(comp);
                    const fileName = `${comp.name}.svg`;
                    const outputPath = path.join(ASSETS_DIR, fileName);
                    writeFile(outputPath, svgContent);

                    const relativeFile = path.relative(SRC_DIR, iconFile);
                    console.log(`  ✅ ${relativeFile}: ${comp.exportName} → assets/${fileName} (${comp.width}x${comp.height})`);

                    results.push({
                        ...comp,
                        fileName,
                        outputPath,
                        sourceFile: iconFile,
                        isLocal: false,
                    });
                }
            }
        }
    }

    if (results.length === 0) {
        console.log('  ℹ️  未找到 SVG 内联组件');
    } else {
        console.log(`  📊 实际生成的SVG组件: ${results.length}个`);
    }

    return results;
}

/**
 * 解析文件中的 SVG 组件，提取 viewBox、width、height 和 Path d 属性
 * 支持 export default 和 export const/function 两种导出格式
 */
function parseSvgComponents(filePath) {
    const content = readFile(filePath);
    const results = [];

    // 1. 先尝试匹配默认导出格式：export default ComponentName;
    const defaultExportRegex = /export\s+default\s+(\w+)/g;
    let match;

    while ((match = defaultExportRegex.exec(content)) !== null) {
        const exportName = match[1];

        // 查找对应的组件定义（const ComponentName = ... 或 function ComponentName ...）
        // 支持类型注解：const ComponentName: Type = ...
        const componentDefRegex = new RegExp('(const|function)\\s+' + exportName + '(?:\\s*:\\s*[^=]+)?\\s*[=(]');
        const defMatch = componentDefRegex.exec(content);

        if (defMatch) {
            const startIdx = defMatch.index;
            const nextExport = content.indexOf('\nexport ', startIdx + 1);
            const endIdx = nextExport === -1 ? content.length : nextExport;
            const componentCode = content.substring(startIdx, endIdx);

            // 必须包含 <Svg 标签才认为是 SVG 组件
            if (!componentCode.includes('<Svg')) continue;

            // 提取所有 Path 的 d 属性
            const paths = [];
            const pathRegex = /d="([^"]+)"/g;
            let pathMatch;
            while ((pathMatch = pathRegex.exec(componentCode)) !== null) {
                paths.push(pathMatch[1]);
            }

            if (paths.length === 0) continue;

            // 提取 width 和 height（优先从 const 变量、其次从 <Svg> 标签属性、最后使用默认值）
            let width = 24, height = 24; // 默认值

            const constWidthMatch = componentCode.match(/const\s+width\s*=\s*(\d+)/);
            const constHeightMatch = componentCode.match(/const\s+height\s*=\s*(\d+)/);
            if (constWidthMatch) width = parseInt(constWidthMatch[1]);
            if (constHeightMatch) height = parseInt(constHeightMatch[1]);

            // 如果没有 const 定义，尝试从 <Svg> 标签属性中提取
            if (!constWidthMatch || !constHeightMatch) {
                const svgTagMatch = componentCode.match(/<Svg[^>]*>/);
                if (svgTagMatch) {
                    const svgTag = svgTagMatch[0];
                    // 支持 width/sWidth 两种属性名
                    const svgWidthMatch = svgTag.match(/(?:s)?[Ww]idth=\{?(\d+)\}/);
                    const svgHeightMatch = svgTag.match(/(?:s)?[Hh]eight=\{?(\d+)\}/);
                    if (svgWidthMatch && !constWidthMatch) width = parseInt(svgWidthMatch[1]);
                    if (svgHeightMatch && !constHeightMatch) height = parseInt(svgHeightMatch[1]);
                }
                // 再尝试从 viewBox 中提取
                const viewBoxMatch = componentCode.match(/viewBox=["']([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)["']/);
                if (viewBoxMatch) {
                    if (!constWidthMatch && !componentCode.match(/<Svg[^>]*(?:s)?[Ww]idth=\{?\d+\}/)) {
                        width = parseInt(viewBoxMatch[3]);
                    }
                    if (!constHeightMatch && !componentCode.match(/<Svg[^>]*(?:s)?[Hh]eight=\{?\d+\}/)) {
                        height = parseInt(viewBoxMatch[4]);
                    }
                }
            }

            // 将驼峰命名转为蛇形命名用于文件名
            const name = exportName
                .replace(/^Icon/, 'icon_')
                .replace(/([A-Z])/g, '_$1')
                .toLowerCase()
                .replace(/^_/, '')
                .replace(/__/g, '_');

            results.push({
                exportName,
                name,
                width,
                height,
                paths,
            });
        }
    }

    // 2. 原有的匹配逻辑（保持兼容性）：export const Name = ... 和 export function Name ...
    // 支持类型注解：export const Name: Type = ...
    const componentRegex = /export\s+(?:const|function)\s+(\w+)(?:\s*:\s*[^=]+)?\s*[=(]/g;

    while ((match = componentRegex.exec(content)) !== null) {
        const exportName = match[1];
        const startIdx = match.index;

        // 找到这个组件的完整代码块（到下一个 export 或文件末尾）
        const nextExport = content.indexOf('\nexport ', startIdx + 1);
        const endIdx = nextExport === -1 ? content.length : nextExport;
        const componentCode = content.substring(startIdx, endIdx);

        // 必须包含 <Svg 标签才认为是 SVG 组件
        if (!componentCode.includes('<Svg')) continue;

        // 提取所有 Path 的 d 属性
        const paths = [];
        const pathRegex = /d="([^"]+)"/g;
        let pathMatch;
        while ((pathMatch = pathRegex.exec(componentCode)) !== null) {
            paths.push(pathMatch[1]);
        }

        if (paths.length === 0) continue;

        // 提取 width 和 height（优先从 const 变量、其次从 <Svg> 标签属性、最后使用默认值）
        let width = 24, height = 24; // 默认值

        const constWidthMatch = componentCode.match(/const\s+width\s*=\s*(\d+)/);
        const constHeightMatch = componentCode.match(/const\s+height\s*=\s*(\d+)/);
        if (constWidthMatch) width = parseInt(constWidthMatch[1]);
        if (constHeightMatch) height = parseInt(constHeightMatch[1]);

        // 如果没有 const 定义，尝试从 <Svg> 标签属性中提取
        if (!constWidthMatch || !constHeightMatch) {
            const svgTagMatch = componentCode.match(/<Svg[^>]*>/);
            if (svgTagMatch) {
                const svgTag = svgTagMatch[0];
                // 支持 width/sWidth 两种属性名
                const svgWidthMatch = svgTag.match(/(?:s)?[Ww]idth=\{?(\d+)\}/);
                const svgHeightMatch = svgTag.match(/(?:s)?[Hh]eight=\{?(\d+)\}/);
                if (svgWidthMatch && !constWidthMatch) width = parseInt(svgWidthMatch[1]);
                if (svgHeightMatch && !constHeightMatch) height = parseInt(svgHeightMatch[1]);
            }
            // 再尝试从 viewBox 中提取
            const viewBoxMatch = componentCode.match(/viewBox=["']([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)["']/);
            if (viewBoxMatch) {
                if (!constWidthMatch && !componentCode.match(/<Svg[^>]*(?:s)?[Ww]idth=\{?\d+\}/)) {
                    width = parseInt(viewBoxMatch[3]);
                }
                if (!constHeightMatch && !componentCode.match(/<Svg[^>]*(?:s)?[Hh]eight=\{?\d+\}/)) {
                    height = parseInt(viewBoxMatch[4]);
                }
            }
        }

        // 将驼峰命名转为蛇形命名用于文件名
        const name = exportName
            .replace(/^Icon/, 'icon_')
            .replace(/([A-Z])/g, '_$1')
            .toLowerCase()
            .replace(/^_/, '')
            .replace(/__/g, '_');

        results.push({
            exportName,
            name,
            width,
            height,
            paths,
        });
    }
    return results;
}

/**
 * 根据解析的组件数据生成 SVG 文件内容
 */
function generateSvgFile(comp) {
    const pathElements = comp.paths
        .map(d => `  <path d="${d}" fill="#000000"/>`)
        .join('\n');

    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${comp.width} ${comp.height}" width="${comp.width}" height="${comp.height}">
${pathElements}
</svg>
`;
}

/**
 * 查找源目录下引用了哪些外部目录的 SVG 图标组件
 * 支持相对路径和 @/ 别名路径
 * 返回 [{ iconFile, usedIcons }] 数组
 */
function findExternalIconImports() {
    const iconImports = {}; // iconFile → Set<iconName>
    const files = getAllSourceFiles(SRC_DIR);

    for (const file of files) {
        const content = readFile(file);
        // 匹配导入外部图标组件的语句
        // 例如: import { IconArrow, IconPlayAlbum } from '../../component/Icon'
        // 或:   import { IconArrow } from '@/component/Icon'
        const importRegex = /import\s*\{([^}]+)\}\s*from\s*['"]([^'"]+)['"]/g;
        let match;

        while ((match = importRegex.exec(content)) !== null) {
            const imports = match[1].split(',').map(s => s.trim()).filter(Boolean);
            const importPath = match[2];

            // 跳过第三方 npm 包（非相对路径且非 @/ 别名）
            if (!importPath.startsWith('.') && !importPath.startsWith('@/')) continue;
            if (importPath.startsWith('@') && !importPath.startsWith('@/')) continue;

            // 使用通用路径解析函数
            const resolved = resolveImportPath(importPath, file);
            if (!resolved) continue;

            // 只处理源目录外部的文件
            if (resolved.startsWith(SRC_DIR + path.sep) || resolved === SRC_DIR) continue;

            // 检查这个文件是否包含 SVG 组件定义
            const candidateContent = readFile(resolved);
            if (candidateContent.includes('react-native-svg') ||
                (candidateContent.includes('<Svg') && candidateContent.includes('<Path'))) {
                if (!iconImports[resolved]) {
                    iconImports[resolved] = new Set();
                }
                imports.forEach(name => iconImports[resolved].add(name));
            }
        }
    }

    return Object.entries(iconImports).map(([iconFile, icons]) => ({
        iconFile,
        usedIcons: [...icons],
    }));
}

// ==================== 3. 替换源代码中的引用 ====================

/**
 * 替换 base64 引用：将变量值替换为 require 本地图片
 */
function replaceBase64References(base64Assets) {
    console.log('\n🔄 [步骤3] 替换 base64 引用...');

    for (const asset of base64Assets) {
        let content = readFile(asset.sourceFile);
        const relativeAssetPath = path.relative(
            path.dirname(asset.sourceFile),
            asset.outputPath
        );

        const oldPattern = new RegExp(
            `(const|let|var)\\s+(${asset.varName})\\s*=\\s*['"\`]${escapeRegex(asset.fullDataUrl)}['"\`]`
        );

        const assetPath = relativeAssetPath.startsWith('.') ? relativeAssetPath : `./${relativeAssetPath}`;
        const newValue = `$1 ${asset.varName} = '${assetPath}'`;

        if (oldPattern.test(content)) {
            content = content.replace(oldPattern, newValue);
            fs.writeFileSync(asset.sourceFile, content);
            const relFile = path.relative(SRC_DIR, asset.sourceFile);
            console.log(`  ✅ ${relFile}: ${asset.varName} → '${assetPath}'`);
        }
    }
}

/**
 * 替换 SVG 组件引用：
 * - 删除 SVG 相关的 import
 * - 将 <IconXxx ... /> 替换为 <Image source={require('./assets/icon_xxx.svg')} ... />
 */
function replaceSvgReferences(svgAssets) {
    console.log('\n🔄 [步骤4] 替换 SVG 组件引用...');

    // 建立映射: exportName → { fileName, ... }
    const svgMap = {};
    for (const asset of svgAssets) {
        svgMap[asset.exportName] = asset;
    }

    const files = getAllSourceFiles(SRC_DIR);

    for (const file of files) {
        let content = readFile(file);
        let modified = false;

        // 检查文件中使用了哪些 SVG 图标
        const usedInFile = [];
        for (const exportName of Object.keys(svgMap)) {
            const usageRegex = new RegExp(`<${exportName}[\\s/>]`);
            if (usageRegex.test(content)) {
                usedInFile.push(exportName);
            }
        }

        if (usedInFile.length === 0) continue;

        const relFile = path.relative(SRC_DIR, file);

        for (const exportName of usedInFile) {
            const asset = svgMap[exportName];
            const relativeAssetPath = path.relative(
                path.dirname(file),
                asset.outputPath
            );
            const assetPath = relativeAssetPath.startsWith('.') ? relativeAssetPath : `./${relativeAssetPath}`;

            // 替换自闭合 JSX 标签（支持单行和多行）
            const selfCloseRegex = new RegExp(
                `<${exportName}([\\s\\S]*?)/>`,
                'g'
            );

            content = content.replace(selfCloseRegex, (match, attrs) => {
                const styleMatch = attrs.match(/style=(\{[^}]*\}|\{[^}]*\{[^}]*\}[^}]*\})/);
                // 提取 color 属性（支持 color={xxx}、color="xxx"、color={'xxx'} 等形式）
                const colorMatch = attrs.match(/\bcolor=(?:\{([^}]+)\}|['"]([^'"]+)['"])/);
                const colorValue = colorMatch ? (colorMatch[1] || `'${colorMatch[2]}'`) : null;

                // style 和 tintColor 是同级属性
                const styleAttr = styleMatch ? ` style=${styleMatch[1]}` : '';
                const tintColorAttr = colorValue ? ` tintColor={${colorValue}}` : '';

                return `<Image source={'${assetPath}'}${styleAttr}${tintColorAttr} />`;
            });

            // 替换非自闭合 JSX 标签：<ComponentName ... ></ComponentName>
            const nonSelfCloseRegex = new RegExp(
                `<${exportName}([\\s\\S]*?)></${exportName}>`,
                'g'
            );

            content = content.replace(nonSelfCloseRegex, (match, attrs) => {
                const styleMatch = attrs.match(/style=(\{[^}]*\}|\{[^}]*\{[^}]*\}[^}]*\})/);
                // 提取 color 属性（支持 color={xxx}、color="xxx"、color={'xxx'} 等形式）
                const colorMatch = attrs.match(/\bcolor=(?:\{([^}]+)\}|['"]([^'"]+)['"])/);
                const colorValue = colorMatch ? (colorMatch[1] || `'${colorMatch[2]}'`) : null;

                // style 和 tintColor 是同级属性
                const styleAttr = styleMatch ? ` style=${styleMatch[1]}` : '';
                const tintColorAttr = colorValue ? ` tintColor={${colorValue}}` : '';

                return `<Image source={'${assetPath}'}${styleAttr}${tintColorAttr} />`;
            });

            modified = true;
            console.log(`  ✅ ${relFile}: <${exportName} ... /> → <Image source={'${assetPath}'} />`);
        }

        if (modified) {
            // 清理不再需要的 SVG import 语句
            content = cleanupSvgImports(content, usedInFile, svgMap);

            // 确保有 Image 的 import
            content = ensureImageImport(content);

            fs.writeFileSync(file, content);
        }
    }
}

/**
 * 清理不再需要的 SVG import
 */
function cleanupSvgImports(content, replacedIcons, svgMap) {
    // 清理所有包含已替换图标的 import 语句
    // 通用匹配：import { ... } from '...' 中包含被替换图标的行
    const importRegex = /import\s*\{([^}]+)\}\s*from\s*(['"][^'"]+['"])\s*;?\n?/g;

    return content.replace(importRegex, (match, imports, modulePath) => {
        const importList = imports.split(',').map(s => s.trim()).filter(Boolean);
        const hasReplacedIcon = importList.some(name => replacedIcons.includes(name));

        if (!hasReplacedIcon) return match; // 不相关的 import，保留

        const remaining = importList.filter(name => !replacedIcons.includes(name));

        if (remaining.length === 0) {
            return ''; // 所有导入都被替换了，删除整行
        }

        return `import { ${remaining.join(', ')} } from ${modulePath};\n`;
    });
}

/**
 * 确保文件中有 Image 的 import
 * 如果 react-native 的 import 中没有 Image，则添加
 */
function ensureImageImport(content) {
    // 匹配常见的 react-native import 模式
    const reactNativeImportRegex = /import\s*\{([^}]+)\}\s*from\s*['"](@tencent\/react-native|react-native)['"];?/;
    const match = content.match(reactNativeImportRegex);

    if (match) {
        const imports = match[1].split(',').map(s => s.trim());
        if (!imports.includes('Image')) {
            const newImports = [...imports, 'Image'].join(', ');
            const moduleName = match[2];
            content = content.replace(reactNativeImportRegex, `import { ${newImports} } from '${moduleName}'`);
        }
    }

    return content;
}

// ==================== 辅助函数 ====================

/**
 * 递归获取目录下所有源文件（.tsx, .ts, .js, .jsx）
 * 排除 node_modules, scripts, assets 目录
 */
function getAllSourceFiles(dir) {
    const results = [];
    const excludeDirs = ['node_modules', 'scripts', 'assets', '.git'];

    function walk(currentDir) {
        const entries = fs.readdirSync(currentDir, { withFileTypes: true });
        for (const entry of entries) {
            if (excludeDirs.includes(entry.name)) continue;

            const fullPath = path.join(currentDir, entry.name);
            if (entry.isDirectory()) {
                walk(fullPath);
            } else if (/\.(tsx?|jsx?|js)$/.test(entry.name)) {
                results.push(fullPath);
            }
        }
    }

    walk(dir);
    return results;
}

/**
 * 转义正则特殊字符
 */
function escapeRegex(str) {
    return str.replace(/[.*+?^${}()|[\]\\\/]/g, '\\$&');
}

// ==================== 主流程 ====================

function main() {
    console.log('='.repeat(60));
    console.log('🚀 React Native 内联资源提取工具');
    console.log(`📁 源目录: ${SRC_DIR}`);
    console.log(`📁 项目根目录: ${PROJECT_ROOT}`);
    console.log(`📁 输出目录: ${ASSETS_DIR}`);
    console.log('='.repeat(60));

    ensureDir(ASSETS_DIR);

    // 步骤1: 提取 base64 资源
    const base64Assets = extractBase64Assets();

    // 步骤2: 提取 SVG 资源
    const svgAssets = extractSvgAssets();

    // 步骤3: 替换 base64 引用
    if (base64Assets.length > 0) {
        replaceBase64References(base64Assets);
    }

    // 步骤4: 替换 SVG 组件引用
    if (svgAssets.length > 0) {
        replaceSvgReferences(svgAssets);
    }

    // 汇总报告
    const totalAssets = base64Assets.length + svgAssets.length;
    console.log('\n' + '='.repeat(60));
    console.log('📊 提取完成汇总:');
    console.log(`  🖼  base64 图片: ${base64Assets.length} 个`);
    console.log(`  🎨 SVG 组件: ${svgAssets.length} 个`);
    console.log(`  📁 输出目录: ${ASSETS_DIR}`);
    console.log('='.repeat(60));

    // 输出 assets 目录内容
    if (fs.existsSync(ASSETS_DIR)) {
        const assetFiles = fs.readdirSync(ASSETS_DIR);
        if (assetFiles.length > 0) {
            console.log('\n📂 生成的资源文件:');
            for (const f of assetFiles) {
                const stats = fs.statSync(path.join(ASSETS_DIR, f));
                console.log(`  📄 ${f} (${stats.size} bytes)`);
            }
        }
    }

    if (totalAssets > 0) {
        console.log('\n💡 提示:');
        console.log('  - SVG 文件中的 fill 颜色默认为 #000000，实际使用时颜色由主题/代码动态控制');
        console.log('  - 替换后的 <Image> 组件保留了原始 style 属性');
        console.log('  - SVG 组件的 color 属性已自动转换为 Image 的 tintColor 样式');
        console.log('  - 请检查替换结果，确保功能正常');
    } else {
        console.log('\nℹ️  源代码中未发现内联资源，无需预处理');
    }

    // 返回退出码
    process.exit(totalAssets > 0 ? 0 : 0);
}

/**
 * 查找当前页面实际使用的SVG组件名称
 * 策略：先找出所有 SVG 组件定义，再检查它们是否被使用
 */
function findUsedIconsInCurrentPage() {
    const usedIcons = new Set();

    // 第一步：收集所有 SVG 组件定义（包括本地和外部）
    const localFiles = getAllSourceFiles(SRC_DIR);
    const externalFiles = collectExternalDependencies();
    const allFiles = [...localFiles, ...externalFiles];

    const svgComponentMap = {}; // exportName → filePath

    for (const file of allFiles) {
        const content = readFile(file);
        // 检测文件是否包含 SVG 组件定义
        if (!content.includes('<Svg') || !content.includes('<Path')) continue;

        // 解析该文件中的所有 SVG 组件
        const svgComponents = parseSvgComponents(file);
        for (const comp of svgComponents) {
            svgComponentMap[comp.exportName] = file;
        }
    }

    // 第二步：在源目录文件中查找这些 SVG 组件的使用
    for (const file of localFiles) {
        const content = readFile(file);

        for (const exportName of Object.keys(svgComponentMap)) {
            // 检查是否使用了这个 SVG 组件：<ComponentName ... />
            const usageRegex = new RegExp(`<${exportName}[\\s/>]`);
            if (usageRegex.test(content)) {
                usedIcons.add(exportName);
            }
        }
    }

    return [...usedIcons];
}

main();





