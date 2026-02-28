#!/bin/bash

# 仅允许非交互式运行，避免中途弹窗中断
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

echo "正在获取当前账号下的项目列表..."
PROJECTS=$(gcloud projects list --format="value(projectId)")

for PROJECT in $PROJECTS; do
    echo "========================================="
    echo "正在扫描项目: $PROJECT"
    
    # 获取项目下所有的 API Keys (隐藏标准错误输出，忽略未启用 API Keys 服务的项目)
    API_KEYS=$(gcloud services api-keys list --project="$PROJECT" --format="value(name)" 2>/dev/null)
    
    if [ -z "$API_KEYS" ]; then
        echo "  [跳过] 项目 $PROJECT 中未找到 API Keys，或无访问权限。"
        continue
    fi
    
    for KEY_NAME in $API_KEYS; do
        echo "  -> 发现 API Key: $KEY_NAME"
        echo "     正在应用限制规则: 仅限 Generative Language API..."
        
        # 更新 API Key 限制
        # --api-targets=service=generativelanguage.googleapis.com 对应控制台的 "限制密钥" -> 特定 API
        gcloud services api-keys update "$KEY_NAME" \
            --project="$PROJECT" \
            --api-targets=service=generativelanguage.googleapis.com \
            --quiet
            
        if [ $? -eq 0 ]; then
            echo "     [成功] 权限已成功收缩。"
        else
            echo "     [失败] 无法更新该密钥，请检查您的 IAM 权限 (需要 API Keys Admin 权限)。"
        fi
    done
done

echo "========================================="
echo "执行完毕：所有项目的 API Keys 已遍历并处理完成。"