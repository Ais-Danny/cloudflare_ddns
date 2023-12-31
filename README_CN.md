# Cloudflare DDNS 动态域名解析

<h3  align="center"><a href="./README.md">[English] </a>/ 简体中文<br></h3>

<h1 align="center"> 

支持 ipv4/ipv6<br>
</h1>

## 1.准备参数获取
- API Token<br>
 进入<a>https://dash.cloudflare.com/profile/api-tokens</a>获取
 要求打开授予token DNS修改权限、ZONE和Zone Settings 读权限
- Email<br>
  登录cloudflare的邮箱
- ZONE_ID<br>
  区域ID（进入cloudflare，点击对应域名，再点击概述右下侧获取）

```shell
#进入https://dash.cloudflare.com/profile/api-tokens获取
TOKEN="aabbccddeeffgghhllmm"
#登录cloudflare的邮箱
EMAIL="12345678@gmail.com"
#区域ID（进入cloudflare，点击对应域名，再点击概述右下侧获取）
ZONE_ID="aabbccddeeffgghhllmm"
#要解析的域名（gmail.com or www.gmail.com）
DOMAIN="www.google.com"
# ip类型(A/AAAA)
TYPE="AAAA"
DAYS_TO_KEEP=7
```

## 2.设置定时任务
```shell
#执行
crontab -e
#填入
#每5分钟运行一次
*/5 * * * * /opt/script/cloudflare_ddns/cloudflare_ddns.sh>/dev/null 2>&1
```
## 3.注意
- 要解析的<font color=red>**域名必须已经存在**</font>
- 运行前请检测是否含有<font color=red>**curl**</font>命令和<font color=red>**jq**</font>命令
- 部分系统可能会出现curl命令使用异常（出现找不到证书的问题,openwrt可使用opkg install --force-reinstall ca-bundle修复)
- 因更新解析记录前只判断了ip和域名是否变化，若修改了其他配置，请删除data.json文件再次重启脚本