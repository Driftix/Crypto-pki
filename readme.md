
# 0. Pré-requis 
## **Mise en place FQDN**
**On accède au fichier hosts et on rajoute une ligne**
```shell
C:WINDOWS/system32/drivers/etc/hosts
```

**Voici la ligne que j'ai rajoutée pour que mon 127.0.0.1 soit accessible via guigui.com en plus de localhost**
```shell
127.0.0.1 guigui.com
```


# 1. Instantiation de la machine SSL avec alpine
**On se place en sh pour pouvoir faire les commandes nécessaires à l'installation de Nginx + configuration des clés et on expose les ports 80 pour http et 443 pour https**

```shell
docker run -it -p 80:80 -p 443:443 --name nginx-alpine-ssl alpine /bin/sh
```

# 2. Ajout des dépendences
**On a donc besoin de nginx, openssl, curl (pour nos tests) et nano (pour editer nos fichiers)**
```shell
apk add nginx
apk add openssl
apk add curl
apk add nano
```

# 3. Configuration de nginx

## a. Test de l'installation
**On peut vérifier que le dossier nginx est bien déjà créé (normalement c'est déjà le cas) !**
```shell
mkdir /run/nginx/
```
**On fait tourner le serveur nginx pour voir si on a bien une réponse**
```shell
nginx
curl localhost
```

**On devrait avoir le résultat suivant :**
```html
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx</center>
</body>
</html>
```

## b. Mise en place de la page

**On accède au fichier de conf de nginx dans d'ancienne version c'était conf.d mais maintenant c'est http.d**
```shell
nano /etc/nginx/http.d/default.conf
```
**Voici ce que vous devrez mettre en place sur ce fichier de conf:**
```conf
server {
        listen 80 default_server;
        listen [::]:80 default_server;
        location / {
                root /var/www/localhost/htdocs; #Ma ligne à rajouter
                # return 404;
        }
        location = /404.html {
                internal;
        }
}
```

**On relance nginx**
```shell
nginx -s reload
```
**On viens créer un fichier html sur le path où notre nginx a été configuré**

```shell
echo "<h1>Hello world!</h1>" > /var/www/localhost/htdocs/index.html;
```
## c. Test
**Vous pouvez tester la config avec une commande curl simple (ou via votre navigateur). Vous devriez avoir un joli "Hello world!"**

```shell
curl localhost
```


# 3. OpenSSL

**On viens générérer une clé et notre certificat avec 1000 jours de validitée et on passe plusieurs informations : informations de pays pays (C), l'État (ST), l'organisation (O), et le common name (CN). Le common Name est l'adresse que j'ai définie dans le pré-requis**

```shell
openssl req -x509 -nodes -days 1000 -subj "/C=FR/ST=Drôme/O=ESGI, Inc./CN=guigui.com" -addext "subjectAltName=DNS:guigui.com" -newkey rsa:2048 -keyout /etc/ssl/private/guigui.com.key -out /etc/ssl/certs/guigui.com.crt;
```

# 4. Modification de nginx pour SSL

**On retourne dans le fichier de conf nginx**
```shell
nano /etc/nginx/http.d/default.conf
```
**Et on rajoute des lignes pour que le fichier ressemble à ceci:**
```conf
server {
        listen 80 default_server;
        listen [::]:80 default_server;
        listen 443 ssl http2 default_server;
        listen [::]:443 ssl http2 default_server;
        ssl_certificate /etc/ssl/certs/guigui.com.crt;
        ssl_certificate_key /etc/ssl/private/guigui.com.key;
        # New root location
        location / {
                root /var/www/localhost/htdocs; 
                # return 404;
        }
        # You may need this to prevent return 404 recursion.
        location = /404.html {
                internal;
        }
}
```
**On vérifie que le fichier est valide**
```shell
nginx -t
```

**On restart nginx**

```shell
nginx -s reload
```

**On peut faire des tests**

```shell
curl https://localhost
curl https://localhost --insecure
```

# 5. Installation du certificat en local

**On commence par récupérer le certificat**
```shell
docker cp nginx-alpine-ssl:/etc/ssl/certs/guigui.com.crt ~/Desktop;
```

**Ensuite il faudra l'installer sur votre machine. En général, démarrez votre navigateur, ensuite paramètres, confidentialitée, sécuritée, gérer les certificats, importer un certificats, ajoutez votre fichier, faites bien attention à l'ajouter au root path, importer et VOILA**



# Extra
**En fait on aimerais bien pouvoir réutiliser ce certificat sans avoir à réimporter le cert pour accéder à notre site web non ? Donc tout ça ça veux dire : DOCKERFIIIIIILE**

* Sur mon pc je crée un dossier par exemple __pki__
* Dedans je met un dossier __guigui.com__
* Et dans __guigui.com__ je crée un dossier __config__

**Ensuite je récupère mes clés et mon fichier de config nginx**


```shell
docker cp nginx-alpine-ssl:/etc/ssl/certs/guigui.com.crt ~/pki/guigui.com/config;

docker cp nginx-alpine-ssl:/etc/ssl/private/guigui.com.key ~/pki/guigui.com/config;

docker cp nginx-alpine-ssl:/etc/nginx/conf.d/default.conf ~/pki/guigui.com/config;
```

* Création d'un fichier __Dockerfile__ dans mon dossier guigui.com

**Ici le contenu de mon DockerFile**

```dockerfile

FROM alpine
RUN apk add nginx; \
    mkdir /run/nginx/; \
    echo "<h1>Hello world!</h1>" > /var/www/localhost/htdocs/index.html;
ADD $PWD/config/default.conf /etc/nginx/conf.d/default.conf
# keys et  certs
ADD $PWD/config/*.key /etc/ssl/private/
ADD $PWD/config/*.crt /etc/ssl/certs/
WORKDIR /var/www/localhost/htdocs
# ENTRYPOINT
COPY $PWD/config/entrypoint.sh /usr/local/bin
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/bin/sh", "/usr/local/bin/entrypoint.sh"]
# EXPOSE PORTS
EXPOSE 80
EXPOSE 443
# RUN COMMAND
CMD ["/bin/sh", "-c", "nginx -g 'daemon off;'; nginx -s reload;"]

```

* On rajoute un entrypoint dans le dossier __guigui.com__

**Voici son contenu**
```dockerfile

cd /etc/nginx/conf.d;

export CRT="${CRT:=guigui.com.crt}";
if [ -f "/etc/ssl/certs/$CRT" ]
then
    #met le crt dans le fichier default.conf
    sed -i "/ssl_certificate \//c\\\tssl_certificate \/etc\/ssl\/certs\/$CRT;" default.conf;
fi
# On vérifie que le fichier key existe
export KEY="${KEY:=guigui.com.key}";
if [ -f "/etc/ssl/private/$KEY" ]
then
    # On rajoute les lignes dans le default.conf nginx
    sed -i "/ssl_certificate_key \//c\\\tssl_certificate_key \/etc\/ssl\/private\/$KEY;" default.conf;
fi
# On reload nginx
nginx -g 'daemon off;'; nginx -s reload;
```


# Final
**On build notre docker**
```shell
docker build . -t nginxssltest;
```
**Puis on peut le lancer**
```shell
docker run -it -d -p 80:80 -p 443:443 --name test nginxssltest;
```