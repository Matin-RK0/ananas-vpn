import 'dart:convert';

class XrayConfigConverter {
  static String convertToFullJson(String link) {
    if (link.startsWith('{')) return link;

    try {
      if (link.startsWith('vless://')) {
        return _convertVless(link);
      } else if (link.startsWith('vmess://')) {
        return _convertVmess(link);
      } else if (link.startsWith('trojan://')) {
        return _convertTrojan(link);
      }
    } catch (e) {
      print('Error converting link: $e');
    }
    
    return link;
  }

  static String _convertVless(String link) {
    final uri = Uri.parse(link);
    final uuid = uri.userInfo;
    final address = uri.host;
    final port = uri.port;
    final query = uri.queryParameters;
    
    String security = query['security'] ?? 'none';
    if (security.isEmpty) security = 'none';
    final hostHeader = query['host'] ?? '';
    final sni = query['sni'] ?? '';

    final streamSettings = {
      "network": query['type'] ?? 'tcp',
      if (security != 'none')
        "security": security,
      if (security == 'tls')
        "tlsSettings": {
          "serverName": (sni.isNotEmpty ? sni : (hostHeader.isNotEmpty ? hostHeader : address)),
          "fingerprint": query['fp'] ?? 'chrome',
          "alpn": query['alpn'] != null ? query['alpn']!.split(',') : ["h2", "http/1.1"]
        },
      if (security == 'reality')
        "realitySettings": {
          "show": false,
          "publicKey": query['pbk'] ?? '',
          "shortId": query['sid'] ?? '',
          "spiderX": query['spx'] ?? '/',
          "serverName": (sni.isNotEmpty ? sni : (hostHeader.isNotEmpty ? hostHeader : address)),
          "fingerprint": query['fp'] ?? 'chrome'
        },
      if (query['type'] == 'ws')
        "wsSettings": {
          "path": query['path'] ?? '/',
          "headers": {"Host": query['host'] ?? ''}
        },
      if (query['type'] == 'tcp' && query['headerType'] == 'http')
        "tcpSettings": {
          "header": {
            "type": "http",
            "request": {
              "version": "1.1",
              "method": "GET",
              "path": ["/"],
              "headers": {
                "Host": [query['host'] ?? ""],
                "User-Agent": ["Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36"],
                "Accept-Encoding": ["gzip, deflate"],
                "Connection": ["keep-alive"],
                "Pragma": "no-cache"
              }
            }
          }
        },
      if (query['type'] == 'grpc')
        "grpcSettings": {
          "serviceName": query['serviceName'] ?? '',
          "multiMode": true,
          "authority": query['authority'] ?? (sni.isNotEmpty ? sni : (hostHeader.isNotEmpty ? hostHeader : address))
        },
      if (query['type'] == 'h2')
        "httpSettings": {
          "path": query['path'] ?? '/',
          "host": [query['host'] ?? address]
        },
      if (query['type'] == 'quic')
        "quicSettings": {
          "security": query['quicSecurity'] ?? 'none',
          "key": query['key'] ?? '',
          "header": {
            "type": query['headerType'] ?? 'none'
          }
        },
      if (query['type'] == 'kcp')
        "kcpSettings": {
          "mtu": 1350,
          "tti": 10,
          "uplinkCapacity": 5,
          "downlinkCapacity": 20,
          "congestion": false,
          "readBufferSize": 1,
          "writeBufferSize": 1,
          "header": {
            "type": query['headerType'] ?? 'none'
          }
        }
    };

    return jsonEncode(_generateBaseConfig("vless", {
      "address": address,
      "port": port,
      "users": [
        {
          "id": uuid,
          "encryption": query['encryption'] ?? 'none',
          "flow": query['flow'] ?? ''
        }
      ]
    }, streamSettings));
  }

  static String _convertVmess(String link) {
    final base64Part = link.substring(8);
    final decoded = utf8.decode(base64.decode(base64.normalize(base64Part)));
    final data = jsonDecode(decoded);

    final streamSettings = {
      "network": data['net'] ?? 'tcp',
      "security": data['tls'] ?? 'none',
      if (data['tls'] == 'tls')
        "tlsSettings": {
          "serverName": data['sni'] ?? data['add'],
          "fingerprint": "chrome"
        },
      if (data['net'] == 'ws')
        "wsSettings": {
          "path": data['path'] ?? '/',
          "headers": {"Host": data['host'] ?? ''}
        },
      if (data['net'] == 'grpc')
        "grpcSettings": {
          "serviceName": data['path'] ?? '',
          "multiMode": true
        },
      if (data['net'] == 'h2')
        "httpSettings": {
          "path": data['path'] ?? '/',
          "host": [data['host'] ?? data['add']]
        }
    };

    return jsonEncode(_generateBaseConfig("vmess", {
      "address": data['add'],
      "port": int.parse(data['port'].toString()),
      "users": [
        {
          "id": data['id'],
          "alterId": int.parse((data['aid'] ?? 0).toString()),
          "security": "auto"
        }
      ]
    }, streamSettings));
  }

