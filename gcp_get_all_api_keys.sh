#!/bin/bash

# --- 配置 ---
# 定义输出文件的名称
OUTPUT_FILE="all_api_keys_FULL.csv"

echo "🔴 警告：此脚本将导出完整的、未加密的API密钥到文件 '$OUTPUT_FILE'。"
echo "这是一个高度敏感的文件，请务必妥善保管并及时删除！"
echo "脚本将在 5 秒后继续..."
sleep 5

# 写入CSV文件的表头 (会覆盖已存在的同名文件)
echo "project_id,display_name,uid,full_key_string,create_time" > "$OUTPUT_FILE"

echo ""
echo "正在获取您有权访问的所有项目列表..."
project_ids=($(gcloud projects list --format="value(projectId)"))

if [ ${#project_ids[@]} -eq 0 ]; then
  echo "未能找到任何项目，或者您没有权限列出项目。"
  exit 1
fi

total_projects=${#project_ids[@]}
current_project_num=0

echo "共找到 $total_projects 个项目。现在开始逐个获取完整的API密钥..."
echo "======================================================================"

# 循环遍历每个项目ID
for project_id in "${project_ids[@]}"
do
  ((current_project_num++))
  echo ""
  echo "--- [项目 $current_project_num / $total_projects] 正在处理项目: $project_id ---"

  # 检查并尝试启用相关API
  gcloud services enable serviceusage.googleapis.com --project="$project_id" &>/dev/null

  # 获取本项目中所有API密钥的ID和元数据。
  # `tail -n +2` 用于跳过gcloud csv输出的表头。
  api_keys_info=$(gcloud services api-keys list --project="$project_id" --format="csv(uid,displayName,createTime)")

  # 检查是否有密钥
  if [[ -z "$(echo "$api_keys_info" | tail -n +2)" ]]; then
      echo "在项目 $project_id 中未找到任何API密钥。"
      continue
  fi
  
  echo "在项目 $project_id 中找到密钥，正在获取完整密钥字符串..."
  
  # 使用 while read 循环处理每一行密钥信息
  echo "$api_keys_info" | tail -n +2 | while IFS=$',' read -r key_id display_name create_time; do
    
    # 对于每个key_id，调用命令获取完整的密钥字符串
    echo "  -> 获取密钥: $display_name ($key_id)"
    full_key_string=$(gcloud services api-keys get-key-string "$key_id" --project="$project_id")

    # 检查是否成功获取
    if [ -z "$full_key_string" ]; then
        full_key_string="<获取失败，请检查权限>"
    fi

    # 将所有信息组合成CSV格式的一行，并追加到输出文件中
    # 对每个字段加双引号，是更稳妥的CSV格式，防止内容中的逗号等特殊字符干扰
    echo "\"$project_id\",\"$display_name\",\"$key_id\",\"$full_key_string\",\"$create_time\"" >> "$OUTPUT_FILE"
  done
done

echo ""
echo "======================================================================"
echo "🎉 任务完成！"
echo "所有项目的【完整】API密钥信息已成功导出到 '$OUTPUT_FILE' 文件中。"
echo "请立即下载并将其移动到安全的位置，然后从Cloud Shell中删除它。"
