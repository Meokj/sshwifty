<h1 align="center" >
    sshwifty
</h1>

> ⚠️ Warning
>
> **Do not provide Sshwifty service under a subpath of your domain** (e.g.`https://example.com/ssh`).  
> This is not standard and is **not officially supported**. It is recommended to access the service directly via the top-level domain.

* Installation
```
bash <(curl -Ls https://raw.githubusercontent.com/co2f2e/sshwifty/main/install.sh) install
```

* Uninstallation
```
bash <(curl -Ls https://raw.githubusercontent.com/co2f2e/sshwifty/main/uninstall.sh)
```

* ChangeLoginPassword
```
bash <(curl -Ls https://raw.githubusercontent.com/co2f2e/sshwifty/main/install.sh) passwd
```

* Nginx
```nginx
    location / {
        proxy_pass http://127.0.0.1:8182;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
```
> [!TIP]
> For more configuration file options and detailed explanations, please refer to the official configuration documentation.



