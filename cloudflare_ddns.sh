#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#进入https://dash.cloudflare.com/profile/api-tokens获取（填的是API Token，中文叫API令牌，别填了下面的API Key，需要授予token DNS修改权限、ZONE和Zone Settings 读权限）
TOKEN=""
#登录cloudflare的邮箱
EMAIL=""
#区域ID（进入cloudflare，点击对应域名，再点击概述右下侧获取）
ZONE_ID=""
#要解析的域名（）
DOMAIN=""
# ip类型(A/AAAA)
TYPE="AAAA"
# 日志保留天数
DAYS_TO_KEEP=7

LOG_DIR="$SCRIPT_DIR/log"
NOW_IP_FILE="$SCRIPT_DIR/data.json"


# 创建日志目录
create_log_directory() {
  if [ ! -d "$LOG_DIR" ]; then
    mkdir "$LOG_DIR"
  fi
}

# 创建日志文件
create_log_file() {
  local current_date=$(date +"%Y-%m-%d")
  LOG_FILE="$LOG_DIR/modification_log_$current_date.log"
  touch "$LOG_FILE"
}

# 获取当前IP地址
get_current_ip() {
  local ip_command=""
  if [ "$TYPE" == "A" ]; then
    ip_command="curl -s -4 ifconfig.me/ip"
  elif [ "$TYPE" == "AAAA" ]; then
    ip_command="curl -s -6 ifconfig.me/ip"
  else
    echo "Invalid IP type specified. Use 'A' or 'AAAA'."
    exit 1
  fi

  $ip_command
}

# 获取域名id
get_domain_id() {
  local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "X-Auth-Email:$EMAIL" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")
  local domain_id=$(echo "$response" | jq -r ".result[] | select(.name == \"$DOMAIN\" and .type == \"$TYPE\") | .id")
  echo "$domain_id"
}

# 从JSON文件中读取之前保存的IP地址和域名
get_previous_data() {
  if [ -e "$NOW_IP_FILE" ]; then
    cat "$NOW_IP_FILE"
  else
    echo "{}"
  fi
}

# 写入JSON文件
write_data() {
  local ip="$1"
  local domain="$2"
  echo "{\"ip\":\"$ip\",\"domain\":\"$domain\"}" > "$NOW_IP_FILE"
}

# 写入日志
write_log() {
  local log_message="$1"
  echo "$log_message" >> "$LOG_FILE"
  echo "$log_message"
}

# 清理旧日志，保留最近7天
cleanup_old_logs() {
  # 获取当前时间的时间戳
  current_timestamp=$(date "+%s")

  find "$LOG_DIR" -type f -name "modification_log_*" -exec basename {} \; | awk -F_ '{print $3}' | while read -r log_date; do
    log_timestamp=$(date -d "$(echo "$log_date" | awk -F. '{print $1}' | awk -F- '{printf "%s-%s-%s", $1, $2, $3}')" "+%s" )
    if [ -n "$log_timestamp" ]; then
      # 计算7天前的时间戳
      cutoff_timestamp=$((current_timestamp - $DAYS_TO_KEEP * 24 * 60 * 60))
      if [ "$log_timestamp" -lt "$cutoff_timestamp" ]; then
        rm -f "$LOG_DIR/modification_log_$log_date"
      fi
    fi
  done
}

# 执行一次主要功能
main() {
  create_log_directory

  local IP=$(get_current_ip)
  local PREVIOUS_DATA=$(get_previous_data)
  local PREVIOUS_IP=$(echo "$PREVIOUS_DATA" | jq -r '.ip')
  local PREVIOUS_DOMAIN=$(echo "$PREVIOUS_DATA" | jq -r '.domain')

  #检查当前IP地址是否与之前的相同
  if [ "$IP" == "$PREVIOUS_IP" ] && [ "$DOMAIN" == "$PREVIOUS_DOMAIN" ]; then
    echo "IP address and domain have not changed. Skipping modification."
  else
    create_log_file
    DOMAIN_ID=$(get_domain_id)
    # 构建curl命令
    local curl_command="curl -s --location --request PUT 'https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DOMAIN_ID' \
    --header 'X-Auth-Email: $EMAIL' \
    --header 'Content-Type: application/json' \
    --header 'Authorization: Bearer $TOKEN' \
    --data-raw '{
      \"content\": \"$IP\",
      \"name\": \"$DOMAIN\",
      \"proxied\": false,
      \"type\": \"$TYPE\",
      \"comment\": \"$(date)\",
      \"ttl\": 60
    }'"

    local response=$(eval "$curl_command")
    local success=$(echo "$response" | jq -r '.success')

    # 写入日志
    local current_time=$(date +"%Y-%m-%d %T")
    if [ "$success" == "true" ]; then
      local log_message="[$current_time] Modification successful. IP: $IP"
      write_log "$log_message"
      # 保存当前IP地址和域名到JSON文件
      write_data "$IP" "$DOMAIN"
    else
      local errors=$(echo "$response" | jq -r '.errors[]')
      local log_message="[$current_time] Modification failed. Errors: $errors"
      write_log "$log_message"
    fi
  fi

  cleanup_old_logs
}

main