  static String _convertTrojan(String link) {
    final uri = Uri.parse(link);
    final password = uri.userInfo;
    final address = uri.host;
    final port = uri.port;
    final query = uri.queryParameters;
    
    String security = query['security'] ?? 'none';
    if (security.isEmpty) security = 'none';

    final streamSettings = {
      "network": query['type'] ?? 'tcp',
      "security": security,
      if (security == 'tls')
        "tlsSettings": {
          "serverName": query['sni'] ?? address,
          "fingerprint": query['fp'] ?? 'chrome'
        },
      if (security == 'reality')
        "realitySettings": {
          "show": false,
          "publicKey": query['pbk'] ?? '',
          "shortId": query['sid'] ?? '',
          "spiderX": query['spx'] ?? '/',
          "serverName": query['sni'] ?? address,
          "fingerprint": query['fp'] ?? 'chrome'
        },
      if (query['type'] == 'ws')
        "wsSettings": {
          "path": query['path'] ?? '/',
          "headers": {"Host": query['host'] ?? address}
        },
      if (query['type'] == 'grpc')
        "grpcSettings": {
          "serviceName": query['serviceName'] ?? '',
          "multiMode": true
        },
      if (query['type'] == 'h2')
        "httpSettings": {
          "path": query['path'] ?? '/',
          "host": [query['host'] ?? address]
        },
      if (query['type'] == 'quic')
        "quicSettings": {
          "security": query['quicSecurity'] ?? 'none',
          "key": query['key'] ?? '',
          "header": {
            "type": query['headerType'] ?? 'none'
          }
        }
    };

    return jsonEncode(_generateBaseConfig("trojan", {
      "address": address,
      "port": port,
      "password": password
    }, streamSettings));
  }

  static Map<String, dynamic> _generateBaseConfig(String protocol, Map<String, dynamic> settings, Map<String, dynamic> streamSettings) {
    return {
      "log": {"loglevel": "info"},
      "fakedns": [{"ipPool": "198.18.0.0/16", "poolSize": 65535}],
      "dns": {
        "servers": [
          "fakedns",
          "localhost"
        ],
        "queryStrategy": "UseIP"
      },
      "inbounds": [
        {
          "tag": "socks-in",
          "protocol": "socks",
          "listen": "127.0.0.1",
          "port": 10808,
          "settings": {
            "udp": true,
            "auth": "noauth"
          }
        },
        {
          "tag": "http-in",
          "protocol": "http",
          "listen": "127.0.0.1",
          "port": 10809,
          "settings": {
            "auth": "noauth"
          }
        },
        {
          "tag": "tun-in",
          "protocol": "tun",
          "settings": {
            "address": ["172.19.0.1/30"],
            "mtu": 1500,
            "stack": "gvisor"
          },
          "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls", "quic", "fakedns"],
            "routeOnly": true
          }
        }
      ],
      "outbounds": [
        {
          "protocol": protocol,
          "settings": {
            "vnext": protocol != "trojan" ? [
              {
                "address": settings['address'],
                "port": settings['port'],
                "users": settings['users']
              }
            ] : null,
            "servers": protocol == "trojan" ? [
              {
                "address": settings['address'],
                "port": settings['port'],
                "password": settings['password']
              }
            ] : null
          },
          "streamSettings": streamSettings,
          "tag": "proxy"
        },
        { "protocol": "freedom", "tag": "direct", "settings": {} },
        { "protocol": "dns", "tag": "dns-out" }
      ],
      "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
          { "type": "field", "port": 53, "outboundTag": "dns-out" },
          {
            "type": "field",
            "outboundTag": "direct",
            "domain": ["geosite:private"],
            "ip": ["geoip:private", "127.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
          },
          { "type": "field", "outboundTag": "proxy", "network": "tcp,udp" }
        ]
      }
    };
  }
}
