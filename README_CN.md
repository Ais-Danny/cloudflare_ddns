# Cloudflare DDNS 动态域名解析

<h3  align="center"><a href="./README.md">[English] </a>/ 简体中文<br></h3>

<h1 align="center"> 

支持 ipv4/ipv6<br>
</h1>

## 1. 功能特点
- ✅ 支持 IPv4 (A记录) 和 IPv6 (AAAA记录)
- ✅ 自动获取 ZONE_ID，无需手动配置
- ✅ 自动创建不存在的 DNS 记录
- ✅ 支持指定网络接口
- ✅ 支持 Cloudflare CDN 代理模式
- ✅ 自动清理旧日志（保留7天）
- ✅ 配置文件管理，方便修改参数

## 2. 依赖要求
- `curl` - 用于发送 HTTP 请求
- `jq` - 用于解析 JSON 数据

## 3. 配置说明

### 3.1 首次运行
直接运行脚本，会自动创建配置文件 `config.json`：

```shell
bash cloudflare_ddns.sh
```

### 3.2 配置文件参数
编辑自动生成的 `config.json` 文件，填入以下参数：

```json
{
    "TOKEN": "xxxx",              // Cloudflare API Token
    "DOMAIN": "xxx.xxx.com",     // 要解析的域名（如：www.example.com）
    "NETWORK_INTERFACE": "",      // 可选：指定网络接口（如：eth0、wlan0）
    "CDN_PROXIED": false,         // 是否启用 Cloudflare CDN 代理（true/false）
    "TYPE": "AAAA"               // IP 类型：A (IPv4) 或 AAAA (IPv6)
}
```

### 3.3 获取 API Token
进入 [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens) 获取，要求：
- 授予 DNS 修改权限
- 授予 ZONE 和 Zone Settings 读权限

## 4. 设置定时任务
使用 `crontab` 设置定时执行脚本：

```shell
# 编辑定时任务
crontab -e

# 每5分钟运行一次（根据需要调整时间间隔）
*/5 * * * * /path/to/cloudflare_ddns.sh >/dev/null 2>&1
```

## 5. 日志管理
- 日志文件位于 `log/` 目录下
- 自动清理7天前的旧日志
- 日志格式：`modification_log_YYYY-MM-DD.log`

## 6. 注意事项
- 确保脚本具有执行权限：`chmod +x cloudflare_ddns.sh`
- 首次运行会自动创建配置文件和日志目录
- 如果修改了配置文件，下次运行脚本会自动使用新配置
- 如果需要强制更新 DNS 记录，可以删除 `data.json` 文件后重新运行脚本
- 部分系统可能出现 curl 证书问题，OpenWrt 可使用 `opkg install --force-reinstall ca-bundle` 修复