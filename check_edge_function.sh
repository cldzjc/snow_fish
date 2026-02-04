#!/bin/bash
# Edge Function 部署验证脚本

echo "🔍 Edge Function 部署状态检查"
echo "================================"
echo ""

# 检查 Supabase CLI
echo "1️⃣  检查 Supabase CLI..."
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI 未安装"
    echo "   请运行: npm install -g @supabase/cli"
    exit 1
else
    echo "✅ Supabase CLI 已安装"
    supabase --version
fi

echo ""
echo "2️⃣  检查项目链接状态..."
if [ ! -f ".supabase/config.toml" ]; then
    echo "⚠️  项目未链接，请运行:"
    echo "   supabase link --project-ref YOUR_PROJECT_ID"
else
    echo "✅ 项目已链接"
fi

echo ""
echo "3️⃣  检查 Edge Function 文件..."
if [ -f "functions/get-oss-upload-url/index.ts" ]; then
    echo "✅ Edge Function 文件存在"
    echo "   路径: functions/get-oss-upload-url/index.ts"
    echo "   大小: $(wc -c < functions/get-oss-upload-url/index.ts) 字节"
else
    echo "❌ Edge Function 文件不存在"
    exit 1
fi

echo ""
echo "4️⃣  部署 Edge Function..."
echo "   运行: supabase functions deploy get-oss-upload-url"
echo ""
echo "部署完成后，检查 Supabase 控制台:"
echo "  1. Functions → get-oss-upload-url"
echo "  2. 点击 Settings 配置环境变量"
echo "  3. 点击 Logs 查看请求日志"
echo "  4. 点击 Invoke 测试函数"
echo ""
echo "🎯 函数部署验证清单:"
echo "   ☐ 函数显示为 'Deployed' 状态"
echo "   ☐ 配置了 4 个 OSS 环境变量"
echo "   ☐ 能在 Logs 中看到请求记录"
echo "   ☐ Invoke 返回 uploadUrl"
