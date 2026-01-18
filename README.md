# sshwifty

<hr>

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
> **Note:** For additional configuration options and detailed descriptions, see the official configuration documentation.


