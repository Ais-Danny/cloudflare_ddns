# Cloudflare DDNS Dynamic Domain Name Resolution

<h3  align="center"> English / <a href="./README_CN.md">[简体中文] </a><br></h3>


<h1 align="center"> 

Supports ipv4/ipv6<br>
</h1>

## 1. Features
- ✅ Supports IPv4 (A record) and IPv6 (AAAA record)
- ✅ Automatically obtains ZONE_ID, no manual configuration required
- ✅ Automatically creates non-existent DNS records
- ✅ Supports specifying network interfaces
- ✅ Supports Cloudflare CDN proxy mode
- ✅ Automatically cleans up old logs (keeps 7 days)
- ✅ Configuration file management for easy parameter modification

## 2. Dependencies
- `curl` - Used for sending HTTP requests
- `jq` - Used for parsing JSON data

## 3. Configuration Instructions

### 3.1 First Run
Directly run the script, which will automatically create a configuration file `config.json`:

```shell
bash cloudflare_ddns.sh
```

### 3.2 Configuration File Parameters
Edit the automatically generated `config.json` file and fill in the following parameters:

```json
{
    "TOKEN": "xxxx",              // Cloudflare API Token
    "DOMAIN": "xxx.xxx.com",     // Domain to be resolved (e.g., www.example.com)
    "NETWORK_INTERFACE": "",      // Optional: Specify network interface (e.g., eth0, wlan0)
    "CDN_PROXIED": false,         // Whether to enable Cloudflare CDN proxy (true/false)
    "TYPE": "AAAA"               // IP type: A (IPv4) or AAAA (IPv6)
}
```

### 3.3 Obtain API Token
Obtain it by visiting [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens). Requirements:
- Grant DNS modification permissions
- Grant read permissions for ZONE and Zone Settings

## 4. Set Up Scheduled Task
Use `crontab` to set up a scheduled task to execute the script:

```shell
# Edit crontab
crontab -e

# Run every 5 minutes (adjust the interval as needed)
*/5 * * * * /path/to/cloudflare_ddns.sh >/dev/null 2>&1
```

## 5. Log Management
- Log files are located in the `log/` directory
- Automatically cleans up logs older than 7 days
- Log format: `modification_log_YYYY-MM-DD.log`

## 6. Notes
- Ensure the script has execution permissions: `chmod +x cloudflare_ddns.sh`
- The first run will automatically create a configuration file and log directory
- If the configuration file is modified, the script will automatically use the new configuration next time it runs
- If you need to force an update of DNS records, you can delete the `data.json` file and rerun the script
- Some systems may encounter curl certificate issues; for OpenWrt, you can use `opkg install --force-reinstall ca-bundle` to fix it