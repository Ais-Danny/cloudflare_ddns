# Cloudflare DDNS Dynamic Domain Name Resolution

<h3  align="center"> English / <a href="./README_CN.md">[简体中文] </a><br></h3>


<h1 align="center"> 

Supports ipv4/ipv6<br>
</h1>

## 1. Prepare Parameters

- API Token<br>
  Obtain it by visiting [https://dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens).
  Grant the token with DNS modification permissions and read permissions for ZONE and Zone Settings.

- Email<br>
  Log in to the Cloudflare email account.

- ZONE_ID<br>
  Zone ID (Go to Cloudflare, click on the corresponding domain, and then click on Overview to find the ID on the bottom right).

```shell
# Obtain from https://dash.cloudflare.com/profile/api-tokens
TOKEN="aabbccddeeffgghhllmm"
# Log in to the Cloudflare email account
EMAIL="12345678@gmail.com"
# Zone ID (Go to Cloudflare, click on the corresponding domain, and then click on Overview to find the ID on the bottom right)
ZONE_ID="aabbccddeeffgghhllmm"
# Domain to be resolved (e.g., gmail.com or www.gmail.com)
DOMAIN="www.google.top"
# IP type (A/AAAA)
TYPE="AAAA"
DAYS_TO_KEEP=7
```

## 2. Set Up Scheduled Task
```shell
#Execute
crontab -e
#Insert
# Run every 5 minutes
*/5 * * * * /opt/script/cloudflare_ddns/cloudflare_ddns.sh >/dev/null 2>&1
```

## 3. Note
- The domain name to be resolved must already exist.