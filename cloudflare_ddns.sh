#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 配置文件路径
CONFIG_FILE="$SCRIPT_DIR/config.json"

# 其他配置（无需修改）
LOG_DIR="$SCRIPT_DIR/log"
NOW_IP_FILE="$SCRIPT_DIR/data.json"
DAYS_TO_KEEP=7

# 读取配置文件
read_config() {
    if [ -f "$CONFIG_FILE" ]; then
        TOKEN=$(jq -r '.TOKEN' "$CONFIG_FILE")
        DOMAIN=$(jq -r '.DOMAIN' "$CONFIG_FILE")
        NETWORK_INTERFACE=$(jq -r '.NETWORK_INTERFACE' "$CONFIG_FILE")
        CDN_PROXIED=$(jq -r '.CDN_PROXIED' "$CONFIG_FILE")
        TYPE=$(jq -r '.TYPE' "$CONFIG_FILE")
    else
        create_config
        read_config
    fi
}

# 创建配置文件
create_config() {
    cat > "$CONFIG_FILE" << EOF
{
    "TOKEN": "xxxx",
    "DOMAIN": "xxx.xxx.com",
    "NETWORK_INTERFACE": "",
    "CDN_PROXIED": false,
    "TYPE": "AAAA"
}
EOF
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] [INFO] Created config file: $CONFIG_FILE"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] [INFO] Please modify the parameters in the configuration file as needed"
}

# 自动获取的参数
ZONE_ID=""  # 将通过API自动获取
RECORD_ID=""  # 将通过API自动获取

exec 3>&1
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
# 写入日志
write_log() {
  local log_message="$1"
  echo -e "$log_message" >> "$LOG_FILE"
  echo -e "$log_message" >&3
}
# 获取当前IP地址
get_current_ip() {
  local ip_command="curl -s"
  # 只有当NETWORK_INTERFACE不为空时，才添加--interface参数
  if [ -n "$NETWORK_INTERFACE" ]; then
    ip_command="$ip_command --interface $NETWORK_INTERFACE"
  fi
  # 添加IP类型参数
  if [ "$TYPE" == "A" ]; then
    ip_command="$ip_command -4 ifconfig.me/ip"
  elif [ "$TYPE" == "AAAA" ]; then
    ip_command="$ip_command -6 ifconfig.me/ip"
  else
    echo "Invalid IP type specified. Use 'A' or 'AAAA'."
    exit 1
  fi

  local ip=$($ip_command)
  
  # 验证IP地址格式
  if [ "$TYPE" == "A" ]; then
    # 验证IPv4地址
    if ! [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      write_log "Invalid IPv4 address: $ip"
      return 1
    fi
  elif [ "$TYPE" == "AAAA" ]; then
    # 验证IPv6地址
    if ! [[ $ip =~ ^([0-9a-fA-F]{0,4}:){1,7}([0-9a-fA-F]{0,4})$ ]]; then
      write_log "Invalid IPv6 address: $ip"
      return 1
    fi
  fi
  echo $ip
  return 0
}

# 提取根域名（用于匹配Zone）
extract_root_domain() {
  local domain="$1"
  # 提取域名的最后两部分作为根域名（例如：git.aisdanny.top -> aisdanny.top）
  local root_domain=$(echo "$domain" | awk -F. '{print $(NF-1) "." $NF}')
  echo "$root_domain"
}

# 自动获取ZONE_ID
get_zone_id() {
  local root_domain=$(extract_root_domain "$DOMAIN")
  local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")
  local zone_id=$(echo "$response" | jq -r ".result[] | select(.name == \"$root_domain\" or .name == \"$DOMAIN\") | .id")
  
  if [ -z "$zone_id" ]; then
    write_log "Error: Could not find Zone ID for domain $DOMAIN"
    exit 1
  fi
  
  echo "$zone_id"
}

# 获取域名记录ID
get_record_id() {
  local zone_id="$1"
  local response=$(curl -s -G "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data-urlencode "name=$DOMAIN" \
    --data-urlencode "type=$TYPE")
  # 检查API请求是否成功
  local success=$(echo "$response" | jq -r ".success")
  if [ "$success" != "true" ]; then
    local errors=$(echo "$response" | jq -r ".errors[]")
    write_log "Error: Failed to query DNS records for $DOMAIN (type: $TYPE). Errors: $errors"
    return 1
  fi
  local record_id=$(echo "$response" | jq -r ".result[0].id")
  if [ -z "$record_id" ] || [ "$record_id" == "null" ]; then
    write_log "Warning: Could not find DNS record for $DOMAIN (type: $TYPE);Will be created automatically;"
    #return 0
  fi
  echo "$record_id"
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
  local timestamp=$(date +"%Y-%m-%d %T")
  echo "{\"ip\":\"$ip\",\"domain\":\"$domain\",\"timestamp\":\"$timestamp\"}" > "$NOW_IP_FILE"
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

# 获取所有必要的Cloudflare参数（ZONE_ID和RECORD_ID）
get_cloudflare_params() {
  echo "Getting Cloudflare parameters for domain: $DOMAIN"
  # 获取ZONE_ID
  ZONE_ID=$(get_zone_id)
  echo "Successfully obtained ZONE_ID: $ZONE_ID"
  # 使用ZONE_ID获取RECORD_ID
  if ! RECORD_ID=$(get_record_id "$ZONE_ID"); then
    exit 1
  fi
  echo "Successfully obtained RECORD_ID: $RECORD_ID"
}

# 执行一次主要功能
main() {
  # 读取配置文件
  read_config
  
  create_log_directory

  if ! IP=$(get_current_ip); then
      return 1
  fi
  local PREVIOUS_DATA=$(get_previous_data)
  local PREVIOUS_IP=$(echo "$PREVIOUS_DATA" | jq -r '.ip')
  local PREVIOUS_DOMAIN=$(echo "$PREVIOUS_DATA" | jq -r '.domain')

  #检查当前IP地址是否与之前的相同
  if [ "$IP" == "$PREVIOUS_IP" ] && [ "$DOMAIN" == "$PREVIOUS_DOMAIN" ]; then
    echo "IP address and domain have not changed. Skipping modification."
  else
    create_log_file
    # 获取Cloudflare参数
    get_cloudflare_params
    
    local ACTION_METHOD="PUT"
    local ACTION_URL="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID"
    if [ -z "$RECORD_ID" ] || [ "$RECORD_ID" == "null" ]; then
        ACTION_METHOD="POST"
        ACTION_URL="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"
    fi
    # 构建curl命令
    local curl_command="curl -s --location --request $ACTION_METHOD $ACTION_URL \
    --header 'Content-Type: application/json' \
    --header 'Authorization: Bearer $TOKEN' \
    --data-raw '{
      \"content\": \"$IP\",
      \"name\": \"$DOMAIN\",
      \"proxied\": $CDN_PROXIED,
      \"type\": \"$TYPE\",
      \"comment\": \"$(date)\",
      \"ttl\": 60
    }'"

    # 执行curl命令，并将结果保存到变量
    local response=$(eval "$curl_command")
    # 解析JSON数据
    local success=$(echo "$response" | jq -r '.success')

    # 写入日志
    local current_time=$(date +"%Y-%m-%d %T")
    if [ "$success" == "true" ]; then
      local log_message="[$current_time] Modification successful. IP: $IP"
      write_log "$log_message"
      # 保存当前IP地址和域名到JSON文件
      write_data "$IP" "$DOMAIN"
    else
      local error_code=$(echo "$response" | jq -r '.errors[0].code')
      local error_message=$(echo "$response" | jq -r '.errors[0].message')
      
      # 检查是否是"An identical record already exists."错误，如果是则忽略
      if [ "$error_code" == "81058" ] || [ "$error_message" == "An identical record already exists." ]; then
        echo "[$current_time] No modification needed. Record already exists with the same content."
        write_data "$IP" "$DOMAIN"
      else
        local errors=$(echo "$response" | jq -r '.errors[]')
        local log_message="[$current_time] Modification failed. Errors: $errors"
        write_log "$log_message \n ip:$IP"
      fi
    fi
  fi

  cleanup_old_logs
}

main
